import SwiftUI

/// One card or section of a tab. Its `width` is its design width at 1440 pt: sections are
/// packed left to right into rows of `TabLayout.rowWidth`, and each row stretches to fit.
struct DeskSection: Identifiable {
    enum Slot { case main, rail }

    let id: String
    let title: String
    var slot = Slot.main
    var width = TabLayout.rowWidth
    let view: AnyView

    init<V: View>(_ id: String, _ title: String, slot: Slot = .main, width: CGFloat = TabLayout.rowWidth, @ViewBuilder view: () -> V) {
        self.id = id
        self.title = title
        self.slot = slot
        self.width = width
        self.view = AnyView(view())
    }
}

/// Ids of sections that code outside `TabLayout` refers to. They are saved in user preferences: never change a value.
enum SectionID {
    static let todayHealth = "today.health"
    static let todayList = "today.list"
}

/// Every tab's cards and sections, listed once. Adding, removing or reordering one is a one-line change.
/// Customise (View → Customise…) stores a per-tab order and hidden set on top of these defaults.
enum TabLayout {
    /// The content column's width in the 1440 pt design.
    static let rowWidth: CGFloat = 788

    @MainActor static func sections(for tab: Tab) -> [DeskSection] {
        switch tab {
        case .today: [
            DeskSection("today.deadlines", "Deadlines", width: 300) { DeadlinesCard() },
            DeskSection("today.today", "Today", width: 472) { TodayCard() },
            DeskSection("today.inbox", "Inbox", width: 420) { InboxCard() },
            DeskSection(SectionID.todayHealth, "Health", width: 352) { HealthCard() },
            DeskSection(SectionID.todayList, "Today's list", width: 386) { TodayList() },
            DeskSection("today.emails", "Important emails", width: 386) { EmailList() },
            DeskSection("today.drafts", "Drafts", width: 386) { DraftList() },
            DeskSection("today.waiting", "Waiting", width: 386) { WaitingList() },
            DeskSection("today.calendar", "Month calendar", slot: .rail) { MonthCalendar() },
            DeskSection("today.confirm", "Needs confirmation", slot: .rail) { ConfirmCard() },
            DeskSection("today.study", "Study today", slot: .rail) { StudyTargetCard(label: "Study today", onToday: true) },
            DeskSection("today.timeline", "Timeline", slot: .rail) { DayTimeline() },
        ]
        case .studying: [
            DeskSection("study.hero", "Exam countdown", width: 500) { StudyHero() },
            DeskSection("study.target", "Today's target", width: 288) { StudyTargetCard() },
            DeskSection("study.lists", "Lists") { StudyLists() },
            DeskSection("study.theory", "Theory", width: 394) { TopicColumn(title: "Theory", theory: true) },
            DeskSection("study.problems", "Problems", width: 394) { TopicColumn(title: "Problems", theory: false) },
            DeskSection("study.plan", "Plan chart", width: 394) { PlanChartCard() },
            DeskSection("study.papers", "Past papers", width: 394) { PaperList() },
        ]
        case .projects: ProjectStatus.allCases.map { status in
            DeskSection("projects.\(status.rawValue)", status.title, width: 197) { ProjectColumn(status: status) }
        }
        case .internships: Derived.targetStatuses.map { status in
            DeskSection("internships.\(status.rawValue)", status.label, width: 197) { TargetCountCard(status: status) }
        } + [DeskSection("internships.targets", "Targets") { TargetsTable() }]
        case .uni: [
            DeskSection("uni.runway", "Deadline runway") { UniRunway() },
            DeskSection("uni.programmes", "Programmes") { UniGrid() },
            DeskSection("uni.contacts", "Contacts") { ContactsBoard() },
        ]
        case .tutoring: [
            DeskSection("tutoring.donut", "This year", width: 284) { MoneyDonut() },
            DeskSection("tutoring.thisMonth", "This month so far", width: 168) { MoneyCard(kind: .month) },
            DeskSection("tutoring.owed", "Owed", width: 168) { MoneyCard(kind: .owed) },
            DeskSection("tutoring.hours", "Hours", width: 168) { MoneyCard(kind: .hours) },
            DeskSection("tutoring.waiting", "Waiting for payment", width: 394) { WaitingPayments() },
            DeskSection("tutoring.monthEnd", "Month end", width: 394) { MonthEnd() },
            DeskSection("tutoring.month", "This month") { TutoringMonthList() },
            DeskSection("tutoring.payments", "Payments") { PaymentsTable() },
            DeskSection("tutoring.week", "This week's lessons", slot: .rail) { WeekLessons() },
        ]
        case .history: [
            DeskSection("history.thisYear", "This year", width: 197) { HistoryStat(kind: .thisYear) },
            DeskSection("history.lastYear", "Last year", width: 197) { HistoryStat(kind: .lastYear) },
            DeskSection("history.allTime", "All time", width: 197) { HistoryStat(kind: .allTime) },
            DeskSection("history.best", "Best month", width: 197) { HistoryStat(kind: .best) },
            DeskSection("history.months", "Monthly earnings") { EarningsBars() },
            DeskSection("history.years", "By year", width: 394) { YearTotals() },
            DeskSection("history.students", "By student", width: 394) { StudentTotals() },
        ]
        case .health: [
            DeskSection("health.sessions", "Sessions", width: 197) { HealthStat(kind: .sessions) },
            DeskSection("health.time", "Time", width: 197) { HealthStat(kind: .time) },
            DeskSection("health.distance", "Distance", width: 197) { HealthStat(kind: .distance) },
            DeskSection("health.streak", "Streak", width: 197) { StreakGrid() },
            DeskSection("health.weeks", "12-week bars", width: 394) { WeekBarsCard() },
            DeskSection("health.activities", "Activities", width: 394) { ActivityList() },
        ]
        case .system: [
            DeskSection("system.latest", "Latest run", width: 500) { LatestRunCard() },
            DeskSection("system.models", "Models", width: 288) { ModelsCard() },
            DeskSection("system.strip", "14-day strip") { RunStrip() },
            DeskSection("system.history", "Run history") { RunHistory() },
        ]
        case .portfolio: [
            DeskSection("portfolio.intro", "What it does", width: 500) { PortfolioIntro() },
            DeskSection("portfolio.evaluation", "Evaluation", width: 288) { PortfolioEvaluation() },
            DeskSection("portfolio.architecture", "Architecture") { ArchitectureDiagram() },
            DeskSection("portfolio.agents", "Agents", width: 320) { PortfolioAgents() },
            DeskSection("portfolio.costs", "Cost and failures", width: 468) { PortfolioCosts() },
        ]
        }
    }

    /// The tab's sections for one slot, in the saved order, without the hidden ones.
    @MainActor static func arranged(_ tab: Tab, _ slot: DeskSection.Slot, prefs: TabPrefs?) -> [DeskSection] {
        ordered(tab, prefs: prefs).filter { $0.slot == slot && prefs?.hidden.contains($0.id) != true }
    }

    /// All of the tab's sections in the saved order; sections added since the order was saved go last.
    @MainActor static func ordered(_ tab: Tab, prefs: TabPrefs?) -> [DeskSection] {
        let all = sections(for: tab)
        guard let order = prefs?.order, !order.isEmpty else { return all }
        let rank = Dictionary(order.enumerated().map { ($1, $0) }, uniquingKeysWith: { first, _ in first })
        return all.enumerated().sorted { a, b in
            (rank[a.element.id] ?? order.count + a.offset) < (rank[b.element.id] ?? order.count + b.offset)
        }.map(\.element)
    }

    /// Packs sections into rows: a section starts a new row when it no longer fits.
    static func rows(_ sections: [DeskSection]) -> [[DeskSection]] {
        var rows: [[DeskSection]] = []
        var used: CGFloat = 0
        let slack: CGFloat = 24
        for section in sections {
            if rows.isEmpty || used + section.width > rowWidth + slack {
                rows.append([section])
                used = section.width
            } else {
                rows[rows.count - 1].append(section)
                used += section.width
            }
        }
        return rows
    }
}

/// Lays a row's sections side by side, sharing the width in proportion to their design widths.
struct WeightedRow: Layout {
    let weights: [CGFloat]
    let spacing: CGFloat

    private func widths(total: CGFloat) -> [CGFloat] {
        let available = max(0, total - spacing * CGFloat(max(0, weights.count - 1)))
        let sum = max(weights.reduce(0, +), 1)
        return weights.map { available * $0 / sum }
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let total = proposal.width ?? TabLayout.rowWidth
        let heights = zip(subviews, widths(total: total)).map { subview, width in
            subview.sizeThatFits(ProposedViewSize(width: width, height: nil)).height
        }
        return CGSize(width: total, height: heights.max() ?? 0)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        for (subview, width) in zip(subviews, widths(total: bounds.width)) {
            subview.place(at: CGPoint(x: x, y: bounds.minY), proposal: ProposedViewSize(width: width, height: bounds.height))
            x += width + spacing
        }
    }
}

/// The main column's sections, flowed into rows.
struct SectionFlow: View {
    @Environment(\.theme) private var t
    let sections: [DeskSection]

    var body: some View {
        VStack(alignment: .leading, spacing: t.sp16) {
            ForEach(Array(TabLayout.rows(sections).enumerated()), id: \.offset) { index, row in
                WeightedRow(weights: row.map(\.width), spacing: t.sp16) {
                    ForEach(row) { $0.view }
                }
                .entrance(index + 1)
            }
        }
    }
}
