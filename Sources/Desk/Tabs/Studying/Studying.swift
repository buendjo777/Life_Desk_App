import SwiftUI

/// The hero card (caution): countdown and the overall progress ring.
struct StudyHero: View {
    @Environment(Store.self) private var store
    @Environment(\.theme) private var t

    var body: some View {
        let d = store.d
        StatCard(title: d.study?.exam ?? d.data.settings.exam?.title ?? "Exam", subtitle: d.examMode ? "Exam mode" : nil,
                 accent: .caution, shape: .triangle, tall: true) {
            HStack(alignment: .center, spacing: t.sp24) {
                VStack(alignment: .leading, spacing: t.sp12) {
                    if let days = d.examDaysLeft {
                        VStack(alignment: .leading, spacing: 0) {
                            HStack(alignment: .firstTextBaseline, spacing: t.sp4) {
                                Text(verbatim: String(max(days, 0))).style(\.bigFigure)
                                Text(verbatim: days == 1 ? "day" : "days").style(\.cardTitle)
                            }
                            if let date = d.examDate {
                                Text(verbatim: d.cal.format(date, "EEE d MMM · HH:mm")).style(\.caption).opacity(t.captionOpacity)
                            }
                        }
                    }
                    HStack(alignment: .top, spacing: t.sp20) {
                        Figure(d.theoryProgress.text, caption: "Theory")
                        Figure(d.problemsProgress.text, caption: "Problems")
                        Figure(d.papersProgress.text, caption: "Papers")
                    }
                }
                Spacer(minLength: 0)
                ProgressRing(value: d.studyProgress.fraction, label: d.studyProgress.percent, caption: "Overall")
            }
        }
    }
}

/// A ring in the card's ink with the value in the middle.
struct ProgressRing: View {
    @Environment(\.theme) private var t
    let value: Double
    let label: String
    let caption: String

    var body: some View {
        ZStack {
            Circle().stroke(t.onAccent.opacity(t.onAccentWash + t.onAccentWash), lineWidth: t.ringLine)
            FilledIn(max(0, min(1, value))) { shown in
                Circle()
                    .trim(from: 0, to: shown)
                    .stroke(t.focus, style: StrokeStyle(lineWidth: t.ringLine, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            VStack(spacing: 0) {
                Text(verbatim: label).style(\.figure)
                Text(verbatim: caption).style(\.caption).opacity(t.captionOpacity)
            }
        }
        .frame(width: t.ring, height: t.ring)
        .padding(t.ringLine / 2)
        .accessibilityElement()
        .accessibilityLabel(Text(verbatim: "\(caption) \(label)"))
    }
}

/// Today's target, from a list or the plan. On Today it sits in the rail as "Study today", without the Claude button.
struct StudyTargetCard: View {
    @Environment(Store.self) private var store
    @Environment(\.theme) private var t
    var label = "Today's target"
    var onToday = false

    var body: some View {
        if !onToday || store.d.studyTarget != nil {
            card
        }
    }

    private var card: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: t.sp8) {
                Text(verbatim: label).style(\.label, \.inkMuted)
                if let target = store.d.studyTarget {
                    Text(verbatim: target.headline).style(\.section, \.ink)
                    Text(verbatim: target.detail).style(\.small, \.inkMuted).fixedSize(horizontal: false, vertical: true)
                    ForEach(target.items, id: \.self) { item in
                        HStack(spacing: t.sp8) {
                            Circle().fill(t.caution).frame(width: t.dot, height: t.dot)
                            Text(verbatim: item).style(\.rowTitle, \.ink).lineLimit(1)
                        }
                    }
                    if let path = store.d.data.settings.exam?.file {
                        ForEach(target.checks) { check in
                            CheckLine(path: path, check: check)
                        }
                    }
                    Spacer(minLength: 0)
                    if onToday {
                        Button("Open Studying") { store.show(.studying) }.buttonStyle(.deskSecondary)
                    } else {
                        LinkButton(title: "Open in Claude", url: store.d.data.settings.exam.flatMap {
                            Links.claude(seed: "Quiz me on the open topics in \($0.file) in my vault, one question at a time.")
                        })
                    }
                }
            }
        }
    }
}

/// The study file's own lists ("This weekend — due 2026-11-15"): a card per `###` group, two side by side.
struct StudyLists: View {
    @Environment(Store.self) private var store
    @Environment(\.theme) private var t

    var body: some View {
        let d = store.d
        if let path = d.data.settings.exam?.file, let lists = d.study?.lists, !lists.isEmpty {
            VStack(alignment: .leading, spacing: t.sp16) {
                ForEach(lists) { list in
                    VStack(alignment: .leading, spacing: t.sp8) {
                        SectionHeader(title: list.title, subtitle: d.listSubtitle(list))
                        ForEach(Array(stride(from: 0, to: list.groups.count, by: 2)), id: \.self) { start in
                            HStack(alignment: .top, spacing: t.sp16) {
                                ForEach(list.groups[start..<min(start + 2, list.groups.count)]) { group in
                                    ListGroupCard(path: path, group: group)
                                }
                                // An odd last card keeps half the width.
                                if list.groups.count > 1, start + 1 == list.groups.count {
                                    Color.clear.frame(maxWidth: .infinity, maxHeight: 0)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

/// One group of a list: its progress, its items, and the video time left when the items say it.
private struct ListGroupCard: View {
    @Environment(\.theme) private var t
    let path: String
    let group: StudyList.Group

    var body: some View {
        let progress = Derived.progress(group.items)
        SurfaceCard {
            VStack(alignment: .leading, spacing: t.sp8) {
                LabelledProgress(label: group.title, value: progress.fraction, valueText: progress.text, accent: .caution)
                    .padding(.bottom, t.sp4)
                ForEach(group.items) { check in
                    CheckLine(path: path, check: check)
                }
                if let minutes = Derived.minutesLeft(group) {
                    Text(verbatim: "\(Derived.durationText(minutes * 60)) of video left").style(\.small, \.inkMuted)
                        .padding(.top, t.sp4)
                }
            }
        }
    }
}

/// One column of topic ticks (Theory or Problems) with its progress bar.
struct TopicColumn: View {
    @Environment(Store.self) private var store
    @Environment(\.theme) private var t
    let title: String
    let theory: Bool

    var body: some View {
        let d = store.d
        let checks = (theory ? d.study?.theory : d.study?.problems) ?? []
        let progress = theory ? d.theoryProgress : d.problemsProgress
        SurfaceCard {
            VStack(alignment: .leading, spacing: t.sp8) {
                LabelledProgress(label: title, value: progress.fraction, valueText: progress.text, accent: .caution)
                    .padding(.bottom, t.sp4)
                if let path = d.data.settings.exam?.file {
                    ForEach(checks) { check in
                        CheckLine(path: path, check: check)
                    }
                }
            }
        }
    }
}

/// A compact checkbox line bound to a file in the vault. Space ticks the highlighted one.
struct CheckLine: View {
    @Environment(Store.self) private var store
    @Environment(\.theme) private var t
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Bumped on each tick: the sparks play once.
    @State private var ticks = 0
    let path: String
    let check: Check

    var body: some View {
        let item = DeskItem.check(path: path, line: check.line)
        let selected = store.selection == item
        HStack(spacing: t.sp8) {
            Button {
                store.selection = item
                if !check.done, store.motion, !reduceMotion { ticks += 1 }
                store.toggleCheck(path: path, line: check.line)
            } label: {
                Image(systemName: check.done ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: t.symbol, weight: .medium))
                    .foregroundStyle(check.done ? t.good : t.inkMuted)
                    .symbolEffect(.bounce, value: ticks)
                    .background(Sparks(trigger: ticks))
            }
            .buttonStyle(.plain)
            .disabled(!store.canWrite(path))
            .help(store.canWrite(path) ? "" : "Desk only reads this file. Tick it in Obsidian.")
            .accessibilityLabel(Text(verbatim: check.done ? "Untick \(check.title)" : "Tick \(check.title)"))
            Text(verbatim: check.title)
                .style(\.body, check.done ? \.inkMuted : \.ink)
                .strikethrough(check.done)
                .lineLimit(2)
            Spacer(minLength: 0)
        }
        .padding(.vertical, t.sp2)
        .padding(.horizontal, t.sp6)
        .background(selected ? t.selection : .clear, in: RoundedRectangle(cornerRadius: t.radiusSmall))
        .contentShape(Rectangle())
        .onTapGesture { store.selection = item }
        .accessibilityAction { store.selection = item }
    }
}

/// The plan chart (info): papers done against the plan line.
struct PlanChartCard: View {
    @Environment(Store.self) private var store
    @Environment(\.theme) private var t

    var body: some View {
        let d = store.d
        StatCard(title: "Past papers", subtitle: "Done against the plan", accent: .info, shape: .star, tall: true) {
            if let chart = d.planChart {
                HStack(alignment: .top, spacing: t.sp20) {
                    Figure(String(chart.done.last ?? 0), caption: "Done")
                    Figure(String(d.plannedPapers(by: d.today)), caption: "Plan by today")
                    Figure(String(chart.total), caption: "Total")
                }
                PlanChartView(chart: chart)
                    .frame(maxWidth: .infinity, minHeight: t.chartHeight - t.sp32)
                HStack {
                    Text(verbatim: d.cal.shortDay(chart.start))
                    Spacer()
                    Text(verbatim: "— done   - - plan")
                    Spacer()
                    Text(verbatim: "Exam \(d.cal.shortDay(chart.end))")
                }
                .style(\.micro)
                .opacity(t.captionOpacity)
            } else {
                Text(verbatim: "No past papers listed yet.").style(\.small)
            }
        }
    }
}

struct PlanChartView: View {
    @Environment(\.theme) private var t
    let chart: Derived.PlanChart

    private func line(_ values: [Int], in size: CGSize, stepped: Bool) -> Path {
        var path = Path()
        let top = CGFloat(max(chart.total, 1))
        for (index, value) in values.enumerated() {
            let point = CGPoint(x: CGFloat(index) / CGFloat(chart.days) * size.width, y: size.height - CGFloat(value) / top * size.height)
            if index == 0 {
                path.move(to: point)
            } else {
                if stepped { path.addLine(to: CGPoint(x: point.x, y: path.currentPoint?.y ?? point.y)) }
                path.addLine(to: point)
            }
        }
        return path
    }

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let todayX = CGFloat(chart.done.count - 1) / CGFloat(chart.days) * size.width
            ZStack(alignment: .topLeading) {
                Rectangle().fill(t.onAccent.opacity(t.onAccentTrack)).frame(height: t.hairline).offset(y: size.height - t.hairline)
                line(chart.plan, in: size, stepped: false)
                    .stroke(t.onAccent.opacity(t.captionOpacity), style: StrokeStyle(lineWidth: t.stroke, dash: [t.sp6, t.sp4]))
                line(chart.done, in: size, stepped: true)
                    .stroke(t.onAccent, style: StrokeStyle(lineWidth: t.stroke + t.hairline, lineCap: .round, lineJoin: .round))
                Circle().fill(t.onAccent).frame(width: t.runwayDot, height: t.runwayDot)
                    .offset(x: todayX - t.runwayDot / 2,
                            y: size.height - CGFloat(chart.done.last ?? 0) / CGFloat(max(chart.total, 1)) * size.height - t.runwayDot / 2)
            }
        }
        .accessibilityElement()
        .accessibilityLabel(Text(verbatim: "\(chart.done.last ?? 0) of \(chart.total) papers done"))
    }
}

/// The past-papers list with score chips.
struct PaperList: View {
    @Environment(Store.self) private var store
    @Environment(\.theme) private var t
    @State private var expanded = false

    var body: some View {
        let d = store.d
        let papers = d.study?.papers ?? []
        let shown = expanded ? papers.count : min(papers.count, t.listRows - 1)
        VStack(alignment: .leading, spacing: t.sp8) {
            SectionHeader(title: "Past papers", subtitle: d.papersProgress.text + " done")
            if papers.isEmpty { EmptyState(line: "No past papers listed.", hint: "Add them under ## Past papers.") }
            if let path = d.data.settings.exam?.file {
                ForEach(papers.prefix(shown)) { paper in
                    let item = DeskItem.check(path: path, line: paper.line)
                    ListRow(leading: .tick(done: paper.done, toggle: { store.toggleCheck(path: path, line: paper.line) }),
                            title: paper.title, subtitle: paper.date.map { "Done \(d.cal.weekdayDay($0))" } ?? "Not done yet",
                            selected: store.selection == item, action: { store.selection = item }) { selected in
                        if let score = paper.score, let outOf = paper.outOf {
                            Chip(text: "\(Parse.number(score))/\(Parse.number(outOf))",
                                 accent: score / max(outOf, 1) >= 0.5 ? .good : .alert, onAccent: selected)
                        }
                    }
                }
            }
            if papers.count > shown {
                MoreLine(phrases: [.init(text: "+ "), .init(text: String(papers.count - shown), strong: true), .init(text: " more papers")]) { expanded = true }
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }
}
