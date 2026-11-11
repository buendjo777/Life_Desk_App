import Foundation

/// What the tabs show, worked out by code from the vault and a clock. No AI, no I/O.
/// Each tab adds its own values in an extension next to its views.
struct Derived {
    let data: VaultData
    let now: Date

    var cal: DeskCalendar { data.cal }
    var today: Date { cal.startOfDay(now) }

    // MARK: Decisions

    /// The last click per row id. A row is decided unless its last click is `reopen`.
    var lastDecision: [String: Decision.Action] {
        var last: [String: Decision.Action] = [:]
        for decision in data.decisions.sorted(by: { $0.at.date < $1.at.date }) {
            last[decision.row] = Decision.Action(rawValue: decision.action)
        }
        return last
    }

    func isDecided(_ rowID: String) -> Bool {
        guard let action = lastDecision[rowID] else { return false }
        return action != .reopen
    }

    // MARK: Today's list

    /// Focus: the agent's `today` rows.
    var focus: [SnapshotRow] { data.rows(.today) }

    /// Every unticked task due today.
    var dueToday: [TaskItem] {
        data.tasks.filter { task in !task.done && task.due.map { cal.isSameDay($0, today) } == true }
    }

    /// The Due tab: due today, minus titles already in Focus.
    var dueList: [TaskItem] {
        let inFocus = Set(focus.map { Self.key($0.title) })
        return dueToday.filter { !inFocus.contains(Self.key($0.title)) }
    }

    /// Unticked tasks dated before today.
    var leftovers: [TaskItem] {
        data.tasks.filter { task in !task.done && task.due.map { $0 < today } == true }
            .sorted { ($0.due ?? .distantPast) > ($1.due ?? .distantPast) }
    }

    /// Proposals still waiting for a click.
    var toConfirm: [SnapshotRow] { data.rows(.confirm).filter { !isDecided($0.id) } }

    static func key(_ title: String) -> String {
        title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    /// The `TASKS.md` item with the same title, if any (also matches "Tick: <title>" proposals).
    func task(titled title: String) -> TaskItem? {
        let wanted = Self.key(title.hasPrefix("Tick: ") ? String(title.dropFirst("Tick: ".count)) : title)
        return data.tasks.first { Self.key($0.title) == wanted }
    }

    /// A Focus row is done when its task is ticked, or when Jose confirmed the row itself.
    func isDone(_ row: SnapshotRow) -> Bool {
        if let task = task(titled: row.title) { return task.done }
        return lastDecision[row.id] == .confirm
    }

    // MARK: Deadlines

    struct Deadline: Identifiable, Hashable {
        let id: String
        let title: String
        /// "Exam", "Alpine", "Lakeside"…
        let short: String
        let date: Date
        let daysLeft: Int
        let isExam: Bool
    }

    /// Upcoming deadlines, nearest first. Programme dates come from the master doc when a `uni/` file links them.
    var deadlines: [Deadline] {
        data.rows(.deadline).compactMap { row -> Deadline? in
            let uni = data.unis.first { $0.deadlineRow == row.id }
            guard let date = uni.flatMap({ data.masterDeadlines[$0.comparisonHeading] })?.date ?? row.when?.date else { return nil }
            let isExam = row.source?.hasPrefix("study/") == true
            let first = row.title.split(separator: " ").first.map(String.init) ?? row.title
            return Deadline(id: row.id, title: row.title, short: isExam ? "Exam" : first, date: date,
                            daysLeft: cal.days(from: today, to: date), isExam: isExam)
        }
        .filter { $0.daysLeft >= 0 }
        .sorted { $0.date < $1.date }
    }

    // MARK: Email, drafts, waiting

    enum EmailTag: String, CaseIterable {
        case needsReply = "needs_reply", deadline, fyi
        var label: String {
            switch self {
            case .needsReply: "Needs reply"
            case .deadline: "Deadline"
            case .fyi: "FYI"
            }
        }
    }

    var emails: [SnapshotRow] { data.rows(.email) }
    func emails(_ tag: EmailTag) -> [SnapshotRow] { emails.filter { $0.tag == tag.rawValue } }
    var draftRows: [SnapshotRow] { data.rows(.draft) }
    var waiting: [SnapshotRow] { data.rows(.waiting) }
    func draft(for row: SnapshotRow) -> Draft? { data.drafts.first { $0.path == row.source } }

    // MARK: Exam mode

    /// Between `mode_starts` and `mode_ends`: Studying opens first and Today hides drafts and waiting.
    var examMode: Bool {
        guard let exam = data.settings.exam,
              let start = Parse.day(exam.modeStarts, cal), let end = Parse.day(exam.modeEnds, cal) else { return false }
        return (start...end).contains(now)
    }

    // MARK: Run status (the same rule as the web Desk)

    enum RunLevel: String {
        case green, amber, red
        var word: String { rawValue.capitalized }
    }

    struct RunStatus {
        let level: RunLevel
        let lastRun: Date?
        /// "06:34", or "Tue 06:34" when the run was not today.
        let lastRunText: String?
    }

    /// The last successful run: the snapshot's `run` row, else the newest ok line in `runs.jsonl`.
    private var lastSuccess: (date: Date, manual: Bool)? {
        if let row = data.rows(.run).first, let when = row.when?.date {
            return (when, row.mode == "manual")
        }
        guard let run = data.runs.last(where: \.isOK), let finished = run.finishedAt?.date else { return nil }
        return (finished, run.mode == "manual")
    }

    /// The most recent scheduled run whose 60 minutes of grace have passed.
    var latestScheduledRun: Date? {
        let parts = data.settings.scheduledRunLocal.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2 else { return nil }
        let components = cal.calendar.dateComponents([.year, .month, .day], from: now)
        guard let year = components.year, let month = components.month, let day = components.day,
              let todayRun = cal.date(year: year, month: month, day: day, hour: parts[0], minute: parts[1]) else { return nil }
        let grace: TimeInterval = 60 * 60
        return todayRun.addingTimeInterval(grace) <= now ? todayRun : cal.add(days: -1, to: todayRun)
    }

    /// Red: the last successful run is older than the latest scheduled run or than 30 hours.
    /// Amber: a manual snapshot. Green otherwise.
    var runStatus: RunStatus {
        guard let last = lastSuccess else { return RunStatus(level: .red, lastRun: nil, lastRunText: nil) }
        let text = cal.isSameDay(last.date, now) ? cal.time(last.date) : cal.format(last.date, "EEE HH:mm")
        let staleHours: TimeInterval = 30 * 60 * 60
        let missedSchedule = latestScheduledRun.map { last.date < $0 } ?? false
        let level: RunLevel = missedSchedule || now.timeIntervalSince(last.date) > staleHours ? .red : last.manual ? .amber : .green
        return RunStatus(level: level, lastRun: last.date, lastRunText: text)
    }

    // MARK: Calendar

    func events(on day: Date) -> [CalEvent] {
        data.events.filter { cal.isSameDay($0.start, day) }.sorted { $0.start < $1.start }
    }

    func isTutoring(_ event: CalEvent) -> Bool { event.calendar == data.settings.tutoringCalendar }

    /// Tutoring events are titled with initials only; show them as "Tutoring · AB".
    func displayTitle(_ event: CalEvent) -> String {
        isTutoring(event) ? "Tutoring · \(event.title)" : event.title
    }

    // MARK: Greeting and summary

    var greeting: String {
        let part = switch cal.hour(now) {
        case 5..<12: "Good morning"
        case 12..<18: "Good afternoon"
        default: "Good evening"
        }
        return "\(part), \(data.settings.name)"
    }

    /// A sentence in pieces; `strong` pieces are drawn in ink, the rest muted.
    struct Phrase: Hashable {
        let text: String
        var strong = false
    }

    static func plural(_ count: Int, _ singular: String, _ plural: String? = nil) -> String {
        "\(count) \(count == 1 ? singular : plural ?? singular + "s")"
    }

    /// "Wednesday 11 November. 4 due today, 3 leftovers and 2 to confirm. 16 days to the exam, 19 to Alpine. Last run 06:34, all green."
    var todaySummary: [Phrase] {
        var phrases = [Phrase(text: cal.format(now, "EEEE d MMMM") + ". ")]
        phrases += [
            Phrase(text: "\(dueToday.count) due today", strong: true), Phrase(text: ", "),
            Phrase(text: Self.plural(leftovers.count, "leftover"), strong: true), Phrase(text: " and "),
            Phrase(text: "\(toConfirm.count) to confirm", strong: true), Phrase(text: ". "),
        ]
        let nearest = deadlines.prefix(2)
        if let first = nearest.first {
            let name = first.isExam ? "the exam" : first.short
            var text = "\(Self.plural(first.daysLeft, "day")) to \(name)"
            if nearest.count > 1, let second = nearest.last {
                text += ", \(second.daysLeft) to \(second.isExam ? "the exam" : second.short)"
            }
            phrases.append(Phrase(text: text + ". "))
        }
        phrases.append(Phrase(text: runSentence))
        return phrases
    }

    var runSentence: String {
        let status = runStatus
        guard let text = status.lastRunText else { return "No run yet: red." }
        switch status.level {
        case .green: return "Last run \(text), all green."
        case .amber: return "Last run \(text), a manual snapshot: amber."
        case .red: return "Last run \(text) is stale: red."
        }
    }
}

extension Derived {
    /// The one-sentence summary under each tab's title.
    func summary(for tab: Tab) -> [Phrase] {
        switch tab {
        case .today: todaySummary
        case .studying: studyingSummary
        default: []
        }
    }

    /// A tab with nothing to show gets one muted line and a hint instead of its sections.
    func emptyState(for tab: Tab) -> (line: String, hint: String?)? {
        switch tab {
        case .studying where data.study == nil:
            if let exam = data.settings.exam { return ("The study file could not be read.", data.hint(exam.file)) }
            return ("No exam set — add one in desk/settings.json.", data.hint(VaultData.settingsFile))
        default: return nil
        }
    }
}
