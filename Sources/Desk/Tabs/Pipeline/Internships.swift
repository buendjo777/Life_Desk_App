import SwiftUI

/// One count card per status: Open, Applied, Interview, Rejected.
struct TargetCountCard: View {
    @Environment(Store.self) private var store
    let status: String

    var body: some View {
        let targets = store.d.targets(status: status)
        StatCard(title: Derived.label(status), accent: Self.accent(status), shape: .square) {
            Figure(String(targets.count), caption: targets.count == 1 ? "target" : "targets")
        }
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

/// The targets table: Apply now · All targets.
struct TargetList: View {
    @Environment(Store.self) private var store
    @Environment(\.theme) private var t
    @State private var all = false
    @State private var expanded = false

    var body: some View {
        let d = store.d
        VStack(alignment: .leading, spacing: t.sp8) {
            if d.data.targets == nil {
                SectionHeader(title: "Targets")
                EmptyState(line: "The internship board has not moved into the vault yet.", hint: "It appears here once internships/board.json exists.")
                LinkButton(title: "Open board", url: Links.web(d.data.settings.links.internshipBoard), primary: true)
            } else {
                let rows = all ? d.allTargets : d.applyNow
                let shown = expanded ? rows.count : min(rows.count, t.listRows + 1)
                SectionHeader(title: "Targets") {
                    CountedTabs(items: [
                        .init(id: false, title: "Apply now", count: d.applyNow.count),
                        .init(id: true, title: "All targets", count: d.allTargets.count),
                    ], selection: $all)
                    LinkButton(title: "Open board", url: Links.web(d.data.settings.links.internshipBoard))
                }
                .padding(.bottom, t.sp2)
                if rows.isEmpty { EmptyState(line: "No targets in this list.") }
                ForEach(rows.prefix(shown)) { target in
                    TargetRow(target: target)
                }
                if rows.count > shown {
                    MoreLine(phrases: [.init(text: "+ "), .init(text: String(rows.count - shown), strong: true), .init(text: " more")]) { expanded = true }
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
            if let graduate = target.graduateOk {
                Chip(text: graduate ? "Graduate OK" : "Needs convenio", accent: graduate ? .moss : .neutral, onAccent: selected)
            }
            if let days = d.daysLeft(target.deadline) {
                Chip(text: days < 0 ? "Closed" : "\(days) d", accent: days < 0 ? .alert : .ochre, onAccent: selected)
            }
            Chip(text: target.statusLabel ?? Derived.label(target.status), accent: TargetCountCard.accent(target.status), onAccent: selected)
            if let url = Links.web(target.url) {
                Button(target.list == "apply_now" ? "Apply" : "Open") { Links.open(url) }.buttonStyle(.deskSecondary)
                    .help(target.url ?? "")
            }
        }
    }
}

struct TargetInspector: View {
    @Environment(Store.self) private var store
    let target: Target

    var body: some View {
        let d = store.d
        InspectorTitle(text: target.company)
        Chip(text: target.statusLabel ?? Derived.label(target.status), accent: TargetCountCard.accent(target.status))
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
