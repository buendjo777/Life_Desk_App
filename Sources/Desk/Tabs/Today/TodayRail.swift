import SwiftUI

/// The month calendar: Monday first, ISO week numbers, today in a rust circle, dots for events and deadlines.
struct MonthCalendar: View {
    @Environment(Store.self) private var store
    @Environment(\.theme) private var t
    /// Months away from the current month.
    @State private var offset = 0

    private static let weekdays = ["MO", "TU", "WE", "TH", "FR", "SA", "SU"]

    var body: some View {
        let d = store.d
        let month = d.cal.add(months: offset, to: d.cal.monthStart(d.now))
        VStack(spacing: t.sp12) {
            HStack {
                arrow("chevron.left", label: "Previous month") { offset -= 1 }
                Spacer()
                Button {
                    offset = 0
                    store.selectedDay = nil
                } label: {
                    Text(verbatim: d.cal.format(month, "MMMM yyyy"))
                        .style(\.smallStrong, \.ink)
                        .padding(.horizontal, t.sp12 + t.sp2)
                        .padding(.vertical, t.sp6)
                        .background(t.tint(.rust), in: Capsule())
                }
                .buttonStyle(.plain)
                .help("Back to today")
                Spacer()
                arrow("chevron.right", label: "Next month") { offset += 1 }
            }
            .padding(.horizontal, t.sp4)
            VStack(spacing: t.sp2) {
                HStack(spacing: 0) {
                    ForEach(Self.weekdays, id: \.self) { name in
                        Text(verbatim: name).style(\.label, \.inkMuted).frame(maxWidth: .infinity)
                    }
                    Color.clear.frame(width: t.weekColumn, height: t.hairline)
                }
                .frame(height: t.sp24)
                ForEach(d.monthGrid(for: month)) { week in
                    HStack(spacing: 0) {
                        ForEach(week.days) { cell in
                            dayCell(cell, d)
                        }
                        Text(verbatim: "W\(week.number)")
                            .style(\.micro, week.isCurrent ? \.ink : \.inkMuted)
                            .fixedSize()
                            .padding(.horizontal, t.sp4 + t.sp2 + t.hairline)
                            .padding(.vertical, t.sp2 + t.hairline)
                            .background(week.isCurrent ? t.surface : .clear, in: Capsule())
                            .frame(width: t.weekColumn)
                    }
                }
            }
        }
    }

    private func arrow(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: t.symbol, weight: .semibold))
                .foregroundStyle(t.ink)
                .frame(width: t.sp24, height: t.sp24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private func dayCell(_ cell: Derived.DayCell, _ d: Derived) -> some View {
        let selected = store.selectedDay.map { d.cal.isSameDay($0, cell.date) } == true && !cell.isToday
        return Button {
            store.selectedDay = cell.isToday ? nil : cell.date
        } label: {
            Text(verbatim: String(cell.day))
                .style(cell.isToday ? \.bodyStrong : \.nav, cell.isToday ? \.onAccent : cell.isWeekend ? \.inkMuted : \.ink)
                .frame(width: t.calendarToday, height: t.calendarToday)
                .background(cell.isToday ? t.rust : selected ? t.surface : .clear, in: Circle())
                .frame(maxWidth: .infinity)
                .frame(height: t.calendarCell)
                .overlay(alignment: .bottom) {
                    if let dot = cell.dot, cell.inMonth {
                        Circle().fill(t.fill(dot)).frame(width: t.calendarDot, height: t.calendarDot).offset(y: t.sp2)
                    }
                }
                .opacity(cell.inMonth ? 1 : t.outOfMonthOpacity)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(d.cal.format(cell.date, "EEEE d MMMM") + (cell.dot == nil ? "" : ", has events"))
    }
}

/// Needs confirmation: proposed ticks and events. Nothing changes until Jose clicks.
struct ConfirmCard: View {
    @Environment(Store.self) private var store
    @Environment(\.theme) private var t
    @State private var index = 0

    var body: some View {
        let pending = store.d.toConfirm
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(verbatim: "Needs confirmation · \(pending.count)").style(\.label, \.inkMuted)
                Spacer()
                if pending.count > 1 {
                    Button {
                        index += 1
                    } label: {
                        Text(verbatim: "\(pending.count - 1) more ›").style(\.chip, \.inkMuted)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Next proposal")
                } else if store.lastDecided != nil {
                    Button {
                        store.reopenLast()
                    } label: {
                        Text(verbatim: "Undo").style(\.chip, \.inkMuted)
                    }
                    .buttonStyle(.plain)
                }
            }
            if pending.isEmpty {
                Text(verbatim: "Nothing to confirm.").style(\.body, \.inkMuted).padding(.top, t.sp8)
            } else {
                ProposalView(row: pending[index % pending.count])
            }
        }
        .padding(.horizontal, t.sp16)
        .padding(.vertical, t.sp12 + t.sp2 + t.hairline)
        .frame(maxWidth: .infinity, alignment: .leading)
        .raisedPanel()
    }
}

/// One proposal: what it would do, the email line behind it (verbatim), and the two buttons.
struct ProposalView: View {
    @Environment(Store.self) private var store
    @Environment(\.theme) private var t
    let row: SnapshotRow

    var body: some View {
        let d = store.d
        let isEvent = row.action == "add_event"
        VStack(alignment: .leading, spacing: 0) {
            Text(verbatim: row.event?.title ?? row.title)
                .style(\.bodyStrong, \.ink)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, t.sp8)
            Text(verbatim: meta(d))
                .style(\.small, \.inkMuted)
                .padding(.top, t.sp2)
            if let evidence = row.evidence {
                // Untrusted email text: verbatim only.
                Text(verbatim: "“\(evidence)”")
                    .style(\.small, \.inkMuted)
                    .italic()
                    .lineSpacing(t.sp2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.leading, t.sp8 + t.hairline)
                    .overlay(alignment: .leading) { Rectangle().fill(t.rust).frame(width: t.stroke) }
                    .padding(.top, t.sp8 + t.hairline)
            }
            HStack(spacing: t.sp8) {
                Button(isEvent ? "Add to calendar" : "Confirm tick") { store.accept(row) }
                    .buttonStyle(.deskPrimary)
                Button("Dismiss") { store.dismiss(row) }
                    .buttonStyle(.deskSecondary)
            }
            .padding(.top, t.sp12)
        }
    }

    private func meta(_ d: Derived) -> String {
        var parts: [String] = []
        if let event = row.event {
            parts.append(d.cal.weekdayDay(event.start.date))
            parts.append(event.allDay == true ? "All day" : d.timeRange(event.start.date, event.end.date))
        } else if let detail = row.detail {
            parts.append(detail)
        }
        if row.gmailThread != nil { parts.append("found in Gmail") }
        return parts.joined(separator: " · ")
    }
}

/// The day's timeline: a time column, event cards, past events faded, a dashed "now" line.
struct DayTimeline: View {
    @Environment(Store.self) private var store
    @Environment(\.theme) private var t
    /// The calendar shown; `nil` means all.
    @State private var filter: String?
    @State private var showFilter = false

    var body: some View {
        let d = store.d
        let day = store.selectedDay ?? d.today
        let isToday = d.cal.isSameDay(day, d.today)
        let events = d.events(on: day).filter { filter == nil || $0.calendar == filter }
        let nowIndex = isToday ? events.firstIndex { $0.end > d.now } ?? events.count : nil
        VStack(alignment: .leading, spacing: t.sp6 + t.hairline) {
            HStack(alignment: .firstTextBaseline, spacing: t.sp10) {
                Text(verbatim: d.cal.weekdayDay(day)).style(\.cardTitle, \.ink)
                Text(verbatim: "Timeline").style(\.small, \.inkMuted)
                Spacer()
                filterButton(d.calendars(on: day))
            }
            if events.isEmpty {
                EmptyState(line: "Nothing in the calendar.", hint: store.mode == .demo ? d.data.hint(VaultData.eventsFile) : store.calendarHint)
            }
            ForEach(Array(events.enumerated()), id: \.element.id) { index, event in
                if index == nowIndex { NowLine(time: d.cal.time(d.now)) }
                EventRow(event: event, past: isToday && event.end <= d.now)
            }
            if nowIndex == events.count, !events.isEmpty { NowLine(time: d.cal.time(d.now)) }
        }
    }

    private func filterButton(_ calendars: [String]) -> some View {
        Button {
            showFilter.toggle()
        } label: {
            Text(verbatim: "\(filter ?? "All") ▾")
                .style(\.chip, \.onPrimary)
                .padding(.horizontal, t.sp10)
                .padding(.vertical, t.sp4)
                .background(t.primary, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Filter by calendar, showing \(filter ?? "all")")
        .popover(isPresented: $showFilter, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: t.sp4) {
                ForEach([String?.none] + calendars.map(Optional.some), id: \.self) { name in
                    Button(name ?? "All") {
                        filter = name
                        showFilter = false
                    }
                    .buttonStyle(.deskSecondary)
                }
            }
            .padding(t.sp12)
        }
    }
}

struct EventRow: View {
    @Environment(Store.self) private var store
    @Environment(\.theme) private var t
    let event: CalEvent
    var past = false

    var body: some View {
        let d = store.d
        let style = d.eventStyle(event)
        HStack(alignment: .top, spacing: t.sp8) {
            Text(verbatim: event.allDay ? "All day" : d.cal.time(event.start))
                .style(\.micro, \.inkMuted)
                .frame(width: t.timeColumn, alignment: .leading)
                .padding(.top, t.sp8)
            HStack(spacing: t.sp10) {
                Badge(content: .symbol(style.symbol), accent: style.accent, small: true)
                VStack(alignment: .leading, spacing: t.hairline) {
                    Text(verbatim: d.displayTitle(event)).style(\.rowTitle, \.ink).lineLimit(1)
                    Text(verbatim: d.eventSubtitle(event)).style(\.small, \.inkMuted).lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(.leading, t.sp8)
            .padding(.trailing, t.sp12)
            .frame(height: t.eventCard)
            .background(t.raised, in: RoundedRectangle(cornerRadius: t.radiusEvent))
        }
        .opacity(past ? t.pastOpacity : 1)
        .accessibilityElement(children: .combine)
    }
}

/// The dashed rust "now" line with its time pill.
struct NowLine: View {
    @Environment(\.theme) private var t
    let time: String

    var body: some View {
        HStack(spacing: t.sp6) {
            Text(verbatim: time)
                .style(\.micro, \.onAccent)
                .fixedSize()
                .padding(.horizontal, t.sp4 + t.sp2)
                .padding(.vertical, t.sp2)
                .background(t.rust, in: Capsule())
                .frame(width: t.timeColumn, alignment: .leading)
            DashedLine()
                .stroke(t.rust, style: StrokeStyle(lineWidth: t.stroke, dash: [t.sp6, t.sp4]))
                .frame(height: t.stroke)
        }
        .frame(height: t.sp12)
        .accessibilityLabel("Now, \(time)")
    }
}
