import SwiftUI

/// The raised panel that slides over the right rail when a row is opened. Esc closes it.
struct Inspector: View {
    @Environment(Store.self) private var store
    @Environment(\.theme) private var t
    let item: DeskItem

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(verbatim: kind).style(\.label, \.inkMuted)
                Spacer()
                Button {
                    store.inspectorOpen = false
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: t.symbolSmall, weight: .bold))
                        .foregroundStyle(t.ink)
                        .frame(width: t.sp24, height: t.sp24)
                        .background(t.surface, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close inspector")
            }
            .padding(.bottom, t.sp12)
            Scroller {
                VStack(alignment: .leading, spacing: t.sp12) {
                    content
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(t.sp16)
        .frame(maxHeight: .infinity, alignment: .top)
        .raisedPanel(shadow: true)
    }

    private var kind: String {
        switch item {
        case .row(let id): store.data.rows.first { $0.id == id }?.section.rawValue ?? "Row"
        case .task: "Task"
        case .check: "Checklist"
        case .project: "Project"
        case .uni: "Programme"
        case .target: "Internship"
        case .person: "Contact"
        case .student: "Student"
        }
    }

    @ViewBuilder private var content: some View {
        switch item {
        case .row(let id):
            if let row = store.data.rows.first(where: { $0.id == id }) {
                RowInspector(row: row)
            } else {
                EmptyState(line: "This row is no longer in the snapshot.")
            }
        case .task(let line):
            if let task = store.data.tasks.first(where: { $0.line == line }) {
                TaskInspector(task: task)
            } else {
                EmptyState(line: "This task is no longer in TASKS.md.")
            }
        case .project(let path):
            if let project = store.data.projects.first(where: { $0.path == path }) {
                ProjectInspector(project: project)
            } else {
                EmptyState(line: "This project file is gone.", hint: path)
            }
        case .uni(let path):
            if let card = store.d.uniCards.first(where: { $0.id == path }) {
                UniInspector(card: card)
            } else {
                EmptyState(line: "This programme file is gone.", hint: path)
            }
        case .target(let id):
            if let target = store.data.targets?.first(where: { $0.id == id }) {
                TargetInspector(target: target)
            } else {
                EmptyState(line: "This target is no longer on the board.")
            }
        case .person(let id):
            if let person = store.data.people?.first(where: { $0.id == id }) {
                PersonInspector(person: person)
            } else {
                EmptyState(line: "This contact is no longer on the board.")
            }
        default:
            EmptyState(line: "Nothing to show.")
        }
    }
}

/// Inspector building blocks.
struct InspectorTitle: View {
    let text: String
    var body: some View {
        Text(verbatim: text).style(\.cardTitle, \.ink).fixedSize(horizontal: false, vertical: true)
    }
}

struct InspectorField: View {
    @Environment(\.theme) private var t
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: t.sp2) {
            Text(verbatim: label).style(\.caption, \.inkMuted)
            Text(verbatim: value).style(\.body, \.ink).fixedSize(horizontal: false, vertical: true).textSelection(.enabled)
        }
    }
}

/// A hand-off button that opens a link built by code.
struct LinkButton: View {
    let title: String
    let url: URL?
    var primary = false

    var body: some View {
        if let url {
            Button(title) { Links.open(url) }
                .buttonStyle(DeskButtonStyle(kind: primary ? .primary : .secondary))
        }
    }
}

/// A snapshot row in the inspector. All of its text is agent-written, so it is drawn verbatim.
struct RowInspector: View {
    @Environment(Store.self) private var store
    @Environment(\.theme) private var t
    let row: SnapshotRow

    var body: some View {
        let d = store.d
        let gmail = row.gmailThread.flatMap(Links.gmail)
        switch row.section {
        case .email:
            InspectorTitle(text: row.title)
            if let tag = row.tag.flatMap(Derived.EmailTag.init) { Chip(text: tag.label, accent: tag.accent) }
            if let subject = row.subject { InspectorField(label: "Subject", value: subject) }
            if let detail = row.detail { InspectorField(label: "Summary", value: detail) }
            if let when = row.when?.date { InspectorField(label: "Received", value: d.cal.format(when, "EEE d MMM, HH:mm")) }
            Text(verbatim: "As of the last run, not live.").style(\.small, \.inkMuted)
            LinkButton(title: "Open in Gmail", url: gmail, primary: true)
            LinkButton(title: "Open in Claude", url: Links.claude(seed: "Help me reply to the Gmail thread behind row \(row.id) in agent/snapshot.json of my vault."))
        case .draft:
            InspectorTitle(text: row.title)
            if let draft = d.draft(for: row) {
                Chip(text: draft.status.capitalized, accent: .steel)
                InspectorField(label: "To", value: draft.to)
                // The draft body is untrusted text: verbatim, no Markdown, no links.
                Text(verbatim: draft.body)
                    .style(\.body, \.ink)
                    .lineSpacing(t.sp4)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(t.sp12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(t.surface, in: RoundedRectangle(cornerRadius: t.radiusNav))
                Text(verbatim: "Nothing is sent automatically. Copy it into Gmail if you like it.").style(\.small, \.inkMuted)
                LinkButton(title: "Open thread in Gmail", url: Links.gmail(thread: draft.thread), primary: true)
                LinkButton(title: "Open in Obsidian", url: Links.obsidian(vault: store.vaultName, file: draft.path))
                LinkButton(title: "Open in Claude", url: Links.claude(seed: "Review my reply draft at \(draft.path) in my vault and suggest edits."))
            } else {
                EmptyState(line: "The draft file is missing.", hint: row.source)
            }
        case .waiting:
            InspectorTitle(text: row.title)
            if let detail = row.detail { InspectorField(label: "Status", value: detail) }
            if let since = row.when?.date {
                InspectorField(label: "Waiting since", value: "\(d.cal.weekdayDay(since)) · \(d.cal.days(from: since, to: d.today)) days")
            }
            LinkButton(title: "Open in Gmail", url: gmail, primary: true)
        case .confirm:
            ProposalView(row: row)
        default:
            InspectorTitle(text: row.title)
            if let detail = row.detail { InspectorField(label: "Note", value: detail) }
            if let source = row.source { InspectorField(label: "Source", value: source.hasPrefix("Gmail") ? "Gmail" : source) }
            if row.section == .today {
                Button(d.isDone(row) ? "Mark not done" : "Mark done") { store.toggleFocus(row) }
                    .buttonStyle(.deskPrimary)
            }
            LinkButton(title: "Open in Gmail", url: gmail)
            LinkButton(title: "Open in Claude", url: Links.claude(seed: "Help me with focus item \(row.id) from agent/snapshot.json in my vault."))
        }
    }
}

/// A `TASKS.md` item in the inspector. The title is Jose's own text.
struct TaskInspector: View {
    @Environment(Store.self) private var store
    let task: TaskItem

    var body: some View {
        let d = store.d
        InspectorTitle(text: task.title)
        InspectorField(label: "Section", value: task.section.isEmpty ? "—" : task.section)
        if let due = task.due {
            InspectorField(label: "Due", value: d.cal.weekdayDay(due))
        }
        Button(task.done ? "Untick" : "Tick") { store.toggle(task) }
            .buttonStyle(.deskPrimary)
        LinkButton(title: "Open in Obsidian", url: Links.obsidian(vault: store.vaultName, file: VaultData.tasksFile))
        LinkButton(title: "Open in Claude", url: Links.claude(seed: "Help me with my task “\(task.title)” from TASKS.md in my vault."))
    }
}
