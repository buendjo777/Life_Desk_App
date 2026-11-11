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

    init(prefs: Preferences? = nil, isSnapshot: Bool = false, demoVault: URL = DemoVault.url) {
        self.prefs = prefs ?? Preferences(defaults: nil)
        self.isSnapshot = isSnapshot
        self.demoVault = demoVault
        resolveMode()
        // In exam mode Studying is the first screen.
        tab = d.examMode ? .studying : .today
        selection = d.focus.first.map { .row($0.id) }
    }

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
        if next != mode {
            overlay = [:]
            addedEvents = []
        }
        mode = next
        reload()
    }

    private var reader: VaultReader {
        VaultReader(root: vaultURL, overlay: mode == .demo ? overlay : [:])
    }

    /// Re-reads the vault and recomputes everything. Demo pins the clock to `demo_today`.
    func reload() {
        var data = VaultData.load(reader)
        if mode == .demo { data.events += addedEvents }
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

    // MARK: Edits (Demo: memory only. Live: disk, added in step 11.)

    /// Saves `text` as the new content of a vault file, then reloads.
    private func save(_ path: String, _ text: String) {
        precondition(!path.hasPrefix("agent/"), "Desk never writes agent/")
        if mode == .demo {
            overlay[path] = text
        }
        reload()
    }

    /// Flips a Markdown checkbox in one of Jose's files.
    func toggleCheck(path: String, line: Int) {
        guard let text = reader.text(path), let updated = Parse.toggleCheckbox(in: text, line: line) else { return }
        save(path, updated)
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
        var text = reader.text(VaultData.decisionsFile) ?? ""
        if !text.isEmpty && !text.hasSuffix("\n") { text += "\n" }
        save(VaultData.decisionsFile, text + line + "\n")
    }

    /// Add (a proposed event) or Confirm (a proposed tick). Nothing happens without this click.
    func accept(_ row: SnapshotRow) {
        if row.action == "add_event", let event = row.event {
            // Title and times only: nothing else from the email reaches the calendar.
            addedEvents.append(CalEvent(id: "added-\(row.id)", calendar: "Desk", title: event.title,
                                        start: event.start.date, end: event.end.date, allDay: event.allDay ?? false))
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

    private func upsert(_ payment: Payment) {
        var payments = data.tutoring.payments
        if let index = payments.firstIndex(where: { $0.id == payment.id }) {
            payments[index] = payment
        } else {
            payments.append(payment)
        }
        save(VaultData.paymentsFile, Parse.paymentsCSV(payments, cal))
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

    // MARK: Sync (Live git sync arrives in step 13)

    func sync() {
        reload()
    }
}
