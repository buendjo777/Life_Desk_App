import SwiftUI

/// A horizontal deadline runway across all programmes, with a today marker.
struct UniRunway: View {
    @Environment(Store.self) private var store
    @Environment(\.theme) private var t

    /// The runway's measured width; until it is known, a typical one at the design size.
    @State private var measured: CGFloat?

    /// A label's height (name and date) and the space between rows.
    private var labelHeight: CGFloat { t.sp32 }
    private var rowGap: CGFloat { t.sp4 }

    var body: some View {
        let d = store.d
        let span = Double(d.uniRunwayDays)
        let marks = d.uniRunwayMarks
        // Rows needed at the measured width, so the card is only as tall as its labels need.
        let planned = lanes(marks, width: measured ?? 1000, span: span)
        let rowsAbove = planned.contains(3) ? 2 : planned.contains(1) ? 1 : 0
        let rowsBelow = planned.contains(2) ? 2 : 1
        let lineY = CGFloat(rowsAbove) * (labelHeight + rowGap) + t.runwayDot / 2
        SurfaceCard {
            VStack(alignment: .leading, spacing: t.sp8) {
                HStack {
                    Text(verbatim: "Deadline runway").style(\.cardTitle, \.ink)
                    Spacer()
                    Text(verbatim: "Today → +\(d.uniRunwayDays) days").style(\.small, \.inkMuted)
                }
                GeometryReader { proxy in
                    let width = proxy.size.width - t.weekColumn * 2
                    let assigned = lanes(marks, width: width, span: span)
                    ZStack(alignment: .topLeading) {
                        Color.clear
                            .onAppear { measured = width }
                            .onChange(of: width) { measured = width }
                        Capsule().fill(t.line).frame(width: proxy.size.width, height: t.stroke + t.stroke)
                            .offset(y: lineY - t.stroke)
                        Circle().fill(t.focus).frame(width: t.runwayDot, height: t.runwayDot)
                            .offset(y: lineY - t.runwayDot / 2)
                        Text(verbatim: "Today").style(\.micro, \.ink).offset(y: y(lane: 0, lineY: lineY))
                        ForEach(Array(marks.enumerated()), id: \.element.id) { index, mark in
                            let x = t.weekColumn + Double(mark.daysLeft) / span * width
                            let lane = assigned[index]
                            Circle().fill(mark.submitted ? t.good : t.infoDeep)
                                .frame(width: t.runwayDot, height: t.runwayDot)
                                .offset(x: x - t.runwayDot / 2, y: lineY - t.runwayDot / 2)
                            // A thin tick ties a label that is not right under its dot to the dot.
                            if lane >= 1 {
                                let top = lane % 2 == 1 ? y(lane: lane, lineY: lineY) + labelHeight : lineY + t.runwayDot / 2
                                let bottom = lane % 2 == 1 ? lineY - t.runwayDot / 2 : y(lane: lane, lineY: lineY)
                                Rectangle().fill(t.line)
                                    .frame(width: t.hairline, height: max(0, bottom - top))
                                    .offset(x: x, y: top)
                            }
                            VStack(spacing: 0) {
                                Text(verbatim: mark.title).style(\.smallStrong, \.ink).lineLimit(1)
                                Text(verbatim: "\(mark.daysLeft) d · \(mark.deadline.map(d.cal.shortDay) ?? "")").style(\.micro, \.inkMuted).lineLimit(1)
                            }
                            .frame(width: t.weekColumn * 2, height: labelHeight)
                            .offset(x: x - t.weekColumn, y: y(lane: lane, lineY: lineY))
                        }
                    }
                }
                .frame(height: lineY + t.runwayDot / 2 + t.sp4 + CGFloat(rowsBelow) * (labelHeight + rowGap))
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(verbatim: "Deadline runway, \(marks.count) deadlines ahead"))
    }

    private func lanes(_ marks: [Derived.RunwayMark], width: Double, span: Double) -> [Int] {
        Derived.runwayLanes(marks.map { t.weekColumn + Double($0.daysLeft) / span * width },
                            labelWidth: t.weekColumn * 2, gap: t.sp4, occupied: t.weekColumn)
    }

    /// The top of a label in `lane`: 0 and 2 below the line, 1 and 3 above it.
    private func y(lane: Int, lineY: CGFloat) -> CGFloat {
        let row = CGFloat(lane / 2)
        return lane % 2 == 0
            ? lineY + t.runwayDot / 2 + t.sp4 + row * (labelHeight + rowGap)
            : lineY - t.runwayDot / 2 - t.sp4 - labelHeight - row * (labelHeight + rowGap)
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

/// One programme card (info): days left, checklist progress and status.
struct UniCardView: View {
    @Environment(Store.self) private var store
    @Environment(\.theme) private var t
    let path: String

    var body: some View {
        if let card = store.d.uniCards.first(where: { $0.id == path }) {
            let selected = store.selection == .uni(path)
            StatCard(title: card.school, accent: selected ? .focus : .info, shape: .chevron) {
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
        Chip(text: card.status, accent: card.isSubmitted ? .good : .info)
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
    @State private var status: PersonStatus?
    @State private var expanded = false

    var body: some View {
        let d = store.d
        VStack(alignment: .leading, spacing: t.sp8) {
            if let people = d.data.people {
                let rows = status.map(d.people) ?? d.sortedPeople
                let shown = expanded ? rows.count : min(rows.count, t.listRows - 2)
                SectionHeader(title: "Contacts") {
                    CountedTabs(items: [.init(id: PersonStatus?.none, title: "All", count: people.count)]
                        + PersonStatus.allCases.map { .init(id: PersonStatus?.some($0), title: $0.label, count: d.people(status: $0).count) },
                        selection: $status)
                }
                .padding(.bottom, t.sp2)
                if rows.isEmpty { EmptyState(line: "Nobody with this status.", hint: d.data.hint(VaultData.contactsBoardFile)) }
                ForEach(rows.prefix(shown)) { person in
                    ListRow(leading: .initials(initials(of: person.name), .info), title: person.name,
                            subtitle: [person.role, person.programme].compactMap { $0 }.joined(separator: " · "),
                            selected: store.selection == .person(person.id), action: { store.open(.person(person.id)) }) { selected in
                        if let next = person.next {
                            Text(verbatim: next).style(\.small, selected ? \.onAccent : \.inkMuted).lineLimit(1)
                                .frame(maxWidth: t.railWidth, alignment: .trailing)
                        }
                        PersonStatusMenu(person: person, onAccent: selected)
                    }
                }
                if rows.count > shown {
                    MoreLine(phrases: [.init(text: "+ "), .init(text: String(rows.count - shown), strong: true), .init(text: " more")]) { expanded = true }
                }
            } else {
                SectionHeader(title: "Contacts")
                EmptyState(line: "The contacts board has not moved into the vault yet.", hint: "It appears here once \(VaultData.contactsBoardFile) exists.")
                LinkButton(title: "Open board", url: Links.web(d.data.settings.links.contactsBoard), primary: true)
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }
}

/// A contact's status chip; clicking it sets the status, in the board's own words.
struct PersonStatusMenu: View {
    @Environment(Store.self) private var store
    let person: Person
    var onAccent = false

    var body: some View {
        StatusMenu(label: person.statusLabel ?? person.status.label, accent: person.status.accent, words: PersonStatus.allCases.map(\.boardWord),
                   editable: person.sourceID != nil, onAccent: onAccent) { store.setPersonStatus(person, to: $0) }
    }
}

struct PersonInspector: View {
    @Environment(Store.self) private var store
    let person: Person

    var body: some View {
        let d = store.d
        InspectorTitle(text: person.name)
        PersonStatusMenu(person: person)
        if let role = person.role { InspectorField(label: "Role", value: role) }
        if let programme = person.programme { InspectorField(label: "Programme", value: programme) }
        let place = [person.lab, person.university].compactMap { $0 }.joined(separator: " · ")
        if !place.isEmpty { InspectorField(label: "Where", value: place) }
        if let why = person.why { InspectorField(label: "Why", value: why) }
        if let paper = person.paper { InspectorField(label: "Paper", value: paper) }
        if let route = person.contactRoute { InspectorField(label: "How to reach", value: route) }
        if let notes = person.notes { InspectorField(label: "Notes", value: notes) }
        if let url = Links.web(person.url) { LinkButton(title: "Open profile", url: url) }
        if let last = person.lastContact?.date {
            InspectorField(label: "Last contact", value: "\(d.cal.weekdayDay(last)) · \(Derived.plural(d.cal.days(from: last, to: d.today), "day")) ago")
        }
        if person.notes == nil, let next = person.next { InspectorField(label: "Next step", value: next) }
        LinkButton(title: "Open in Claude", url: Links.safeID(person.id).flatMap { Links.claude(seed: "Help me plan my next message to contact \($0) in \(VaultData.contactsBoardFile) in my vault.") }, primary: true)
    }
}
