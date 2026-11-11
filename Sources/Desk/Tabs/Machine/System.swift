import SwiftUI

/// The latest run (navy): status, duration, messages scanned, drafts and the usage note.
struct LatestRunCard: View {
    @Environment(Store.self) private var store
    @Environment(\.theme) private var t

    var body: some View {
        let d = store.d
        StatCard(title: "Latest run", subtitle: d.lastRun.map { d.cal.format($0.startedAt.date, "EEE d MMM · HH:mm") }, accent: .navy, shape: .cog, tall: true) {
            if let run = d.lastRun {
                HStack(alignment: .top, spacing: t.sp24) {
                    Figure(run.isOK ? "OK" : Derived.label(run.status), caption: run.mode ?? "run")
                    Figure(Derived.runDuration(run), caption: "Duration")
                    Figure(String(run.messagesScanned ?? 0), caption: "Scanned")
                    Figure(String(run.drafts ?? 0), caption: "Drafts")
                }
                Spacer(minLength: 0)
                // Agent-written text: verbatim.
                if let note = run.usageNote { Text(verbatim: note).style(\.small).opacity(t.captionOpacity) }
                HStack(spacing: t.sp8) {
                    Circle().fill(t.fill(d.runStatus.level.accent)).frame(width: t.sp8, height: t.sp8)
                    Text(verbatim: "\(d.runStatus.level.word) · \(d.runSentence)").style(\.smallStrong)
                }
            } else {
                Text(verbatim: d.data.hint(VaultData.runsFile) ?? "No runs recorded yet.").style(\.small)
            }
        }
    }
}

/// The models used in the latest run (navy).
struct ModelsCard: View {
    @Environment(Store.self) private var store
    @Environment(\.theme) private var t

    var body: some View {
        let d = store.d
        StatCard(title: "Models", subtitle: "Latest run", accent: .navy, shape: .cog, tall: true) {
            if d.modelsUsed.isEmpty { Text(verbatim: "No agents listed.").style(\.small) }
            ForEach(d.modelsUsed) { use in
                VStack(alignment: .leading, spacing: t.sp2) {
                    HStack(alignment: .firstTextBaseline, spacing: t.sp6) {
                        Text(verbatim: use.model).style(\.cardTitle)
                        Text(verbatim: "×\(use.agents.count)").style(\.small).opacity(t.captionOpacity)
                    }
                    Text(verbatim: use.agents.joined(separator: " · ")).style(\.small).opacity(t.captionOpacity)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
            Button("Portfolio") { store.show(.portfolio) }
                .buttonStyle(.deskSecondary)
                .environment(\.theme, Theme(scheme: .dark, density: t.density))
        }
    }
}

/// A 14-day strip of runs: one cell per day, always with a word.
struct RunStrip: View {
    @Environment(Store.self) private var store
    @Environment(\.theme) private var t

    var body: some View {
        let d = store.d
        SurfaceCard {
            VStack(alignment: .leading, spacing: t.sp12) {
                HStack(alignment: .firstTextBaseline) {
                    Text(verbatim: "Last \(Derived.runStripDays) days").style(\.cardTitle, \.ink)
                    Spacer()
                    Text(verbatim: "\(d.runStrip.filter { $0.state == .ok }.count) ok · \(d.runStrip.filter { $0.state == .failed }.count) failed · \(d.runStrip.filter { $0.state == .none }.count) no run")
                        .style(\.small, \.inkMuted)
                }
                HStack(spacing: t.sp6) {
                    ForEach(d.runStrip) { day in
                        VStack(spacing: t.sp4) {
                            RoundedRectangle(cornerRadius: t.radiusSmall + t.sp2)
                                .fill(day.state == .ok ? t.moss : day.state == .failed ? t.alert : t.line)
                                .frame(height: t.streakCell)
                                .overlay {
                                    Text(verbatim: day.state == .ok ? (day.runs > 1 ? "OK ×\(day.runs)" : "OK") : day.state == .failed ? "Fail" : "—")
                                        .style(\.micro)
                                        .foregroundStyle(day.state == .failed ? t.panelText : day.state == .ok ? t.onAccent : t.inkMuted)
                                }
                            Text(verbatim: d.cal.format(day.date, "d")).style(\.micro, d.cal.isSameDay(day.date, d.today) ? \.rust : \.inkMuted)
                        }
                        .frame(maxWidth: .infinity)
                        .accessibilityElement()
                        .accessibilityLabel(Text(verbatim: "\(d.cal.shortDay(day.date)): \(day.state.rawValue)"))
                    }
                }
            }
        }
    }
}

/// The run history table with status chips.
struct RunHistory: View {
    @Environment(Store.self) private var store
    @Environment(\.theme) private var t
    @State private var expanded = false

    var body: some View {
        let d = store.d
        let runs = d.runHistory
        let shown = expanded ? runs.count : min(runs.count, t.listRows)
        VStack(alignment: .leading, spacing: t.sp8) {
            SectionHeader(title: "Run history", subtitle: "agent/runs.jsonl")
            if runs.isEmpty { EmptyState(line: "No runs recorded yet.", hint: d.data.hint(VaultData.runsFile)) }
            ForEach(runs.prefix(shown)) { run in
                let failures = run.failures ?? []
                ListRow(leading: .symbol(run.isOK ? (failures.isEmpty ? "checkmark" : "exclamationmark") : "xmark", run.isOK ? (failures.isEmpty ? .moss : .ochre) : .alert),
                        title: "\(d.cal.format(run.startedAt.date, "EEE d MMM · HH:mm")) · \(Derived.runDuration(run))",
                        // Failure lines and usage notes are agent-written: ListRow draws them verbatim.
                        subtitle: failures.isEmpty ? [Derived.modelsText(run), run.usageNote].compactMap { $0 }.joined(separator: " · ") : failures.joined(separator: " · ")) { _ in
                    Text(verbatim: "\(run.messagesScanned ?? 0) scanned · \(Derived.plural(run.drafts ?? 0, "draft"))").style(\.small, \.inkMuted)
                    if run.mode == "manual" { Chip(text: "Manual", accent: .ochre) }
                    Chip(text: run.isOK ? "OK" : Derived.label(run.status), accent: run.isOK ? .moss : .alert)
                }
            }
            if runs.count > shown {
                MoreLine(phrases: [.init(text: "+ "), .init(text: String(runs.count - shown), strong: true), .init(text: " earlier runs")]) { expanded = true }
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }
}
