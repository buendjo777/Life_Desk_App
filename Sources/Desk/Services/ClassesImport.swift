import Foundation

/// Jose's tutoring log is one Notes note, "Classes": month headings; under them each student's name, an
/// optional rate "(50)" and the lesson dates in brackets "(05/10)", with "x1.5" for 90 minutes; totals such
/// as "Total for October: 200€" or "TOTAL Brand: 150€"; and other text (bank details, budgets, messages) that
/// is ignored. Desk reads it from Notes and writes `tutoring/` (gitignored, never committed):
/// - lessons.csv: every month and student, for the History tab;
/// - payments.csv (this term) and payments-archive.csv, keeping the sent and paid dates Desk recorded;
/// - students.md (current students) and students-archive.md;
/// - contacts.json: names and parents for the invoices (phone numbers already there are kept);
/// - classes-review.md: what to check.
/// Jose's answers (default rates, families, parents, students to ignore, months already paid) are in
/// `tutoring/import.json`.
enum ClassesImport {
    static let settingsFile = "tutoring/import.json"
    static let lessonsFile = VaultData.lessonsFile
    static let paymentsArchiveFile = VaultData.paymentsArchiveFile
    static let lessonDatesFile = VaultData.lessonDatesFile
    static let studentsArchiveFile = "tutoring/students-archive.md"
    static let reviewFile = "tutoring/classes-review.md"

    struct Settings: Decodable {
        /// The rate while the note has no number for a student yet ("Nora": 40). A number in the note wins.
        var rates: [String: Double] = [:]
        /// Family → students, for totals like "Total for January (Vidal)".
        var families: [String: [String]] = [:]
        var parents: [String: String] = [:]
        var ignore: [String] = []
        /// Months up to this one ("2026-10") are paid.
        var paidThrough: String?
        /// Students with lessons in this many recent months are current; the others are archived.
        var currentMonths = 3
        /// How many months, counting this one, follow the note. Older months stay as Desk first wrote them.
        var refreshMonths = 2

        enum CodingKeys: String, CodingKey {
            case rates, families, parents, ignore, paidThrough = "paid_through", currentMonths = "current_months", refreshMonths = "refresh_months"
        }

        init() {}

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            rates = try c.decodeIfPresent([String: Double].self, forKey: .rates) ?? [:]
            families = try c.decodeIfPresent([String: [String]].self, forKey: .families) ?? [:]
            parents = try c.decodeIfPresent([String: String].self, forKey: .parents) ?? [:]
            ignore = try c.decodeIfPresent([String].self, forKey: .ignore) ?? []
            paidThrough = try c.decodeIfPresent(String.self, forKey: .paidThrough)
            currentMonths = try c.decodeIfPresent(Int.self, forKey: .currentMonths) ?? 3
            refreshMonths = max(1, try c.decodeIfPresent(Int.self, forKey: .refreshMonths) ?? 2)
        }

        static func load(_ text: String?) -> Settings {
            text.flatMap { try? JSONDecoder().decode(Settings.self, from: Data($0.utf8)) } ?? Settings()
        }
    }

    /// Reads the note from Notes, sorts it and, unless `write` is false, writes `tutoring/`.
    static func run(vault: URL, today: Date, cal: DeskCalendar, note: String? = nil, write: Bool = true) throws -> Result {
        if write, let refusal = refusal(for: vault) { throw NotesReader.Failure(message: refusal) }
        let settings = Settings.load(VaultReader(root: vault).text(settingsFile))
        let notes = try NotesReader.fetch(title: note).notes
        // "Classes" itself wins over other notes whose titles start with the word.
        let exact = notes.filter { ["classes", "clases"].contains(fold($0.title)) }
        let text = (exact.isEmpty ? notes : exact).map(\.body).joined(separator: "\n")
        let result = sort(parse(text), settings: settings, today: today, cal: cal)
        if write { try ClassesImport.write(result, settings: settings, to: vault, today: today, cal: cal) }
        return result
    }
}
