import SwiftUI

/// A horizontal deadline runway across all programmes, with a today marker.
struct UniRunway: View {
    @Environment(Store.self) private var store
    @Environment(\.theme) private var t

    var body: some View {
        let d = store.d
        let span = Double(d.uniRunwayDays)
        let cards = d.uniCards.filter { ($0.daysLeft ?? -1) >= 0 }
        SurfaceCard {
            VStack(alignment: .leading, spacing: t.sp8) {
                HStack {
                    Text(verbatim: "Deadline runway").style(\.cardTitle, \.ink)
                    Spacer()
                    Text(verbatim: "Today → +\(d.uniRunwayDays) days").style(\.small, \.inkMuted)
                }
                GeometryReader { proxy in
                    let width = proxy.size.width - t.weekColumn * 2
                    ZStack(alignment: .topLeading) {
                        Capsule().fill(t.line).frame(width: proxy.size.width, height: t.stroke + t.stroke)
                            .offset(y: t.runwayDot / 2 - t.stroke)
                        Circle().fill(t.rust).frame(width: t.runwayDot, height: t.runwayDot)
                        Text(verbatim: "Today").style(\.micro, \.ink).offset(y: t.runwayDot + t.sp4)
                        ForEach(cards) { card in
                            let x = t.weekColumn + Double(card.daysLeft ?? 0) / span * width
                            Circle().fill(card.status == "Submitted" ? t.moss : t.steelDeep)
                                .frame(width: t.runwayDot, height: t.runwayDot)
                                .offset(x: x - t.runwayDot / 2)
                            VStack(spacing: 0) {
                                Text(verbatim: card.school.split(separator: " ").first.map(String.init) ?? card.school).style(\.smallStrong, \.ink)
                                Text(verbatim: "\(card.daysLeft ?? 0) d · \(card.deadline.map(d.cal.shortDay) ?? "")").style(\.micro, \.inkMuted)
                            }
                            .frame(width: t.weekColumn * 2)
                            .offset(x: x - t.weekColumn, y: t.runwayDot + t.sp4)
                        }
                    }
                }
                .frame(height: t.runwayDot + t.sp32 + t.sp4)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(verbatim: "Deadline runway, \(cards.count) programmes ahead"))
    }
}

/// The programme cards, three to a row, nearest deadline first.
struct UniGrid: View {
    @Environment(Store.self) private var store
    @Environment(\.theme) private var t

    var body: some View {
        let cards = store.d.uniCards
        let perRow = t.uniColumns
        if cards.isEmpty {
            EmptyState(line: "No programmes yet.", hint: "Add one file per programme in uni/.")
        }
        VStack(spacing: t.sp16) {
            ForEach(Array(stride(from: 0, to: cards.count, by: perRow)), id: \.self) { start in
                HStack(spacing: t.sp16) {
                    ForEach(start..<start + perRow, id: \.self) { index in
                        if index < cards.count {
                            UniCardView(path: cards[index].id)
                        } else {
                            Color.clear.frame(maxWidth: .infinity, maxHeight: t.hairline)
                        }
                    }
                }
            }
        }
    }
}

/// One programme card (steel): days left, checklist progress and status.
struct UniCardView: View {
    @Environment(Store.self) private var store
    @Environment(\.theme) private var t
    let path: String

    var body: some View {
        if let card = store.d.uniCards.first(where: { $0.id == path }) {
            let selected = store.selection == .uni(path)
            StatCard(title: card.school, accent: selected ? .rust : .steel, shape: .chevron) {
                Text(verbatim: card.degree).style(\.small).opacity(t.captionOpacity).lineLimit(1).padding(.top, -t.sp12)
                HStack(alignment: .top, spacing: t.sp20) {
                    if let days = card.daysLeft {
                        Figure(days < 0 ? "—" : String(days), unit: days < 0 ? nil : "d",
                               caption: days < 0 ? "Closed" : card.deadline.map(store.d.cal.shortDay) ?? "")
                    }
                    Figure(card.progress.text, caption: "Checklist")
                }
                ProgressBar(value: card.progress.fraction, onCard: true)
                HStack(spacing: t.sp6) {
                    Text(verbatim: card.status).style(\.smallStrong)
                    if let next = card.next {
                        Text(verbatim: "· next: \(next)").style(\.small).opacity(t.captionOpacity).lineLimit(1)
                    }
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: t.radiusCard))
            .onTapGesture { store.open(.uni(path)) }
            .accessibilityAction { store.open(.uni(path)) }
            .accessibilityAddTraits(.isButton)
        }
    }
}

/// A programme in the inspector: its checklist and its section of the comparison doc.
struct UniInspector: View {
    @Environment(Store.self) private var store
    @Environment(\.theme) private var t
    let card: Derived.UniCard

    var body: some View {
        let d = store.d
        InspectorTitle(text: card.school)
        Text(verbatim: card.degree).style(\.small, \.inkMuted)
        Chip(text: card.status, accent: card.status == "Submitted" ? .moss : .steel)
        if let deadline = card.deadline, let days = card.daysLeft {
            InspectorField(label: "Deadline", value: "\(d.cal.format(deadline, "EEE d MMM yyyy, HH:mm")) · \(days < 0 ? "closed" : Derived.plural(days, "day"))")
        }
        Text(verbatim: "Checklist · \(card.progress.text)").style(\.caption, \.inkMuted)
        VStack(alignment: .leading, spacing: 0) {
            ForEach(card.programme.items) { CheckLine(path: card.programme.path, check: $0) }
        }
        Text(verbatim: "From the programme comparison").style(\.caption, \.inkMuted)
        if let section = d.comparison(for: card.programme) {
            MarkdownView(text: section)
                .padding(t.sp12)
                .background(t.surface, in: RoundedRectangle(cornerRadius: t.radiusNav))
        } else {
            EmptyState(line: "No section with this heading in the comparison doc.", hint: card.programme.comparisonHeading)
        }
        LinkButton(title: "Open in Obsidian", url: Links.obsidian(vault: store.vaultName, file: card.programme.path), primary: true)
        LinkButton(title: "Open in Claude", url: Links.claude(seed: "Help me with my application in \(card.programme.path) in my vault. The comparison is in \(VaultData.comparisonDoc)."))
    }
}

/// The Contacts Board: counts by status, then the list.
struct ContactsBoard: View {
    @Environment(Store.self) private var store
    @Environment(\.theme) private var t
    @State private var status: String?
    @State private var expanded = false

    var body: some View {
        let d = store.d
        VStack(alignment: .leading, spacing: t.sp8) {
            if let people = d.data.people {
                let rows = status.map(d.people) ?? people
                let shown = expanded ? rows.count : min(rows.count, t.listRows - 2)
                SectionHeader(title: "Contacts") {
                    CountedTabs(items: [.init(id: String?.none, title: "All", count: people.count)]
                        + Derived.personStatuses.map { .init(id: String?.some($0), title: Derived.label($0), count: d.people(status: $0).count) },
                        selection: $status)
                }
                .padding(.bottom, t.sp2)
                if rows.isEmpty { EmptyState(line: "Nobody with this status.", hint: d.data.hint(VaultData.peopleFile)) }
                ForEach(rows.prefix(shown)) { person in
                    ListRow(leading: .initials(initials(of: person.name), .steel), title: person.name,
                            subtitle: [person.role, person.programme].compactMap { $0 }.joined(separator: " · "),
                            selected: store.selection == .person(person.id), action: { store.open(.person(person.id)) }) { selected in
                        if let next = person.next {
                            Text(verbatim: next).style(\.small, selected ? \.onAccent : \.inkMuted).lineLimit(1)
                                .frame(maxWidth: t.railWidth, alignment: .trailing)
                        }
                        Chip(text: Derived.label(person.status), accent: Self.accent(person.status), onAccent: selected)
                    }
                }
                if rows.count > shown {
                    MoreLine(phrases: [.init(text: "+ "), .init(text: String(rows.count - shown), strong: true), .init(text: " more")]) { expanded = true }
                }
            } else {
                SectionHeader(title: "Contacts")
                EmptyState(line: "The contacts board has not moved into the vault yet.", hint: "It appears here once contacts/people.json exists.")
                LinkButton(title: "Open board", url: Links.web(d.data.settings.links.contactsBoard), primary: true)
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    static func accent(_ status: String) -> Accent {
        switch status {
        case "replied", "call_booked": .moss
        case "sent", "drafted": .steel
        case "no_reply": .alert
        default: .neutral
        }
    }
}

struct PersonInspector: View {
    @Environment(Store.self) private var store
    let person: Person

    var body: some View {
        let d = store.d
        InspectorTitle(text: person.name)
        Chip(text: Derived.label(person.status), accent: ContactsBoard.accent(person.status))
        if let role = person.role { InspectorField(label: "Role", value: role) }
        if let programme = person.programme { InspectorField(label: "Programme", value: programme) }
        if let last = person.lastContact?.date {
            InspectorField(label: "Last contact", value: "\(d.cal.weekdayDay(last)) · \(Derived.plural(d.cal.days(from: last, to: d.today), "day")) ago")
        }
        if let next = person.next { InspectorField(label: "Next step", value: next) }
        LinkButton(title: "Open board", url: Links.web(d.data.settings.links.contactsBoard))
        LinkButton(title: "Open in Claude", url: Links.safeID(person.id).flatMap { Links.claude(seed: "Help me plan my next message to contact \($0) in contacts/people.json in my vault.") }, primary: true)
    }
}
