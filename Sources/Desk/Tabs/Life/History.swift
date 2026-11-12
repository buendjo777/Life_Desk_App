import SwiftUI

/// The four History figures: this year, last year, all time, best month.
struct HistoryStat: View {
    enum Kind: String { case thisYear, lastYear, allTime, best }
    @Environment(Store.self) private var store
    let kind: Kind

    var body: some View {
        let d = store.d
        switch kind {
        case .thisYear:
            let year = d.earnings(inYear: d.currentYear)
            StatCard(title: "This year", subtitle: d.currentYear, accent: .steel, shape: .star) {
                Figure(d.money(year.amount), caption: Derived.plural(year.lessons, "lesson"))
            }
        case .lastYear:
            let year = d.earnings(inYear: d.previousYear)
            StatCard(title: "Last year", subtitle: d.previousYear, accent: .steel, shape: .star) {
                Figure(d.money(year.amount), caption: Derived.plural(year.lessons, "lesson"))
            }
        case .allTime:
            let all = d.allTime
            StatCard(title: "All time", accent: .moss, shape: .star) {
                Figure(d.money(all.amount), caption: all.months.min().map { "Since \(d.monthName($0, pattern: "MMM yyyy"))" } ?? "No lessons yet")
            }
        case .best:
            let best = d.bestMonth
            StatCard(title: "Best month", accent: .ochre, shape: .star) {
                Figure(best.map { d.money($0.amount) } ?? "—", caption: best.map { d.monthName($0.key) } ?? "No lessons yet")
            }
        }
    }
}

/// Euros per month for the last 24 months; this month in the deep tone.
struct EarningsBars: View {
    @Environment(Store.self) private var store
    @Environment(\.theme) private var t

    var body: some View {
        let d = store.d
        let bars = d.historyBars
        let top = max(bars.map(\.amount).max() ?? 0, 1)
        SurfaceCard {
            VStack(alignment: .leading, spacing: t.sp12) {
                HStack(alignment: .firstTextBaseline) {
                    Text(verbatim: "Last \(Derived.historyMonths) months").style(\.cardTitle, \.ink)
                    Spacer()
                    Text(verbatim: "€ per month · \(d.money(bars.map(\.amount).reduce(0, +))) in all").style(\.small, \.inkMuted)
                }
                GeometryReader { proxy in
                    let room = max(t.sp2, proxy.size.height - t.sp32 - t.sp16)
                    HStack(alignment: .bottom, spacing: t.sp4) {
                        ForEach(bars) { bar in
                            let current = bar.key == d.currentMonth
                            VStack(spacing: t.sp4) {
                                Text(verbatim: bar.amount > 0 ? Parse.number(bar.amount.rounded()) : " ")
                                    .style(\.micro, current ? \.ink : \.inkMuted).lineLimit(1).minimumScaleFactor(t.tightScale)
                                RoundedRectangle(cornerRadius: t.radiusSmall)
                                    .fill(current ? t.deep(.steel) : t.fill(.steel))
                                    .frame(height: bar.amount > 0 ? max(t.sp2, CGFloat(bar.amount / top) * room) : t.hairline)
                                Text(verbatim: d.monthName(bar.key, pattern: "LLLLL")).style(\.micro, current ? \.ink : \.inkMuted)
                                // The year under each January, and under the first bar.
                                Text(verbatim: bar.key.hasSuffix("-01") || bar.id == bars.first?.id ? String(bar.key.prefix(4)) : " ")
                                    .style(\.micro, \.inkMuted).fixedSize()
                            }
                            .frame(maxWidth: .infinity)
                            .accessibilityElement()
                            .accessibilityLabel(Text(verbatim: "\(d.monthName(bar.key)): \(d.money(bar.amount)), \(Derived.plural(bar.lessons, "lesson"))"))
                        }
                    }
                    .frame(height: proxy.size.height, alignment: .bottom)
                }
                .frame(minHeight: t.chartHeight + t.sp32 + t.sp16, maxHeight: .infinity)
            }
        }
    }
}

/// Each year: lessons, hours, students, euros and the change on the year before.
struct YearTotals: View {
    @Environment(Store.self) private var store
    @Environment(\.theme) private var t

    var body: some View {
        let d = store.d
        let years = d.earningsByYear
        VStack(alignment: .leading, spacing: t.sp8) {
            SectionHeader(title: "By year", subtitle: store.importStatus ?? "From the Classes note")
            if years.isEmpty { EmptyState(line: "No lessons yet.") }
            ForEach(Array(years.enumerated()), id: \.element.id) { index, year in
                let partial = year.key == d.currentYear
                // No change for this year (not over) or against the first year (it started mid-year).
                let change = partial || index + 2 >= years.count ? nil : Derived.change(year.amount, from: years[index + 1].amount)
                ListRow(leading: .symbol("calendar", .steel), title: partial ? "\(year.key) so far" : year.key,
                        subtitle: "\(Derived.plural(year.lessons, "lesson")) · \(Derived.hoursText(year.hours)) · \(Derived.plural(year.students.count, "student"))") { _ in
                    if let change { Text(verbatim: change).style(\.small, \.inkMuted) }
                    Chip(text: d.money(year.amount), accent: .moss)
                }
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }
}

/// Each student's total, highest first, former students included.
struct StudentTotals: View {
    @Environment(Store.self) private var store
    @Environment(\.theme) private var t
    @State private var expanded = false

    var body: some View {
        let d = store.d
        let rows = d.earningsByStudent
        let current = rows.filter(\.current).count
        let shown = expanded ? rows.count : min(rows.count, t.listRows - 1)
        VStack(alignment: .leading, spacing: t.sp8) {
            SectionHeader(title: "By student", subtitle: "\(current) current · \(rows.count - current) former")
            if rows.isEmpty { EmptyState(line: "No lessons yet.") }
            ForEach(rows.prefix(shown)) { student in
                ListRow(leading: .initials(student.initials, student.current ? .ochre : .neutral), title: student.name,
                        subtitle: "\(d.monthName(student.first, pattern: "MMM yyyy")) – \(d.monthName(student.last, pattern: "MMM yyyy")) · \(Derived.plural(student.total.lessons, "lesson"))") { _ in
                    if student.current { Chip(text: "Current", accent: .ochre) }
                    Text(verbatim: d.money(student.total.amount)).style(\.bodyStrong, \.ink)
                }
            }
            if rows.count > shown {
                MoreLine(phrases: [.init(text: "+ "), .init(text: String(rows.count - shown), strong: true), .init(text: " more students")]) { expanded = true }
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }
}
