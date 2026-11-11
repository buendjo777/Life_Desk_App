import Foundation

/// Pure text-to-model parsers for every vault file. None of them throws:
/// malformed input gives `nil` or an empty value, and the views show an empty state.
enum Parse {
    // MARK: Dates

    /// `2026-11-12`, `2026-11-30 11:59 CET` (wall-clock time in the vault's zone) or a full ISO 8601 datetime.
    static func stamp(_ raw: String, _ cal: DeskCalendar) -> Stamp? {
        let text = raw.trimmingCharacters(in: .whitespaces)
        if let match = text.wholeMatch(of: /(\d{4})-(\d{2})-(\d{2})(?:[ T](\d{1,2}):(\d{2})(?: [A-Z]{2,5})?)?/) {
            guard let year = Int(match.1), let month = Int(match.2), let day = Int(match.3),
                  (1...12).contains(month), (1...31).contains(day) else { return nil }
            let hour = match.4.flatMap { Int($0) }
            let minute = match.5.flatMap { Int($0) }
            guard (0...23).contains(hour ?? 0), (0...59).contains(minute ?? 0) else { return nil }
            guard let date = cal.date(year: year, month: month, day: day, hour: hour ?? 0, minute: minute ?? 0) else { return nil }
            return Stamp(date: date, hasTime: hour != nil)
        }
        let formatter = ISO8601DateFormatter()
        for options: ISO8601DateFormatter.Options in [[.withInternetDateTime], [.withInternetDateTime, .withFractionalSeconds]] {
            formatter.formatOptions = options
            if let date = formatter.date(from: text) { return Stamp(date: date, hasTime: true) }
        }
        return nil
    }

    static func day(_ raw: String?, _ cal: DeskCalendar) -> Date? {
        raw.flatMap { stamp($0, cal) }?.date
    }

    // MARK: JSON

    private static func decoder(_ cal: DeskCalendar) -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.userInfo[.deskCalendar] = cal
        return decoder
    }

    static func json<T: Decodable>(_ type: T.Type, _ text: String, _ cal: DeskCalendar) -> T? {
        try? decoder(cal).decode(type, from: Data(text.utf8))
    }

    /// Decodes each element on its own, so one bad row does not empty the list.
    private struct Lossy<T: Decodable>: Decodable {
        let value: T?
        init(from decoder: Decoder) throws { value = try? T(from: decoder) }
    }

    /// A JSON array. `nil` when the text is not an array at all; bad elements are skipped.
    static func array<T: Decodable>(_ type: T.Type, _ text: String, _ cal: DeskCalendar) -> [T]? {
        json([Lossy<T>].self, text, cal)?.compactMap(\.value)
    }

    /// JSON Lines: one object per line; blank and bad lines are skipped.
    static func lines<T: Decodable>(_ type: T.Type, _ text: String, _ cal: DeskCalendar) -> [T] {
        text.split(whereSeparator: \.isNewline).compactMap { json(type, String($0), cal) }
    }

    // MARK: Markdown building blocks

    static func splitLines(_ text: String) -> [String] {
        text.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n")
    }

    /// YAML-style front matter between two `---` lines. Returns the fields and the first body line index.
    static func frontMatter(_ lines: [String]) -> (fields: [String: String], bodyStart: Int) {
        guard lines.first?.trimmingCharacters(in: .whitespaces) == "---",
              let end = lines.dropFirst().firstIndex(where: { $0.trimmingCharacters(in: .whitespaces) == "---" })
        else { return ([:], 0) }
        var fields: [String: String] = [:]
        for line in lines[1..<end] {
            guard let colon = line.firstIndex(of: ":") else { continue }
            let key = line[..<colon].trimmingCharacters(in: .whitespaces)
            var value = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
            if value.count >= 2, let first = value.first, first == value.last, first == "\"" || first == "'" {
                value = String(value.dropFirst().dropLast())
            }
            if !key.isEmpty { fields[key] = value }
        }
        return (fields, end + 1)
    }

    /// A `- [ ]` or `- [x]` line.
    static func checkbox(_ line: String) -> (done: Bool, title: String)? {
        guard let match = line.wholeMatch(of: /\s*[-*] \[([ xX])\] (.*)/) else { return nil }
        return (match.1 != " ", match.2.trimmingCharacters(in: .whitespaces))
    }

    /// `## Heading` text, or `nil`.
    static func heading(_ line: String, level: Int = 2) -> String? {
        let prefix = String(repeating: "#", count: level) + " "
        guard line.hasPrefix(prefix) else { return nil }
        return line.dropFirst(prefix.count).trimmingCharacters(in: .whitespaces)
    }

    /// Every checkbox from `start`, tagged with the `##` section it sits under.
    static func checks(_ lines: [String], from start: Int = 0) -> [(section: String, check: Check)] {
        var section = ""
        var result: [(String, Check)] = []
        for index in lines.indices.dropFirst(start) {
            if let title = heading(lines[index]) {
                section = title
            } else if let box = checkbox(lines[index]) {
                result.append((section, Check(title: box.title, done: box.done, line: index)))
            }
        }
        return result
    }

    /// Flips the checkbox on `line`. `nil` when that line is not a checkbox.
    static func toggleCheckbox(in text: String, line: Int) -> String? {
        var lines = splitLines(text)
        guard lines.indices.contains(line), let box = checkbox(lines[line]),
              let open = lines[line].firstIndex(of: "[") else { return nil }
        let mark = lines[line].index(after: open)
        lines[line].replaceSubrange(mark...mark, with: box.done ? " " : "x")
        return lines.joined(separator: "\n")
    }

    /// A pipe table as rows keyed by the header cells.
    static func table(_ text: String) -> [[String: String]] {
        let rows = splitLines(text)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.hasPrefix("|") }
            .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "|")).components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) } }
        guard let header = rows.first else { return [] }
        return rows.dropFirst()
            .filter { !$0.allSatisfy { $0.allSatisfy { "-: ".contains($0) } } }
            .map { cells in Dictionary(zip(header, cells), uniquingKeysWith: { first, _ in first }) }
    }

    /// The body under a `## heading`, up to the next `##`.
    static func section(_ text: String, heading wanted: String) -> String? {
        let lines = splitLines(text)
        guard let start = lines.firstIndex(where: { heading($0) == wanted }) else { return nil }
        let rest = lines[(start + 1)...]
        let end = rest.firstIndex(where: { heading($0) != nil }) ?? lines.endIndex
        return lines[(start + 1)..<end].joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: Jose's files

    /// `TASKS.md`: checkboxes under `##` sections, due dates as `📅 YYYY-MM-DD`.
    static func tasks(_ text: String, _ cal: DeskCalendar) -> [TaskItem] {
        checks(splitLines(text)).map { section, check in
            var title = check.title
            var due: Date?
            if let match = title.firstMatch(of: /\s*📅\s*(\d{4}-\d{2}-\d{2})/) {
                due = day(String(match.1), cal)
                title.removeSubrange(match.range)
            }
            return TaskItem(title: title.trimmingCharacters(in: .whitespaces), section: section, done: check.done, due: due, line: check.line)
        }
    }

    /// The study file: front matter, `## Theory`, `## Problems` and `## Past papers`.
    static func study(_ text: String, _ cal: DeskCalendar) -> StudyFile? {
        let lines = splitLines(text)
        let (fields, bodyStart) = frontMatter(lines)
        let all = checks(lines, from: bodyStart)
        guard !fields.isEmpty || !all.isEmpty else { return nil }
        func group(_ name: String) -> [Check] { all.filter { $0.section == name }.map(\.check) }
        let papers = group("Past papers").map { check -> StudyFile.Paper in
            // "June 2025 — 2026-11-08 — 6.5/10"; an unticked paper is the title alone.
            let parts = check.title.components(separatedBy: " — ").map { $0.trimmingCharacters(in: .whitespaces) }
            let score = parts.dropFirst().compactMap { $0.wholeMatch(of: /([\d.]+)\s*\/\s*([\d.]+)/) }.first
            return StudyFile.Paper(
                title: parts[0], done: check.done,
                date: parts.dropFirst().compactMap { day($0, cal) }.first,
                score: score.flatMap { Double($0.1) }, outOf: score.flatMap { Double($0.2) },
                line: check.line
            )
        }
        return StudyFile(
            exam: fields["exam"] ?? "", date: day(fields["date"], cal),
            planPerDay: fields["plan_per_day"].flatMap(Int.init) ?? 0, planStart: day(fields["plan_start"], cal),
            theory: group("Theory"), problems: group("Problems"), papers: papers
        )
    }

    static func project(path: String, _ text: String, _ cal: DeskCalendar) -> Project? {
        let lines = splitLines(text)
        let (fields, bodyStart) = frontMatter(lines)
        guard let title = fields["title"], let status = ProjectStatus(rawValue: fields["status"] ?? "") else { return nil }
        return Project(
            path: path, title: title, status: status, next: fields["next"] ?? "",
            nextDate: day(fields["next_date"], cal), doc: fields["doc"],
            items: checks(lines, from: bodyStart).map(\.check)
        )
    }

    static func uni(path: String, _ text: String) -> UniProgramme? {
        let lines = splitLines(text)
        let (fields, bodyStart) = frontMatter(lines)
        guard let title = fields["title"] else { return nil }
        return UniProgramme(
            path: path, title: title, deadlineRow: fields["deadline_row"] ?? "",
            comparisonHeading: fields["comparison_heading"] ?? "",
            items: checks(lines, from: bodyStart).map(\.check)
        )
    }

    /// `nini/masters-deadlines-2027.md`: programme → deadline. This doc is the master for programme deadlines.
    static func masterDeadlines(_ text: String, _ cal: DeskCalendar) -> [String: Stamp] {
        var result: [String: Stamp] = [:]
        for row in table(text) {
            if let programme = row["Programme"], let deadline = row["Deadline"].flatMap({ stamp($0, cal) }) {
                result[programme] = deadline
            }
        }
        return result
    }

    /// A draft: front matter `to, thread, status, created`, then the body.
    static func draft(path: String, _ text: String, _ cal: DeskCalendar) -> Draft? {
        let lines = splitLines(text)
        let (fields, bodyStart) = frontMatter(lines)
        guard bodyStart > 0 else { return nil }
        return Draft(
            path: path, to: fields["to"] ?? "", thread: fields["thread"] ?? "",
            status: fields["status"] ?? "unreviewed", created: day(fields["created"], cal),
            body: lines[bodyStart...].joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    // MARK: tutoring/

    /// `students.md`: a table `Initials | Level | Subject | Rate (€/h) | Pays by`.
    static func students(_ text: String) -> [Student] {
        table(text).compactMap { row in
            guard let initials = row["Initials"], !initials.isEmpty else { return nil }
            let rate = row.first { $0.key.hasPrefix("Rate") }?.value ?? ""
            return Student(
                initials: initials, level: row["Level"] ?? "", subject: row["Subject"] ?? "",
                rate: Double(rate.replacingOccurrences(of: ",", with: ".")) ?? 0, paysBy: row["Pays by"] ?? ""
            )
        }
    }

    static let paymentsHeader = "month,initials,lessons,hours,amount,sent,paid"

    /// `payments.csv`: `month,initials,lessons,hours,amount,sent,paid`.
    static func payments(_ text: String, _ cal: DeskCalendar) -> [Payment] {
        splitLines(text).dropFirst().compactMap { line in
            let cells = line.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            guard cells.count >= 5, cells[0].wholeMatch(of: /\d{4}-\d{2}/) != nil, !cells[1].isEmpty,
                  let lessons = Int(cells[2]), let hours = Double(cells[3]), let amount = Double(cells[4]) else { return nil }
            return Payment(
                month: cells[0], initials: cells[1], lessons: lessons, hours: hours, amount: amount,
                sent: cells.count > 5 ? day(cells[5], cal) : nil, paid: cells.count > 6 ? day(cells[6], cal) : nil
            )
        }
    }

    static func paymentsCSV(_ payments: [Payment], _ cal: DeskCalendar) -> String {
        let rows = payments.map { p in
            [p.month, p.initials, String(p.lessons), number(p.hours), number(p.amount),
             p.sent.map(cal.isoDay) ?? "", p.paid.map(cal.isoDay) ?? ""].joined(separator: ",")
        }
        return ([paymentsHeader] + rows).joined(separator: "\n") + "\n"
    }

    /// `13.5` stays `13.5`; `8.0` becomes `8`.
    static func number(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(value)
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
