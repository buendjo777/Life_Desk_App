import Foundation

/// Reads vault files. An in-memory overlay shadows the disk, which is how Demo mode
/// "writes" without ever touching it.
struct VaultReader {
    let root: URL
    var overlay: [String: String] = [:]

    func text(_ path: String) -> String? {
        overlay[path] ?? (try? String(contentsOf: root.appendingPathComponent(path), encoding: .utf8))
    }

    /// Relative paths of the files in `folder` with the given extension, sorted.
    func list(_ folder: String, ext: String) -> [String] {
        let onDisk = (try? FileManager.default.contentsOfDirectory(atPath: root.appendingPathComponent(folder).path)) ?? []
        let paths = onDisk.filter { $0.hasSuffix("." + ext) }.map { "\(folder)/\($0)" }
        let overlaid = overlay.keys.filter { $0.hasPrefix(folder + "/") && $0.hasSuffix("." + ext) }
        return Set(paths).union(overlaid).sorted()
    }
}

/// Where the bundled demo vault lives: inside `Desk.app`, or the repo when run with `swift run`.
enum DemoVault {
    static let url: URL = {
        if let bundled = Bundle.main.resourceURL?.appendingPathComponent("demo-vault"),
           FileManager.default.fileExists(atPath: bundled.path) {
            return bundled
        }
        // Sources/Desk/Model/Vault.swift → the repo root.
        return URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("demo-vault")
    }()
}

/// Everything Desk reads from a vault, already parsed.
struct VaultData {
    var settings = DeskSettings()
    var cal = DeskCalendar(timeZone: TimeZone.current.identifier)
    var rows: [SnapshotRow] = []
    var runs: [Run] = []
    var drafts: [Draft] = []
    var activities: [Activity] = []
    var tasks: [TaskItem] = []
    var study: StudyFile?
    var projects: [Project] = []
    var unis: [UniProgramme] = []
    var masterDeadlines: [String: Stamp] = [:]
    /// `nil` when the file is absent: the tab then shows an Open board button.
    var targets: [Target]?
    var people: [Person]?
    var decisions: [Decision] = []
    /// Demo: `calendar/events.json`. Live: filled from EventKit by the store.
    var events: [CalEvent] = []
    var tutoring = Tutoring()
    /// Trusted Markdown from Jose's own docs (the two master's docs and each project's `doc:`), by path,
    /// with wikilinks already shown as plain text.
    var docs: [String: String] = [:]
    /// One-line hints for files that are missing or malformed, by path.
    var issues: [String: String] = [:]

    static let comparisonDoc = "Masters/Programme comparison.md"
    static let deadlinesDoc = "Masters/Deadlines 2027.md"
    static let snapshotFile = "agent/snapshot.json"
    static let runsFile = "agent/runs.jsonl"
    static let stravaFile = "agent/exports/strava.json"
    static let tasksFile = "TASKS.md"
    static let settingsFile = "desk/settings.json"
    static let decisionsFile = "desk/decisions.jsonl"
    static let eventsFile = "calendar/events.json"
    static let targetsFile = "internships/targets.json"
    /// Jose's internship board: "openings" (postings) and "targets" (companies and labs). Desk sets statuses in it;
    /// the Monday scan adds postings. Wins over the older `agent/board.json` export and targets.json.
    static let boardFile = "internships/board.json"
    static let agentBoardFile = "agent/board.json"
    static let peopleFile = "contacts/people.json"
    /// The master's contacts board in the vault; Desk sets statuses in it. Wins over people.json.
    static let contactsBoardFile = "contacts/board.json"
    static let studentsFile = "tutoring/students.md"
    static let paymentsFile = "tutoring/payments.csv"
    static let tutoringContactsFile = "tutoring/contacts.json"
    static let lessonsFile = "tutoring/lessons.csv"
    static let lessonDatesFile = "tutoring/lesson-dates.csv"
    static let paymentsArchiveFile = "tutoring/payments-archive.csv"

    /// The master doc's deadline for a programme, when its comparison heading or title names the same
    /// programme. Otherwise the agent's `deadline` row has the date.
    func masterDeadline(for programme: UniProgramme) -> Stamp? {
        masterDeadlines[Parse.nameKey(programme.comparisonHeading)] ?? masterDeadlines[Parse.nameKey(programme.title)]
    }

    func rows(_ section: RowSection) -> [SnapshotRow] {
        rows.filter { $0.section == section }.sorted { ($0.rank ?? .max) < ($1.rank ?? .max) }
    }

    /// The hint for an empty state, e.g. "agent/snapshot.json is missing."
    func hint(_ path: String) -> String? { issues[path] }
}

extension VaultData {
    /// Loads and parses every file. Never throws: problems become `issues`.
    static func load(_ reader: VaultReader) -> VaultData {
        var data = VaultData()

        func read(_ path: String) -> String? {
            let text = reader.text(path)
            if text == nil { data.issues[path] = "\(path) is missing." }
            return text
        }
        func malformed(_ path: String) { data.issues[path] = "\(path) could not be read." }

        if let text = read(settingsFile) {
            if let settings = Parse.json(DeskSettings.self, text, data.cal) { data.settings = settings } else { malformed(settingsFile) }
        }
        let cal = DeskCalendar(timeZone: data.settings.timezone)
        data.cal = cal

        if let text = read(snapshotFile) {
            if let rows = Parse.array(SnapshotRow.self, text, cal) { data.rows = rows } else { malformed(snapshotFile) }
        }
        if let text = read(runsFile) {
            data.runs = Parse.lines(Run.self, text, cal).sorted { $0.startedAt.date < $1.startedAt.date }
        }
        if let text = read(stravaFile) {
            if let activities = Parse.array(Activity.self, text, cal) { data.activities = activities } else { malformed(stravaFile) }
        }
        data.drafts = reader.list("agent/drafts", ext: "md").compactMap { path in
            reader.text(path).flatMap { Parse.draft(path: path, $0, cal) }
        }

        if let text = read(tasksFile) { data.tasks = Parse.tasks(text, cal) }
        if let exam = data.settings.exam, let text = read(exam.file) {
            data.study = Parse.study(text, cal)
            if data.study == nil { malformed(exam.file) }
        }
        data.projects = reader.list("projects", ext: "md").compactMap { path in
            reader.text(path).flatMap { Parse.project(path: path, $0, cal) }
        }
        data.unis = reader.list("uni", ext: "md").compactMap { path in
            reader.text(path).flatMap { Parse.uni(path: path, $0) }
        }
        let docPaths = Set([deadlinesDoc, comparisonDoc] + data.projects.compactMap(\.doc).filter(Parse.isTrustedDoc))
        for path in docPaths {
            if let text = reader.text(path) { data.docs[path] = ParseCache.plainDoc(path, text) }
        }
        for path in [deadlinesDoc, comparisonDoc] where data.docs[path] == nil {
            data.issues[path] = "\(path) is missing."
        }
        if let text = data.docs[deadlinesDoc] { data.masterDeadlines = ParseCache.masterDeadlines(text, cal) }

        // Optional boards: absent until they move into the vault.
        if let file = [boardFile, agentBoardFile].first(where: { reader.text($0) != nil }), let text = reader.text(file) {
            data.targets = Parse.board(text, cal)
            if data.targets == nil { malformed(file) }
        } else if let text = reader.text(targetsFile) {
            data.targets = Parse.array(Target.self, text, cal) ?? []
            if Parse.array(Target.self, text, cal) == nil { malformed(targetsFile) }
        }
        if let text = reader.text(contactsBoardFile) {
            data.people = Parse.contactsBoard(text, cal)
            if data.people == nil { malformed(contactsBoardFile) }
        } else if let text = reader.text(peopleFile) {
            data.people = Parse.array(Person.self, text, cal) ?? []
            if Parse.array(Person.self, text, cal) == nil { malformed(peopleFile) }
        }
        if let text = reader.text(decisionsFile) { data.decisions = Parse.lines(Decision.self, text, cal) }
        if let text = reader.text(eventsFile) { data.events = Parse.array(CalEvent.self, text, cal) ?? [] }

        if let text = read(studentsFile) { data.tutoring.students = Parse.students(text) }
        if let text = reader.text(paymentsFile) { data.tutoring.payments = Parse.payments(text, cal) }
        if let text = reader.text(lessonsFile) { data.tutoring.lessons = Parse.lessons(text) }
        if let text = reader.text(lessonDatesFile) { data.tutoring.lessonDates = Parse.lessonDates(text, cal) }
        if let text = reader.text(paymentsArchiveFile) { data.tutoring.archive = Parse.payments(text, cal) }
        if let text = reader.text(tutoringContactsFile) {
            data.tutoring.contacts = Parse.json([String: TutoringContact].self, text, cal) ?? [:]
        }
        for student in data.tutoring.students {
            if let text = reader.text("tutoring/notes/\(student.initials).md") {
                data.tutoring.notes[student.initials] = Parse.notes(text, cal)
            }
        }
        data.tutoring.template = reader.text("tutoring/template.md")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        data.tutoring.reminderTemplate = reader.text("tutoring/template-reminder.md")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return data
    }

    /// Re-reads one file Desk writes and updates only what it feeds: a tick costs one small file, not the vault.
    /// False when `path` is not one of those files; the caller then reloads everything.
    mutating func refresh(_ path: String, from reader: VaultReader) -> Bool {
        let text = reader.text(path)
        if path == Self.tasksFile {
            tasks = text.map { Parse.tasks($0, cal) } ?? []
        } else if path == Self.decisionsFile {
            decisions = text.map { Parse.lines(Decision.self, $0, cal) } ?? []
        } else if path == Self.paymentsFile {
            tutoring.payments = text.map { Parse.payments($0, cal) } ?? []
        } else if path == settings.exam?.file, let text, let parsed = Parse.study(text, cal) {
            study = parsed
        } else if path == Self.boardFile, let text, let board = Parse.board(text, cal) {
            targets = board
        } else if path == Self.contactsBoardFile, let text, let board = Parse.contactsBoard(text, cal) {
            people = board
        } else if let index = unis.firstIndex(where: { $0.path == path }), let text, let uni = Parse.uni(path: path, text) {
            unis[index] = uni
        } else {
            return false
        }
        return true
    }
}

/// The long docs (the programme comparison, the deadline table) are most of a reload's work and rarely change,
/// so the last parse of each is kept and reused while its text is the same.
enum ParseCache {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var docs: [String: (raw: String, plain: String)] = [:]
    nonisolated(unsafe) private static var deadlines: (raw: String, zone: String, result: [String: Stamp])?

    static func plainDoc(_ path: String, _ raw: String) -> String {
        lock.lock()
        if let hit = docs[path], hit.raw == raw {
            lock.unlock()
            return hit.plain
        }
        lock.unlock()
        let plain = Parse.plainWikilinks(raw)
        lock.lock()
        docs[path] = (raw, plain)
        lock.unlock()
        return plain
    }

    static func masterDeadlines(_ text: String, _ cal: DeskCalendar) -> [String: Stamp] {
        let zone = cal.calendar.timeZone.identifier
        lock.lock()
        if let hit = deadlines, hit.raw == text, hit.zone == zone {
            lock.unlock()
            return hit.result
        }
        lock.unlock()
        let result = Parse.masterDeadlines(text, cal)
        lock.lock()
        deadlines = (text, zone, result)
        lock.unlock()
        return result
    }
}
