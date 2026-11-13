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
        for fractional in [false, true] {
            if let date = Formatters.iso(timeZone: cal.calendar.timeZone, fractional: fractional).date(from: text) {
                return Stamp(date: date, hasTime: true)
            }
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

    /// A `- [ ]` or `- [x]` line (`*` works too, indented or not). Matched by hand rather than with a regex:
    /// every line of every Markdown file goes through here on each reload.
    static func checkbox(_ line: String) -> (done: Bool, title: String)? {
        let rest = line.drop(while: \.isWhitespace)
        guard let bullet = rest.first, bullet == "-" || bullet == "*" else { return nil }
        let box = Array(rest.dropFirst().prefix(5))
        guard box.count == 5, box[0] == " ", box[1] == "[", box[3] == "]", box[4] == " ",
              box[2] == " " || box[2] == "x" || box[2] == "X" else { return nil }
        return (box[2] != " ", rest.dropFirst(6).trimmingCharacters(in: .whitespaces))
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
    /// With `expecting`, the checkbox must still carry that title; if the file moved underneath,
    /// the one line that does is used instead, and `nil` is returned when there is not exactly one.
    static func toggleCheckbox(in text: String, line wanted: Int, expecting title: String? = nil) -> String? {
        var lines = splitLines(text)
        var line = wanted
        if let title {
            func matches(_ index: Int) -> Bool {
                lines.indices.contains(index) && checkbox(lines[index])?.title.hasPrefix(title) == true
            }
            if !matches(line) {
                let found = lines.indices.filter(matches)
                guard found.count == 1 else { return nil }
                line = found[0]
            }
        }
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

    /// The body under a heading of any level (`##`, `###`…), up to the next heading of the same or a
    /// higher level. Headings match by `nameKey`, so case, accents and bold markers don't matter.
    static func section(_ text: String, heading wanted: String) -> String? {
        let lines = splitLines(text)
        let key = nameKey(wanted)
        guard let start = lines.firstIndex(where: { anyHeading($0).map { nameKey($0.text) == key } == true }),
              let level = anyHeading(lines[start])?.level else { return nil }
        let end = lines[(start + 1)...].firstIndex { (anyHeading($0)?.level ?? .max) <= level } ?? lines.endIndex
        return lines[(start + 1)..<end].joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// `### Heading` → (3, "Heading"); `nil` for any other line.
    static func anyHeading(_ line: String) -> (level: Int, text: String)? {
        guard let match = line.wholeMatch(of: /(#{1,6})\s+(.+?)\s*/) else { return nil }
        return (match.1.count, String(match.2))
    }

    /// A key for names written slightly differently: no case, accents or bold markers, dashes and
    /// middle dots as spaces, single spaces. "ETH Zürich — **MSc**" and "eth zurich - msc" match.
    static func nameKey(_ name: String) -> String {
        let folded = name.replacingOccurrences(of: "**", with: "")
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en")).lowercased()
        return String(folded.map { "—–-·•".contains($0) ? " " : $0 }).split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    /// Obsidian wikilinks as the plain text Obsidian shows: `[[Note]]` → "Note", `[[folder/Note|label]]`
    /// → "label", `[[Note#Heading]]` → "Note > Heading", `![[embed]]` → "embed". In tables the alias bar
    /// is written `\|`. Applied once, when Jose's docs are loaded.
    static func plainWikilinks(_ text: String) -> String {
        text.replacing(/!?\[\[([^\[\]\n]+?)\]\]/) { match -> String in
            let inner = String(match.1)
            var target = inner
            if let bar = inner.firstIndex(of: "|") {
                let alias = inner[inner.index(after: bar)...].trimmingCharacters(in: .whitespaces)
                if !alias.isEmpty { return alias }
                target = String(inner[..<bar])
            }
            if target.hasSuffix("\\") { target.removeLast() }
            let parts = target.split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false).map(String.init)
            var note = parts[0].split(separator: "/").last.map(String.init) ?? ""
            if note.lowercased().hasSuffix(".md") { note.removeLast(3) }
            note = note.trimmingCharacters(in: .whitespaces)
            guard parts.count == 2, !parts[1].hasPrefix("^") else { return note }
            let heading = parts[1].trimmingCharacters(in: .whitespaces)
            return note.isEmpty ? heading : "\(note) > \(heading)"
        }
    }

    /// A doc Desk may render as trusted Markdown: a plain relative `.md` path inside the vault, never
    /// under `agent/` (agent-written text is untrusted and stays plain text) or `.git/`.
    static func isTrustedDoc(_ path: String) -> Bool {
        let parts = path.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
        guard path.lowercased().hasSuffix(".md"), !parts.contains(where: { $0.isEmpty || $0 == "." || $0 == ".." }),
              let first = parts.first?.lowercased() else { return false }
        return first != "agent" && first != ".git"
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

    /// More papers a day than anyone sits; keeps arithmetic on file content bounded.
    static let maxPlanPerDay = 50

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
            planPerDay: min(maxPlanPerDay, max(0, fields["plan_per_day"].flatMap(Int.init) ?? 0)), planStart: day(fields["plan_start"], cal),
            theory: group("Theory"), problems: group("Problems"), papers: papers,
            lists: studyLists(lines, from: bodyStart, cal)
        )
    }

    static let studySections: Set<String> = ["Theory", "Problems", "Past papers"]

    /// The study file's own lists: each other `##` section with checkboxes, its `###` headings as groups.
    /// "This weekend — due 2026-11-15" gives the title "This weekend" and the due day.
    static func studyLists(_ lines: [String], from start: Int, _ cal: DeskCalendar) -> [StudyList] {
        var lists: [StudyList] = []
        var inList = false
        for index in lines.indices.dropFirst(start) {
            let line = lines[index]
            if let title = heading(line) {
                inList = !studySections.contains(title)
                if inList { lists.append(studyList(title, line: index, cal)) }
            } else if inList, let title = heading(line, level: 3) {
                lists[lists.count - 1].groups.append(StudyList.Group(title: title, items: [], line: index))
            } else if inList, let box = checkbox(line) {
                let list = lists.count - 1
                if lists[list].groups.isEmpty {
                    lists[list].groups.append(StudyList.Group(title: lists[list].title, items: [], line: index))
                }
                lists[list].groups[lists[list].groups.count - 1].items.append(Check(title: box.title, done: box.done, line: index))
            }
        }
        return lists.compactMap { list in
            var list = list
            list.groups.removeAll { $0.items.isEmpty }
            return list.groups.isEmpty ? nil : list
        }
    }

    private static func studyList(_ heading: String, line: Int, _ cal: DeskCalendar) -> StudyList {
        guard let match = heading.firstMatch(of: /\s*[—–-]*\s*\b[Dd]ue\s+(.+)$/) else {
            return StudyList(title: heading, due: nil, groups: [], line: line)
        }
        let title = heading[..<match.range.lowerBound].trimmingCharacters(in: .whitespaces)
        return StudyList(title: title.isEmpty ? heading : title, due: looseDate(String(match.1), cal)?.date, groups: [], line: line)
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

    /// `Masters/Deadlines 2027.md`: programme → deadline, keyed by `nameKey`. The date is in a "Closes"
    /// (or "Deadline") column. This doc is the master for programme deadlines.
    static func masterDeadlines(_ text: String, _ cal: DeskCalendar) -> [String: Stamp] {
        var result: [String: Stamp] = [:]
        for row in table(text) {
            guard let programme = row["Programme"], let raw = row["Closes"] ?? row["Deadline"],
                  let deadline = looseDate(raw, cal) else { continue }
            result[nameKey(programme)] = deadline
        }
        return result
    }

    /// A date as people write it in a doc: ISO, or "3 Nov 2026" / "**30 Nov 2026, 11:59 CET**" (wall-clock
    /// time in the vault's zone). Bold markers and trailing words are ignored.
    static func looseDate(_ raw: String, _ cal: DeskCalendar) -> Stamp? {
        let text = raw.replacingOccurrences(of: "**", with: "")
        if let iso = text.firstMatch(of: /\d{4}-\d{2}-\d{2}(?:[ T]\d{1,2}:\d{2})?/), let stamp = stamp(String(iso.0), cal) {
            return stamp
        }
        guard let match = text.firstMatch(of: /(\d{1,2})\s+([A-Za-z]{3})[a-z]*\.?\s+(\d{4})(?:,?\s+(\d{1,2}):(\d{2}))?/),
              let day = Int(match.1), (1...31).contains(day), let year = Int(match.3),
              let month = monthNumbers[match.2.lowercased()] else { return nil }
        let hour = match.4.flatMap { Int($0) }, minute = match.5.flatMap { Int($0) }
        guard (0...23).contains(hour ?? 0), (0...59).contains(minute ?? 0),
              let date = cal.date(year: year, month: month, day: day, hour: hour ?? 0, minute: minute ?? 0) else { return nil }
        return Stamp(date: date, hasTime: hour != nil)
    }

    /// English and Spanish month abbreviations.
    static let monthNumbers: [String: Int] = [
        "jan": 1, "ene": 1, "feb": 2, "mar": 3, "apr": 4, "abr": 4, "may": 5, "jun": 6, "jul": 7,
        "aug": 8, "ago": 8, "sep": 9, "oct": 10, "nov": 11, "dec": 12, "dic": 12,
    ]

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
    /// The Internship Target Board's own export (`internships/board.json`): its "openings" (live postings) become
    /// Apply now and its "targets" (companies and labs) the rest of the list. Field names follow the board's
    /// collections; anything else is ignored, and an opening needs only a company.
    static func board(_ text: String, _ cal: DeskCalendar) -> [Target]? {
        guard let root = (try? JSONSerialization.jsonObject(with: Data(text.utf8))) as? [String: Any] else { return nil }
        func docs(_ key: String) -> [[String: Any]] {
            if let list = root[key] as? [[String: Any]] { return list }
            // A collection exported as {id: document}.
            let byID = root[key] as? [String: [String: Any]] ?? [:]
            return byID.keys.sorted().map { id in byID[id, default: [:]].merging(["id": id]) { kept, _ in kept } }
        }
        func string(_ doc: [String: Any], _ keys: [String]) -> String? {
            for key in keys {
                if let value = doc[key] as? String, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    return value.trimmingCharacters(in: .whitespacesAndNewlines)
                }
                if let value = doc[key] as? NSNumber { return value.stringValue }
            }
            return nil
        }
        func target(_ doc: [String: Any], index: Int, list: String) -> Target? {
            guard let company = string(doc, ["company", "name", "organisation", "organization", "org", "lab"]) else { return nil }
            let raw = string(doc, ["status"])
            let notes = string(doc, ["notes", "note"])
            // A target has no job title: its track and kind ("MedTech · Company") say what it is.
            let role = string(doc, ["title", "role", "position"])
                ?? [string(doc, ["track"]), string(doc, ["kind"])].compactMap { $0 }.joined(separator: " · ").nilIfEmpty
            return Target(
                id: "\(list)-\(string(doc, ["id"]) ?? String(index))", company: company,
                role: role, city: string(doc, ["location", "place", "city"]), country: string(doc, ["country"]),
                list: list, status: boardStatus(raw ?? ""), graduateOk: string(doc, ["eligType", "elig_type"]).map { $0.lowercased() == "graduate" },
                deadline: string(doc, ["deadline", "closes"]).flatMap { looseDate($0, cal) },
                next: notes.map { String($0.split(separator: "\n").first ?? "") }, url: string(doc, ["url", "link", "careers", "website"]),
                statusLabel: raw, start: string(doc, ["start"]), duration: string(doc, ["duration"]), language: string(doc, ["language"]),
                eligibility: string(doc, ["eligibility"]), fit: string(doc, ["fit", "why"]), notes: notes,
                priority: string(doc, ["priority"]), order: string(doc, ["order", "placeOrder"]).flatMap(Double.init) ?? Double(index),
                sourceID: string(doc, ["id"]), added: string(doc, ["added"]).flatMap { day($0, cal) }
            )
        }
        let openings = docs("openings").enumerated().compactMap { target($0.element, index: $0.offset, list: "apply_now") }
            .sorted { ($0.order ?? 0) < ($1.order ?? 0) }
        let targets = docs("targets").enumerated().compactMap { target($0.element, index: $0.offset, list: "target") }
        return openings + targets
    }

    /// Sets one entry's status in `internships/board.json` by rewriting only its `"status"` line, so the file keeps
    /// its layout and Desk's edit merges cleanly with the Monday scan's additions. `nil` when the entry is not found.
    static func setBoardStatus(_ text: String, id: String, status: String) -> String? {
        func quoted(_ value: String) -> String {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .withoutEscapingSlashes
            return (try? encoder.encode(value)).map { String(decoding: $0, as: UTF8.self) } ?? "\"\""
        }
        var lines = splitLines(text)
        let idKey = "\"id\": \(quoted(id))"
        guard let start = lines.firstIndex(where: { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            return trimmed == idKey || trimmed == idKey + ","
        }) else { return nil }
        let indent = lines[start].prefix { $0 == " " }.count
        // The entry's keys sit at its indent; a shallower line closes it. Look both ways from the id.
        var range: [Int] = []
        var up = start - 1
        while up >= 0, lines[up].prefix(while: { $0 == " " }).count >= indent { range.append(up); up -= 1 }
        var down = start + 1
        while down < lines.count, lines[down].prefix(while: { $0 == " " }).count >= indent { range.append(down); down += 1 }
        guard let line = range.first(where: { lines[$0].prefix(while: { $0 == " " }).count == indent
                                         && lines[$0].trimmingCharacters(in: .whitespaces).hasPrefix("\"status\":") }) else { return nil }
        let comma = lines[line].trimmingCharacters(in: .whitespaces).hasSuffix(",") ? "," : ""
        lines[line] = String(repeating: " ", count: indent) + "\"status\": \(quoted(status))" + comma
        return lines.joined(separator: "\n")
    }

    /// The contacts board (`contacts/board.json`): one person per entry, grouped by programme (or university).
    static func contactsBoard(_ text: String, _ cal: DeskCalendar) -> [Person]? {
        guard let root = (try? JSONSerialization.jsonObject(with: Data(text.utf8))) as? [String: Any],
              let docs = root["contacts"] as? [[String: Any]] else { return nil }
        func string(_ doc: [String: Any], _ key: String) -> String? {
            if let value = doc[key] as? String, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return value.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            return (doc[key] as? NSNumber)?.stringValue
        }
        return docs.enumerated().compactMap { index, doc -> Person? in
            guard let id = string(doc, "id"), let name = string(doc, "name") else { return nil }
            let words = string(doc, "status") ?? "Not contacted"
            let notes = string(doc, "notes")
            let order = string(doc, "progOrder").flatMap(Double.init) ?? 100 + (string(doc, "uniOrder").flatMap(Double.init) ?? Double(index))
            return Person(
                id: id, name: name, programme: string(doc, "prog") ?? string(doc, "uni"), role: string(doc, "role"),
                status: personStatus(words), lastContact: nil, next: notes.map { String($0.split(separator: "\n").first ?? "") },
                statusLabel: words, university: string(doc, "uni"), lab: string(doc, "lab"), why: string(doc, "why"),
                paper: string(doc, "paper"), contactRoute: string(doc, "contact"), notes: notes, url: string(doc, "url"),
                priority: string(doc, "priority"), order: order, sourceID: id
            )
        }
    }

    /// The contacts board's status words in Desk's keys.
    static func personStatus(_ words: String) -> String {
        switch words.lowercased() {
        case let text where text.contains("drafted"): "drafted"
        case let text where text.contains("sent"): "sent"
        case let text where text.contains("replied"): "replied"
        case let text where text.contains("call"): "call_booked"
        case let text where text.contains("no reply"): "no_reply"
        default: "not_contacted"
        }
    }

    /// The board's status words in Desk's four: rejected or closed, an interview or a call, applied, else open.
    static func boardStatus(_ raw: String) -> String {
        let text = raw.lowercased()
        if ["reject", "closed", "declin", "no longer"].contains(where: text.contains) { return "rejected" }
        if ["interview", "call", "offer"].contains(where: text.contains) { return "interview" }
        if ["applied", "submitted", "sent"].contains(where: text.contains) { return "applied" }
        return "open"
    }

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

extension String {
    /// `nil` for an empty string.
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
