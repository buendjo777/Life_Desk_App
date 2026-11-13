import Foundation

/// Values behind the Today tab's cards, calendar, timeline and search.
extension Derived {
    /// Deadlines with one entry per name and day: two uni files sharing one application window
    /// (ETH's BME and ITET) show once on the Deadlines card and in the summary.
    var distinctDeadlines: [Deadline] {
        var seen = Set<String>()
        return deadlines.filter { seen.insert("\($0.short)|\(cal.isoDay($0.date))").inserted }
    }

    // MARK: Deadline runway

    static let runwayDays = 90

    struct RunwayPoint: Identifiable {
        let id: String
        /// 0…1 along the runway.
        let fraction: Double
        /// The three nearest deadlines are drawn solid.
        let near: Bool
    }

    var runway: [RunwayPoint] {
        deadlines.filter { $0.daysLeft <= Self.runwayDays }.enumerated().map { index, deadline in
            RunwayPoint(id: deadline.id, fraction: Double(deadline.daysLeft) / Double(Self.runwayDays), near: index < 3)
        }
    }

    // MARK: Day strip, 07:00–22:00

    static let stripStart = 7.0
    static let stripEnd = 22.0
    static let stripTicks = [7, 10, 13, 16, 19, 22]

    struct StripBlock: Identifiable {
        let id: String
        /// 0…1 along the strip.
        let start: Double
        let end: Double
        let past: Bool
    }

    static func stripFraction(_ hours: Double) -> Double {
        min(1, max(0, (hours - stripStart) / (stripEnd - stripStart)))
    }

    var stripBlocks: [StripBlock] {
        events(on: today).filter { !$0.allDay }.compactMap { event in
            let start = Self.stripFraction(cal.hours(event.start))
            let end = Self.stripFraction(cal.hours(event.end))
            guard end > start else { return nil }
            return StripBlock(id: event.id, start: start, end: end, past: event.end <= now)
        }
    }

    /// Where "now" sits on the strip; `nil` outside 07:00–22:00.
    var nowFraction: Double? {
        let hours = cal.hours(now)
        return (Self.stripStart...Self.stripEnd).contains(hours) ? Self.stripFraction(hours) : nil
    }

    // MARK: Inbox

    var lastRun: Run? { data.runs.last }

    /// "23 scanned · 06:34": as of the last run, not live.
    var scannedText: String? {
        guard let run = data.runs.last(where: \.isOK), let scanned = run.messagesScanned else { return nil }
        return "\(scanned) scanned · \(runStatus.lastRunText ?? "")"
    }

    // MARK: Health (this week)

    func activities(inWeekOf date: Date) -> [Activity] {
        let start = cal.weekStart(date)
        let end = cal.add(days: 7, to: start)
        return data.activities.filter { $0.date.date >= start && $0.date.date < end }
    }

    var weekActivities: [Activity] { activities(inWeekOf: now) }
    var lastActivity: Activity? { data.activities.max { $0.date.date < $1.date.date } }

    /// 9430 s → (2, 37).
    static func hoursMinutes(_ seconds: Int) -> (hours: Int, minutes: Int) {
        let minutes = Int((Double(seconds) / 60).rounded())
        return (minutes / 60, minutes % 60)
    }

    /// Health has something to show: an activity export. Without one its tab and card are hidden.
    var hasHealthData: Bool { !data.activities.isEmpty }

    /// Whether a section is shown, by its id: Health's card waits for its data.
    func shows(_ sectionID: String) -> Bool {
        sectionID != "today.health" || hasHealthData
    }

    static func durationText(_ seconds: Int) -> String {
        let (hours, minutes) = hoursMinutes(seconds)
        return hours > 0 ? "\(hours) h \(String(format: "%02d", minutes))" : "\(minutes) min"
    }

    static func kilometres(_ metres: Double) -> String {
        String(format: "%.1f", metres / 1000)
    }

    // MARK: Month calendar

    struct DayCell: Identifiable {
        let date: Date
        let day: Int
        let inMonth: Bool
        let isToday: Bool
        let isWeekend: Bool
        /// Ochre: a deadline. Rust: a proposed event. Steel: a calendar event.
        let dot: Accent?
        var id: Date { date }
    }

    struct WeekRow: Identifiable {
        let number: Int
        let isCurrent: Bool
        let days: [DayCell]
        var id: Date { days[0].date }
    }

    /// Six Monday-first weeks covering `month`, with ISO week numbers.
    func monthGrid(for month: Date) -> [WeekRow] {
        let monthStart = cal.monthStart(month)
        let first = cal.weekStart(monthStart)
        let deadlineDays = Set(deadlines.map { cal.startOfDay($0.date) })
        let proposalDays = Set(toConfirm.compactMap { $0.event.map { cal.startOfDay($0.start.date) } })
        let eventDays = Set(data.events.filter { !isTutoring($0) }.map { cal.startOfDay($0.start) })
        return (0..<6).map { week in
            let days = (0..<7).map { offset -> DayCell in
                let date = cal.add(days: week * 7 + offset, to: first)
                let isToday = cal.isSameDay(date, today)
                let dot: Accent? = isToday ? nil : deadlineDays.contains(date) ? .ochre : proposalDays.contains(date) ? .rust : eventDays.contains(date) ? .steel : nil
                return DayCell(date: date, day: cal.day(date), inMonth: cal.isSameDay(cal.monthStart(date), monthStart),
                               isToday: isToday, isWeekend: offset >= 5, dot: dot)
            }
            return WeekRow(number: cal.weekNumber(days[0].date), isCurrent: cal.isSameDay(cal.weekStart(today), days[0].date), days: days)
        }
    }

    // MARK: Timeline

    /// The icon and accent for a calendar event, from its calendar and title.
    func eventStyle(_ event: CalEvent) -> (symbol: String, accent: Accent) {
        let words = Set(event.title.lowercased().split(whereSeparator: { !$0.isLetter }).map(String.init))
        func has(_ candidates: String...) -> Bool { !words.isDisjoint(with: candidates) }
        if isTutoring(event) { return ("person", .ochre) }
        if has("exam") { return ("triangle", .ochre) }
        if has("flight", "train") { return ("airplane", .steel) }
        if has("call", "interview") { return ("phone", .steel) }
        if has("meeting", "session") { return ("person.2", .steel) }
        if has("run", "gym", "ride", "swim", "strength", "walk") { return ("waveform.path.ecg", .moss) }
        return ("scope", .rust)
    }

    func timeRange(_ start: Date, _ end: Date) -> String {
        "\(cal.time(start))–\(cal.time(end))"
    }

    /// "Retiro park · 07:00–07:45".
    func eventSubtitle(_ event: CalEvent) -> String {
        let range = event.allDay ? "All day" : timeRange(event.start, event.end)
        return [event.location, range].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
    }

    /// The calendars that appear on `day`, for the timeline filter.
    func calendars(on day: Date) -> [String] {
        Array(Set(events(on: day).map(\.calendar))).sorted()
    }

    // MARK: Search

    enum SearchScope: String, CaseIterable, Identifiable {
        case all = "All", tasks = "Tasks", emails = "Emails", projects = "Projects", people = "People"
        var id: String { rawValue }
    }

    struct SearchHit: Identifiable {
        let id: String
        let title: String
        let subtitle: String
        let scope: SearchScope
        let tab: Tab
        let item: DeskItem
    }

    func search(_ query: String, scope: SearchScope) -> [SearchHit] {
        let needle = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !needle.isEmpty else { return [] }
        func matches(_ fields: String?...) -> Bool {
            fields.contains { $0?.lowercased().contains(needle) == true }
        }
        var hits: [SearchHit] = []
        if scope == .all || scope == .tasks {
            hits += data.tasks.filter { matches($0.title, $0.section) }.map {
                SearchHit(id: "task-\($0.line)", title: $0.title, subtitle: $0.section, scope: .tasks, tab: .today, item: .task($0.line))
            }
        }
        if scope == .all || scope == .emails {
            hits += emails.filter { matches($0.title, $0.subject, $0.detail) }.map {
                SearchHit(id: $0.id, title: $0.title, subtitle: $0.subject ?? "", scope: .emails, tab: .today, item: .row($0.id))
            }
        }
        if scope == .all || scope == .projects {
            hits += data.projects.filter { matches($0.title, $0.next) }.map {
                SearchHit(id: $0.path, title: $0.title, subtitle: $0.next, scope: .projects, tab: .projects, item: .project($0.path))
            }
        }
        if scope == .all || scope == .people {
            hits += (data.people ?? []).filter { matches($0.name, $0.programme, $0.role) }.map {
                SearchHit(id: "person-\($0.id)", title: $0.name, subtitle: $0.programme ?? "", scope: .people, tab: .uni, item: .person($0.id))
            }
        }
        return hits
    }
}
