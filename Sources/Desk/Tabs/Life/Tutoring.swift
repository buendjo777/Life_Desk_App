import SwiftUI

/// This year's money as a donut: received against still to come (owed, plus this month so far).
struct MoneyDonut: View {
    @Environment(Store.self) private var store
    @Environment(\.theme) private var t

    var body: some View {
        let d = store.d
        let received = d.receivedThisYear
        let pending = d.toComeThisYear
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
                    legend(.moss, "Received in \(d.currentYear)", d.money(received))
                    legend(.ochre, "Still to come", d.money(pending))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(verbatim: "Received in \(d.currentYear) \(d.money(received)), still to come \(d.money(pending))"))
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

/// The three money cards: this month so far, owed, hours.
struct MoneyCard: View {
    enum Kind: String { case month, owed, hours }
    @Environment(Store.self) private var store
    let kind: Kind

    var body: some View {
        let d = store.d
        let month = d.thisMonth
        switch kind {
        case .month:
            StatCard(title: "This month", accent: .moss, shape: .ring) {
                Figure(d.money(d.earnedThisMonth), caption: Derived.plural(month.map(\.lessons).reduce(0, +), "lesson") + " so far")
            }
        case .owed:
            let invoices = d.waitingForPayment.count + d.monthEnd.count
            StatCard(title: "Owed", accent: .ochre, shape: .ring) {
                Figure(d.money(d.owedAmount), caption: invoices == 0 ? "Nothing owed" : Derived.plural(invoices, "invoice"))
            }
        case .hours:
            let taught = month.map(\.hours).reduce(0, +)
            let planned = month.map(\.plannedHours).reduce(0, +)
            StatCard(title: "Hours", accent: .steel, shape: .ring) {
                Figure(Parse.number(taught), unit: "h", caption: planned > taught ? "of \(Parse.number(planned)) planned" : "taught this month")
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
            SectionHeader(title: "This month", subtitle: d.lessonsFromNote ? "From the Classes note · hours × rate"
                          : "From the \(d.data.settings.tutoringCalendar) calendar · hours × rate")
            if d.data.tutoring.students.isEmpty {
                EmptyState(line: "No students yet.", hint: d.data.hint(VaultData.studentsFile))
            }
            ForEach(d.thisMonth) { entry in
                let student = entry.student
                ListRow(leading: .initials(student.initials, .ochre),
                        title: ([d.studentName(student.initials), student.subject].filter { !$0.isEmpty }).joined(separator: " · "),
                        subtitle: ([student.level, "\(d.money(student.rate))/h", student.paysBy.isEmpty ? "" : "pays by \(student.paysBy)"]
                            .filter { !$0.isEmpty }).joined(separator: " · "),
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
                    Text(verbatim: "\(d.studentName(payment.initials)) · \(d.monthName(payment.month))").style(\.rowTitle, \.ink)
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
    @State private var extra = 0

    var body: some View {
        let d = store.d
        let rows = d.paymentsTable
        let shown = min(rows.count, t.listRows - 1 + extra)
        VStack(alignment: .leading, spacing: t.sp8) {
            SectionHeader(title: "Payments", subtitle: "Every month in the Classes note · local only, never committed")
            if rows.isEmpty { EmptyState(line: "No payments recorded yet.", hint: "Mark a month as sent to start the table.") }
            ForEach(rows.prefix(shown)) { payment in
                ListRow(leading: .initials(payment.initials, .ochre), title: "\(d.studentName(payment.initials)) · \(d.monthName(payment.month))",
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
                MoreLine(phrases: [.init(text: "+ "), .init(text: String(rows.count - shown), strong: true),
                                   .init(text: rows.count - shown > 30 ? " earlier payments · show 30" : " earlier payments")]) { extra += 30 }
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
                EmptyState(line: "No lessons this week.",
                           hint: d.data.tutoring.lessonDates.isEmpty ? "Lessons come from the \(d.data.settings.tutoringCalendar) calendar." : "Lessons come from the Classes note.")
            }
            ForEach(lessons) { lesson in
                let initials = lesson.initials
                HStack(alignment: .top, spacing: t.sp8) {
                    Text(verbatim: d.cal.format(lesson.start, "EEE")).style(\.micro, \.inkMuted)
                        .frame(width: t.timeColumn, alignment: .leading).padding(.top, t.sp8)
                    HStack(spacing: t.sp10) {
                        Badge(content: .initials(initials), accent: .ochre, small: true)
                        VStack(alignment: .leading, spacing: t.hairline) {
                            Text(verbatim: d.studentName(initials)).style(\.rowTitle, \.ink).lineLimit(1)
                            Text(verbatim: lesson.detail).style(\.small, \.inkMuted)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.leading, t.sp8).padding(.trailing, t.sp12)
                    .frame(height: t.eventCard)
                    .background(t.raised, in: RoundedRectangle(cornerRadius: t.radiusEvent))
                }
                .opacity(lesson.past ? t.pastOpacity : 1)
                .contentShape(Rectangle())
                .onTapGesture { store.open(.student(initials)) }
                .accessibilityAction { store.open(.student(initials)) }
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
        let contact = d.data.tutoring.contacts[student.initials]
        InspectorTitle(text: ([d.studentName(student.initials), student.subject].filter { !$0.isEmpty }).joined(separator: " · "))
        InspectorField(label: "Rate", value: "\(d.money(student.rate))/h")
        if let history = d.studentHistory(student.initials) { InspectorField(label: "History", value: history) }
        // Details for the invoices; they stay in tutoring/ on this Mac.
        EditableField(label: "Parent", value: contact?.parent ?? "", prompt: "Who gets the WhatsApp") { store.updateContact(student.initials, parent: $0) }
        EditableField(label: "Phone", value: contact?.phone ?? "", prompt: "+34 600 000 000") { store.updateContact(student.initials, phone: $0) }
        EditableField(label: "Subject", value: student.subject, prompt: "Maths AA HL") { store.updateStudent(student.initials, subject: $0) }
        EditableField(label: "Level", value: student.level, prompt: "IB Diploma") { store.updateStudent(student.initials, level: $0) }
        EditableField(label: "Pays by", value: student.paysBy, prompt: "bank transfer") { store.updateStudent(student.initials, paysBy: $0) }
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
