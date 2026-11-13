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

        enum CodingKeys: String, CodingKey {
            case rates, families, parents, ignore, paidThrough = "paid_through", currentMonths = "current_months"
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
        }

        static func load(_ text: String?) -> Settings {
            text.flatMap { try? JSONDecoder().decode(Settings.self, from: Data($0.utf8)) } ?? Settings()
        }
    }

    // MARK: Reading the note

    struct Lesson: Equatable {
        var day: Int
        var month: Int
        var hours: Double
    }

    struct Entry {
        var name: String
        var rate: Double?
        var twoRates = false
        var lessons: [Lesson] = []
        /// "4 lessons" without dates.
        var count = 0
        /// "(+ 2 septiembre)": lessons from another month, counted here.
        var extras = 0
        var amount: Double?
        var group: String?
        var hours: Double { lessons.map(\.hours).reduce(0, +) + Double(count + extras) }
        var lessonCount: Int { lessons.count + count + extras }
    }

    struct Total {
        var amount: Double
        var family: String?
        /// How many students of the month were listed above the total: a total covers those.
        var upto: Int
    }

    struct Block {
        var month: Int
        var year: Int?
        var entries: [Entry] = []
        var totals: [Total] = []
    }

    static func fold(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en")).lowercased()
            .trimmingCharacters(in: .whitespaces)
    }

    static func words(_ text: String) -> [String] {
        fold(text).split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init)
    }

    static let monthWords: [String: Int] = [
        "january": 1, "february": 2, "march": 3, "april": 4, "may": 5, "june": 6, "july": 7, "august": 8,
        "september": 9, "october": 10, "november": 11, "december": 12, "summer": 7,
        "enero": 1, "febrero": 2, "marzo": 3, "abril": 4, "mayo": 5, "junio": 6, "julio": 7, "agosto": 8,
        "septiembre": 9, "octubre": 10, "noviembre": 11, "diciembre": 12, "verano": 7,
    ]

    /// Words in a level heading: "IB HL:", "Middle school:", "10th grade:".
    static let levelWords: Set<String> = ["ib", "hl", "sl", "school", "grade", "app", "analysis", "math", "maths",
                                          "bach", "eso", "middle", "high", "9th", "10th", "11th", "12th"]

    static func parse(_ text: String) -> (blocks: [Block], ignored: Int) {
        var blocks: [Block] = []
        var ignored = 0
        var pendingYear: Int?
        var group: String?
        for raw in Parse.splitLines(text) {
            let line = String(raw.trimmingCharacters(in: .whitespaces).drop { "*• ".contains($0) })
                .trimmingCharacters(in: .whitespaces)
            if line.isEmpty { continue }
            let w = words(line)
            if let year = line.wholeMatch(of: /(\d{4}):?/).flatMap({ Int($0.1) }) {
                pendingYear = year
                continue
            }
            if w.first == "iban" {
                ignored += 1
                continue
            }
            if w.first == "total" {
                guard let amount = euroAmounts(line).last else {
                    ignored += 1
                    continue
                }
                var target = blocks.indices.last
                var upto = target.map { blocks[$0].entries.count } ?? 0
                if let named = w.compactMap({ monthWords[$0] }).first,
                   let found = blocks.indices.suffix(5).last(where: { blocks[$0].month == named }) {
                    if found != target { upto = blocks[found].entries.count }
                    target = found
                }
                if let target { blocks[target].totals.append(Total(amount: amount, family: family(in: line), upto: upto)) }
                continue
            }
            if let heading = line.wholeMatch(of: /(\p{L}+)\s*:?/), let month = monthWords[fold(String(heading.1))] {
                blocks.append(Block(month: month, year: pendingYear))
                pendingYear = nil
                group = nil
                continue
            }
            if line.hasSuffix(":"), !line.contains("("), !Set(w).isDisjoint(with: levelWords) {
                group = String(line.dropLast()).trimmingCharacters(in: .whitespaces)
                continue
            }
            guard var entry = entry(from: line) else {
                ignored += 1
                continue
            }
            entry.group = group
            if blocks.isEmpty, let first = entry.lessons.first { blocks.append(Block(month: first.month)) }
            guard let last = blocks.indices.last else { continue }
            blocks[last].entries.append(entry)
        }
        return (blocks, ignored)
    }

    /// A student line: "Hugo: (06/10), (13/10)", "Lina (30): (03/02)", "Omar: (65/70): (05/10)",
    /// "Nora (50): 4 lessons", "Hugo Brand: 2 classes (23/09, 29/09) 50€". `nil` for anything else.
    static func entry(from line: String) -> Entry? {
        let text = line.replacing(/\((\d{1,2}),(\d{1,2})\)/) { "(\($0.1)/\($0.2))" }
        let pattern = /(\p{L}[\p{L} ]*\p{L})\s*(?:\((\d{2,3})(?:\/(\d{2,3}))?\)(?=\s*:))?\s*:?\s*(?:\((\d{2,3})(?:\/(\d{2,3}))?\)\s*:)?\s*(.*)/
        guard let m = text.wholeMatch(of: pattern), m.1.split(separator: " ").count <= 3 else { return nil }
        let rest = String(m.6)
        var entry = Entry(name: String(m.1).trimmingCharacters(in: .whitespaces))
        entry.rate = (m.2 ?? m.4).flatMap { Double($0) }
        entry.twoRates = (m.3 ?? m.5) != nil
        for date in rest.matches(of: /(?:^|\D)(\d{1,2})\/(\d{1,2})(?!\d)/) {
            guard let day = Int(date.1), let month = Int(date.2), (1...31).contains(day), (1...12).contains(month) else { continue }
            let hours = rest[date.range.upperBound...].prefixMatch(of: /\)?\s*[xX]\s*(\d+(?:[.,]\d+)?)/)
                .flatMap { Double($0.1.replacingOccurrences(of: ",", with: ".")) } ?? 1
            entry.lessons.append(Lesson(day: day, month: month, hours: hours))
        }
        if entry.lessons.isEmpty, let count = rest.firstMatch(of: /(\d+)\s*(?:lessons?|classes?|clases?)/.ignoresCase()) {
            entry.count = Int(count.1) ?? 0
        }
        entry.extras = rest.matches(of: /\(\+\s*(\d+)\s*\p{L}+\)/).compactMap { Int($0.1) }.reduce(0, +)
        entry.amount = euroAmounts(rest).last
        return entry.lessonCount == 0 ? nil : entry
    }

    static func euroAmounts(_ text: String) -> [Double] {
        text.matches(of: /(\d+(?:[.,]\d+)?)\s*€/).compactMap { Double($0.1.replacingOccurrences(of: ",", with: ".")) }
    }

    /// "Total for January (Vidal)" → "Vidal"; "TOTAL Brand: 150€" → "Brand"; "Total for October" → nil.
    static func family(in line: String) -> String? {
        if let m = line.firstMatch(of: /\(([^)]*\p{L}[^)]*)\)/) { return String(m.1).trimmingCharacters(in: .whitespaces) }
        let rest = line.split(whereSeparator: { !$0.isLetter }).map(String.init)
            .filter { !["total", "for", "de", "of"].contains(fold($0)) && monthWords[fold($0)] == nil }
        return rest.isEmpty ? nil : rest.joined(separator: " ")
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

    /// One lesson on its day, for the Tutoring tab's week.
    struct Dated: Equatable {
        var date: String
        var code: String
        var hours: Double
    }

    struct Result {
        var rows: [Row] = []
        var dates: [Dated] = []
        var checks: [String] = []
        /// Initials → the name as written ("Hugo Brand").
        var names: [String: String] = [:]
        var levels: [String: String] = [:]
        var current: [String] = []
        var archived: [String] = []
        var recaps = 0
        var ignored = 0
        var latestRate: [String: Double] {
            var rates: [String: Double] = [:]
            for row in rows { if let rate = row.rate { rates[row.code] = rate } }
            return rates
        }
    }

    static let candidates: [Double] = [25, 30, 35, 40, 45, 50, 60, 65, 70]

    static func sort(_ parsed: (blocks: [Block], ignored: Int), settings: Settings, today: Date, cal: DeskCalendar) -> Result {
        var result = Result(ignored: parsed.ignored)
        let ignore = Set(settings.ignore.map(fold))
        func ignored(_ name: String) -> Bool {
            ignore.contains(fold(name)) || ignore.contains(fold(name).split(separator: " ").first.map(String.init) ?? "")
        }
        // Ignored students leave the month, and each total then counts only the students left above it.
        var blocks = parsed.blocks.map { block -> Block in
            var block = block
            let skip = block.entries.map { ignored($0.name) }
            for t in block.totals.indices { block.totals[t].upto = skip.prefix(block.totals[t].upto).filter { !$0 }.count }
            block.entries = zip(block.entries, skip).filter { !$0.1 }.map { $0.0 }
            return block
        }

        // One key per student: "Hugo" is "Hugo Brand" when only one full name starts with it.
        var keys: [String] = []
        for entry in blocks.flatMap(\.entries) where !keys.contains(fold(entry.name)) { keys.append(fold(entry.name)) }
        var alias: [String: String] = [:]
        for key in keys where !key.contains(" ") {
            let longer = keys.filter { $0.hasPrefix(key + " ") }
            if longer.count == 1 { alias[key] = longer[0] }
        }
        func canon(_ name: String) -> String { alias[fold(name)] ?? fold(name) }
        var codes: [String: String] = [:]
        var used = Set<String>()
        for key in keys.map({ alias[$0] ?? $0 }) where codes[key] == nil {
            let parts = key.split(separator: " ").map { $0.uppercased() }
            let first = parts.first ?? "XX"
            var options = parts.count > 1 ? [String([first.first ?? "X", parts[1].first ?? "X"])] : []
            options += first.dropFirst().filter(\.isLetter).map { String([first.first ?? "X", $0]) }
            let code = options.first { !used.contains($0) }
                ?? (2...99).map { String(first.prefix(2)) + String($0) }.first { !used.contains($0) } ?? key
            used.insert(code)
            codes[key] = code
        }
        func code(_ name: String) -> String { codes[canon(name)] ?? "?" }
        for entry in blocks.flatMap(\.entries) where entry.name.count > (result.names[code(entry.name)]?.count ?? 0) {
            result.names[code(entry.name)] = entry.name
        }

        // A month list that repeats lessons already counted (an invoice recap) is not counted again.
        var window: [Set<String>] = []
        var counted: [Block] = []
        for block in blocks {
            let lessons = Set(block.entries.flatMap { e in e.lessons.map { "\(code(e.name))|\($0.day)|\($0.month)" } })
            let seen = window.suffix(8).reduce(into: Set<String>()) { $0.formUnion($1) }
            if lessons.count >= 2, Double(lessons.intersection(seen).count) >= 2.0 / 3.0 * Double(lessons.count) {
                result.recaps += 1
            } else {
                window.append(lessons)
                counted.append(block)
            }
        }
        blocks = counted
        guard !blocks.isEmpty else { return result }

        // Years: the newest month is this one or the last one passed; going back, a higher month is a year earlier.
        let nowYear = cal.calendar.component(.year, from: today)
        let nowMonth = cal.calendar.component(.month, from: today)
        var year = (blocks.last?.month ?? 1) <= nowMonth ? nowYear : nowYear - 1
        var years = [Int](repeating: 0, count: blocks.count)
        for i in blocks.indices.reversed() {
            if i < blocks.count - 1, blocks[i].month > blocks[i + 1].month { year -= 1 }
            years[i] = year
            if let written = blocks[i].year, written != year {
                result.checks.append(String(format: "%04d-%02d: the note writes %d before this month.", year, blocks[i].month, written))
            }
        }

        // Rates: a number in the note > an amount on the line > Jose's default before any number > a fitting total
        // > the student's previous rate.
        func defaultRate(_ name: String) -> Double? {
            let full = canon(name)
            return settings.rates.first { fold($0.key) == full || fold($0.key) == full.split(separator: " ").first.map(String.init) }?.value
        }
        func inFamily(_ name: String, _ family: String?) -> Bool {
            guard let family else { return false }
            let full = canon(name)
            if full.split(separator: " ").last.map(String.init) == fold(family).split(separator: " ").last.map(String.init) { return true }
            return settings.families.first { fold($0.key) == fold(family) }?.value.contains { fold($0) == full || fold($0) == full.split(separator: " ").first.map(String.init) } == true
        }
        var lastRate: [String: Double] = [:]
        var numbered = Set<String>()
        for (i, block) in blocks.enumerated() {
            let ym = String(format: "%04d-%02d", years[i], block.month)
            // Each dated lesson on its day. A lesson from a neighbouring month across New Year takes that year.
            for entry in block.entries {
                for lesson in entry.lessons {
                    var year = years[i]
                    if lesson.month - block.month > 6 { year -= 1 } else if block.month - lesson.month > 6 { year += 1 }
                    guard let day = cal.date(year: year, month: lesson.month, day: lesson.day),
                          cal.calendar.component(.day, from: day) == lesson.day else { continue }
                    result.dates.append(Dated(date: String(format: "%04d-%02d-%02d", year, lesson.month, lesson.day),
                                              code: code(entry.name), hours: lesson.hours))
                }
            }
            var order: [String] = []
            var lessons: [String: Int] = [:]
            var hours: [String: Double] = [:]
            var rate: [String: Double] = [:]
            var written: [String: Double] = [:]
            var name: [String: String] = [:]
            for entry in block.entries {
                let c = code(entry.name)
                if lessons[c] == nil { order.append(c) }
                name[c] = entry.name
                lessons[c, default: 0] += entry.lessonCount
                hours[c, default: 0] += entry.hours
                if let r = entry.rate { rate[c] = r }
                if let a = entry.amount { written[c, default: 0] += a }
                if let g = entry.group { result.levels[c] = g }
                if entry.extras > 0 { result.checks.append("\(ym): \(entry.name) has \"+\(entry.extras)\" lessons from another month; counted here.") }
                if entry.twoRates, let r = entry.rate { result.checks.append("\(ym): \(entry.name) has two rates written; \(Parse.number(r)) used.") }
            }
            for c in order {
                if rate[c] != nil { numbered.insert(c) }
                if rate[c] == nil, let a = written[c], let h = hours[c], h > 0 { rate[c] = a / h }
                if rate[c] == nil, !numbered.contains(c), let d = defaultRate(name[c] ?? "") { rate[c] = d }
            }
            var pooled = 0.0
            var poolUpto = 0
            for total in block.totals {
                let members = order.filter { inFamily(name[$0] ?? "", total.family) }
                if !members.isEmpty {
                    let open = members.filter { rate[$0] == nil }
                    let fixed = members.compactMap { c in rate[c].map { $0 * (hours[c] ?? 0) } }.reduce(0, +)
                    if !open.isEmpty, let fit = fitRates(open.map { hours[$0] ?? 0 }, total.amount - fixed, open.map { lastRate[$0] }), fit.exact {
                        for (c, r) in zip(open, fit.rates) { rate[c] = r }
                    }
                } else if let family = total.family, settings.families.keys.contains(where: { fold($0) == fold(family) }) {
                    result.checks.append("\(ym): the \(family) total of \(Parse.number(total.amount)) € has no lessons in that month.")
                } else {
                    pooled += total.amount
                    poolUpto = max(poolUpto, total.upto)
                }
            }
            // A month's total covers every student listed above it, families included.
            func above(_ upto: Int) -> [String] {
                let codes = Set(block.entries.prefix(upto).map { code($0.name) })
                return order.filter(codes.contains)
            }
            if pooled > 0 {
                let rest = above(poolUpto)
                let open = rest.filter { rate[$0] == nil }
                let fixed = rest.compactMap { c in rate[c].map { $0 * (hours[c] ?? 0) } }.reduce(0, +)
                if !open.isEmpty, let fit = fitRates(open.map { hours[$0] ?? 0 }, pooled - fixed, open.map { lastRate[$0] }) {
                    if fit.exact { for (c, r) in zip(open, fit.rates) { rate[c] = r } }
                    if !fit.exact {
                        result.checks.append("\(ym): the total of \(Parse.number(pooled)) € fits no mix of rates for \(rest.compactMap { result.names[$0] }.joined(separator: ", ")); rates left unknown.")
                    } else if fit.ambiguous {
                        result.checks.append("\(ym): the total of \(Parse.number(pooled)) € fits more than one mix of rates.")
                    }
                }
            }
            for c in order {
                if rate[c] == nil { rate[c] = lastRate[c] }
            }
            // A total the final rates don't reproduce is worth a look.
            for total in block.totals {
                let group = total.family == nil ? above(total.upto) : order.filter { inFamily(name[$0] ?? "", total.family) }
                guard !group.isEmpty, group.allSatisfy({ rate[$0] != nil }) else { continue }
                let got = group.map { (rate[$0] ?? 0) * (hours[$0] ?? 0) }.reduce(0, +)
                if abs(got - total.amount) > 0.01 {
                    result.checks.append("\(ym): \(total.family.map { "the \($0) total" } ?? "the total") says \(Parse.number(total.amount)) €; the rates give \(Parse.number(got)) €.")
                }
            }
            for c in order {
                result.rows.append(Row(month: ym, code: c, lessons: lessons[c] ?? 0, hours: hours[c] ?? 0, rate: rate[c]))
                if let r = rate[c] { lastRate[c] = r }
            }
        }
        for row in result.rows where row.rate == nil {
            result.checks.append("\(row.month): no rate known for \(result.names[row.code] ?? row.code).")
        }
        let recent = Set(Array(Set(result.rows.map(\.month))).sorted().suffix(max(1, settings.currentMonths)))
        var seenCodes: [String] = []
        for row in result.rows where !seenCodes.contains(row.code) { seenCodes.append(row.code) }
        let currentSet = Set(result.rows.filter { recent.contains($0.month) }.map(\.code))
        result.current = seenCodes.filter(currentSet.contains)
        result.archived = seenCodes.filter { !currentSet.contains($0) }
        return result
    }

    /// One rate per student whose sum matches the total: the smallest difference, then the fewest changes from
    /// each student's previous rate, then the fewest different rates. `nil` for more than five students.
    static func fitRates(_ hours: [Double], _ total: Double, _ prior: [Double?]) -> (rates: [Double], exact: Bool, ambiguous: Bool)? {
        let n = hours.count
        guard n > 0, n <= 5 else { return nil }
        var best: (rates: [Double], score: (Double, Int, Int))?
        var exact = 0
        var digits = [Int](repeating: 0, count: n)
        while true {
            let chosen = digits.map { candidates[$0] }
            let diff = (abs(zip(hours, chosen).map(*).reduce(0, +) - total) * 100).rounded() / 100
            if diff < 0.01 { exact += 1 }
            let score = (diff, zip(chosen, prior).filter { $1 != nil && $0 != $1 }.count, Set(chosen).count)
            if best == nil || score < (best?.score ?? score) { best = (chosen, score) }
            var i = 0
            while i < n {
                digits[i] += 1
                if digits[i] < candidates.count { break }
                digits[i] = 0
                i += 1
            }
            if i == n { break }
        }
        guard let best else { return nil }
        return (best.rates, best.score.0 < 0.01, exact > 1)
    }

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
            let level = result.levels[c] ?? old?.level ?? ""
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
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        try save(VaultData.tutoringContactsFile, String(decoding: try encoder.encode(contacts), as: UTF8.self) + "\n")

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
