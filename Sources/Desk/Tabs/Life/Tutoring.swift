import SwiftUI

/// Received vs pending as a donut.
struct MoneyDonut: View {
    @Environment(Store.self) private var store
    @Environment(\.theme) private var t

    var body: some View {
        let d = store.d
        let received = d.receivedThisMonth
        let pending = d.pendingAmount
        let total = received + pending
        SurfaceCard {
            HStack(spacing: t.sp20) {
                ZStack {
                    Circle().stroke(t.line, lineWidth: t.donutLine)
                    if total > 0 {
                        Circle().trim(from: 0, to: received / total)
                            .stroke(t.moss, style: StrokeStyle(lineWidth: t.donutLine))
                            .rotationEffect(.degrees(-90))
                        Circle().trim(from: received / total, to: 1)
                            .stroke(t.ochre, style: StrokeStyle(lineWidth: t.donutLine))
                            .rotationEffect(.degrees(-90))
                    }
                    VStack(spacing: 0) {
                        Text(verbatim: total > 0 ? "\(Int((received / total * 100).rounded()))%" : "—").style(\.figure, \.ink)
                        Text(verbatim: "received").style(\.caption, \.inkMuted)
                    }
                }
                .frame(width: t.donut - t.donutLine, height: t.donut - t.donutLine)
                .padding(t.donutLine / 2)
                VStack(alignment: .leading, spacing: t.sp8) {
                    legend(.moss, "Received", d.money(received))
                    legend(.ochre, "Pending", d.money(pending))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Received \(d.money(received)), pending \(d.money(pending))")
    }

    private func legend(_ accent: Accent, _ label: String, _ value: String) -> some View {
        HStack(spacing: t.sp6) {
            Circle().fill(t.fill(accent)).frame(width: t.sp8, height: t.sp8)
            VStack(alignment: .leading, spacing: 0) {
                Text(verbatim: value).style(\.bodyStrong, \.ink)
                Text(verbatim: label).style(\.caption, \.inkMuted)
            }
        }
    }
}

/// The three money cards: received, pending, hours.
struct MoneyCard: View {
    enum Kind: String { case received, pending, hours }
    @Environment(Store.self) private var store
    let kind: Kind

    var body: some View {
        let d = store.d
        let month = d.thisMonth
        switch kind {
        case .received:
            StatCard(title: "Received", accent: .moss, shape: .ring) {
                Figure(d.money(d.receivedThisMonth), caption: "Paid in \(d.monthName(d.currentMonth, pattern: "LLLL"))")
            }
        case .pending:
            StatCard(title: "Pending", accent: .ochre, shape: .ring) {
                Figure(d.money(d.pendingAmount), caption: Derived.plural(d.waitingForPayment.count, "invoice") + " sent")
            }
        case .hours:
            StatCard(title: "Hours", accent: .steel, shape: .ring) {
                Figure(Parse.number(month.map(\.hours).reduce(0, +)), unit: "h",
                       caption: "of \(Parse.number(month.map(\.plannedHours).reduce(0, +))) planned")
            }
        }
    }
}

/// This month per student: hours and amount from the tutoring calendar.
struct TutoringMonthList: View {
    @Environment(Store.self) private var store
    @Environment(\.theme) private var t

    var body: some View {
        let d = store.d
        VStack(alignment: .leading, spacing: t.sp8) {
            SectionHeader(title: "This month", subtitle: "From the \(d.data.settings.tutoringCalendar) calendar · hours × rate")
            if d.data.tutoring.students.isEmpty {
                EmptyState(line: "No students yet.", hint: d.data.hint(VaultData.studentsFile))
            }
            ForEach(d.thisMonth) { entry in
                ListRow(leading: .initials(entry.student.initials, .ochre), title: "\(entry.student.initials) · \(entry.student.subject)",
                        subtitle: "\(entry.student.level) · \(d.money(entry.student.rate))/h · pays by \(entry.student.paysBy)",
                        selected: store.selection == .student(entry.student.initials), action: { store.open(.student(entry.student.initials)) }) { selected in
                    Text(verbatim: "\(Derived.plural(entry.lessons, "lesson")) · \(Derived.hoursText(entry.hours)) of \(Parse.number(entry.plannedHours))")
                        .style(\.small, selected ? \.onAccent : \.inkMuted)
                    Chip(text: d.money(entry.amount), accent: .moss, onAccent: selected)
                }
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }
}

/// A card for one invoice with its actions.
private struct InvoiceCard<Actions: View>: View {
    @Environment(Store.self) private var store
    @Environment(\.theme) private var t
    let payment: Payment
    let detail: String
    @ViewBuilder var actions: Actions

    var body: some View {
        let d = store.d
        VStack(alignment: .leading, spacing: t.sp8) {
            HStack(spacing: t.sp10) {
                Badge(content: .initials(payment.initials), accent: .ochre)
                VStack(alignment: .leading, spacing: t.sp2) {
                    Text(verbatim: "\(payment.initials) · \(d.monthName(payment.month))").style(\.rowTitle, \.ink)
                    Text(verbatim: detail).style(\.small, \.inkMuted).lineLimit(1)
                }
                Spacer(minLength: 0)
                Text(verbatim: d.money(payment.amount)).style(\.cardTitle, \.ink)
            }
            HStack(spacing: t.sp8) { actions }
        }
        .padding(t.sp12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .raisedPanel(radius: t.radiusRow)
    }
}

/// Waiting for payment: sent, unpaid rows, each with Send reminder.
struct WaitingPayments: View {
    @Environment(Store.self) private var store
    @Environment(\.theme) private var t

    var body: some View {
        let d = store.d
        VStack(alignment: .leading, spacing: t.sp8) {
            SectionHeader(title: "Waiting for payment")
            if d.waitingForPayment.isEmpty { EmptyState(line: "Nobody owes anything.") }
            ForEach(d.waitingForPayment) { payment in
                let days = payment.sent.map { d.cal.days(from: $0, to: d.today) } ?? 0
                InvoiceCard(payment: payment, detail: "Sent \(payment.sent.map(d.cal.shortDay) ?? "—") · \(Derived.plural(days, "day")) ago") {
                    if let link = d.whatsAppLink(for: payment, reminder: true) {
                        Button("Send reminder") { Links.open(link) }.buttonStyle(.deskPrimary)
                            .help("Opens WhatsApp with the reminder. Nothing is sent until you press send.")
                    } else {
                        Text(verbatim: "No contact in tutoring/contacts.json").style(\.small, \.inkMuted)
                    }
                    Button("Mark paid") { store.markPaid(payment) }.buttonStyle(.deskSecondary)
                }
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }
}

/// Month end: a finished month not yet sent. Send on WhatsApp, then Mark sent.
struct MonthEnd: View {
    @Environment(Store.self) private var store
    @Environment(\.theme) private var t

    var body: some View {
        let d = store.d
        VStack(alignment: .leading, spacing: t.sp8) {
            SectionHeader(title: "Month end")
            if d.monthEnd.isEmpty {
                EmptyState(line: "Every finished month has been sent.",
                           hint: "\(d.monthName(d.currentMonth, pattern: "LLLL")) appears here on the 1st.")
            }
            ForEach(d.monthEnd) { payment in
                InvoiceCard(payment: payment, detail: "\(Derived.plural(payment.lessons, "lesson")) · \(Derived.hoursText(payment.hours))") {
                    if let link = d.whatsAppLink(for: payment, reminder: false) {
                        Button("Send on WhatsApp") { Links.open(link) }.buttonStyle(.deskPrimary)
                            .help("Opens WhatsApp with the monthly message. Nothing is sent until you press send.")
                    }
                    Button("Mark sent") { store.markSent(payment) }.buttonStyle(.deskSecondary)
                }
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }
}

/// The payments table with status chips and Mark paid.
struct PaymentsTable: View {
    @Environment(Store.self) private var store
    @Environment(\.theme) private var t
    @State private var expanded = false

    var body: some View {
        let d = store.d
        let rows = d.paymentsTable
        let shown = expanded ? rows.count : min(rows.count, t.listRows - 1)
        VStack(alignment: .leading, spacing: t.sp8) {
            SectionHeader(title: "Payments", subtitle: "tutoring/payments.csv · local only, never committed")
            if rows.isEmpty { EmptyState(line: "No payments recorded yet.", hint: "Mark a month as sent to start the table.") }
            ForEach(rows.prefix(shown)) { payment in
                ListRow(leading: .initials(payment.initials, .ochre), title: "\(payment.initials) · \(d.monthName(payment.month))",
                        subtitle: "\(Derived.plural(payment.lessons, "lesson")) · \(Derived.hoursText(payment.hours))"
                            + (payment.paid.map { " · paid \(d.cal.shortDay($0))" } ?? payment.sent.map { " · sent \(d.cal.shortDay($0))" } ?? ""),
                        selected: store.selection == .student(payment.initials), action: { store.open(.student(payment.initials)) }) { selected in
                    Text(verbatim: d.money(payment.amount)).style(\.bodyStrong, selected ? \.onAccent : \.ink)
                    if payment.status == .sent {
                        Button("Mark paid") { store.markPaid(payment) }.buttonStyle(.deskSecondary)
                    }
                    Chip(text: payment.status.rawValue, accent: payment.status.accent, onAccent: selected)
                }
            }
            if rows.count > shown {
                MoreLine(phrases: [.init(text: "+ "), .init(text: String(rows.count - shown), strong: true), .init(text: " earlier payments")]) { expanded = true }
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }
}

extension Payment.Status {
    var accent: Accent {
        switch self {
        case .notSent: .neutral
        case .sent: .ochre
        case .paid: .moss
        }
    }
}

/// The rail: this week's lessons.
struct WeekLessons: View {
    @Environment(Store.self) private var store
    @Environment(\.theme) private var t

    var body: some View {
        let d = store.d
        let lessons = d.weekLessons
        VStack(alignment: .leading, spacing: t.sp6 + t.hairline) {
            HStack(alignment: .firstTextBaseline, spacing: t.sp10) {
                Text(verbatim: "This week").style(\.cardTitle, \.ink)
                Text(verbatim: "W\(d.cal.weekNumber(d.now)) · \(Derived.plural(lessons.count, "lesson"))").style(\.small, \.inkMuted)
            }
            .padding(.top, t.sp8)
            if lessons.isEmpty {
                EmptyState(line: "No lessons this week.", hint: "Lessons come from the \(d.data.settings.tutoringCalendar) calendar.")
            }
            ForEach(lessons) { event in
                let initials = event.title.trimmingCharacters(in: .whitespaces)
                HStack(alignment: .top, spacing: t.sp8) {
                    Text(verbatim: d.cal.format(event.start, "EEE")).style(\.micro, \.inkMuted)
                        .frame(width: t.timeColumn, alignment: .leading).padding(.top, t.sp8)
                    HStack(spacing: t.sp10) {
                        Badge(content: .initials(initials), accent: .ochre, small: true)
                        VStack(alignment: .leading, spacing: t.hairline) {
                            Text(verbatim: "\(initials) · \(d.student(initials)?.subject ?? "Lesson")").style(\.rowTitle, \.ink).lineLimit(1)
                            Text(verbatim: d.timeRange(event.start, event.end)).style(\.small, \.inkMuted)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.leading, t.sp8).padding(.trailing, t.sp12)
                    .frame(height: t.eventCard)
                    .background(t.raised, in: RoundedRectangle(cornerRadius: t.radiusEvent))
                }
                .opacity(event.end <= d.now ? t.pastOpacity : 1)
                .contentShape(Rectangle())
                .onTapGesture { store.open(.student(initials)) }
                .accessibilityElement(children: .combine)
            }
        }
    }
}

/// A student in the inspector: initials only, the rate and the last lesson note.
struct StudentInspector: View {
    @Environment(Store.self) private var store
    @Environment(\.theme) private var t
    let student: Student

    var body: some View {
        let d = store.d
        let notes = d.data.tutoring.notes[student.initials] ?? []
        InspectorTitle(text: "\(student.initials) · \(student.subject)")
        InspectorField(label: "Level", value: student.level)
        InspectorField(label: "Rate", value: "\(d.money(student.rate))/h · pays by \(student.paysBy)")
        if let note = notes.last {
            Text(verbatim: "Last note · \(d.cal.weekdayDay(note.date))").style(\.caption, \.inkMuted)
            Text(verbatim: note.text)
                .style(\.body, \.ink).lineSpacing(t.sp2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(t.sp12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(t.surface, in: RoundedRectangle(cornerRadius: t.radiusNav))
            if notes.count > 1 {
                Text(verbatim: "\(notes.count - 1) earlier \(notes.count == 2 ? "note" : "notes") in tutoring/notes/\(student.initials).md").style(\.small, \.inkMuted)
            }
        } else {
            EmptyState(line: "No lesson notes yet.", hint: "tutoring/notes/\(student.initials).md")
        }
        LinkButton(title: "Open notes in Obsidian", url: Links.obsidian(vault: store.vaultName, file: "tutoring/notes/\(student.initials).md"), primary: true)
    }
}
