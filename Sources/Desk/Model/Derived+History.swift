import Foundation

/// The History tab: what tutoring earned by month, year and student, from `tutoring/lessons.csv`
/// (written by Desk from the Classes note).
extension Derived {
    /// Lessons, hours and euros for a month, a year or a student.
    struct Earnings: Identifiable {
        /// "2026-10", "2026" or a student's initials.
        let key: String
        var lessons = 0
        var hours = 0.0
        var amount = 0.0
        var months: Set<String> = []
        var students: Set<String> = []
        var id: String { key }

        mutating func add(_ row: LessonRow) {
            lessons += row.lessons
            hours += row.hours
            amount += row.amount ?? 0
            months.insert(row.month)
            students.insert(row.initials)
        }
    }

    struct StudentEarnings: Identifiable {
        let initials: String
        let name: String
        let total: Earnings
        /// In `students.md`: taught in the last few months.
        let current: Bool
        var first: String { total.months.min() ?? "" }
        var last: String { total.months.max() ?? "" }
        var id: String { initials }
    }

    static let historyMonths = 24

    private func earnings(by key: (LessonRow) -> String) -> [String: Earnings] {
        data.tutoring.lessons.reduce(into: [:]) { result, row in
            let k = key(row)
            result[k, default: Earnings(key: k)].add(row)
        }
    }

    /// Every month with lessons, oldest first.
    var earningsByMonth: [Earnings] { earnings { $0.month }.values.sorted { $0.key < $1.key } }

    /// The last 24 months up to this one; a month without lessons is an empty bar.
    var historyBars: [Earnings] {
        let byMonth = earnings { $0.month }
        guard let start = Parse.day(currentMonth + "-01", cal) else { return [] }
        return (0..<Self.historyMonths).reversed().map { back in
            let key = cal.monthKey(cal.add(months: -back, to: start))
            return byMonth[key] ?? Earnings(key: key)
        }
    }

    /// Newest year first.
    var earningsByYear: [Earnings] { earnings { String($0.month.prefix(4)) }.values.sorted { $0.key > $1.key } }

    func earnings(inYear year: String) -> Earnings { earnings { String($0.month.prefix(4)) }[year] ?? Earnings(key: year) }

    /// Highest total first, former students included.
    var earningsByStudent: [StudentEarnings] {
        let current = Set(data.tutoring.students.map(\.initials))
        var names: [String: String] = [:]
        for row in data.tutoring.lessons where row.student.count > (names[row.initials]?.count ?? 0) {
            names[row.initials] = row.student
        }
        return earnings { $0.initials }.values.map { total in
            StudentEarnings(initials: total.key, name: names[total.key] ?? total.key, total: total, current: current.contains(total.key))
        }
        .sorted { ($0.total.amount, $1.initials) > ($1.total.amount, $0.initials) }
    }

    var allTime: Earnings { data.tutoring.lessons.reduce(into: Earnings(key: "all")) { $0.add($1) } }
    var bestMonth: Earnings? { earningsByMonth.max { $0.amount < $1.amount } }
    var currentYear: String { String(currentMonth.prefix(4)) }
    var previousYear: String { String((Int(currentYear) ?? 1) - 1) }

    /// "+26%" or "−12%" from one total to the next.
    static func change(_ now: Double, from before: Double) -> String? {
        guard before > 0 else { return nil }
        let percent = Int(((now / before - 1) * 100).rounded())
        return (percent < 0 ? "−" : "+") + "\(abs(percent))%"
    }

    var historySummary: [Phrase] {
        let all = allTime
        guard let first = all.months.min() else {
            return [Phrase(text: "No lessons yet.", strong: true), Phrase(text: " Desk reads them from the Classes note in Notes.")]
        }
        return [
            Phrase(text: "\(money(all.amount)) earned", strong: true),
            Phrase(text: " since \(monthName(first)): \(Self.plural(all.lessons, "lesson")) with \(Self.plural(all.students.count, "student")). "),
            Phrase(text: "\(money(earnings(inYear: currentYear).amount)) so far in \(currentYear).", strong: true),
        ]
    }
}
