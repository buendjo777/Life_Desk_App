import Foundation

extension ClassesImport {
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
}
