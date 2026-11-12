import Foundation

/// Imports Jose's lesson summaries from the Notes folder "Classes" into `tutoring/notes/<initials>.md`.
/// Local only: `tutoring/` is gitignored, and the files carry initials, never names (SPEC "tutoring/").
/// The parts here are pure and tested; `NotesReader` fetches the notes and `ImportCommand` runs it.
enum ClassesImport {
    struct Note {
        /// The subfolder of "Classes" the note sits in, if any.
        var folder: String?
        var title: String
        var body: String
        var created: Date
    }

    struct Entry: Equatable {
        var date: Date
        var text: String
    }

    struct Result {
        /// Initials → entries, oldest first.
        var students: [String: [Entry]] = [:]
        var notesRead = 0
        var locked = 0
        var unmatched = 0
        var bySubfolder = false
        var datedByText = 0
        var datedByCreation = 0
        var namesRemoved = 0
        var emailsRemoved = 0
        var phonesRemoved = 0
    }

    static let marker = "<!-- Imported by Desk from Notes › Classes. The next import replaces this file: edit the notes in Notes. -->"

    // MARK: Import

    static func run(_ notes: [Note], locked: Int = 0, contacts: [String: TutoringContact], cal: DeskCalendar) -> Result {
        var result = Result()
        result.notesRead = notes.count
        result.locked = locked
        result.bySubfolder = notes.contains { $0.folder != nil }
        let usable = contacts.filter { isSafeCode($0.key) }

        // 1. Who each note is about: its subfolder, else its title.
        var named: [(note: Note, key: String)] = []
        for note in notes {
            let folderName = note.folder?.split(separator: "/").last.map(String.init).flatMap(cleanName)
            guard let name = folderName ?? studentName(inTitle: note.title) else {
                result.unmatched += 1
                continue
            }
            named.append((note, Parse.nameKey(name)))
        }

        // 2. Initials: a contact's when the first name matches, else derived; never two students on one code.
        var codes: [String: String] = [:]
        var used = Set(usable.keys)
        let sortedContacts = usable.sorted { $0.key < $1.key }
        for key in Set(named.map(\.key)).sorted() {
            if let contact = sortedContacts.first(where: { sameStudent(Parse.nameKey($0.value.student), key) }) {
                codes[key] = contact.key
                continue
            }
            let base = initials(forKey: key)
            var code = base
            var suffix = 2
            while used.contains(code) {
                code = base + String(suffix)
                suffix += 1
            }
            used.insert(code)
            codes[key] = code
        }

        // 3. Names to remove: every known student and parent word becomes that student's initials.
        var known: [String: String] = [:]
        for (code, contact) in usable {
            for word in Parse.nameKey(contact.student + " " + contact.parent).split(separator: " ") where word.count >= 2 {
                known[String(word)] = code
            }
        }
        for (key, code) in codes {
            for word in key.split(separator: " ") where word.count >= 2 { known[String(word)] = code }
        }

        // 4. Dated, anonymised entries per student.
        for (note, key) in named {
            guard let code = codes[key] else { continue }
            var words = known
            for word in key.split(separator: " ") where word.count >= 2 { words[String(word)] = code }
            let split = entries(of: note, cal: cal)
            result.datedByText += split.byText
            result.datedByCreation += split.byCreation
            for entry in split.entries {
                let clean = redact(entry.text, words: words)
                result.namesRemoved += clean.names
                result.emailsRemoved += clean.emails
                result.phonesRemoved += clean.phones
                result.students[code, default: []].append(Entry(date: entry.date, text: clean.text))
            }
        }
        for (code, entries) in result.students {
            result.students[code] = merged(entries)
        }
        return result
    }

    /// Entries sorted oldest first; two on the same day become one.
    static func merged(_ entries: [Entry]) -> [Entry] {
        var result: [Entry] = []
        for entry in entries.sorted(by: { $0.date < $1.date }) {
            if let last = result.last, last.date == entry.date {
                result[result.count - 1].text += "\n\n" + entry.text
            } else {
                result.append(entry)
            }
        }
        return result
    }

    // MARK: Names and initials

    /// Words that may come before the name in a title: "Clase con Emma", "Martes Álex".
    static let fillerWords: Set<String> = [
        "clase", "clases", "class", "lesson", "sesion", "session", "tutoria", "con", "with",
        "lunes", "martes", "miercoles", "jueves", "viernes", "sabado", "domingo",
        "monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday",
    ]

    /// The student's name in a note title: dates removed, the first part before a separator, filler dropped.
    /// "Álex 12/11" → "Álex", "12/11/2026 - Carla - Física" → "Carla", "Clase con Emma, 3 nov" → "Emma".
    static func studentName(inTitle title: String) -> String? {
        var text = title
        while let found = handDate(in: text, atStart: false) {
            text.replaceSubrange(found.range, with: " ")
        }
        let parts = text.split(separator: /\s[-–—|]\s|[:|,(\[]/).map(String.init)
        return parts.first(where: { $0.contains(where: \.isLetter) }).flatMap(cleanName)
    }

    /// Letters-only words with leading filler dropped; `nil` when nothing is left.
    static func cleanName(_ raw: String) -> String? {
        var words = raw.split(whereSeparator: { !$0.isLetter }).map(String.init)
        while let first = words.first, fillerWords.contains(Parse.nameKey(first)) { words.removeFirst() }
        return words.isEmpty ? nil : words.joined(separator: " ")
    }

    /// "alex bermudez" → "AB"; a single name gives its first two letters: "carla" → "CA".
    static func initials(forKey key: String) -> String {
        let words = key.split(separator: " ").map { $0.uppercased() }
        guard let first = words.first else { return "XX" }
        if words.count >= 2, let a = first.first, let b = words[1].first { return String([a, b]) }
        return String(first.prefix(2))
    }

    /// The same student when the names are equal or the first names are.
    static func sameStudent(_ a: String, _ b: String) -> Bool {
        a == b || (a.split(separator: " ").first != nil && a.split(separator: " ").first == b.split(separator: " ").first)
    }

    /// Initials become file names, so only letters and digits.
    static func isSafeCode(_ code: String) -> Bool {
        (1...6).contains(code.count) && code.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber) }
    }

    // MARK: Dates written by hand

    struct HandDate {
        var range: Range<String.Index>
        var day: Int
        var month: Int
        var year: Int?
    }

    /// 2026-11-12, 12/11/2026, 12-11-26, 12/11, "12 nov", "12 de noviembre de 2026".
    static func handDate(in text: String, atStart: Bool) -> HandDate? {
        func find<Output>(_ regex: Regex<Output>) -> Regex<Output>.Match? {
            atStart ? text.prefixMatch(of: regex) : text.firstMatch(of: regex)
        }
        if let m = find(/(\d{4})-(\d{1,2})-(\d{1,2})/) {
            return HandDate(range: m.range, day: Int(m.3) ?? 0, month: Int(m.2) ?? 0, year: Int(m.1))
        }
        if let m = find(/(\d{1,2})[\/.\-](\d{1,2})[\/.\-](\d{4}|\d{2})(?!\d)/) {
            return HandDate(range: m.range, day: Int(m.1) ?? 0, month: Int(m.2) ?? 0, year: Int(m.3))
        }
        let words = /(\d{1,2})(?:\s+de)?\s+(ene|feb|mar|abr|may|jun|jul|ago|sep|oct|nov|dic|jan|apr|aug|dec)[a-záéíóú]*\.?(?:,?\s+(?:de\s+)?(\d{4}))?/
        if let m = find(words.ignoresCase()), let month = Parse.monthNumbers[m.2.lowercased()] {
            return HandDate(range: m.range, day: Int(m.1) ?? 0, month: month, year: m.3.flatMap { Int($0) })
        }
        if let m = find(/(\d{1,2})\/(\d{1,2})(?![\/\d])/) {
            return HandDate(range: m.range, day: Int(m.1) ?? 0, month: Int(m.2) ?? 0, year: nil)
        }
        return nil
    }

    /// That day in `year`, or `nil` when it doesn't exist (31/11).
    static func make(_ found: HandDate, year: Int, cal: DeskCalendar) -> Date? {
        guard (1...12).contains(found.month), (1...31).contains(found.day),
              let date = cal.date(year: year < 100 ? 2000 + year : year, month: found.month, day: found.day),
              cal.day(date) == found.day else { return nil }
        return date
    }

    /// A title's date. Without a year: the year the note was written, or the year before when that would
    /// put the lesson more than a week after the note (a summary is written on or after the lesson).
    static func date(_ found: HandDate, near: Date, cal: DeskCalendar) -> Date? {
        if let year = found.year { return make(found, year: year, cal: cal) }
        let year = cal.calendar.component(.year, from: near)
        guard let date = make(found, year: year, cal: cal) else { return nil }
        return date > cal.add(days: 7, to: near) ? (make(found, year: year - 1, cal: cal) ?? date) : date
    }

    /// A dated line in a running log. Without a year the log stays in order: the year moves on only
    /// when the date would fall more than a month before the previous entry.
    static func date(_ found: HandDate, after previous: Date, cal: DeskCalendar) -> Date? {
        if let year = found.year { return make(found, year: year, cal: cal) }
        let year = cal.calendar.component(.year, from: previous)
        guard let date = make(found, year: year, cal: cal) else { return nil }
        return date < cal.add(days: -31, to: previous) ? (make(found, year: year + 1, cal: cal) ?? date) : date
    }

    /// A line that starts a dated entry: "12/11", "## 2026-11-14", "Martes 18/11: repaso".
    /// The date must stand alone or be followed by a separator, so "3/4 of the exercises" is just text.
    static func leadingDate(_ line: String) -> (found: HandDate, rest: String)? {
        var text = String(line.trimmingCharacters(in: .whitespaces).drop { "#-*•· ".contains($0) })
        let weekday = /(?:lunes|martes|mi[eé]rcoles|jueves|viernes|s[aá]bado|domingo|mon|tue|wed|thu|fri|sat|sun)[a-z]*\.?,?\s+/
        if let found = text.prefixMatch(of: weekday.ignoresCase()) { text = String(text[found.range.upperBound...]) }
        guard let found = handDate(in: text, atStart: true) else { return nil }
        let after = text[found.range.upperBound...].drop { $0 == " " }
        guard after.first.map({ ":-—–.)|".contains($0) }) ?? true else { return nil }
        return (found, String(after.drop { ":-—–.)| ".contains($0) }))
    }

    /// A note's entries. A note can be one lesson (dated by its title, else its creation date) or a running
    /// log whose lines start new dated entries.
    static func entries(of note: Note, cal: DeskCalendar) -> (entries: [Entry], byText: Int, byCreation: Int) {
        var lines = Parse.splitLines(note.body)
        if lines.first?.trimmingCharacters(in: .whitespaces) == note.title.trimmingCharacters(in: .whitespaces) {
            lines.removeFirst()
        }
        let titleDate = handDate(in: note.title, atStart: false).flatMap { date($0, near: note.created, cal: cal) }
        var entries: [Entry] = []
        var byText = 0
        var byCreation = 0
        var current = titleDate ?? note.created
        var fromText = titleDate != nil
        var buffer: [String] = []
        func flush() {
            let text = buffer.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            buffer = []
            guard !text.isEmpty else { return }
            entries.append(Entry(date: cal.startOfDay(current), text: text))
            if fromText { byText += 1 } else { byCreation += 1 }
        }
        for line in lines {
            if let found = leadingDate(line), let date = date(found.found, after: current, cal: cal) {
                flush()
                current = date
                fromText = true
                if !found.rest.isEmpty { buffer.append(found.rest) }
            } else {
                buffer.append(line)
            }
        }
        flush()
        return (entries, byText, byCreation)
    }

    // MARK: Anonymising

    /// Known names become initials (whole words, ignoring case and accents); emails and phone numbers go.
    static func redact(_ text: String, words: [String: String]) -> (text: String, names: Int, emails: Int, phones: Int) {
        var emails = 0
        var phones = 0
        var out = text.replacing(/[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}/) { _ -> String in
            emails += 1
            return "[email]"
        }
        out = out.replacing(/\+\d[\d \-]{7,14}\d|\b[6789]\d{2}[ \-]?\d{3}[ \-]?\d{3}\b/) { _ -> String in
            phones += 1
            return "[phone]"
        }
        // Runs of letters, so "Bermúdez's" and "Ana-María" are caught as well as plain words.
        var names = 0
        out = out.replacing(/\p{L}+/) { match -> String in
            let word = String(match.0)
            guard let code = words[Parse.nameKey(word)] else { return word }
            names += 1
            return code
        }
        return (out, names, emails, phones)
    }

    // MARK: Output

    /// `notes/<initials>.md` as SPEC describes it: `## YYYY-MM-DD` entries, newest last.
    static func render(_ entries: [Entry], cal: DeskCalendar) -> String {
        ([marker, ""] + entries.flatMap { ["## \(cal.isoDay($0.date))", $0.text, ""] }).joined(separator: "\n")
    }

    /// Why the import must not write to this vault, or `nil` when it may.
    static func refusal(for vault: URL) -> String? {
        let path = vault.standardizedFileURL.path
        if path.contains("/demo-vault") { return "Desk never writes to the demo vault." }
        guard FileManager.default.fileExists(atPath: vault.appendingPathComponent(".git").path) else {
            return "\(path) is not a git vault."
        }
        // tutoring/ must be gitignored, so nothing imported can reach GitHub.
        guard (try? Git(root: vault).run(["check-ignore", "-q", "tutoring/notes/XX.md"])) != nil else {
            return "tutoring/ is not in the vault's .gitignore, so the import could be committed. Add it first."
        }
        return nil
    }

    struct WriteReport {
        var written: [String] = []
        var skipped: [String] = []
        var createdStudents = false
    }

    /// Writes one file per student. A notes file that the importer did not create is never overwritten.
    /// `students.md` is created with the initials when it is missing, and otherwise left alone.
    static func write(_ result: Result, to vault: URL, cal: DeskCalendar) throws -> WriteReport {
        let folder = vault.appendingPathComponent("tutoring/notes")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        var report = WriteReport()
        for (code, entries) in result.students.sorted(by: { $0.key < $1.key }) where isSafeCode(code) {
            let url = folder.appendingPathComponent("\(code).md")
            let path = "tutoring/notes/\(code).md"
            if let existing = try? String(contentsOf: url, encoding: .utf8), !existing.hasPrefix(marker) {
                report.skipped.append(path)
                continue
            }
            try render(entries, cal: cal).write(to: url, atomically: true, encoding: .utf8)
            report.written.append(path)
        }
        let students = vault.appendingPathComponent(VaultData.studentsFile)
        if !FileManager.default.fileExists(atPath: students.path), !result.students.isEmpty {
            let rows = result.students.keys.sorted().filter(isSafeCode).map { "| \($0) |  |  |  |  |" }
            let table = ["| Initials | Level | Subject | Rate (€/h) | Pays by |", "|---|---|---|---|---|"] + rows
            try (table.joined(separator: "\n") + "\n").write(to: students, atomically: true, encoding: .utf8)
            report.createdStudents = true
        }
        return report
    }

    /// The summary printed after an import: counts and initials only, never a title, a name or a line of text.
    static func report(_ result: Result, dryRun: Bool, writeCheck: String?, written: WriteReport?, cal: DeskCalendar) -> String {
        var lines = ["Classes import" + (dryRun ? " (dry run: nothing written)" : "")]
        lines.append("Read \(result.notesRead) notes (\(result.bySubfolder ? "a subfolder per student" : "the student from each title")); "
                     + "\(result.locked) locked, skipped; \(result.unmatched) with no student found.")
        let students = result.students.sorted { $0.key < $1.key }.map { code, entries -> String in
            let first = entries.first.map { cal.format($0.date, "MMM yyyy") } ?? ""
            let last = entries.last.map { cal.format($0.date, "MMM yyyy") } ?? ""
            return "\(code) \(entries.count) (\(first == last ? first : "\(first) – \(last)"))"
        }
        lines.append("Students: " + (students.isEmpty ? "none" : students.joined(separator: ", ")))
        lines.append("Dates: \(result.datedByText) from a title or a dated line, \(result.datedByCreation) from the note's creation date.")
        lines.append("Removed from the text: \(result.namesRemoved) names, \(result.emailsRemoved) emails, \(result.phonesRemoved) phone numbers.")
        lines.append("Write check: " + (writeCheck ?? "ok, tutoring/ is gitignored"))
        if let written {
            lines.append("Wrote: " + (written.written.isEmpty ? "nothing" : written.written.joined(separator: ", ")))
            if !written.skipped.isEmpty {
                lines.append("Skipped (not created by the importer): " + written.skipped.joined(separator: ", "))
            }
            if written.createdStudents {
                lines.append("Created tutoring/students.md with the initials; fill in level, subject, rate and how they pay.")
            }
        }
        return lines.joined(separator: "\n")
    }
}
