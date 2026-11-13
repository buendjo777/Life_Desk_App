import SwiftUI

/// One count card per status: Open, Applied, Interview, Rejected. Clicking one shows only those below.
struct TargetCountCard: View {
    @Environment(Store.self) private var store
    @Environment(\.theme) private var t
    let status: String

    var body: some View {
        let targets = store.d.targets(status: status)
        let picked = store.targetFilter == status
        Button {
            store.targetFilter = picked ? nil : status
        } label: {
            StatCard(title: Derived.label(status), subtitle: picked ? "Showing" : nil, accent: Self.accent(status), shape: .square) {
                Figure(String(targets.count), caption: targets.count == 1 ? "target" : "targets")
            }
            .overlay(RoundedRectangle(cornerRadius: t.radiusCard).strokeBorder(t.ink, lineWidth: picked ? t.stroke + t.hairline : 0))
            .opacity(store.targetFilter == nil || picked ? 1 : t.captionOpacity)
            .contentShape(RoundedRectangle(cornerRadius: t.radiusCard))
        }
        .buttonStyle(.plain)
        .help(picked ? "Show every target again" : "Show only \(Derived.label(status).lowercased()) targets")
        .accessibilityAddTraits(picked ? [.isButton, .isSelected] : .isButton)
    }

    static func accent(_ status: String) -> Accent {
        switch status {
        case "open": .ochre
        case "applied": .steel
        case "interview", "offer": .moss
        case "rejected": .navy
        default: .neutral
        }
    }
}

/// The targets table: Apply now · All targets, or only the status picked on a card. Long lists grow 30 rows at a time.
struct TargetList: View {
    @Environment(Store.self) private var store
    @Environment(\.theme) private var t
    @State private var all = false
    @State private var extra = 0

    var body: some View {
        let d = store.d
        VStack(alignment: .leading, spacing: t.sp8) {
            if d.data.targets == nil {
                SectionHeader(title: "Targets")
                EmptyState(line: "The internship board has not moved into the vault yet.", hint: "It appears here once internships/board.json exists.")
                LinkButton(title: "Open board", url: Links.web(d.data.settings.links.internshipBoard), primary: true)
            } else {
                let filter = store.targetFilter
                let rows = filter.map { d.filteredTargets(status: $0) } ?? (all ? d.allTargets : d.applyNow)
                let shown = min(rows.count, t.listRows + 1 + extra)
                SectionHeader(title: filter.map { "\(Derived.label($0)) · \(rows.count)" } ?? "Targets") {
                    if filter != nil {
                        Button("Show all") { store.targetFilter = nil }.buttonStyle(.deskSecondary)
                    } else {
                        CountedTabs(items: [
                            .init(id: false, title: "Apply now", count: d.applyNow.filter { $0.status != "rejected" }.count),
                            .init(id: true, title: "All targets", count: d.allTargets.count),
                        ], selection: $all)
                    }
                    LinkButton(title: "Open board", url: Links.web(d.data.settings.links.internshipBoard))
                }
                .padding(.bottom, t.sp2)
                .onChange(of: filter) { extra = 0 }
                .onChange(of: all) { extra = 0 }
                if rows.isEmpty { EmptyState(line: "No targets in this list.") }
                ForEach(rows.prefix(shown)) { target in
                    TargetRow(target: target)
                }
                if rows.count > shown {
                    MoreLine(phrases: [.init(text: "+ "), .init(text: String(rows.count - shown), strong: true),
                                       .init(text: rows.count - shown > 30 ? " more · show 30" : " more")]) { extra += 30 }
                }
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }
}

struct TargetRow: View {
    @Environment(Store.self) private var store
    @Environment(\.theme) private var t
    let target: Target

    var body: some View {
        let d = store.d
        let place = [target.city, target.country].compactMap { $0 }.joined(separator: ", ")
        ListRow(leading: .initials(initials(of: target.company), TargetCountCard.accent(target.status)), title: target.company,
                subtitle: [target.role, place.isEmpty ? nil : place].compactMap { $0 }.joined(separator: " · "),
                selected: store.selection == .target(target.id), action: { store.open(.target(target.id)) }) { selected in
            if let next = target.next {
                Text(verbatim: next).style(\.small, selected ? \.onAccent : \.inkMuted).lineLimit(1)
                    .frame(maxWidth: t.railWidth - t.sp32, alignment: .trailing)
            }
            if let priority = target.priority {
                Chip(text: "Priority \(priority)", accent: priority == "A" ? .rust : .neutral, onAccent: selected)
            }
            if let graduate = target.graduateOk {
                Chip(text: graduate ? "Graduate OK" : "Needs convenio", accent: graduate ? .moss : .neutral, onAccent: selected)
            }
            if let days = d.daysLeft(target.deadline) {
                Chip(text: days < 0 ? "Closed" : "\(days) d", accent: days < 0 ? .alert : .ochre, onAccent: selected)
            }
            if d.isNew(target) { Chip(text: "New", accent: .rust, onAccent: selected) }
            TargetStatusMenu(target: target, onAccent: selected)
            if let url = Links.web(target.url) {
                Button(target.list == "apply_now" && target.status == "open" ? "Apply" : "Open") { Links.open(url) }.buttonStyle(.deskSecondary)
                    .help(target.url ?? "")
            }
        }
    }
}

/// The status chip; clicking it sets the status, in the board's own words.
struct TargetStatusMenu: View {
    @Environment(Store.self) private var store
    let target: Target
    var onAccent = false

    var body: some View {
        let chip = Chip(text: target.statusLabel ?? Derived.label(target.status), accent: TargetCountCard.accent(target.status), onAccent: onAccent)
        if store.isSnapshot || target.sourceID == nil {
            chip
        } else {
            Menu {
                ForEach(Derived.boardStatuses, id: \.self) { status in
                    Button {
                        store.setTargetStatus(target, to: status)
                    } label: {
                        if status == target.statusLabel { Label(status, systemImage: "checkmark") } else { Text(status) }
                    }
                }
            } label: {
                chip
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("Set the status")
            .accessibilityLabel(Text(verbatim: "Status: \(target.statusLabel ?? Derived.label(target.status)). Change it"))
        }
    }
}

struct TargetInspector: View {
    @Environment(Store.self) private var store
    let target: Target

    var body: some View {
        let d = store.d
        InspectorTitle(text: target.company)
        TargetStatusMenu(target: target)
        if let role = target.role { InspectorField(label: "Role", value: role) }
        InspectorField(label: "Where", value: [target.city, target.country].compactMap { $0 }.joined(separator: ", "))
        InspectorField(label: "List", value: target.list == "apply_now" ? "Apply now" : "Target")
        let when = [target.start, target.duration].compactMap { $0 }.joined(separator: " · ")
        if !when.isEmpty { InspectorField(label: "When", value: when) }
        if let language = target.language { InspectorField(label: "Language", value: language) }
        if let graduate = target.graduateOk { InspectorField(label: "Open to graduates", value: graduate ? "Yes" : "Needs a convenio") }
        if let eligibility = target.eligibility { InspectorField(label: "Eligibility", value: eligibility) }
        if let fit = target.fit { InspectorField(label: "Fit", value: fit) }
        if let deadline = target.deadline, let days = d.daysLeft(deadline) {
            InspectorField(label: "Deadline", value: "\(d.cal.weekdayDay(deadline.date)) · \(days < 0 ? "closed" : Derived.plural(days, "day"))")
        }
        if let notes = target.notes { InspectorField(label: "Notes", value: notes) } else if let next = target.next { InspectorField(label: "Next step", value: next) }
        LinkButton(title: target.list == "apply_now" ? "Apply" : "Open posting", url: Links.web(target.url), primary: true)
        LinkButton(title: "Open board", url: Links.web(d.data.settings.links.internshipBoard))
        LinkButton(title: "Open in Claude", url: Links.safeID(target.id).flatMap { Links.claude(seed: "Help me with internship target \($0) in internships/board.json in my vault.") })
    }
}
