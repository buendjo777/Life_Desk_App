import SwiftUI

enum Mode: String, Codable, CaseIterable, Identifiable {
    case demo, live
    var id: String { rawValue }
    var label: String { rawValue.uppercased() }
}

/// Something that can be highlighted, ticked with Space and opened in the inspector with Return.
enum DeskItem: Hashable {
    /// A snapshot row, by id.
    case row(String)
    /// A `TASKS.md` item, by line.
    case task(Int)
    /// A checkbox in the study file or a `uni/` file.
    case check(path: String, line: Int)
    case project(String)
    case uni(String)
    case target(String)
    case person(String)
    case student(String)
}

/// The app's single source of truth: the mode, the parsed vault, the clock and the selection.
@Observable
@MainActor
final class Store {
    let prefs: Preferences
    /// True while drawing offscreen snapshots: views swap AppKit-backed controls for stand-ins.
    let isSnapshot: Bool
    @ObservationIgnored private let demoVault: URL
    /// Live only: EventKit. `nil` in tests, snapshots and Demo.
    @ObservationIgnored private let calendar: CalendarSource?
    /// Live only: the vault's git queue.
    @ObservationIgnored private var git: VaultGit?
    /// The tail of the queued git work; `settle()` waits for it.
    @ObservationIgnored private var pending: Task<Void, Never>?
    /// Git jobs queued or running.
    @ObservationIgnored private var busy = 0
    /// Bumped whenever the mode or the vault changes; queued work from an older epoch is dropped.
    @ObservationIgnored private var epoch = 0
    /// Live calendar events, refreshed on sync.
    @ObservationIgnored private var liveEvents: [CalEvent] = []
    /// Why the live calendar is empty, if it is.
    private(set) var calendarHint: String?

    var tab: Tab = .today
    private(set) var mode: Mode = .demo
    /// The vault and everything derived from it at `now`.
    private(set) var d = Derived(data: VaultData(), now: Date())
    /// The highlighted item. The inspector shows it while `inspectorOpen`.
    var selection: DeskItem?
    var inspectorOpen = false
    var banner: String?
    /// The day shown in the timeline; `nil` means today.
    var selectedDay: Date?
    private(set) var lastSync: Date?

    var query = ""
    var searchScope = Derived.SearchScope.all
    /// Bumped by ⌘F; the search field takes focus when it changes.
    var searchFocus = 0
    var showCustomise = false

    /// Demo "writes" live here and never reach the disk.
    @ObservationIgnored private var overlay: [String: String] = [:]
    /// Events added from proposals in Demo mode (memory only).
    @ObservationIgnored private var addedEvents: [CalEvent] = []
    /// The last proposal decided in this session, for Undo.
    private(set) var lastDecided: String?

    init(prefs: Preferences? = nil, isSnapshot: Bool = false, demoVault: URL = DemoVault.url, calendar: CalendarSource? = nil) {
        self.prefs = prefs ?? Preferences(defaults: nil)
        self.isSnapshot = isSnapshot
        self.demoVault = demoVault
        self.calendar = calendar
        resolveMode()
        // In exam mode Studying is the first screen.
        tab = d.examMode ? .studying : .today
        selection = d.focus.first.map { .row($0.id) }
    }

    /// The Portfolio screen's data: always the bundled demo vault at its pinned clock, never the live vault.
    @ObservationIgnored private(set) lazy var showcase: Derived = {
        let data = VaultData.load(VaultReader(root: demoVault))
        return Derived(data: data, now: Parse.day(data.settings.demoToday, data.cal) ?? Date())
    }()
    @ObservationIgnored private(set) lazy var portfolio: PortfolioInfo? = {
        VaultReader(root: demoVault).text("desk/portfolio.json").flatMap { Parse.json(PortfolioInfo.self, $0, showcase.cal) }
    }()

    var data: VaultData { d.data }
    var now: Date { d.now }
    var cal: DeskCalendar { d.cal }
    var vaultURL: URL { mode == .live ? prefs.vaultURL : demoVault }
    var vaultName: String { vaultURL.lastPathComponent }
    var inspector: DeskItem? { inspectorOpen ? selection : nil }

    // MARK: Loading

    /// Demo is the default until a live vault path is set and exists. Snapshots are always Demo.
    func resolveMode() {
        let next: Mode = !isSnapshot && prefs.wantsLive && prefs.vaultExists ? .live : .demo
        overlay = [:]
        addedEvents = []
        liveEvents = []
        banner = nil
        lastSync = nil
        busy = 0
        pending = nil
        epoch += 1
        mode = next
        git = next == .live ? VaultGit(root: prefs.vaultURL) : nil
        reload()
    }

    /// After a change in Settings: pick the mode again and, in Live, pull and load the calendar at once.
    func settingsChanged() {
        resolveMode()
        sync()
    }

    private var reader: VaultReader {
        VaultReader(root: vaultURL, overlay: mode == .demo ? overlay : [:])
    }

    /// Re-reads the vault and recomputes everything. Demo pins the clock to `demo_today`.
    func reload() {
        var data = VaultData.load(reader)
        if mode == .demo {
            data.events += addedEvents
        } else {
            // `calendar/events.json` is a Demo stand-in; Live shows the Mac calendar only.
            data.events = liveEvents
        }
        let pinned = mode == .demo ? Parse.day(data.settings.demoToday, data.cal) : nil
        d = Derived(data: data, now: pinned ?? Date())
        if mode == .demo { lastSync = d.now.addingTimeInterval(-120) }
    }

    /// Live only: moves the clock forward. The demo clock stays pinned.
    func tick() {
        guard mode == .live else { return }
        d = Derived(data: d.data, now: Date())
    }

    // MARK: Selection

    func open(_ item: DeskItem) {
        selection = item
        inspectorOpen = true
    }

    func show(_ tab: Tab) {
        self.tab = tab
        inspectorOpen = false
    }

    /// Space: ticks the highlighted item, if it can be ticked.
    func tickSelection() {
        switch selection {
        case .row(let id):
            if let row = d.focus.first(where: { $0.id == id }) { toggleFocus(row) }
        case .task(let line):
            if let task = data.tasks.first(where: { $0.line == line }) { toggle(task) }
        case .check(let path, let line):
            toggleCheck(path: path, line: line)
        default:
            break
        }
    }

    // MARK: Edits (Demo: memory only. Live: disk, then commit, pull --rebase, push.)

    func canWrite(_ path: String) -> Bool {
        VaultWriter.isWritable(path, studyFile: data.settings.exam?.file)
    }

    /// An edit that was not written, with the sentence for the banner.
    private struct Refused: Error { let message: String }

    /// Changes one of Jose's files. `transform` gets the file's current text and returns the new
    /// text, or `nil` when the edit no longer applies (the file changed underneath).
    /// Live edits never overlap a running git operation: they wait behind it and re-read the file.
    private func edit(_ path: String, _ transform: @escaping (String) -> String?) {
        guard canWrite(path) else {
            banner = "Desk does not write \(path)."
            return
        }
        guard mode == .live else {
            // Demo never writes to disk.
            if let text = transform(reader.text(path) ?? "") {
                overlay[path] = text
            } else {
                banner = Self.stale(path)
            }
            reload()
            return
        }
        let message = VaultWriter.commitMessage(for: path)
        if busy == 0 {
            do {
                try applyLive(path, transform)
            } catch {
                banner = (error as? Refused)?.message ?? "Could not save \(path): \(error.localizedDescription)"
                return
            }
            if VaultWriter.isCommitted(path) {
                enqueue(failure: "Saved locally, but the vault did not sync") { try await $0.commitAndSync(path: path, message: message) }
            }
        } else {
            enqueue(failure: "Could not save \(path)") { [weak self] git in
                try self?.applyLive(path, transform)
                if VaultWriter.isCommitted(path) { try await git.commitAndSync(path: path, message: message) }
            }
        }
    }

    private static func stale(_ path: String) -> String {
        "\(path) changed on disk, so nothing was written. The view is reloaded; try again."
    }

    private func applyLive(_ path: String, _ transform: (String) -> String?) throws {
        // Demo never writes to disk, even if an edit was queued while the app was still Live.
        guard mode == .live else { throw Refused(message: "Not saved: Desk is no longer in Live mode.") }
        guard let text = transform(reader.text(path) ?? "") else {
            reload()
            throw Refused(message: Self.stale(path))
        }
        try VaultWriter.write(text, to: path, in: prefs.vaultURL, studyFile: data.settings.exam?.file)
        reload()
    }

    /// Queues git work behind whatever is already running. A failure shows the banner.
    private func enqueue(failure: String, _ work: @escaping (VaultGit) async throws -> Void) {
        guard let git else { return }
        let previous = pending
        let queuedIn = epoch
        busy += 1
        pending = Task { [weak self] in
            await previous?.value
            // The mode or the vault changed while this waited: drop it, write nothing.
            guard let self, self.epoch == queuedIn else { return }
            do {
                try await work(git)
                self.finished(nil, queuedIn)
            } catch let refused as Refused {
                self.finished(refused.message, queuedIn)
            } catch {
                self.finished("\(failure). \(error.localizedDescription)", queuedIn)
            }
        }
    }

    private func finished(_ problem: String?, _ queuedIn: Int) {
        guard epoch == queuedIn else { return }
        busy -= 1
        banner = problem
        if problem == nil { lastSync = Date() }
        reload()
    }

    /// Waits for queued git work (used by tests).
    func settle() async {
        await pending?.value
    }

    /// The title the model holds for a checkbox, used to check the line is still the same item.
    private func checkTitle(path: String, line: Int) -> String? {
        if path == VaultData.tasksFile { return data.tasks.first { $0.line == line }?.title }
        if path == data.settings.exam?.file, let study = data.study {
            return (study.theory + study.problems).first { $0.line == line }?.title ?? study.papers.first { $0.line == line }?.title
        }
        return (data.unis.first { $0.path == path }?.items ?? data.projects.first { $0.path == path }?.items)?.first { $0.line == line }?.title
    }

    /// Flips a Markdown checkbox in one of Jose's files.
    /// If the file changed since it was read, the item is found again by its title; a tick never
    /// lands on a different item.
    func toggleCheck(path: String, line: Int) {
        guard let title = checkTitle(path: path, line: line) else { return }
        edit(path) { Parse.toggleCheckbox(in: $0, line: line, expecting: title) }
    }

    func toggle(_ task: TaskItem) {
        toggleCheck(path: VaultData.tasksFile, line: task.line)
    }

    /// Ticking a Focus row ticks its task in `TASKS.md`; a row with no task is recorded as a click.
    func toggleFocus(_ row: SnapshotRow) {
        if let task = d.task(titled: row.title) {
            toggle(task)
        } else {
            decide(row.id, d.isDone(row) ? .reopen : .confirm)
        }
    }

    /// Appends one click to `desk/decisions.jsonl`, so the agent never re-proposes.
    func decide(_ rowID: String, _ action: Decision.Action) {
        func quoted(_ value: String) -> String {
            String(data: (try? JSONEncoder().encode(value)) ?? Data("\"\"".utf8), encoding: .utf8) ?? "\"\""
        }
        let line = "{\"at\": \(quoted(cal.isoStamp(now))), \"row\": \(quoted(rowID)), \"action\": \(quoted(action.rawValue))}"
        edit(VaultData.decisionsFile) { text in
            text + (text.isEmpty || text.hasSuffix("\n") ? "" : "\n") + line + "\n"
        }
    }

    /// Add (a proposed event) or Confirm (a proposed tick). Nothing happens without this click.
    func accept(_ row: SnapshotRow) {
        if row.action == "add_event" {
            // A proposal with no event cannot be added, and must not be recorded as a clean confirmation.
            guard let event = row.event else {
                banner = "This proposal has no event to add."
                return
            }
            // Title and times only: nothing else from the email reaches the calendar.
            if mode == .live {
                do {
                    guard let calendar else { throw Git.Failure(message: "The calendar is not available.") }
                    try calendar.add(title: event.title, start: event.start.date, end: event.end.date, allDay: event.allDay ?? false)
                    refreshCalendar()
                } catch {
                    banner = "Could not add the event: \(error.localizedDescription)"
                    return
                }
            } else {
                addedEvents.append(CalEvent(id: "added-\(row.id)", calendar: "Desk", title: event.title,
                                            start: event.start.date, end: event.end.date, allDay: event.allDay ?? false))
            }
            decide(row.id, .add)
        } else {
            if let task = d.task(titled: row.title), !task.done { toggle(task) }
            decide(row.id, .confirm)
        }
        lastDecided = row.id
    }

    func dismiss(_ row: SnapshotRow) {
        decide(row.id, .dismiss)
        lastDecided = row.id
    }

    /// Undo: puts the last decided proposal back in the queue.
    func reopenLast() {
        guard let id = lastDecided else { return }
        addedEvents.removeAll { $0.id == "added-\(id)" }
        decide(id, .reopen)
        lastDecided = nil
    }

    // MARK: Tutoring (tutoring/payments.csv: local, never committed)

    /// Changes one row of `payments.csv` in place; every other line is kept as it is.
    private func upsert(_ payment: Payment) {
        let cal = cal
        edit(VaultData.paymentsFile) { Parse.upsertPayment(payment, in: $0, cal) }
    }

    func markSent(_ payment: Payment) {
        var payment = payment
        payment.sent = d.today
        upsert(payment)
    }

    func markPaid(_ payment: Payment) {
        var payment = payment
        payment.paid = d.today
        upsert(payment)
    }

    // MARK: Sync

    /// Live: `git pull --ff-only`, then re-read the vault and the calendar. On failure, a banner:
    /// never a silently stale view. Demo: re-read the bundled vault.
    func sync() {
        guard mode == .live else {
            reload()
            return
        }
        enqueue(failure: "Sync failed, so this view may be stale") { try await $0.pull() }
        refreshCalendar()
    }

    /// Live: asks for calendar access once, then loads events around today.
    func refreshCalendar() {
        guard mode == .live, let calendar else { return }
        Task { [weak self] in
            let granted = await calendar.requestAccess()
            guard let self, self.mode == .live else { return }
            self.calendarHint = granted ? nil : "Calendar access is off: System Settings → Privacy & Security → Calendars → Desk."
            let today = Date()
            self.liveEvents = granted ? calendar.events(from: self.cal.add(days: -62, to: today), to: self.cal.add(days: 120, to: today)) : []
            self.reload()
        }
    }
}
