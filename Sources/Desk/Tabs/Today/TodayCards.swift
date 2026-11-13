import SwiftUI

/// Deadlines (caution): the nearest three with days left, and a 90-day runway.
struct DeadlinesCard: View {
    @Environment(Store.self) private var store
    @Environment(\.theme) private var t

    var body: some View {
        let d = store.d
        StatCard(title: "Deadlines", accent: .caution, shape: .triangle, tall: true) {
            if d.deadlines.isEmpty {
                Text(verbatim: d.data.hint(VaultData.snapshotFile) ?? "No upcoming deadlines.").style(\.small)
            } else {
                HStack(alignment: .top, spacing: t.sp20 + t.sp2) {
                    ForEach(d.distinctDeadlines.prefix(3)) { deadline in
                        Figure(String(deadline.daysLeft), unit: "d", caption: "\(deadline.short)\n\(d.cal.shortDay(deadline.date))")
                    }
                }
                Spacer(minLength: 0)
                Runway(points: d.runway)
            }
        }
    }
}

/// A thin line from today to +90 days with a dot per deadline.
struct Runway: View {
    @Environment(\.theme) private var t
    let points: [Derived.RunwayPoint]
    /// On canvas (Uni apps) the runway is drawn in ink instead of the card's ink.
    var onCard = true

    var body: some View {
        let ink = onCard ? t.onAccent : t.ink
        VStack(spacing: t.sp6) {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(ink.opacity(t.onAccentTrack)).frame(height: t.stroke)
                    ForEach(points) { point in
                        Circle()
                            .fill(point.near ? ink : (onCard ? t.caution : t.canvas))
                            .overlay(Circle().strokeBorder(ink, lineWidth: t.stroke))
                            .frame(width: t.runwayDot, height: t.runwayDot)
                            .offset(x: point.fraction * proxy.size.width - t.runwayDot / 2)
                    }
                }
                .frame(height: t.runwayDot)
            }
            .frame(height: t.runwayDot)
            HStack {
                Text(verbatim: "Today")
                Spacer()
                Text(verbatim: "+30")
                Spacer()
                Text(verbatim: "+60")
                Spacer()
                Text(verbatim: "+\(Derived.runwayDays) d")
            }
            .style(\.micro)
            .foregroundStyle(ink)
            .opacity(t.captionOpacity)
        }
        .accessibilityElement()
        .accessibilityLabel(Text(verbatim: "\(points.count) deadlines in the next \(Derived.runwayDays) days"))
    }
}

/// Today (focus): focus, due, leftovers, to confirm, and the 07:00–22:00 day strip.
struct TodayCard: View {
    @Environment(Store.self) private var store
    @Environment(\.theme) private var t

    var body: some View {
        let d = store.d
        StatCard(title: "Today", subtitle: d.cal.weekdayDay(d.now), accent: .focus, shape: .circle, tall: true) {
            HStack(alignment: .top, spacing: t.sp24 + t.sp2) {
                Figure(String(d.focus.count), caption: "Focus")
                Figure(String(d.dueToday.count), caption: "Due today")
                Figure(String(d.leftovers.count), caption: "Leftovers")
                Figure(String(d.toConfirm.count), caption: "To confirm")
            }
            Spacer(minLength: 0)
            DayStrip()
        }
    }
}

/// The day from 07:00 to 22:00: a block per event and a dashed "now" marker.
struct DayStrip: View {
    @Environment(Store.self) private var store
    @Environment(\.theme) private var t

    var body: some View {
        let d = store.d
        let pillHeight = t.sp16
        VStack(spacing: t.sp4) {
            GeometryReader { proxy in
                let width = proxy.size.width
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: t.radiusSmall)
                        .fill(t.onAccent.opacity(t.onAccentWash))
                        .frame(height: t.stripBar)
                        .offset(y: pillHeight + t.sp2)
                    ForEach(d.stripBlocks) { block in
                        RoundedRectangle(cornerRadius: t.radiusSmall - t.hairline)
                            .fill(t.onAccent.opacity(block.past ? t.tintOpacity : t.onAccentBlock))
                            .frame(width: max(t.sp4, (block.end - block.start) * width), height: t.stripBar)
                            .offset(x: block.start * width, y: pillHeight + t.sp2)
                    }
                    if let fraction = d.nowFraction {
                        Rectangle()
                            .fill(.clear)
                            .frame(width: t.stroke, height: t.stripBar + t.sp12)
                            .overlay(
                                DashedLine(vertical: true).stroke(t.onAccent, style: StrokeStyle(lineWidth: t.stroke, dash: [t.sp4, t.sp2 + t.hairline]))
                            )
                            .offset(x: fraction * width - t.hairline, y: pillHeight - t.sp4)
                        Text(verbatim: d.cal.time(d.now))
                            .style(\.micro)
                            .foregroundStyle(t.panelText)
                            .frame(width: t.timeColumn, height: pillHeight)
                            .background(t.onAccent, in: Capsule())
                            .frame(width: t.timeColumn)
                            .offset(x: min(max(fraction * width, t.timeColumn / 2), width - t.timeColumn / 2) - t.timeColumn / 2, y: -t.sp4)
                    }
                }
            }
            .frame(height: pillHeight + t.sp2 + t.stripBar)
            GeometryReader { proxy in
                ForEach(Derived.stripTicks, id: \.self) { hour in
                    let fraction = Derived.stripFraction(Double(hour))
                    Text(verbatim: String(format: "%02d", hour))
                        .style(\.micro)
                        .opacity(t.captionOpacity)
                        .fixedSize()
                        .alignmentGuide(.leading) { fraction == 0 ? 0 : fraction == 1 ? $0.width : $0.width / 2 }
                        .offset(x: fraction * proxy.size.width)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(height: t.sp12)
        }
        .accessibilityElement()
        .accessibilityLabel(Text(verbatim: "\(d.stripBlocks.count) events today"))
    }
}

/// A straight line for dashed strokes.
struct DashedLine: Shape {
    var vertical = false

    func path(in rect: CGRect) -> Path {
        var path = Path()
        if vertical {
            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        } else {
            path.move(to: CGPoint(x: rect.minX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        }
        return path
    }
}

/// Inbox (info): important, need reply, deadline. As of the last run, not live.
struct InboxCard: View {
    @Environment(Store.self) private var store
    @Environment(\.theme) private var t

    var body: some View {
        let d = store.d
        StatCard(title: "Inbox", subtitle: d.scannedText, accent: .info, shape: .star) {
            HStack(alignment: .top, spacing: t.sp24 + t.sp2) {
                Figure(String(d.emails.count), caption: "Important")
                Figure(String(d.emails(.needsReply).count), caption: "Need reply")
                Figure(String(d.emails(.deadline).count), caption: "Deadline")
            }
        }
    }
}

/// Health (good): sessions and time this week, and the last workout.
struct HealthCard: View {
    @Environment(Store.self) private var store
    @Environment(\.theme) private var t

    var body: some View {
        let d = store.d
        let week = d.weekActivities
        let (hours, minutes) = Derived.hoursMinutes(week.map(\.durationS).reduce(0, +))
        StatCard(title: "Health", subtitle: "This week", accent: .good, shape: .heart) {
            HStack(alignment: .top, spacing: t.sp24) {
                Figure(String(week.count), caption: "Sessions")
                Figure(parts: [.init(text: String(hours)), .init(text: "h", unit: true), .init(text: String(format: " %02d", minutes))], caption: "Time")
                if let last = d.lastActivity {
                    let when = d.cal.isSameDay(last.date.date, d.now) ? "Today's" : "Last"
                    if let metres = last.distanceM {
                        Figure(Derived.kilometres(metres), unit: "km", caption: "\(when) \(last.type.lowercased())")
                    } else {
                        Figure(String(last.durationS / 60), unit: "min", caption: "\(when) \(last.type.lowercased())")
                    }
                }
            }
        }
    }
}
