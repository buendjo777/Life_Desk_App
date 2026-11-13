import Foundation

/// Values behind Health (from `strava.json`) and System (from `runs.jsonl`).
extension Derived {
    // MARK: Health

    var weekSeconds: Int { weekActivities.map(\.durationS).reduce(0, +) }
    var weekMetres: Double { weekActivities.compactMap(\.distanceM).reduce(0, +) }

    struct StreakDay: Identifiable {
        let date: Date
        /// "M", "T"…
        let letter: String
        let trained: Bool
        let isToday: Bool
        let future: Bool
        var id: Date { date }
    }

    /// Monday to Sunday of the current week.
    var streak: [StreakDay] {
        let start = cal.weekStart(now)
        let trained = Set(weekActivities.map { cal.startOfDay($0.date.date) })
        return (0..<7).map { offset in
            let date = cal.add(days: offset, to: start)
            return StreakDay(date: date, letter: String(cal.format(date, "EEEEE")), trained: trained.contains(date),
                             isToday: cal.isSameDay(date, today), future: date > today)
        }
    }

    struct WeekBar: Identifiable {
        let start: Date
        let seconds: Int
        let sessions: Int
        let isCurrent: Bool
        var id: Date { start }
    }

    static let healthWeeks = 12

    /// Training time per week for the last 12 weeks, oldest first.
    var weekBars: [WeekBar] {
        let current = cal.weekStart(now)
        return (0..<Self.healthWeeks).reversed().map { back in
            let start = cal.add(days: -7 * back, to: current)
            let activities = activities(inWeekOf: start)
            return WeekBar(start: start, seconds: activities.map(\.durationS).reduce(0, +), sessions: activities.count, isCurrent: back == 0)
        }
    }

    /// Newest first.
    var activityList: [Activity] { data.activities.sorted { $0.date.date > $1.date.date } }

    static func activitySymbol(_ type: String) -> String {
        switch type {
        case "Run": "figure.run"
        case "Ride": "bicycle"
        case "Strength": "dumbbell"
        case "Swim": "figure.pool.swim"
        case "Walk": "figure.walk"
        default: "waveform.path.ecg"
        }
    }

    func activityDetail(_ activity: Activity) -> String {
        var parts = [activity.type, Self.durationText(activity.durationS)]
        if let metres = activity.distanceM { parts.append("\(Self.kilometres(metres)) km") }
        if let hr = activity.avgHr { parts.append("\(hr) bpm") }
        return parts.joined(separator: " · ")
    }

    var healthSummary: [Phrase] {
        guard !data.activities.isEmpty else { return [] }
        var phrases = [
            Phrase(text: "\(Self.plural(weekActivities.count, "session")) this week", strong: true),
            Phrase(text: ", \(Self.durationText(weekSeconds)) and \(Self.kilometres(weekMetres)) km. "),
        ]
        if let last = lastActivity {
            let days = cal.days(from: last.date.date, to: today)
            phrases.append(Phrase(text: "Last: \(last.name), \(days == 0 ? "today" : days == 1 ? "yesterday" : "\(days) days ago"). "))
        }
        phrases.append(Phrase(text: "As of the last run, not live."))
        return phrases
    }

    // MARK: System

    /// Newest first.
    var runHistory: [Run] { data.runs.reversed() }

    static func runDuration(_ run: Run) -> String {
        guard let seconds = run.duration.map({ Int($0.rounded()) }), seconds >= 0 else { return "—" }
        return "\(seconds / 60) min \(String(format: "%02d", seconds % 60)) s"
    }

    struct RunDay: Identifiable {
        enum State: String { case ok = "OK", failed = "Failed", none = "No run" }
        let date: Date
        let state: State
        let runs: Int
        let manual: Bool
        var id: Date { date }
    }

    static let runStripDays = 14

    /// One cell per day for the last 14 days. A day is failed when any of its runs failed or aborted.
    var runStrip: [RunDay] {
        (0..<Self.runStripDays).reversed().map { back in
            let date = cal.add(days: -back, to: today)
            let runs = data.runs.filter { cal.isSameDay($0.startedAt.date, date) }
            let state: RunDay.State = runs.isEmpty ? .none : runs.allSatisfy(\.isOK) ? .ok : .failed
            return RunDay(date: date, state: state, runs: runs.count, manual: runs.contains { $0.mode == "manual" })
        }
    }

    struct ModelUse: Identifiable {
        let model: String
        let agents: [String]
        var id: String { model }
    }

    /// The models in the latest run and the agents that used each.
    var modelsUsed: [ModelUse] {
        let agents = lastRun?.agents ?? []
        return Dictionary(grouping: agents, by: \.model)
            .map { ModelUse(model: $0.key, agents: $0.value.map(\.name)) }
            .sorted { ($0.agents.count, $1.model) > ($1.agents.count, $0.model) }
    }

    /// "sonnet ×3 · haiku ×2".
    static func modelsText(_ run: Run) -> String {
        Dictionary(grouping: run.agents ?? [], by: \.model)
            .sorted { ($0.value.count, $1.key) > ($1.value.count, $0.key) }
            .map { "\($0.key) ×\($0.value.count)" }.joined(separator: " · ")
    }

    var failedRuns: [Run] { data.runs.filter { !$0.isOK } }
    /// Every failure line in the history, newest first.
    var failureLog: [(run: Run, text: String)] {
        runHistory.flatMap { run in (run.failures ?? []).map { (run, $0) } }
    }

    var systemSummary: [Phrase] {
        guard !data.runs.isEmpty else { return [] }
        let ok = data.runs.filter(\.isOK).count
        return [
            Phrase(text: "\(ok) of \(data.runs.count) runs succeeded", strong: true),
            Phrase(text: " since \(cal.shortDay(data.runs[0].startedAt.date)). "),
            Phrase(text: runSentence),
            Phrase(text: " Scheduled daily at \(data.settings.scheduledRunLocal)."),
        ]
    }
}
