import AppKit
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
    /// Live: changes waiting behind a git job, shown at once (path → text). Each path counts its waiting writes.
    @ObservationIgnored private var pendingText: [String: String] = [:]
    @ObservationIgnored private var pendingCount: [String: Int] = [:]
    /// Live: committed files changed since the last sync. They are synced together once ticking pauses.
    @ObservationIgnored private var dirty: Set<String> = []
    @ObservationIgnored private var syncTimer: Task<Void, Never>?
    @ObservationIgnored private var quitObserver: NSObjectProtocol?
    /// How long Desk waits after the last change before it commits and pushes.
    static let syncPause: Duration = .seconds(2)
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

    /// Internship apps: the status card Jose picked; the list below shows only that status.
    var targetFilter: String?

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
        quitObserver = NotificationCenter.default.addObserver(forName: NSApplication.willTerminateNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.commitBeforeQuit() }
        }
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
        VaultReader(root: demoVault).text(VaultData.portfolioFile).flatMap { Parse.json(PortfolioInfo.self, $0, showcase.cal) }
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
        pendingText = [:]
        pendingCount = [:]
        dirty = []
        syncTimer?.cancel()
        syncTimer = nil
        epoch += 1
        mode = next
        git = next == .live ? VaultGit(root: prefs.vaultURL) : nil
        reload()
    }

    /// After a change in Settings: pick the mode again and, in Live, pull, load the calendar and read the
    /// Classes note at once.
    func settingsChanged() {
        resolveMode()
        sync()
        importClasses(explicit: false)
    }

    private var reader: VaultReader {
        VaultReader(root: vaultURL, overlay: mode == .demo ? overlay : pendingText)
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
        d = derive(data, now: pinned ?? Date())
        if mode == .demo { lastSync = d.now.addingTimeInterval(-120) }
    }

    /// Everything derived from the vault at `now`, with the day's starting point for the tide: the first look
    /// of the day records what is open; later looks count today's ticks against it.
    private func derive(_ data: VaultData, now: Date) -> Derived {
        var derived = Derived(data: data, now: now)
        let day = derived.cal.isoDay(now)
        var start = prefs.dayStart
        if start?.day != day {
            start = DayStart(day: day, key: derived.paceNow.key, open: derived.paceNow.open)
        } else if let known = start, derived.open(forPace: known.key) > known.open {
            // Items were added during the day: the day's start grows with them.
            start?.open = derived.open(forPace: known.key)
        }
        if start != prefs.dayStart { prefs.dayStart = start }
        derived.dayStart = start.map { Derived.Pace(key: $0.key, open: $0.open) }
        return derived
    }

    /// Movement is on: not in snapshots, and not when switched off in Customise.
    var motion: Bool { !isSnapshot && prefs.motion }

    /// After Desk changed one file: re-parse just that file when it feeds one part of the model, else everything.
    private func reload(changed path: String) {
        var data = d.data
        guard data.refresh(path, from: reader) else { return reload() }
        d = derive(data, now: mode == .demo ? d.now : Date())
    }

    /// Live only: moves the clock forward. The demo clock stays pinned.
    func tick() {
        guard mode == .live else { return }
        d = derive(d.data, now: Date())
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
    /// The view changes at once. Live writes never overlap a running git operation: while one runs, the change
    /// is shown from memory and written when it ends. Commits and pushes wait for a pause in ticking (`syncPause`).
    private func edit(_ path: String, _ transform: @escaping (String) -> String?) {
        guard canWrite(path) else {
            banner = "Desk does not write \(path)."
            return
        }
        guard mode == .live else {
            // Demo never writes to disk.
            if let text = transform(reader.text(path) ?? "") {
                overlay[path] = text
                reload(changed: path)
            } else {
                banner = Self.stale(path)
                reload()
            }
            return
        }
        if busy == 0 {
            do {
                try applyLive(path, transform)
            } catch {
                banner = (error as? Refused)?.message ?? "Could not save \(path): \(error.localizedDescription)"
                return
            }
            if VaultWriter.isCommitted(path) { scheduleSync(path) }
        } else {
            guard let shown = transform(reader.text(path) ?? "") else {
                banner = Self.stale(path)
                return
            }
            pendingText[path] = shown
            pendingCount[path, default: 0] += 1
            reload(changed: path)
            enqueue(failure: "Could not save \(path)", isSync: false) { [weak self] _ in
                defer { self?.landed(path) }
                try self?.applyLive(path, transform)
                if VaultWriter.isCommitted(path) { self?.scheduleSync(path) }
            }
        }
    }

    /// A waiting write has run or failed. Once none is left for `path`, the view shows the file on disk again.
    private func landed(_ path: String) {
        pendingCount[path, default: 1] -= 1
        guard (pendingCount[path] ?? 0) <= 0 else { return }
        pendingCount[path] = nil
        pendingText[path] = nil
        reload(changed: path)
    }

    /// Commits and pushes once ticking pauses, so five quick ticks make one sync instead of five in a row.
    private func scheduleSync(_ path: String) {
        dirty.insert(path)
        syncTimer?.cancel()
        let queuedIn = epoch
        syncTimer = Task { [weak self] in
            try? await Task.sleep(for: Self.syncPause)
            guard !Task.isCancelled, let self, self.epoch == queuedIn else { return }
            self.flushSync()
        }
    }

    private func flushSync() {
        syncTimer?.cancel()
        syncTimer = nil
        let paths = dirty.sorted()
        dirty = []
        guard !paths.isEmpty else { return }
        enqueue(failure: "Saved locally, but the vault did not sync") { try await $0.commitAndSync(paths: paths) }
    }

    /// On quit: commit what was waiting for the pause, so no tick is left uncommitted. The next sync pushes it.
    func commitBeforeQuit() {
        guard mode == .live, !dirty.isEmpty, busy == 0 else { return }
        syncTimer?.cancel()
        let git = Git(root: prefs.vaultURL)
        guard git.busyReason() == nil else { return }
        for path in dirty.sorted() {
            _ = try? git.run(["add", "--", path])
            _ = try? git.run(["commit", "-m", VaultWriter.commitMessage(for: path), "--", path])
        }
        dirty = []
    }

    private static func stale(_ path: String) -> String {
        "\(path) changed on disk, so nothing was written. The view is reloaded; try again."
    }

    private func applyLive(_ path: String, _ transform: (String) -> String?) throws {
        // Demo never writes to disk, even if an edit was queued while the app was still Live.
        guard mode == .live else { throw Refused(message: "Not saved: Desk is no longer in Live mode.") }
        // The file on disk, not the view: a change waiting in `pendingText` is already in the view.
        guard let text = transform(VaultReader(root: prefs.vaultURL).text(path) ?? "") else {
            reload()
            throw Refused(message: Self.stale(path))
        }
        try VaultWriter.write(text, to: path, in: prefs.vaultURL, studyFile: data.settings.exam?.file)
        reload(changed: path)
    }

    /// Queues git work behind whatever is already running. A failure shows the banner. A sync (`isSync`) may
    /// pull other changes, so everything is re-read after it; a waiting write has already refreshed its file.
    private func enqueue(failure: String, isSync: Bool = true, _ work: @escaping (VaultGit) async throws -> Void) {
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
                self.finished(nil, queuedIn, isSync: isSync)
            } catch let refused as Refused {
                self.finished(refused.message, queuedIn, isSync: isSync)
            } catch {
                self.finished("\(failure). \(error.localizedDescription)", queuedIn, isSync: isSync)
            }
        }
    }

    private func finished(_ problem: String?, _ queuedIn: Int, isSync: Bool) {
        guard epoch == queuedIn else { return }
        busy -= 1
        banner = problem
        guard isSync else { return }
        if problem == nil { lastSync = Date() }
        reload()
    }

    /// Syncs what is waiting for the pause and waits for all queued git work (used by tests).
    func settle() async {
        repeat {
            if syncTimer != nil { flushSync() }
            await pending?.value
        } while syncTimer != nil
    }

    /// The title the model holds for a checkbox, used to check the line is still the same item.
    private func checkTitle(path: String, line: Int) -> String? {
        if path == VaultData.tasksFile { return data.tasks.first { $0.line == line }?.title }
        if path == data.settings.exam?.file, let study = data.study {
            return (study.theory + study.problems + study.lists.flatMap(\.items)).first { $0.line == line }?.title
                ?? study.papers.first { $0.line == line }?.title
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

    /// Sets a contact's status in `contacts/board.json`, in the board's own words.
    func setPersonStatus(_ person: Person, to status: String) {
        guard let id = person.sourceID else {
            banner = "This contact is not in contacts/board.json, so its status cannot be set here."
            return
        }
        edit(VaultData.contactsBoardFile) { Parse.setBoardStatus($0, id: id, status: status) }
    }

    // MARK: Student details (tutoring/, local, never committed)

    /// Sets a student's parent or phone in `contacts.json`, the only file with names and numbers.
    func updateContact(_ initials: String, parent: String? = nil, phone: String? = nil) {
        let cal = cal
        let first = String(d.studentName(initials).split(separator: " ").first ?? Substring(initials))
        edit(VaultData.tutoringContactsFile) { text in
            var contacts = Parse.json([String: TutoringContact].self, text, cal) ?? [:]
            var contact = contacts[initials] ?? TutoringContact(parent: "", student: first, phone: "")
            if let parent { contact.parent = parent.trimmingCharacters(in: .whitespacesAndNewlines) }
            if let phone { contact.phone = phone.trimmingCharacters(in: .whitespacesAndNewlines) }
            contacts[initials] = contact
            return Parse.contactsJSON(contacts)
        }
    }

    /// Sets a student's level, subject or payment method in `students.md`.
    func updateStudent(_ initials: String, level: String? = nil, subject: String? = nil, paysBy: String? = nil) {
        edit(VaultData.studentsFile) { Parse.updateStudentRow($0, initials: initials, level: level, subject: subject, paysBy: paysBy) }
    }

    // MARK: Internships (internships/board.json)

    /// Sets a posting's or target's status in the board, in the board's own words.
    func setTargetStatus(_ target: Target, to status: String) {
        guard let id = target.sourceID else {
            banner = "This list is not in internships/board.json, so its statuses cannot be set here."
            return
        }
        edit(VaultData.boardFile) { Parse.setBoardStatus($0, id: id, status: status) }
    }

    // MARK: Tutoring (tutoring/payments.csv: local, never committed)

    /// Changes one row of `payments.csv` in place; every other line is kept as it is.
    private func upsert(_ payment: Payment) {
        // The import rewrites payments.csv; a click during it could be lost.
        guard !importing else {
            banner = "Desk is reading the Classes note. Try again in a few seconds."
            return
        }
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

    // MARK: The Classes note (Notes → tutoring/, Live only)

    /// The last read of the Classes note: when, and its one-line result or why it failed.
    private(set) var importStatus: String?
    @ObservationIgnored private var importing = false
    @ObservationIgnored private var lastImport: Date?
    /// How often the 15-minute sync reads the note again; each read wakes Notes.
    static let importInterval: TimeInterval = 3 * 3600

    /// On the periodic sync: reads the note again once `importInterval` has passed since the last read.
    func importClassesIfDue() {
        guard let last = lastImport, Date().timeIntervalSince(last) >= Self.importInterval else { return }
        importClasses(explicit: false)
    }

    /// Live: reads the Classes note through Notes and rewrites `tutoring/` (gitignored, so no git). Runs on
    /// launch and on Sync Now, never on the 15-minute timer, because each read wakes Notes. A failure shows
    /// the banner only when Jose asked for the sync (⌘R).
    func importClasses(explicit: Bool) {
        guard mode == .live, !isSnapshot, !importing else { return }
        importing = true
        let vault = prefs.vaultURL
        let cal = cal
        let queuedIn = epoch
        Task { [weak self] in
            let outcome = await Task.detached(priority: .utility) { () -> (checks: Int, error: String?) in
                do {
                    return (Set(try ClassesImport.run(vault: vault, today: Date(), cal: cal).checks).count, nil)
                } catch {
                    return (0, error.localizedDescription)
                }
            }.value
            guard let self else { return }
            self.importing = false
            guard self.epoch == queuedIn, self.mode == .live else { return }
            let time = self.cal.format(Date(), "HH:mm")
            self.lastImport = Date()
            if let error = outcome.error {
                self.importStatus = "Not read from Notes at \(time): \(error)"
                if explicit { self.banner = "The Classes note was not imported. \(error)" }
            } else {
                self.importStatus = "Read from Notes at \(time)"
                    + (outcome.checks > 0 ? " · \(outcome.checks) to check in \(ClassesImport.reviewFile)" : "")
            }
            self.reload()
        }
    }

    // MARK: Sync

    /// Live: `git pull --ff-only`, then re-read the vault and the calendar. On failure, a banner:
    /// never a silently stale view. Demo: re-read the bundled vault.
    func sync() {
        guard mode == .live else {
            reload()
            return
        }
        // Changes waiting for the pause go first, so the pull never meets an uncommitted tick.
        if !dirty.isEmpty { flushSync() }
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
