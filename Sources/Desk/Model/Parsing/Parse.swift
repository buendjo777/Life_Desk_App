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

    // MARK: JSON documents

    /// A text value of a JSON object, trying each key in turn: trimmed, empty ones skipped, numbers as text.
    static func string(_ doc: [String: Any], _ keys: String...) -> String? {
        for key in keys {
            if let value = doc[key] as? String, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return value.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            if let value = doc[key] as? NSNumber { return value.stringValue }
        }
        return nil
    }
}

extension String {
    /// `nil` for an empty string.
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
