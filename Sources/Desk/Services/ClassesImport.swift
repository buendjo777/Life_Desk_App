import Foundation

/// Jose's tutoring log is one Notes note titled "Classes": a heading per month, then each student's name and
/// the dates of their lessons (an hour each; "x0.5" or "x1.5" for 30 or 90 minutes), and the month's total
/// under it. This turns it into a preliminary sort in `tutoring/` with initials instead of names.
/// Only dates, durations and amounts are read: no other text is copied. `tutoring/` is gitignored.
enum ClassesImport {
    // MARK: The note

    struct Lesson: Equatable {
        var day: Int?
        var hours: Double
    }

    struct StudentBlock {
        var name: String
        var lessons: [Lesson] = []
        /// An amount written on the student's own line, if any.
        var amount: Double?
    }

    struct MonthBlock {
        var month: Int
        var year: Int?
        var students: [StudentBlock] = []
        var total: Double?
    }

    struct Log {
        var months: [MonthBlock] = []
        /// One letter per line, printed by the dry run instead of the text: M month, S student, D dates,
        /// A an amount for a student, T a total, B blank, ? not understood.
        var shape = ""
        var unrecognised = 0
        var outsideMonth = 0

        mutating func append(_ other: Log) {
            months += other.months
            shape += (shape.isEmpty ? "" : " | ") + other.shape
            unrecognised += other.unrecognised
            outsideMonth += other.outsideMonth
        }
    }

    static func parse(_ text: String, title: String = "") -> Log {
        var lines = Parse.splitLines(text).map(clean)
        if !title.isEmpty, let first = lines.first, Parse.nameKey(first) == Parse.nameKey(title) { lines.removeFirst() }
        var log = Log()
        for (index, line) in lines.enumerated() {
            if line.isEmpty {
                log.shape += "B"
                continue
            }
            // A month name without a year followed by dates is a student called like a month ("Abril").
            let next = lines[(index + 1)...].first { !$0.isEmpty }
            if let heading = monthHeading(line), heading.year != nil || !(next.map(startsWithLessons) ?? false) {
                log.months.append(MonthBlock(month: heading.month, year: heading.year))
                log.shape += "M"
                continue
            }
            guard let m = log.months.indices.last else {
                log.shape += "?"
                log.unrecognised += 1
                continue
            }
            let (body, amount) = splitAmount(line)
            if isTotal(line) {
                if let total = amount ?? lastAmount(line) {
                    log.months[m].total = total
                    log.shape += "T"
                } else {
                    log.shape += "?"
                    log.unrecognised += 1
                }
                continue
            }
            // A name counts when dates follow it, on its line or the next; otherwise it is free text.
            if let student = splitName(body), !student.rest.isEmpty || amount != nil || (next.map(startsWithLessons) ?? false) {
                let found = lessons(in: student.rest, month: log.months[m].month)
                let key = Parse.nameKey(student.name)
                if found.lessons.isEmpty, let amount,
                   let s = log.months[m].students.lastIndex(where: { Parse.nameKey($0.name) == key }) {
                    // "Álex: 175€" under the dates: that student's amount for the month.
                    log.months[m].students[s].amount = amount
                    log.shape += "A"
                    continue
                }
                log.months[m].students.append(StudentBlock(name: student.name, lessons: found.lessons, amount: amount))
                log.outsideMonth += found.outside
                log.shape += "S"
                continue
            }
            let found = lessons(in: body, month: log.months[m].month)
            if !found.lessons.isEmpty, let s = log.months[m].students.indices.last {
                log.months[m].students[s].lessons += found.lessons
                if let amount { log.months[m].students[s].amount = amount }
                log.outsideMonth += found.outside
                log.shape += "D"
            } else if let amount, !body.contains(where: \.isLetter) {
                // A bare amount under a month is its total.
                log.months[m].total = amount
                log.shape += "T"
            } else {
                log.shape += "?"
                log.unrecognised += 1
            }
        }
        return log
    }

    /// Bullets, heading marks, bold and checkboxes off; notes in brackets dropped, except a duration "(x1.5)".
    static func clean(_ raw: String) -> String {
        var line = raw.replacingOccurrences(of: "**", with: "").replacingOccurrences(of: "__", with: "")
        line = String(line.trimmingCharacters(in: .whitespaces).drop { "#>*-•· ".contains($0) })
        if let box = line.prefixMatch(of: /\[[ xX]\]\s*/) { line = String(line[box.range.upperBound...]) }
        line = line.replacing(/\(([^()]*)\)/) { match -> String in
            match.1.contains(/^\s*[xX×*]\s*\d/) ? " \(match.1) " : " "
        }
        return line.trimmingCharacters(in: .whitespaces)
    }

    static func startsWithLessons(_ line: String) -> Bool {
        line.first?.isNumber == true || line.prefixMatch(of: /[xX×*]\s*\d/) != nil
    }

    /// Lowercase words without accents: "Noviembre 2026:" → ["noviembre", "2026"].
    static func words(_ text: String) -> [String] {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en")).lowercased()
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init)
    }

    static let monthWords: [String: Int] = [
        "enero": 1, "january": 1, "ene": 1, "jan": 1, "febrero": 2, "february": 2, "feb": 2,
        "marzo": 3, "march": 3, "mar": 3, "abril": 4, "april": 4, "abr": 4, "apr": 4, "mayo": 5, "may": 5,
        "junio": 6, "june": 6, "jun": 6, "julio": 7, "july": 7, "jul": 7, "agosto": 8, "august": 8, "ago": 8, "aug": 8,
        "septiembre": 9, "setiembre": 9, "september": 9, "sep": 9, "sept": 9, "set": 9,
        "octubre": 10, "october": 10, "oct": 10, "noviembre": 11, "november": 11, "nov": 11,
        "diciembre": 12, "december": 12, "dic": 12, "dec": 12,
    ]

    /// Abbreviations only count as a month with a year ("Mar 2026"), so "Mar" alone can be a name.
    static let abbreviations: Set<String> = ["ene", "jan", "feb", "mar", "abr", "apr", "may", "jun", "jul", "ago", "aug", "sep", "sept", "set", "oct", "nov", "dic", "dec"]

    /// "Noviembre 2026", "noviembre", "Nov 26", "noviembre de 2025", "2026-11", "11/2026".
    static func monthHeading(_ line: String) -> (month: Int, year: Int?)? {
        var w = words(line)
        func year(_ number: Int) -> Int? {
            let full = number < 100 ? 2000 + number : number
            return (2015...2040).contains(full) ? full : nil
        }
        if w.count == 2, let a = Int(w[0]), let b = Int(w[1]) {
            if a > 99, let y = year(a), (1...12).contains(b) { return (b, y) }
            if b > 99, (1...12).contains(a), let y = year(b) { return (a, y) }
            return nil
        }
        guard w.count <= 3, let first = w.first, let month = monthWords[first] else { return nil }
        w.removeFirst()
        if w.first == "de" { w.removeFirst() }
        guard let rest = w.first else { return abbreviations.contains(first) ? nil : (month, nil) }
        guard w.count == 1, let number = Int(rest), let y = year(number) else { return nil }
        return (month, y)
    }

    static func isTotal(_ line: String) -> Bool {
        let w = words(line)
        return w.first == "total" || w.first == "suma" || w.contains("total") || line.hasPrefix("=")
    }

    static let number = /\d{1,3}(?:\.\d{3})+(?:,\d+)?|\d+(?:[.,]\d+)?/

    /// The amount written on a line ("= 100€", "100 €", "€100"), and the line without it.
    static func splitAmount(_ line: String) -> (body: String, amount: Double?) {
        if let equals = line.firstIndex(of: "=") {
            return (String(line[..<equals]).trimmingCharacters(in: .whitespaces), lastAmount(String(line[equals...])))
        }
        guard line.contains("€") else { return (line, nil) }
        let after = /(\d{1,3}(?:\.\d{3})+(?:,\d+)?|\d+(?:[.,]\d+)?)\s*€/
        let before = /€\s*(\d{1,3}(?:\.\d{3})+(?:,\d+)?|\d+(?:[.,]\d+)?)/
        guard let match = line.firstMatch(of: after) ?? line.firstMatch(of: before) else { return (line, nil) }
        var body = line
        body.removeSubrange(match.range)
        return (body.trimmingCharacters(in: .whitespaces), amount(String(match.1)))
    }

    /// The last number on a line.
    static func lastAmount(_ line: String) -> Double? {
        line.matches(of: number).last.flatMap { amount(String($0.0)) }
    }

    /// Spanish style when there is a comma ("1.250,50" → 1250.5); a dot before exactly three digits is a
    /// thousands mark ("1.250" → 1250); otherwise a decimal point ("62.5").
    static func amount(_ text: String) -> Double? {
        if text.contains(",") { return Double(text.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: ".")) }
        if text.wholeMatch(of: /\d{1,3}(?:\.\d{3})+/) != nil { return Double(text.replacingOccurrences(of: ".", with: "")) }
        return Double(text)
    }

    /// A student's name, alone or before their dates: "Álex", "Álex Bermúdez: 3/11, 5/11", "Carla 4/11".
    static func splitName(_ text: String) -> (name: String, rest: String)? {
        guard text.first?.isLetter == true, !startsWithLessons(text) else { return nil }
        var end = text.firstIndex { $0.isNumber || ":–—".contains($0) } ?? text.endIndex
        if let dash = text.range(of: " - "), dash.lowerBound < end { end = dash.lowerBound }
        guard let name = cleanName(String(text[..<end])), name.count >= 2, name.split(separator: " ").count <= 4 else { return nil }
        let rest = String(text[end...].drop { ":-–— ".contains($0) })
        if !rest.isEmpty, lessons(in: rest, month: 0).lessons.isEmpty { return nil }
        return (name, rest)
    }

    /// Dates with their durations: "3/11, 5/11 x1.5, 12/11 (x0,5)", "1, 8, 15x0.5". A date is one hour;
    /// a multiplier after it changes that lesson. `outside` counts dates written with another month.
    static func lessons(in text: String, month: Int) -> (lessons: [Lesson], outside: Int) {
        var lessons: [Lesson] = []
        var outside = 0
        let token = /(?<mult>[xX×*]\s*\d+(?:[.,]\d+)?)|(?<date>\d{1,2}(?:[\/.\-]\d{1,2})?(?:[\/.\-](?:\d{4}|\d{2}))?)/
        for match in text.matches(of: token) {
            if let mult = match.output.mult {
                let value = Double(mult.drop { !$0.isNumber }.replacingOccurrences(of: ",", with: "."))
                if let value, value > 0, value <= 4, !lessons.isEmpty { lessons[lessons.count - 1].hours = value }
            } else if let date = match.output.date {
                let parts = date.split(whereSeparator: { "/.-".contains($0) }).compactMap { Int($0) }
                guard let day = parts.first, (1...31).contains(day) else { continue }
                if parts.count >= 2 {
                    guard (1...12).contains(parts[1]) else { continue }
                    if month != 0, parts[1] != month { outside += 1 }
                }
                lessons.append(Lesson(day: day, hours: 1))
            }
        }
        return (lessons, outside)
    }

    /// A line's structure without its words: a word becomes "A" (capitalised) or "a", a number "9"; only
    /// generic words show (MES for a month, DIA for a weekday, TOTAL, EUR, and "x", "h", "min").
    /// "Álex: 3/10 x1,5" → "A: 9/9 x9,9". Used to see the note's layout without printing its text.
    static func mask(_ line: String, token: ((_ word: String, _ original: String) -> String)? = nil) -> String {
        let weekdays: Set<String> = ["lunes", "martes", "miercoles", "jueves", "viernes", "sabado", "domingo"]
        var out = ""
        var run = ""
        var runIsLetters = false
        func flush() {
            guard !run.isEmpty else { return }
            if runIsLetters, let token, !weekdays.contains(words(run).first ?? "") {
                out += token(words(run).first ?? "", run)
            } else if runIsLetters {
                let word = words(run).first ?? ""
                if monthWords[word] != nil && !abbreviations.contains(word) || ["sept", "set"].contains(word) { out += "MES" }
                else if weekdays.contains(word) { out += "DIA" }
                else if word == "total" || word == "suma" { out += "TOTAL" }
                else if ["euros", "euro", "eur"].contains(word) { out += "EUR" }
                else if ["x", "h", "min"].contains(word) { out += word }
                else { out += run.first?.isUppercase == true ? "A" : "a" }
            } else {
                out += "9"
            }
            run = ""
        }
        for char in line {
            if char.isLetter || char.isNumber {
                if !run.isEmpty, runIsLetters != char.isLetter { flush() }
                runIsLetters = char.isLetter
                run.append(char)
            } else {
                flush()
                // Invisible or unusual characters show as their code, e.g. U+FFFC for an inline object.
                if char.isASCII || "€º·–—•…“”‘’".contains(char) {
                    out.append(char == "\t" ? " " : char)
                } else {
                    out += char.unicodeScalars.map { String(format: "⟨U+%04X⟩", $0.value) }.joined()
                }
            }
        }
        flush()
        return out.replacing(/\ {2,}/, with: " ").trimmingCharacters(in: .whitespaces)
    }

    /// Like `mask`, but each distinct word gets a stable stand-in (W1, W2…), so a word that repeats, like
    /// a student across months, shows as the same stand-in while no word is printed. Month names show.
    static func pseudonymise(_ lines: [String]) -> [String] {
        let generic: Set<String> = ["total", "suma", "euros", "euro", "eur", "x", "h", "min", "de", "y", "clase", "clases"]
        var table: [String: String] = [:]
        return lines.map { line in
            mask(line, token: { word, original in
                if monthWords[word] != nil, !abbreviations.contains(word) { return word }
                if generic.contains(word) { return word }
                if let token = table[word] { return token }
                let token = "W\(table.count + 1)"
                table[word] = token
                return token
            })
        }
    }

    /// The structure view printed by `--shape`: the first lines with words replaced by stand-ins, then how
    /// often each masked pattern occurs.
    static func shapeReport(_ text: String, title: String, lines limit: Int = 130) -> String {
        var lines = Parse.splitLines(text)
        if let first = lines.first, Parse.nameKey(first) == Parse.nameKey(title) { lines.removeFirst() }
        let masked = lines.map { mask($0) }
        let stand = pseudonymise(lines)
        var counts: [String: Int] = [:]
        for line in masked where !line.isEmpty { counts[line, default: 0] += 1 }
        var out = ["Structure of the first \(min(limit, masked.count)) of \(masked.count) lines (words replaced by stand-ins):"]
        out += stand.prefix(limit).enumerated().filter { !$0.element.isEmpty }.map { String(format: "%3d  ", $0.offset + 1) + $0.element }
        out.append("Most common line patterns in the whole note:")
        out += counts.sorted { $0.value > $1.value || ($0.value == $1.value && $0.key < $1.key) }.prefix(25).map { "\($0.value)×  \($0.key)" }
        return out.joined(separator: "\n")
    }

    // MARK: Sorting

    struct Row: Equatable {
        var month: String
        var code: String
        var lessons: Int
        var hours: Double
        var rate: Double?
        var amount: Double? { rate.map { ($0 * hours * 100).rounded() / 100 } }
    }

    struct MonthCheck: Equatable {
        var month: String
        var total: Double?
        var computed: Double?
        var fits: Bool
    }

    struct Result {
        var rows: [Row] = []
        var months: [MonthCheck] = []
        var checks: [String] = []
        var log = Log()
        var namesWithoutLessons = 0
        var students: [String] { Array(Set(rows.map(\.code))).sorted() }
    }

    /// The rates Jose has charged, newest first.
    static let rates: [Double] = [50, 40, 30, 25]

    static func sort(_ log: Log, contacts: [String: TutoringContact] = [:], today: Date, cal: DeskCalendar) -> Result {
        var result = Result(log: log)
        let years = assignYears(log.months, today: today, cal: cal)
        // Oldest month first, so each student's previous rate is known and the earliest students get
        // the plainest initials.
        let order = log.months.indices.sorted { (years[$0], log.months[$0].month) < (years[$1], log.months[$1].month) }
        let blocks = order.flatMap { log.months[$0].students }
        result.namesWithoutLessons = blocks.filter { $0.lessons.isEmpty }.count
        let codes = assignCodes(blocks.filter { !$0.lessons.isEmpty }.map(\.name), contacts: contacts)
        var lastRate: [String: Double] = [:]
        for index in order {
            let block = log.months[index]
            let key = String(format: "%04d-%02d", years[index], block.month)
            var seen: [String] = []
            var hours: [String: Double] = [:]
            var count: [String: Int] = [:]
            var written: [String: Double] = [:]
            for student in block.students where !student.lessons.isEmpty {
                guard let code = codes[Parse.nameKey(student.name)] else { continue }
                if hours[code] == nil { seen.append(code) }
                hours[code, default: 0] += student.lessons.map(\.hours).reduce(0, +)
                count[code, default: 0] += student.lessons.count
                if let amount = student.amount { written[code, default: 0] += amount }
            }
            guard !seen.isEmpty else { continue }
            var rate: [String: Double] = [:]
            for code in seen {
                if let amount = written[code], let h = hours[code], h > 0 { rate[code] = amount / h }
            }
            let open = seen.filter { rate[$0] == nil }
            var fits = false
            if let total = block.total {
                let fixed = seen.compactMap { code in rate[code].map { $0 * (hours[code] ?? 0) } }.reduce(0, +)
                let fit = fitRates(hours: open.map { hours[$0] ?? 0 }, total: total - fixed, prior: open.map { lastRate[$0] })
                for (code, value) in zip(open, fit.rates) { rate[code] = value }
                fits = fit.exact
                let mix = seen.map { "\($0) \(rate[$0].map(Parse.number) ?? "?")" }.joined(separator: ", ")
                let sum = seen.compactMap { code in rate[code].map { $0 * (hours[code] ?? 0) } }.reduce(0, +)
                if !fit.exact {
                    result.checks.append("\(key): no mix of \(rates.map(Parse.number).joined(separator: "/")) €/h gives your total of \(Parse.number(total)) €; the closest is \(Parse.number(sum)) € (\(mix) €/h).")
                } else if fit.ambiguous {
                    result.checks.append("\(key): your total of \(Parse.number(total)) € fits more than one mix of rates; I used \(mix) €/h.")
                }
            } else {
                for code in open { rate[code] = lastRate[code] }
                let unknown = open.filter { rate[$0] == nil }
                result.checks.append(unknown.isEmpty
                    ? "\(key): no total under it, so each student's previous rate is used."
                    : "\(key): no total under it, and no earlier rate for \(unknown.joined(separator: ", ")).")
            }
            var computed: Double? = 0
            for code in seen {
                let row = Row(month: key, code: code, lessons: count[code] ?? 0, hours: hours[code] ?? 0, rate: rate[code])
                result.rows.append(row)
                if let value = rate[code] { lastRate[code] = value }
                computed = computed.flatMap { sum in row.amount.map { sum + $0 } }
            }
            result.months.append(MonthCheck(month: key, total: block.total, computed: computed, fits: fits))
        }
        if log.unrecognised > 0 {
            result.checks.append("\(log.unrecognised) lines weren't understood; they are marked ? in the shape.")
        }
        if log.outsideMonth > 0 {
            result.checks.append("\(log.outsideMonth) dates are written with a different month than their heading.")
        }
        if result.namesWithoutLessons > 0 {
            result.checks.append("\(result.namesWithoutLessons) name lines had no dates and were left out.")
        }
        return result
    }

    /// One rate per student, from `rates`, whose total matches the month's: the smallest difference first,
    /// then the fewest changes from each student's previous rate, then the fewest different rates.
    static func fitRates(hours: [Double], total: Double, prior: [Double?]) -> (rates: [Double], exact: Bool, ambiguous: Bool) {
        let n = hours.count
        guard n > 0 else { return ([], abs(total) < 0.01, false) }
        guard n <= 8 else {
            let chosen = prior.map { $0 ?? rates[0] }
            return (chosen, abs(zip(hours, chosen).map(*).reduce(0, +) - total) < 0.01, false)
        }
        var best: (rates: [Double], score: (Double, Int, Int))?
        var ties = 0
        var digits = [Int](repeating: 0, count: n)
        while true {
            let chosen = digits.map { rates[$0] }
            let diff = (abs(zip(hours, chosen).map(*).reduce(0, +) - total) * 100).rounded() / 100
            let changes = zip(chosen, prior).filter { $1 != nil && $0 != $1 }.count
            let score = (diff, changes, Set(chosen).count)
            if let current = best {
                if score < current.score {
                    best = (chosen, score)
                    ties = 0
                } else if score == current.score {
                    ties += 1
                }
            } else {
                best = (chosen, score)
            }
            var i = 0
            while i < n {
                digits[i] += 1
                if digits[i] < rates.count { break }
                digits[i] = 0
                i += 1
            }
            if i == n { break }
        }
        guard let best else { return (prior.map { $0 ?? rates[0] }, false, false) }
        let exact = best.score.0 < 0.01
        return (best.rates, exact, exact && ties > 0)
    }

    /// Years for months written without one: the note's order (oldest or newest first) is followed from a
    /// heading that has a year, or else the newest month is this month or the last one that has passed.
    static func assignYears(_ months: [MonthBlock], today: Date, cal: DeskCalendar) -> [Int] {
        guard !months.isEmpty else { return [] }
        var forward = 0
        var backward = 0
        for (a, b) in zip(months, months.dropFirst()) {
            let delta = (b.month - a.month + 12) % 12
            if delta == 0 { continue }
            if delta <= 6 { forward += 1 } else { backward += 1 }
        }
        let oldestFirst = forward >= backward
        var position = [0]
        for (a, b) in zip(months, months.dropFirst()) {
            let delta = oldestFirst ? (b.month - a.month + 12) % 12 : -((a.month - b.month + 12) % 12)
            position.append((position.last ?? 0) + delta)
        }
        let offset: Int
        if let i = months.indices.first(where: { months[$0].year != nil }), let year = months[i].year {
            offset = year * 12 + months[i].month - 1 - position[i]
        } else {
            let newest = position.indices.max { position[$0] < position[$1] } ?? 0
            let nowYear = cal.calendar.component(.year, from: today)
            let nowMonth = cal.calendar.component(.month, from: today)
            let year = months[newest].month <= nowMonth ? nowYear : nowYear - 1
            offset = year * 12 + months[newest].month - 1 - position[newest]
        }
        return months.indices.map { months[$0].year ?? (position[$0] + offset) / 12 }
    }

    /// Initials for every name, in order of first appearance: a `contacts.json` key when the first name
    /// matches, else derived, with a digit on a clash. "Álex" and "Álex Bermúdez" are one student when only
    /// one full name starts with "Álex".
    static func assignCodes(_ names: [String], contacts: [String: TutoringContact]) -> [String: String] {
        var keys: [String] = []
        for key in names.map(Parse.nameKey) where !keys.contains(key) { keys.append(key) }
        var alias: [String: String] = [:]
        for key in keys where !key.contains(" ") {
            let longer = keys.filter { $0.hasPrefix(key + " ") }
            if longer.count == 1 { alias[key] = longer[0] }
        }
        keys = keys.filter { alias[$0] == nil }
        let usable = contacts.filter { isSafeCode($0.key) }.sorted { $0.key < $1.key }
        var used = Set(usable.map(\.key))
        var codes: [String: String] = [:]
        for key in keys {
            if let contact = usable.first(where: { sameStudent(Parse.nameKey($0.value.student), key) }) {
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
        for (short, long) in alias { codes[short] = codes[long] }
        return codes
    }

    // MARK: Names

    /// Words that may come before a name: "Clase con Emma", "Martes Álex".
    static let fillerWords: Set<String> = [
        "clase", "clases", "class", "lesson", "sesion", "session", "tutoria", "con", "with",
        "lunes", "martes", "miercoles", "jueves", "viernes", "sabado", "domingo",
        "monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday",
    ]

    /// Letters-only words with leading filler dropped; `nil` when nothing is left.
    static func cleanName(_ raw: String) -> String? {
        var parts = raw.split(whereSeparator: { !$0.isLetter }).map(String.init)
        while let first = parts.first, fillerWords.contains(Parse.nameKey(first)) { parts.removeFirst() }
        return parts.isEmpty ? nil : parts.joined(separator: " ")
    }

    /// "alex bermudez" → "AB"; a single name gives its first two letters: "carla" → "CA".
    static func initials(forKey key: String) -> String {
        let parts = key.split(separator: " ").map { $0.uppercased() }
        guard let first = parts.first else { return "XX" }
        if parts.count >= 2, let a = first.first, let b = parts[1].first { return String([a, b]) }
        return String(first.prefix(2))
    }

    /// The same student when the names are equal or the first names are.
    static func sameStudent(_ a: String, _ b: String) -> Bool {
        a == b || (a.split(separator: " ").first != nil && a.split(separator: " ").first == b.split(separator: " ").first)
    }

    /// Initials become table cells and may become file names, so only letters and digits.
    static func isSafeCode(_ code: String) -> Bool {
        (1...6).contains(code.count) && code.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber) }
    }

    // MARK: Output

    static let reviewFile = "tutoring/classes-review.md"
    static let marker = "<!-- Preliminary sort by Desk of the Notes note \"Classes\". Initials only; it never leaves the Mac. The next import replaces this file. -->"

    /// The review file: what to check first, then lessons, hours, rates and amounts by month and by student.
    static func review(_ result: Result) -> String {
        var lines = [marker, "", "# Tutoring: preliminary sort", ""]
        lines.append("Each date is a one-hour lesson; x0.5 and x1.5 count as 30 and 90 minutes. Each month's rates are fitted to its total from \(rates.map(Parse.number).joined(separator: ", ")) €/h.")
        lines += ["", "## To check", ""]
        lines += result.checks.isEmpty ? ["Nothing: every month's total fits."] : result.checks.map { "- \($0)" }
        lines += ["", "## By month", "", "| Month | Student | Lessons | Hours | €/h | Amount |", "|---|---|---|---|---|---|"]
        for row in result.rows {
            lines.append("| \(row.month) | \(row.code) | \(row.lessons) | \(Parse.number(row.hours)) | \(row.rate.map(Parse.number) ?? "?") | \(row.amount.map(Parse.number) ?? "?") |")
        }
        lines += ["", "## Totals", "", "| Month | Your total | Desk's total | Fits |", "|---|---|---|---|"]
        for month in result.months {
            lines.append("| \(month.month) | \(month.total.map(Parse.number) ?? "—") | \(month.computed.map(Parse.number) ?? "—") | \(month.fits ? "yes" : "check") |")
        }
        lines += ["", "## By student", "", "| Student | First month | Last month | Lessons | Hours | Amount |", "|---|---|---|---|---|---|"]
        for code in result.students {
            let rows = result.rows.filter { $0.code == code }
            lines.append("| \(code) | \(rows.first?.month ?? "") | \(rows.last?.month ?? "") | \(rows.map(\.lessons).reduce(0, +)) | \(Parse.number(rows.map(\.hours).reduce(0, +))) | \(Parse.number(rows.compactMap(\.amount).reduce(0, +))) |")
        }
        return lines.joined(separator: "\n") + "\n"
    }

    /// The summary printed after an import: counts, initials, months and amounts, never a name or a line of text.
    static func report(_ result: Result, notes: Int, dryRun: Bool, writeCheck: String?, written: String?) -> String {
        let lessons = result.rows.map(\.lessons).reduce(0, +)
        let hours = result.rows.map(\.hours).reduce(0, +)
        var lines = ["Classes import" + (dryRun ? " (dry run: nothing written)" : "")]
        lines.append("Read \(notes) note\(notes == 1 ? "" : "s"): \(result.months.count) months (\(result.months.first?.month ?? "–") to \(result.months.last?.month ?? "–")), \(result.students.count) students, \(lessons) lessons, \(Parse.number(hours)) hours.")
        lines.append("Totals: \(result.months.filter { $0.total != nil }.count) of \(result.months.count) months have one; \(result.months.filter(\.fits).count) fit the rates exactly.")
        var latest: [String: Double] = [:]
        for row in result.rows { if let rate = row.rate { latest[row.code] = rate } }
        lines.append("Latest rate per student: " + (latest.isEmpty ? "none" : latest.sorted { $0.key < $1.key }.map { "\($0.key) \(Parse.number($0.value))" }.joined(separator: ", ")) + " €/h.")
        let shape = result.log.shape
        lines.append("Shape (a letter per line): " + (shape.count > 400 ? String(shape.prefix(400)) + "…" : shape))
        if !result.checks.isEmpty {
            lines.append("To check (\(result.checks.count)):")
            lines += result.checks.prefix(15).map { "- \($0)" }
            if result.checks.count > 15 { lines.append("- and \(result.checks.count - 15) more in the review file") }
        }
        lines.append("Write check: " + (writeCheck ?? "ok, tutoring/ is gitignored"))
        if let written { lines.append("Wrote \(written).") }
        return lines.joined(separator: "\n")
    }

    /// Why the import must not write to this vault, or `nil` when it may.
    static func refusal(for vault: URL) -> String? {
        let path = vault.standardizedFileURL.path
        if path.contains("/demo-vault") { return "Desk never writes to the demo vault." }
        guard FileManager.default.fileExists(atPath: vault.appendingPathComponent(".git").path) else {
            return "\(path) is not a git vault."
        }
        // tutoring/ must be gitignored, so nothing imported can reach GitHub.
        guard (try? Git(root: vault).run(["check-ignore", "-q", "tutoring/XX.md"])) != nil else {
            return "tutoring/ is not in the vault's .gitignore, so the import could be committed. Add it first."
        }
        return nil
    }

    /// Writes the review file. A file at that path that Desk did not write is never replaced.
    static func write(_ result: Result, to vault: URL) throws -> String {
        let url = vault.appendingPathComponent(reviewFile)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        if let existing = try? String(contentsOf: url, encoding: .utf8), !existing.hasPrefix(marker) {
            throw NotesReader.Failure(message: "\(reviewFile) exists and wasn't written by Desk, so nothing was replaced.")
        }
        try review(result).write(to: url, atomically: true, encoding: .utf8)
        return reviewFile
    }
}
