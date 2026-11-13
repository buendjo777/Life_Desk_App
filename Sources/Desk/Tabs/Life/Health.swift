import SwiftUI

/// The three Health stat cards: sessions, time and distance this week.
struct HealthStat: View {
    enum Kind: String { case sessions, time, distance }
    @Environment(Store.self) private var store
    let kind: Kind

    var body: some View {
        let d = store.d
        switch kind {
        case .sessions:
            StatCard(title: "Sessions", subtitle: "This week", accent: .good, shape: .heart) {
                Figure(String(d.weekActivities.count), caption: "W\(d.cal.weekNumber(d.now))")
            }
        case .time:
            let (hours, minutes) = Derived.hoursMinutes(d.weekSeconds)
            StatCard(title: "Time", subtitle: "This week", accent: .good, shape: .heart) {
                Figure(parts: [.init(text: String(hours)), .init(text: "h", unit: true), .init(text: String(format: " %02d", minutes))], caption: "Moving time")
            }
        case .distance:
            StatCard(title: "Distance", subtitle: "This week", accent: .good, shape: .heart) {
                Figure(Derived.kilometres(d.weekMetres), unit: "km", caption: "Run, ride, swim")
            }
        }
    }
}

/// Seven rounded squares, Monday to Sunday: good = trained, line = rest.
struct StreakGrid: View {
    @Environment(Store.self) private var store
    @Environment(\.theme) private var t

    var body: some View {
        let days = store.d.streak
        SurfaceCard {
            VStack(alignment: .leading, spacing: t.sp12) {
                HStack(alignment: .firstTextBaseline) {
                    Text(verbatim: "Streak").style(\.cardTitle, \.ink)
                    Spacer()
                    Text(verbatim: "\(days.filter(\.trained).count) of 7 days").style(\.small, \.inkMuted)
                }
                HStack(spacing: t.sp6) {
                    ForEach(days) { day in
                        VStack(spacing: t.sp4) {
                            RoundedRectangle(cornerRadius: t.radiusSmall + t.sp2)
                                .fill(day.trained ? t.good : t.line)
                                .opacity(day.future ? t.pastOpacity : 1)
                                .frame(maxWidth: t.streakCell)
                                .frame(height: t.streakCell)
                                .overlay {
                                    if day.trained {
                                        Image(systemName: "checkmark").font(.system(size: t.symbolSmall, weight: .bold)).foregroundStyle(t.onAccent)
                                    }
                                }
                            Text(verbatim: day.letter).style(\.micro, day.isToday ? \.focus : \.inkMuted)
                        }
                        .frame(maxWidth: .infinity)
                        .accessibilityElement()
                        .accessibilityLabel(Text(verbatim: "\(store.d.cal.format(day.date, "EEEE")): \(day.trained ? "trained" : day.future ? "still to come" : "rest")"))
                    }
                }
            }
        }
    }
}

/// Training time per week for the last 12 weeks (good bars).
struct WeekBarsCard: View {
    @Environment(Store.self) private var store
    @Environment(\.theme) private var t

    var body: some View {
        let d = store.d
        let bars = d.weekBars
        let top = max(bars.map(\.seconds).max() ?? 0, 1)
        SurfaceCard {
            VStack(alignment: .leading, spacing: t.sp12) {
                HStack(alignment: .firstTextBaseline) {
                    Text(verbatim: "Last \(Derived.healthWeeks) weeks").style(\.cardTitle, \.ink)
                    Spacer()
                    Text(verbatim: "Hours per week · best \(Derived.durationText(top))").style(\.small, \.inkMuted)
                }
                // The bars grow with the card, so the chart fills the row beside the activity list.
                GeometryReader { proxy in
                    let room = max(t.sp2, proxy.size.height - t.sp32)
                    HStack(alignment: .bottom, spacing: t.sp6) {
                        ForEach(bars) { bar in
                            VStack(spacing: t.sp4) {
                                Text(verbatim: String(format: "%.1f", Double(bar.seconds) / 3600)).style(\.micro, bar.isCurrent ? \.ink : \.inkMuted)
                                RoundedRectangle(cornerRadius: t.radiusSmall)
                                    .fill(bar.isCurrent ? t.goodDeep : t.good)
                                    .frame(height: max(t.sp2, CGFloat(bar.seconds) / CGFloat(top) * room))
                                Text(verbatim: "W\(d.cal.weekNumber(bar.start))").style(\.micro, bar.isCurrent ? \.ink : \.inkMuted)
                            }
                            .frame(maxWidth: .infinity)
                            .accessibilityElement()
                            .accessibilityLabel(Text(verbatim: "Week \(d.cal.weekNumber(bar.start)): \(Derived.durationText(bar.seconds)), \(Derived.plural(bar.sessions, "session"))"))
                        }
                    }
                    .frame(height: proxy.size.height, alignment: .bottom)
                }
                .frame(minHeight: t.chartHeight + t.sp32, maxHeight: .infinity)
            }
        }
    }
}

/// The activity list, newest first.
struct ActivityList: View {
    @Environment(Store.self) private var store
    @Environment(\.theme) private var t
    @State private var expanded = false

    var body: some View {
        let d = store.d
        let rows = d.activityList
        let shown = expanded ? rows.count : min(rows.count, t.listRows - 1)
        VStack(alignment: .leading, spacing: t.sp8) {
            SectionHeader(title: "Activities", subtitle: "Strava · last 12 weeks")
            if rows.isEmpty { EmptyState(line: "No activities exported yet.", hint: d.data.hint(VaultData.stravaFile)) }
            ForEach(rows.prefix(shown)) { activity in
                ListRow(leading: .symbol(Derived.activitySymbol(activity.type), .good), title: activity.name, subtitle: d.activityDetail(activity)) { _ in
                    Chip(text: d.cal.weekdayDay(activity.date.date), accent: d.cal.isSameDay(activity.date.date, d.today) ? .good : .neutral)
                }
            }
            if rows.count > shown {
                MoreLine(phrases: [.init(text: "+ "), .init(text: String(rows.count - shown), strong: true), .init(text: " earlier activities")]) { expanded = true }
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }
}
