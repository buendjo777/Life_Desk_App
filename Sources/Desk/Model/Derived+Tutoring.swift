import Foundation

/// Values behind the Tutoring tab. Everything here uses initials; names and phone numbers
/// are read only when a WhatsApp message is built for Jose to send himself.
extension Derived {
    var currentMonth: String { cal.monthKey(now) }

    /// "405 €", "13.5 h".
    func money(_ amount: Double) -> String {
        "\(Parse.number((amount * 100).rounded() / 100)) \(data.settings.currency == "EUR" ? "€" : data.settings.currency)"
    }

    static func hoursText(_ hours: Double) -> String { "\(Parse.number(hours)) h" }

    /// "2026-10" → "October 2026", or "octubre" in the tutoring locale for messages.
    func monthName(_ key: String, pattern: String = "LLLL yyyy", locale: String = "en_GB") -> String {
        guard let date = Parse.day(key + "-01", cal) else { return key }
        return cal.format(date, pattern, locale: locale)
    }

    var tutoringEvents: [CalEvent] { data.events.filter(isTutoring).sorted { $0.start < $1.start } }

    struct StudentMonth: Identifiable {
        let student: Student
        /// Lessons that have already happened.
        let lessons: Int
        let hours: Double
        let amount: Double
        /// Everything in the calendar for the month, including lessons still to come.
        let plannedHours: Double
        var id: String { student.id }
    }

    /// Hours and amount per student for a month, from the tutoring calendar (event titles are initials).
    func tutoringMonth(_ key: String) -> [StudentMonth] {
        let events = tutoringEvents.filter { cal.monthKey($0.start) == key }
        return data.tutoring.students.map { student in
            let mine = events.filter { $0.title.trimmingCharacters(in: .whitespaces) == student.initials }
            let done = mine.filter { $0.end <= now }
            func hours(_ list: [CalEvent]) -> Double { list.map { $0.end.timeIntervalSince($0.start) / 3600 }.reduce(0, +) }
            return StudentMonth(student: student, lessons: done.count, hours: hours(done),
                                amount: hours(done) * student.rate, plannedHours: hours(mine))
        }
    }

    var thisMonth: [StudentMonth] { tutoringMonth(currentMonth) }

    /// Paid this month.
    var receivedThisMonth: Double {
        data.tutoring.payments.filter { $0.paid.map { cal.monthKey($0) == currentMonth } == true }.map(\.amount).reduce(0, +)
    }

    /// Sent and not yet paid, oldest first.
    var waitingForPayment: [Payment] {
        data.tutoring.payments.filter { $0.status == .sent }.sorted { ($0.sent ?? now) < ($1.sent ?? now) }
    }

    var pendingAmount: Double { waitingForPayment.map(\.amount).reduce(0, +) }

    /// Finished months not yet sent: a row without a sent date, or calendar lessons with no row at all.
    var monthEnd: [Payment] {
        var result = data.tutoring.payments.filter { $0.status == .notSent && $0.month < currentMonth }
        let months = Set(tutoringEvents.map { cal.monthKey($0.start) }).filter { $0 < currentMonth }
        for month in months.sorted() {
            for entry in tutoringMonth(month) where entry.lessons > 0 {
                let id = "\(month)-\(entry.student.initials)"
                if !data.tutoring.payments.contains(where: { $0.id == id }) {
                    result.append(Payment(month: month, initials: entry.student.initials, lessons: entry.lessons,
                                          hours: entry.hours, amount: entry.amount, sent: nil, paid: nil))
                }
            }
        }
        return result.sorted { ($0.month, $0.initials) < ($1.month, $1.initials) }
    }

    /// Newest month first.
    var paymentsTable: [Payment] {
        data.tutoring.payments.sorted { ($0.month, $1.initials) > ($1.month, $0.initials) }
    }

    func student(_ initials: String) -> Student? { data.tutoring.students.first { $0.initials == initials } }

    /// The monthly message or the reminder, with its placeholders filled in. `nil` without a contact.
    func tutoringMessage(for payment: Payment, reminder: Bool) -> String? {
        guard let contact = data.tutoring.contacts[payment.initials] else { return nil }
        let template = reminder ? data.tutoring.reminderTemplate : data.tutoring.template
        guard !template.isEmpty else { return nil }
        let values = [
            "{parent}": contact.parent, "{student}": contact.student,
            "{month}": monthName(payment.month, pattern: "LLLL", locale: data.settings.tutoringLocale),
            "{lessons}": String(payment.lessons), "{hours}": Parse.number(payment.hours),
            "{amount}": Parse.number(payment.amount), "{method}": student(payment.initials)?.paysBy ?? "",
        ]
        return values.reduce(template) { $0.replacingOccurrences(of: $1.key, with: $1.value) }
    }

    /// The wa.me link for that message. Nothing is sent until Jose presses send in WhatsApp.
    func whatsAppLink(for payment: Payment, reminder: Bool) -> URL? {
        guard let contact = data.tutoring.contacts[payment.initials],
              let text = tutoringMessage(for: payment, reminder: reminder) else { return nil }
        return Links.whatsApp(phone: contact.phone, text: text)
    }

    /// This week's lessons, Monday to Sunday.
    var weekLessons: [CalEvent] {
        let start = cal.weekStart(now)
        let end = cal.add(days: 7, to: start)
        return tutoringEvents.filter { $0.start >= start && $0.start < end }
    }

    func lastNote(_ initials: String) -> LessonNote? { data.tutoring.notes[initials]?.last }

    var tutoringSummary: [Phrase] {
        let month = thisMonth
        let hours = month.map(\.hours).reduce(0, +)
        let amount = month.map(\.amount).reduce(0, +)
        var phrases = [
            Phrase(text: "\(Self.hoursText(hours)) taught in \(monthName(currentMonth, pattern: "LLLL"))", strong: true),
            Phrase(text: ", worth \(money(amount)). "),
        ]
        let waiting = waitingForPayment
        phrases.append(waiting.isEmpty ? Phrase(text: "Nobody owes anything.")
                       : Phrase(text: "\(Self.plural(waiting.count, "payment")) pending: \(money(pendingAmount)).", strong: true))
        if !monthEnd.isEmpty { phrases.append(Phrase(text: " \(Self.plural(monthEnd.count, "month-end message")) to send.")) }
        return phrases
    }
}
