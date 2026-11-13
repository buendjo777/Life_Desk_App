import Foundation

extension ClassesImport {
    // MARK: Writing tutoring/

    /// Why the import must not write to this vault, or `nil` when it may.
    static func refusal(for vault: URL) -> String? {
        let path = vault.standardizedFileURL.path
        if path.contains("/demo-vault") { return "Desk never writes to the demo vault." }
        guard FileManager.default.fileExists(atPath: vault.appendingPathComponent(".git").path) else {
            return "\(path) is not a git vault."
        }
        guard (try? Git(root: vault).run(["check-ignore", "-q", "tutoring/XX.md"])) != nil else {
            return "tutoring/ is not in the vault's .gitignore, so the import could be committed. Add it first."
        }
        return nil
    }

    /// The month's last day, "2026-10" → "2026-10-31".
    static func monthEnd(_ month: String, cal: DeskCalendar) -> Date? {
        guard let first = Parse.day(month + "-01", cal) else { return nil }
        return cal.add(days: -1, to: cal.add(months: 1, to: first))
    }

    /// Writes every file from the sort, keeping what Desk or Jose recorded there: sent and paid dates, phone
    /// numbers, parents, subjects and how each student pays.
    static func write(_ result: Result, settings: Settings, to vault: URL, today: Date, cal: DeskCalendar) throws {
        let reader = VaultReader(root: vault)
        func save(_ path: String, _ text: String) throws {
            let url = vault.appendingPathComponent(path)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try text.write(to: url, atomically: true, encoding: .utf8)
        }
        let thisMonth = cal.monthKey(today)
        let recent = Set(Array(Set(result.rows.map(\.month))).sorted().suffix(max(1, settings.currentMonths)))
        let current = Set(result.current)

        // lessons.csv: everything, for History.
        var lessons = [Parse.lessonsHeader]
        for row in result.rows {
            let name = (result.names[row.code] ?? row.code).replacingOccurrences(of: ",", with: " ")
            lessons.append("\(row.month),\(row.code),\(name),\(row.lessons),\(Parse.number(row.hours)),\(row.rate.map(Parse.number) ?? ""),\(row.amount.map(Parse.number) ?? "")")
        }
        try save(lessonsFile, lessons.joined(separator: "\n") + "\n")

        // Payments for finished months; the sent and paid dates already recorded are kept.
        let existing = (Parse.payments(reader.text(VaultData.paymentsFile) ?? "", cal) + Parse.payments(reader.text(paymentsArchiveFile) ?? "", cal))
        let recorded = Dictionary(existing.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var term: [Payment] = []
        var archive: [Payment] = []
        for row in result.rows where row.month < thisMonth {
            guard let amount = row.amount else { continue }
            let id = "\(row.month)-\(row.code)"
            let paid = settings.paidThrough.map { row.month <= $0 } == true ? monthEnd(row.month, cal: cal) : nil
            let payment = Payment(month: row.month, initials: row.code, lessons: row.lessons, hours: row.hours, amount: amount,
                                  sent: recorded[id]?.sent ?? paid, paid: recorded[id]?.paid ?? paid)
            if recent.contains(row.month), current.contains(row.code) { term.append(payment) } else { archive.append(payment) }
        }
        // This month's invoices belong to Desk's month-end flow until the month is over.
        term += recorded.values.filter { $0.month >= thisMonth }.sorted { $0.id < $1.id }
        try save(VaultData.paymentsFile, Parse.paymentsCSV(term, cal))
        try save(paymentsArchiveFile, Parse.paymentsCSV(archive, cal))

        // students.md: current students; subject, level and payment method already there are kept.
        let known = Dictionary(Parse.students(reader.text(VaultData.studentsFile) ?? "").map { ($0.initials, $0) }, uniquingKeysWith: { first, _ in first })
        let latest = result.latestRate
        var students = ["| Initials | Level | Subject | Rate (€/h) | Pays by |", "|---|---|---|---|---|"]
        for c in result.current {
            let old = known[c]
            // A level Jose set in Desk wins over the note's group heading.
            let level = old?.level.isEmpty == false ? old?.level ?? "" : result.levels[c] ?? ""
            students.append("| \(c) | \(level) | \(old?.subject ?? "") | \(latest[c].map(Parse.number) ?? "") | \(old?.paysBy.isEmpty == false ? old?.paysBy ?? "" : "bank transfer") |")
        }
        try save(VaultData.studentsFile, students.joined(separator: "\n") + "\n")

        var former = ["# Former students", "", "No lessons in the last \(settings.currentMonths) months. Written by Desk from the Classes note.", "",
                      "| Student | Initials | Level | First month | Last month | Lessons | Last €/h |", "|---|---|---|---|---|---|---|"]
        for c in result.archived {
            let rows = result.rows.filter { $0.code == c }
            former.append("| \(result.names[c] ?? c) | \(c) | \(result.levels[c] ?? "") | \(rows.first?.month ?? "") | \(rows.last?.month ?? "") | \(rows.map(\.lessons).reduce(0, +)) | \(latest[c].map(Parse.number) ?? "?") |")
        }
        try save(studentsArchiveFile, former.joined(separator: "\n") + "\n")

        // contacts.json: names for the invoices; parents and phones already there are kept.
        var contacts = Parse.json([String: TutoringContact].self, reader.text(VaultData.tutoringContactsFile) ?? "", cal) ?? [:]
        for c in result.current {
            let name = result.names[c] ?? c
            let first = String(name.split(separator: " ").first ?? Substring(name))
            let parent = settings.parents.first { fold($0.key) == fold(name) || fold($0.key) == fold(first) }?.value ?? ""
            let old = contacts[c]
            contacts[c] = TutoringContact(parent: old?.parent.isEmpty == false ? old?.parent ?? "" : parent, student: first, phone: old?.phone ?? "")
        }
        try save(VaultData.tutoringContactsFile, Parse.contactsJSON(contacts))

        let dates = result.dates.sorted { ($0.date, $0.code) < ($1.date, $1.code) }
            .map { "\($0.date),\($0.code),\(Parse.number($0.hours))" }
        try save(lessonDatesFile, ([Parse.lessonDatesHeader] + dates).joined(separator: "\n") + "\n")

        try save(reviewFile, review(result))
    }

    /// The review: what to check, then each student and each month, with names written out.
    static func review(_ result: Result) -> String {
        let latest = result.latestRate
        var lines = ["# Tutoring, sorted by Desk from the Classes note", "",
                     "Each date is a one-hour lesson (x0.5, x1.5, x2 change its length). Rates: the number after a name when there is one; before that, the rate in import.json; otherwise one that fits the month's total; otherwise the student's previous rate.", "",
                     "## To check", ""]
        lines += result.checks.isEmpty ? ["Nothing."] : Array(Set(result.checks)).sorted().map { "- \($0)" }
        if result.recaps > 0 { lines.append("- \(result.recaps) month lists repeat lessons already counted (an invoice recap) and were not counted again.") }
        lines += ["", "## Students", "", "| Student | Level | From | To | Lessons | Hours | Earned | Latest €/h |", "|---|---|---|---|---|---|---|---|"]
        for c in result.current + result.archived {
            let rows = result.rows.filter { $0.code == c }
            lines.append("| \(result.names[c] ?? c)\(result.current.contains(c) ? "" : " (former)") | \(result.levels[c] ?? "") | \(rows.first?.month ?? "") | \(rows.last?.month ?? "") | \(rows.map(\.lessons).reduce(0, +)) | \(Parse.number(rows.map(\.hours).reduce(0, +))) | \(Parse.number(rows.compactMap(\.amount).reduce(0, +))) € | \(latest[c].map(Parse.number) ?? "?") |")
        }
        lines += ["", "## Months", "", "| Month | Student | Lessons | Hours | €/h | Amount |", "|---|---|---|---|---|---|"]
        for row in result.rows {
            lines.append("| \(row.month) | \(result.names[row.code] ?? row.code) | \(row.lessons) | \(Parse.number(row.hours)) | \(row.rate.map(Parse.number) ?? "?") | \(row.amount.map { Parse.number($0) + " €" } ?? "?") |")
        }
        return lines.joined(separator: "\n") + "\n"
    }

    /// One line for Desk's status: counts and euros only.
    static func summary(_ result: Result) -> String {
        let earned = result.rows.compactMap(\.amount).reduce(0, +)
        return "\(result.rows.map(\.lessons).reduce(0, +)) lessons, \(result.names.count) students, \(Parse.number(earned.rounded())) €; \(Set(result.checks).count) to check"
    }

    /// The command line's report: counts, euros and initials, never a name or a line of the note.
    static func report(_ result: Result) -> String {
        var lines = ["Classes: " + summary(result) + ".",
                     "\(result.current.count) current, \(result.archived.count) former; \(result.recaps) recap lists skipped; \(result.ignored) other lines ignored."]
        var years: [String: (lessons: Int, euros: Double)] = [:]
        for row in result.rows {
            let year = String(row.month.prefix(4))
            years[year, default: (0, 0)].lessons += row.lessons
            years[year, default: (0, 0)].euros += row.amount ?? 0
        }
        lines += years.keys.sorted().map { "\($0): \(years[$0]?.lessons ?? 0) lessons, \(Parse.number((years[$0]?.euros ?? 0).rounded())) €" }
        let rates = (result.current + result.archived).map { c -> String in
            var seen: [String] = []
            for row in result.rows where row.code == c {
                let rate = row.rate.map(Parse.number) ?? "?"
                if seen.last != rate { seen.append(rate) }
            }
            return "\(c) \(seen.joined(separator: "→"))"
        }
        lines.append("€/h: " + rates.joined(separator: "; "))
        lines += Array(Set(result.checks)).sorted().map { "- " + redact($0, names: result.names) }
        return lines.joined(separator: "\n")
    }

    /// A check with student names turned into initials and other names into their first letter.
    static func redact(_ check: String, names: [String: String]) -> String {
        var text = check
        for (code, name) in names.sorted(by: { $0.value.count > $1.value.count }) {
            text = text.replacingOccurrences(of: name, with: code)
        }
        return text.replacing(/\b\p{Lu}\p{Ll}+/) { String($0.output.first ?? "?") + "." }
    }
}
