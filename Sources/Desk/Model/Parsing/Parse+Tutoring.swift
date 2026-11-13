import Foundation

/// The `tutoring/` files: students, payments, lessons and notes.
extension Parse {
    /// `students.md`: a table `Initials | Level | Subject | Rate (€/h) | Pays by`.
    static func students(_ text: String) -> [Student] {
        table(text).compactMap { row in
            guard let initials = row["Initials"], !initials.isEmpty else { return nil }
            let rate = row.first { $0.key.hasPrefix("Rate") }?.value ?? ""
            return Student(
                initials: initials, level: row["Level"] ?? "", subject: row["Subject"] ?? "",
                rate: Double(rate.replacingOccurrences(of: ",", with: ".")).flatMap { $0.isFinite ? $0 : nil } ?? 0, paysBy: row["Pays by"] ?? ""
            )
        }
    }

    static let paymentsHeader = "month,initials,lessons,hours,amount,sent,paid"

    /// `payments.csv`: `month,initials,lessons,hours,amount,sent,paid`.
    static func payments(_ text: String, _ cal: DeskCalendar) -> [Payment] {
        splitLines(text).dropFirst().compactMap { line in
            let cells = line.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            guard cells.count >= 5, cells[0].wholeMatch(of: /\d{4}-\d{2}/) != nil, !cells[1].isEmpty,
                  let lessons = Int(cells[2]), let hours = Double(cells[3]), let amount = Double(cells[4]),
                  hours.isFinite, amount.isFinite else { return nil }
            return Payment(
                month: cells[0], initials: cells[1], lessons: lessons, hours: hours, amount: amount,
                sent: cells.count > 5 ? day(cells[5], cal) : nil, paid: cells.count > 6 ? day(cells[6], cal) : nil
            )
        }
    }

    static let lessonsHeader = "month,initials,student,lessons,hours,rate,amount"
    static let lessonDatesHeader = "date,initials,hours"

    /// `contacts.json` as Desk and the import write it.
    static func contactsJSON(_ contacts: [String: TutoringContact]) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return ((try? encoder.encode(contacts)).map { String(decoding: $0, as: UTF8.self) } ?? "{}") + "\n"
    }

    /// Changes a student's level, subject or payment method in `students.md`, keeping the rate and every other row.
    static func updateStudentRow(_ text: String, initials: String, level: String? = nil, subject: String? = nil, paysBy: String? = nil) -> String? {
        var lines = splitLines(text)
        guard let index = lines.firstIndex(where: { $0.trimmingCharacters(in: .whitespaces).hasPrefix("| \(initials) |") }) else { return nil }
        let cells = lines[index].split(separator: "|", omittingEmptySubsequences: false).map { $0.trimmingCharacters(in: .whitespaces) }
        guard cells.count >= 7 else { return nil }
        func clean(_ value: String) -> String { value.replacingOccurrences(of: "|", with: "/").trimmingCharacters(in: .whitespacesAndNewlines) }
        let row = [cells[1], level.map(clean) ?? cells[2], subject.map(clean) ?? cells[3], cells[4], paysBy.map(clean) ?? cells[5]]
        lines[index] = "| " + row.joined(separator: " | ") + " |"
        return lines.joined(separator: "\n")
    }

    /// `lesson-dates.csv`: `date,initials,hours`, one row per dated lesson in the Classes note.
    static func lessonDates(_ text: String, _ cal: DeskCalendar) -> [LessonDate] {
        splitLines(text).dropFirst().compactMap { line in
            let cells = line.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            guard cells.count >= 3, let date = day(cells[0], cal), !cells[1].isEmpty,
                  let hours = Double(cells[2]), hours.isFinite else { return nil }
            return LessonDate(date: date, initials: cells[1], hours: hours)
        }
    }

    /// `lessons.csv`: `month,initials,student,lessons,hours,rate,amount`; rate and amount are empty when unknown.
    static func lessons(_ text: String) -> [LessonRow] {
        splitLines(text).dropFirst().compactMap { line in
            let cells = line.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            guard cells.count >= 7, cells[0].wholeMatch(of: /\d{4}-\d{2}/) != nil, !cells[1].isEmpty,
                  let lessons = Int(cells[3]), let hours = Double(cells[4]), hours.isFinite else { return nil }
            func value(_ cell: String) -> Double? { Double(cell).flatMap { $0.isFinite ? $0 : nil } }
            return LessonRow(month: cells[0], initials: cells[1], student: cells[2], lessons: lessons, hours: hours,
                             rate: value(cells[5]), amount: value(cells[6]))
        }
    }

    static func paymentsCSV(_ payments: [Payment], _ cal: DeskCalendar) -> String {
        let rows = payments.map { p in
            [p.month, p.initials, String(p.lessons), number(p.hours), number(p.amount),
             p.sent.map(cal.isoDay) ?? "", p.paid.map(cal.isoDay) ?? ""].joined(separator: ",")
        }
        return ([paymentsHeader] + rows).joined(separator: "\n") + "\n"
    }

    /// Replaces the row for that month and student, or appends it. Lines Desk cannot parse are kept untouched.
    static func upsertPayment(_ payment: Payment, in text: String, _ cal: DeskCalendar) -> String {
        let row = paymentsCSV([payment], cal).components(separatedBy: "\n")[1]
        var lines = splitLines(text)
        while lines.last?.trimmingCharacters(in: .whitespaces).isEmpty == true { lines.removeLast() }
        if lines.isEmpty { lines = [paymentsHeader] }
        func isRow(_ line: String) -> Bool {
            let cells = line.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            return cells.count >= 2 && cells[0] == payment.month && cells[1] == payment.initials
        }
        if let index = lines.firstIndex(where: isRow) {
            lines[index] = row
        } else {
            lines.append(row)
        }
        return lines.joined(separator: "\n") + "\n"
    }

    /// `13.5` stays `13.5`; `8.0` becomes `8`. Safe for any value a file can hold.
    static func number(_ value: Double) -> String {
        guard value.isFinite else { return "—" }
        return value == value.rounded() && abs(value) < 1e15 ? String(Int(value)) : String(value)
    }

    /// `notes/<initials>.md`: `## YYYY-MM-DD` entries, newest last.
    static func notes(_ text: String, _ cal: DeskCalendar) -> [LessonNote] {
        var notes: [LessonNote] = []
        var current: (date: Date, lines: [String])?
        func flush() {
            if let current {
                notes.append(LessonNote(date: current.date, text: current.lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)))
            }
        }
        for line in splitLines(text) {
            if let title = heading(line), let date = day(title, cal) {
                flush()
                current = (date, [])
            } else {
                current?.lines.append(line)
            }
        }
        flush()
        return notes.sorted { $0.date < $1.date }
    }
}
