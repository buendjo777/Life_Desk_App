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
    /// Trusted Markdown from the `nini/` mirror, by path.
    var docs: [String: String] = [:]
    /// One-line hints for files that are missing or malformed, by path.
    var issues: [String: String] = [:]

    static let comparisonDoc = "nini/workbook-programme-comparison.md"
    static let deadlinesDoc = "nini/masters-deadlines-2027.md"
    static let snapshotFile = "agent/snapshot.json"
    static let runsFile = "agent/runs.jsonl"
    static let stravaFile = "agent/exports/strava.json"
    static let tasksFile = "TASKS.md"
    static let settingsFile = "desk/settings.json"
    static let decisionsFile = "desk/decisions.jsonl"
    static let eventsFile = "calendar/events.json"
    static let targetsFile = "internships/targets.json"
    static let peopleFile = "contacts/people.json"
    static let studentsFile = "tutoring/students.md"
    static let paymentsFile = "tutoring/payments.csv"
    static let tutoringContactsFile = "tutoring/contacts.json"

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
        for path in reader.list("nini", ext: "md") {
            data.docs[path] = reader.text(path)
        }
        if let text = data.docs[deadlinesDoc] { data.masterDeadlines = Parse.masterDeadlines(text, cal) }

        // Optional boards: absent until they move into the vault.
        if let text = reader.text(targetsFile) {
            data.targets = Parse.array(Target.self, text, cal) ?? []
            if Parse.array(Target.self, text, cal) == nil { malformed(targetsFile) }
        }
        if let text = reader.text(peopleFile) {
            data.people = Parse.array(Person.self, text, cal) ?? []
            if Parse.array(Person.self, text, cal) == nil { malformed(peopleFile) }
        }
        if let text = reader.text(decisionsFile) { data.decisions = Parse.lines(Decision.self, text, cal) }
        if let text = reader.text(eventsFile) { data.events = Parse.array(CalEvent.self, text, cal) ?? [] }

        if let text = read(studentsFile) { data.tutoring.students = Parse.students(text) }
        if let text = reader.text(paymentsFile) { data.tutoring.payments = Parse.payments(text, cal) }
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
}
