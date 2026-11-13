import Foundation

extension ClassesImport {
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
}
