import Foundation

// The data contract from SPEC.md. Unknown fields are ignored; optional fields may be absent.
// JSON keys are snake_case and decoded with `.convertFromSnakeCase`.

// MARK: desk/settings.json

struct DeskSettings: Decodable {
    var name = "there"
    var timezone = TimeZone.current.identifier
    var scheduledRunLocal = "06:30"
    var exam: Exam?
    var tutoringCalendar = "Tutoring"
    var tutoringLocale = "es_ES"
    var currency = "EUR"
    var links = Links()
    /// Demo vault only: the pinned clock.
    var demoToday: String?

    struct Exam: Decodable {
        var title: String
        var file: String
        var modeStarts: String?
        var modeEnds: String?
    }

    struct Links: Decodable {
        var internshipBoard: String?
        var contactsBoard: String?
        var runNow: String?
    }

    init() {}

    enum CodingKeys: String, CodingKey {
        case name, timezone, scheduledRunLocal, exam, tutoringCalendar, tutoringLocale, currency, links, demoToday
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let fallback = DeskSettings()
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? fallback.name
        timezone = try c.decodeIfPresent(String.self, forKey: .timezone) ?? fallback.timezone
        scheduledRunLocal = try c.decodeIfPresent(String.self, forKey: .scheduledRunLocal) ?? fallback.scheduledRunLocal
        exam = try? c.decodeIfPresent(Exam.self, forKey: .exam)
        tutoringCalendar = try c.decodeIfPresent(String.self, forKey: .tutoringCalendar) ?? fallback.tutoringCalendar
        tutoringLocale = try c.decodeIfPresent(String.self, forKey: .tutoringLocale) ?? fallback.tutoringLocale
        currency = try c.decodeIfPresent(String.self, forKey: .currency) ?? fallback.currency
        links = (try? c.decodeIfPresent(Links.self, forKey: .links)) ?? Links()
        demoToday = try c.decodeIfPresent(String.self, forKey: .demoToday)
    }
}

// MARK: agent/snapshot.json

enum RowSection: String, Decodable {
    case run, deadline, today, confirm, event, draft, waiting, email, workout
}

/// One brief row written by the nightly agent. Its text is untrusted: draw it with `Text(verbatim:)`.
struct SnapshotRow: Decodable, Identifiable, Hashable {
    let id: String
    let section: RowSection
    var rank: Int?
    var title: String
    var detail: String?
    var when: Stamp?
    var source: String?
    var mode: String?
    var subject: String?
    var tag: String?
    var action: String?
    var event: RowEvent?
    var evidence: String?

    /// The Gmail thread id, when `source` is `Gmail <thread id>` and the id is plain hex.
    var gmailThread: String? {
        guard let source, source.hasPrefix("Gmail ") else { return nil }
        let id = String(source.dropFirst("Gmail ".count))
        return !id.isEmpty && id.allSatisfy(\.isHexDigit) ? id : nil
    }
}

struct RowEvent: Decodable, Hashable {
    var title: String
    var start: Stamp
    var end: Stamp
    var allDay: Bool?
}

// MARK: Other agent files

struct Run: Decodable, Identifiable, Hashable {
    var startedAt: Stamp
    var finishedAt: Stamp?
    var status: String
    var mode: String?
    var agents: [Agent]?
    var messagesScanned: Int?
    var drafts: Int?
    var usageNote: String?
    var failures: [String]?

    struct Agent: Decodable, Hashable {
        var name: String
        var model: String
    }

    var id: Date { startedAt.date }
    var isOK: Bool { status == "ok" }
    var duration: TimeInterval? { finishedAt.map { $0.date.timeIntervalSince(startedAt.date) } }
}

/// A reply draft from `agent/drafts/`. The body is untrusted text.
struct Draft: Identifiable, Hashable {
    var path: String
    var to: String
    var thread: String
    var status: String
    var created: Date?
    var body: String
    var id: String { path }
}

struct Activity: Decodable, Identifiable, Hashable {
    var id: String
    var date: Stamp
    var type: String
    var name: String
    var durationS: Int
    var distanceM: Double?
    var avgHr: Int?
}

// MARK: Jose's files

/// A Markdown checkbox, with the line it sits on so a tick can be written back.
struct Check: Identifiable, Hashable {
    var title: String
    var done: Bool
    var line: Int
    var id: Int { line }
}

struct TaskItem: Identifiable, Hashable {
    var title: String
    var section: String
    var done: Bool
    var due: Date?
    var line: Int
    var id: Int { line }
}

struct StudyFile {
    var exam: String
    var date: Date?
    var planPerDay: Int
    var planStart: Date?
    var theory: [Check]
    var problems: [Check]
    var papers: [Paper]
    /// Jose's own lists: every other `##` section with checkboxes, e.g. "This weekend — due 2026-11-15".
    var lists: [StudyList] = []

    struct Paper: Identifiable, Hashable {
        var title: String
        var done: Bool
        var date: Date?
        var score: Double?
        var outOf: Double?
        var line: Int
        var id: Int { line }
    }
}

/// A list in the study file: a `##` section other than Theory, Problems and Past papers, with an optional due day
/// ("This weekend — due 2026-11-15") and its `###` headings as groups.
struct StudyList: Identifiable, Hashable {
    var title: String
    var due: Date?
    var groups: [Group]
    var line: Int
    var id: Int { line }
    var items: [Check] { groups.flatMap(\.items) }
    var open: [Check] { items.filter { !$0.done } }

    struct Group: Identifiable, Hashable {
        var title: String
        var items: [Check]
        var line: Int
        var id: Int { line }
    }
}

enum ProjectStatus: String, CaseIterable, Identifiable {
    case active, waiting, frozen, idea
    var id: String { rawValue }
    var title: String { self == .idea ? "Ideas" : rawValue.capitalized }
}

struct Project: Identifiable, Hashable {
    var path: String
    var title: String
    var status: ProjectStatus
    var next: String
    var nextDate: Date?
    var doc: String?
    var items: [Check]
    var id: String { path }
}

struct UniProgramme: Identifiable, Hashable {
    var path: String
    var title: String
    var deadlineRow: String
    var comparisonHeading: String
    var items: [Check]
    var id: String { path }
}

struct Target: Decodable, Identifiable, Hashable {
    var id: String
    var company: String
    var role: String?
    var city: String?
    var country: String?
    var list: String
    var status: String
    var graduateOk: Bool?
    var deadline: Stamp?
    var next: String?
    var url: String?
    /// From the Internship Target Board: its own status words ("Not started"), and the posting's details.
    var statusLabel: String?
    var start: String?
    var duration: String?
    var language: String?
    var eligibility: String?
    var fit: String?
    var notes: String?
    /// The board's priority for a target ("A", "B", "C") and its order (an opening's, or a target's place).
    var priority: String?
    var order: Double?
    /// The entry's id in internships/board.json, for writing its status back; and the day the scan added it.
    var sourceID: String?
    var added: Date?
}

struct Person: Decodable, Identifiable, Hashable {
    var id: String
    var name: String
    var programme: String?
    var role: String?
    var status: String
    var lastContact: Stamp?
    var next: String?
    /// From the contacts board (`contacts/board.json`): its status words and the details behind each person.
    var statusLabel: String?
    var university: String?
    var lab: String?
    var why: String?
    var paper: String?
    var contactRoute: String?
    var notes: String?
    var url: String?
    var priority: String?
    var order: Double?
    var sourceID: String?
}

/// One click, appended to `desk/decisions.jsonl`.
struct Decision: Decodable, Hashable {
    var at: Stamp
    var row: String
    var action: String

    enum Action: String {
        case add, dismiss, confirm, reopen
    }
}

struct CalEvent: Identifiable, Hashable {
    var id: String
    var calendar: String
    var title: String
    var start: Date
    var end: Date
    var allDay: Bool
    var location: String?
}

extension CalEvent: Decodable {
    enum CodingKeys: String, CodingKey {
        case id, calendar, title, start, end, allDay, location
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        calendar = try c.decodeIfPresent(String.self, forKey: .calendar) ?? ""
        title = try c.decode(String.self, forKey: .title)
        start = try c.decode(Stamp.self, forKey: .start).date
        end = try c.decode(Stamp.self, forKey: .end).date
        allDay = try c.decodeIfPresent(Bool.self, forKey: .allDay) ?? false
        location = try c.decodeIfPresent(String.self, forKey: .location)
    }
}

// MARK: tutoring/ (local only)

struct Student: Identifiable, Hashable {
    var initials: String
    var level: String
    var subject: String
    var rate: Double
    var paysBy: String
    var id: String { initials }
}

struct Payment: Identifiable, Hashable {
    var month: String
    var initials: String
    var lessons: Int
    var hours: Double
    var amount: Double
    var sent: Date?
    var paid: Date?
    var id: String { "\(month)-\(initials)" }

    enum Status: String {
        case notSent = "Not sent", sent = "Sent", paid = "Paid"
    }

    var status: Status { paid != nil ? .paid : sent != nil ? .sent : .notSent }
}

/// The only record with names and a phone number. It never leaves the Mac.
struct TutoringContact: Codable, Hashable {
    var parent: String
    var student: String
    var phone: String
}

struct LessonNote: Hashable {
    var date: Date
    var text: String
}

/// `tutoring/lessons.csv`, written by Desk from the Classes note: one row per month and student.
struct LessonRow: Hashable {
    var month: String
    var initials: String
    var student: String
    var lessons: Int
    var hours: Double
    var rate: Double?
    var amount: Double?
}

/// `tutoring/lesson-dates.csv`, written by Desk from the Classes note: one row per dated lesson.
struct LessonDate: Hashable {
    var date: Date
    var initials: String
    var hours: Double
}

struct Tutoring {
    var students: [Student] = []
    /// This term's invoices (`payments.csv`), the ones Desk marks sent and paid.
    var payments: [Payment] = []
    /// Earlier invoices (`payments-archive.csv`), written by the import.
    var archive: [Payment] = []
    var lessons: [LessonRow] = []
    var lessonDates: [LessonDate] = []
    var contacts: [String: TutoringContact] = [:]
    var notes: [String: [LessonNote]] = [:]
    var template = ""
    var reminderTemplate = ""
}
