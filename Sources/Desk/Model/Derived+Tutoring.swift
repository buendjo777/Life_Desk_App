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

    /// True once Desk has read the Classes note into `tutoring/lessons.csv`: the note is then the record.
    var lessonsFromNote: Bool { !data.tutoring.lessons.isEmpty }

    /// Hours and amount per student for a month. From the Classes note when Desk has read it, with the
    /// tutoring calendar adding only lessons still to come; otherwise from the calendar (event titles are initials).
    func tutoringMonth(_ key: String) -> [StudentMonth] {
        let events = tutoringEvents.filter { cal.monthKey($0.start) == key }
        let rows = data.tutoring.lessons.filter { $0.month == key }
        return data.tutoring.students.map { student in
            let mine = events.filter { $0.title.trimmingCharacters(in: .whitespaces) == student.initials }
            let done = mine.filter { $0.end <= now }
            func hours(_ list: [CalEvent]) -> Double { list.map { $0.end.timeIntervalSince($0.start) / 3600 }.reduce(0, +) }
            guard lessonsFromNote else {
                return StudentMonth(student: student, lessons: done.count, hours: hours(done),
                                    amount: hours(done) * student.rate, plannedHours: hours(mine))
            }
            let row = rows.first { $0.initials == student.initials }
            let taught = row?.hours ?? 0
            return StudentMonth(student: student, lessons: row?.lessons ?? 0, hours: taught,
                                amount: row?.amount ?? taught * (row?.rate ?? student.rate),
                                plannedHours: taught + hours(mine.filter { $0.end > now }))
        }
    }

    var thisMonth: [StudentMonth] { tutoringMonth(currentMonth) }

    /// Every invoice: this term's (`payments.csv`) and the archive's, this term's copy first.
    var allPayments: [Payment] {
        let term = Set(data.tutoring.payments.map(\.id))
        return data.tutoring.payments + data.tutoring.archive.filter { !term.contains($0.id) }
    }

    /// A student's name as the Classes note writes it ("Lucas Moreno"), else the contact's first name, else the initials.
    func studentName(_ initials: String) -> String {
        var best = ""
        for row in data.tutoring.lessons where row.initials == initials && row.student.count > best.count { best = row.student }
        if !best.isEmpty { return best }
        if let name = data.tutoring.contacts[initials]?.student, !name.isEmpty { return name }
        return initials
    }

    /// Paid this month.
    var receivedThisMonth: Double {
        allPayments.filter { $0.paid.map { cal.monthKey($0) == currentMonth } == true }.map(\.amount).reduce(0, +)
    }

    /// Earned so far this month, from the Classes note (or the calendar).
    var earnedThisMonth: Double { thisMonth.map(\.amount).reduce(0, +) }

    /// Paid invoices for this year's months, counted by the invoice's month rather than the day it was paid:
    /// imported months count as paid on their last day.
    var receivedThisYear: Double {
        allPayments.filter { $0.paid != nil && $0.month.hasPrefix(currentYear) }.map(\.amount).reduce(0, +)
    }

    /// What finished months still owe: invoices sent and not paid, and months not yet sent.
    var owedAmount: Double { pendingAmount + monthEnd.map(\.amount).reduce(0, +) }

    /// Still to come this year: what is owed plus this month so far.
    var toComeThisYear: Double { owedAmount + earnedThisMonth }

    /// Sent and not yet paid, oldest first.
    var waitingForPayment: [Payment] {
        allPayments.filter { $0.status == .sent }.sorted { ($0.sent ?? now) < ($1.sent ?? now) }
    }

    var pendingAmount: Double { waitingForPayment.map(\.amount).reduce(0, +) }

    /// Finished months not yet sent: a row without a sent date, or, without the Classes note, calendar lessons
    /// with no row at all. (Desk writes a row for every finished month in the note.)
    var monthEnd: [Payment] {
        let known = Set(allPayments.map(\.id))
        var result = allPayments.filter { $0.status == .notSent && $0.month < currentMonth }
        let months = lessonsFromNote ? [] : Set(tutoringEvents.map { cal.monthKey($0.start) }).filter { $0 < currentMonth }
        for month in months.sorted() {
            for entry in tutoringMonth(month) where entry.lessons > 0 {
                let id = "\(month)-\(entry.student.initials)"
                if !known.contains(id) {
                    result.append(Payment(month: month, initials: entry.student.initials, lessons: entry.lessons,
                                          hours: entry.hours, amount: entry.amount, sent: nil, paid: nil))
                }
            }
        }
        // With the note: the month that just ended, until Desk's next import writes its rows.
        if lessonsFromNote, let first = Parse.day(currentMonth + "-01", cal) {
            let previous = cal.monthKey(cal.add(months: -1, to: first))
            for row in data.tutoring.lessons where row.month == previous {
                guard let student = student(row.initials), !known.contains("\(row.month)-\(row.initials)") else { continue }
                result.append(Payment(month: row.month, initials: row.initials, lessons: row.lessons, hours: row.hours,
                                      amount: row.amount ?? row.hours * student.rate, sent: nil, paid: nil))
            }
        }
        return result.sorted { ($0.month, $0.initials) < ($1.month, $1.initials) }
    }

    /// Newest month first, the archive included.
    var paymentsTable: [Payment] {
        allPayments.sorted { ($0.month, $1.initials) > ($1.month, $0.initials) }
    }

    /// A student's lessons and earnings across every month in the note: "Since Sep 2025 · 34 lessons · 1700 €".
    func studentHistory(_ initials: String) -> String? {
        let rows = data.tutoring.lessons.filter { $0.initials == initials }
        guard let first = rows.map(\.month).min() else { return nil }
        return "Since \(monthName(first, pattern: "MMM yyyy")) · \(Self.plural(rows.map(\.lessons).reduce(0, +), "lesson")) · \(money(rows.compactMap(\.amount).reduce(0, +)))"
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

    /// A lesson in the week rail: logged in the Classes note, or on the tutoring calendar.
    struct WeekLesson: Identifiable {
        let id: String
        let start: Date
        let initials: String
        /// "17:00–18:00" for a calendar lesson, "1.5 h" for one from the note.
        let detail: String
        let past: Bool
    }

    /// This week's lessons, Monday to Sunday. With dated lessons from the Classes note, those are the record and
    /// the calendar adds only lessons still to come; otherwise the calendar alone.
    var weekLessons: [WeekLesson] {
        let start = cal.weekStart(now)
        let end = cal.add(days: 7, to: start)
        let dated = data.tutoring.lessonDates.filter { $0.date >= start && $0.date < end }
        let logged = dated.enumerated().map { index, lesson in
            WeekLesson(id: "note-\(index)", start: lesson.date, initials: lesson.initials,
                       detail: Self.hoursText(lesson.hours), past: true)
        }
        let events = tutoringEvents.filter { $0.start >= start && $0.start < end && (data.tutoring.lessonDates.isEmpty || $0.end > now) }
        let planned = events.map { event in
            WeekLesson(id: event.id, start: event.start, initials: event.title.trimmingCharacters(in: .whitespaces),
                       detail: timeRange(event.start, event.end), past: event.end <= now)
        }
        return (logged + planned).sorted { $0.start < $1.start }
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
