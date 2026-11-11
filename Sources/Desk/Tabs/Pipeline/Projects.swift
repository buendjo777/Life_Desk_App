import SwiftUI

/// One board column: a header with a count chip, then compact cards.
struct ProjectColumn: View {
    @Environment(Store.self) private var store
    @Environment(\.theme) private var t
    let status: ProjectStatus

    var body: some View {
        let projects = store.d.projects(status)
        VStack(alignment: .leading, spacing: t.sp8) {
            HStack(spacing: t.sp8) {
                Text(verbatim: status.title).style(\.cardTitle, \.ink)
                Chip(text: String(projects.count), accent: status.accent)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, t.sp4)
            .padding(.bottom, t.sp4)
            if projects.isEmpty {
                EmptyState(line: "Nothing \(status == .idea ? "here" : status.rawValue).")
            }
            ForEach(projects) { project in
                ProjectCard(project: project)
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }
}

extension ProjectStatus {
    var accent: Accent {
        switch self {
        case .active: .rust
        case .waiting: .ochre
        case .frozen: .steel
        case .idea: .moss
        }
    }
}

struct ProjectCard: View {
    @Environment(Store.self) private var store
    @Environment(\.theme) private var t
    let project: Project

    var body: some View {
        let d = store.d
        let selected = store.selection == .project(project.path)
        let progress = Derived.progress(project.items)
        VStack(alignment: .leading, spacing: t.sp6) {
            Text(verbatim: project.title)
                .style(\.rowTitle, selected ? \.onAccent : \.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text(verbatim: project.next)
                .style(\.small, selected ? \.onAccent : \.inkMuted)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: t.sp4)
            HStack(spacing: t.sp6) {
                if let date = project.nextDate {
                    Chip(text: d.cal.shortDay(date), accent: date < d.today ? .alert : project.status.accent, onAccent: selected)
                }
                Spacer(minLength: 0)
                if progress.total > 0 {
                    Text(verbatim: progress.text).style(\.micro, selected ? \.onAccent : \.inkMuted)
                }
            }
            if progress.total > 0 {
                ProgressBar(value: progress.fraction, accent: project.status.accent, onCard: selected)
            }
        }
        .padding(t.sp12 + t.sp2)
        .frame(maxWidth: .infinity, minHeight: t.boardCardMin, alignment: .topLeading)
        .fixedSize(horizontal: false, vertical: true)
        .background(selected ? t.rust : t.surface, in: RoundedRectangle(cornerRadius: t.radiusRow))
        .contentShape(RoundedRectangle(cornerRadius: t.radiusRow))
        .onTapGesture { store.open(.project(project.path)) }
        .deskAnimation(selected)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
}

/// A project in the inspector: its next step, the checklist and the linked `nini/` doc.
struct ProjectInspector: View {
    @Environment(Store.self) private var store
    @Environment(\.theme) private var t
    let project: Project

    var body: some View {
        let d = store.d
        InspectorTitle(text: project.title)
        Chip(text: project.status == .idea ? "Idea" : project.status.title, accent: project.status.accent)
        InspectorField(label: "Next", value: project.next.isEmpty ? "—" : project.next)
        if let date = project.nextDate {
            InspectorField(label: "By", value: d.cal.weekdayDay(date))
        }
        if !project.items.isEmpty {
            Text(verbatim: "Checklist").style(\.caption, \.inkMuted)
            VStack(alignment: .leading, spacing: 0) {
                ForEach(project.items) { CheckLine(path: project.path, check: $0) }
            }
        }
        if let doc = project.doc {
            Text(verbatim: doc).style(\.caption, \.inkMuted)
            if let text = d.data.docs[doc] {
                MarkdownView(text: text)
                    .padding(t.sp12)
                    .background(t.surface, in: RoundedRectangle(cornerRadius: t.radiusNav))
            } else {
                EmptyState(line: "The linked doc is not in the mirror.", hint: doc)
            }
        }
        LinkButton(title: "Open in Obsidian", url: Links.obsidian(vault: store.vaultName, file: project.path), primary: true)
        LinkButton(title: "Open in Claude", url: Links.claude(seed: "Help me move my project forward: \(project.path) in my vault\(project.doc.map { ", background in \($0)" } ?? "")."))
    }
}
