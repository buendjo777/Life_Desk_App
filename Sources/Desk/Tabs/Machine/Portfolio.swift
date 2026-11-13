import SwiftUI

/// Optional `desk/portfolio.json` in the demo vault: the numbers only Jose can supply.
struct PortfolioInfo: Decodable {
    var evaluation: Evaluation?
    var thesisUrl: String?

    struct Evaluation: Decodable {
        /// 0…1: important emails the agent failed to flag as needing a reply.
        var missedReplyRate: Double
        var sample: Int?
        var note: String?
    }
}

extension Derived {
    struct CostLine: Identifiable {
        let item: String
        let cost: String
        let note: String
        var id: String { item }
    }

    /// The zero-cost constraints from the spec, plus the agent's own latest usage note.
    var costTable: [CostLine] {
        [
            CostLine(item: "App", cost: "0 €", note: "Swift and Xcode are free; ad-hoc signature, no Developer Program"),
            CostLine(item: "Server", cost: "0 €", note: "There is none: the app reads files from a git clone"),
            CostLine(item: "Vault", cost: "0 €", note: "A private GitHub repo"),
            CostLine(item: "Nightly run", cost: "Plan", note: lastRun?.usageNote ?? "No run recorded yet"),
        ]
    }

    static let architecture: [(title: String, detail: String, accent: Accent)] = [
        ("Nightly agents", "Read mail and calendar in the cloud", .deep),
        ("Vault (git)", "snapshot.json · runs.jsonl · drafts · Jose's notes", .caution),
        ("Desk for Mac", "git pull · pure parsers · nine tabs", .focus),
        ("Jose", "Ticks, Add, Dismiss → decisions.jsonl", .good),
    ]
}

/// What the system does (deep).
struct PortfolioIntro: View {
    @Environment(Store.self) private var store
    @Environment(\.theme) private var t

    var body: some View {
        let d = store.showcase
        StatCard(title: "Desk: a life desk run by nightly agents", accent: .deep, shape: .cog, tall: true) {
            Text(verbatim: "Cloud agents read the inbox and the calendar every night and write a brief into a private git vault. "
                + "Desk is the native Mac app that reads it: what is due, what needs a reply, what to confirm. "
                + "It holds no credentials, renders untrusted text as plain text, and changes nothing without a click.")
                .style(\.body).lineSpacing(t.sp4).opacity(t.onAccentBlock)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: t.summaryWidth, alignment: .leading)
            Spacer(minLength: 0)
            HStack(alignment: .top, spacing: t.sp24) {
                Figure(String(Tab.sidebar.count), caption: "Tabs")
                Figure(String(d.lastRun?.agents?.count ?? 0), caption: "Agents")
                Figure(String(d.data.runs.count), caption: "Runs logged")
                Figure("0", unit: "€", caption: "Running cost")
            }
        }
    }
}

/// The evaluation result (caution): the missed-reply rate, or an honest empty state.
struct PortfolioEvaluation: View {
    @Environment(Store.self) private var store
    @Environment(\.theme) private var t

    var body: some View {
        StatCard(title: "Evaluation", subtitle: "Missed-reply rate", accent: .caution, shape: .triangle, tall: true) {
            if let evaluation = store.portfolio?.evaluation {
                Figure(String(format: "%.1f", evaluation.missedReplyRate * 100), unit: "%",
                       caption: evaluation.sample.map { "of \($0) emails that needed a reply" } ?? "Missed replies")
                if let note = evaluation.note {
                    Text(verbatim: note).style(\.small).opacity(t.captionOpacity).fixedSize(horizontal: false, vertical: true)
                }
            } else {
                Text(verbatim: "Not measured yet.").style(\.cardTitle)
                Text(verbatim: "The result appears here once desk/portfolio.json has an evaluation. Nothing is shown until it is real.")
                    .style(\.small).opacity(t.captionOpacity).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            if let url = Links.web(store.portfolio?.thesisUrl) {
                Button("Open the thesis repo") { Links.open(url) }.buttonStyle(.deskPrimary)
            } else {
                Text(verbatim: "Thesis repo: add thesis_url to desk/portfolio.json.").style(\.small).opacity(t.captionOpacity)
            }
        }
    }
}

/// The architecture diagram: four boxes and the arrows between them.
struct ArchitectureDiagram: View {
    @Environment(\.theme) private var t

    var body: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: t.sp12) {
                HStack(alignment: .firstTextBaseline) {
                    Text(verbatim: "Architecture").style(\.cardTitle, \.ink)
                    Spacer()
                    Text(verbatim: "One writer per file · no server · no tokens in the app").style(\.small, \.inkMuted)
                }
                HStack(spacing: t.sp8) {
                    ForEach(Array(Derived.architecture.enumerated()), id: \.offset) { index, box in
                        if index > 0 {
                            Image(systemName: "arrow.right").font(.system(size: t.symbol, weight: .bold)).foregroundStyle(t.inkMuted)
                                .accessibilityHidden(true)
                        }
                        VStack(alignment: .leading, spacing: t.sp4) {
                            Text(verbatim: box.title).style(\.bodyStrong)
                            Text(verbatim: box.detail).style(\.small).opacity(t.onAccentBlock).fixedSize(horizontal: false, vertical: true)
                        }
                        .foregroundStyle(t.on(box.accent))
                        .padding(t.sp12)
                        .frame(maxWidth: .infinity, minHeight: t.boardCardMin, alignment: .topLeading)
                        .background(t.fill(box.accent), in: RoundedRectangle(cornerRadius: t.radiusRow))
                    }
                }
                HStack(spacing: t.sp8) {
                    Image(systemName: "arrow.uturn.left").font(.system(size: t.symbolSmall, weight: .bold)).foregroundStyle(t.inkMuted)
                    Text(verbatim: "The agent reads decisions.jsonl on its next run, so it never re-proposes. The Mac calendar reaches Desk through EventKit; WhatsApp is never read, only opened with a prefilled message.")
                        .style(\.small, \.inkMuted).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// The agents and their models, from the latest demo run.
struct PortfolioAgents: View {
    @Environment(Store.self) private var store
    @Environment(\.theme) private var t

    var body: some View {
        let agents = store.showcase.lastRun?.agents ?? []
        VStack(alignment: .leading, spacing: t.sp8) {
            SectionHeader(title: "Agents", subtitle: "Cheaper models read, stronger ones write and verify")
            if agents.isEmpty { EmptyState(line: "No agents listed in the last run.") }
            ForEach(agents, id: \.self) { agent in
                ListRow(leading: .symbol("cpu", .deep), title: agent.name, subtitle: nil) { _ in
                    Chip(text: agent.model, accent: agent.model == "haiku" ? .info : .caution)
                }
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }
}

/// The cost table and the failure log.
struct PortfolioCosts: View {
    @Environment(Store.self) private var store
    @Environment(\.theme) private var t

    var body: some View {
        let d = store.showcase
        VStack(alignment: .leading, spacing: t.sp8) {
            SectionHeader(title: "Cost")
            ForEach(d.costTable) { line in
                ListRow(leading: .symbol("eurosign", .good), title: line.item, subtitle: line.note) { _ in
                    Chip(text: line.cost, accent: .good)
                }
            }
            SectionHeader(title: "Failure log", subtitle: "\(d.failedRuns.count) failed of \(d.data.runs.count) runs")
            if d.failureLog.isEmpty { EmptyState(line: "No failures logged.") }
            ForEach(Array(d.failureLog.enumerated()), id: \.offset) { _, entry in
                // Agent-written lines: ListRow draws them verbatim.
                ListRow(leading: .symbol(entry.run.isOK ? "exclamationmark" : "xmark", entry.run.isOK ? .caution : .alert),
                        title: entry.text, subtitle: d.cal.format(entry.run.startedAt.date, "EEE d MMM · HH:mm")) { _ in
                    Chip(text: entry.run.isOK ? "Recovered" : "Failed", accent: entry.run.isOK ? .caution : .alert)
                }
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }
}
