import Foundation

/// Values behind the Studying tab: countdown, progress, the paper plan and today's target.
extension Derived {
    var study: StudyFile? { data.study }

    var examDate: Date? { study?.date ?? deadlines.first(where: \.isExam)?.date }
    var examDaysLeft: Int? { examDate.map { cal.days(from: today, to: $0) } }

    struct Progress: Hashable {
        let done: Int
        let total: Int
        var fraction: Double { total == 0 ? 0 : Double(done) / Double(total) }
        var text: String { "\(done)/\(total)" }
        var percent: String { "\(Int((fraction * 100).rounded()))%" }
    }

    static func progress(_ checks: [Check]) -> Progress {
        Progress(done: checks.filter(\.done).count, total: checks.count)
    }

    var theoryProgress: Progress { Self.progress(study?.theory ?? []) }
    var problemsProgress: Progress { Self.progress(study?.problems ?? []) }
    var papersProgress: Progress {
        Progress(done: study?.papers.filter(\.done).count ?? 0, total: study?.papers.count ?? 0)
    }

    /// Theory, problems and past papers together.
    var studyProgress: Progress {
        Progress(done: theoryProgress.done + problemsProgress.done + papersProgress.done,
                 total: theoryProgress.total + problemsProgress.total + papersProgress.total)
    }

    /// Papers the plan expects done by the end of `day`: `plan_per_day` from `plan_start`, capped at the total.
    func plannedPapers(by day: Date) -> Int {
        guard let study, let start = study.planStart, study.planPerDay > 0 else { return 0 }
        let days = min(Self.maxChartDays, max(0, cal.days(from: start, to: day) + 1))
        return min(study.papers.count, days * study.planPerDay)
    }

    /// Papers done by the end of `day`. A ticked paper with no date counts from today.
    func donePapers(by day: Date) -> Int {
        (study?.papers ?? []).filter { $0.done && cal.startOfDay($0.date ?? today) <= cal.startOfDay(day) }.count
    }

    struct PlanChart {
        let start: Date
        let end: Date
        /// One value per day from `start` to `end`.
        let plan: [Int]
        /// One value per day from `start` to today.
        let done: [Int]
        let total: Int
        var days: Int { max(1, plan.count - 1) }
    }

    /// The plan chart never spans more than a year.
    static let maxChartDays = 366

    /// Done against plan, from the first paper (or the plan start) to the exam.
    var planChart: PlanChart? {
        guard let study, !study.papers.isEmpty, let end = examDate.map(cal.startOfDay) else { return nil }
        let firsts = [study.planStart, study.papers.compactMap(\.date).min(), today].compactMap { $0 }
        guard let first = firsts.min().map(cal.startOfDay), first < end else { return nil }
        // A typo in a date must not ask for a chart thousands of days wide.
        let start = max(first, cal.add(days: -Self.maxChartDays, to: end))
        let span = cal.days(from: start, to: end)
        let upToToday = min(span, max(0, cal.days(from: start, to: today)))
        return PlanChart(
            start: start, end: end,
            plan: (0...span).map { plannedPapers(by: cal.add(days: $0, to: start)) },
            done: (0...upToToday).map { donePapers(by: cal.add(days: $0, to: start)) },
            total: study.papers.count
        )
    }

    // MARK: Lists ("This weekend — due 2026-11-15")

    /// Minutes written in an item's title: "Lecture 6 · Beam deflection · 110 min" → 110.
    static func minutes(_ check: Check) -> Int? {
        check.title.firstMatch(of: /(\d+)\s*min\b/).flatMap { Int($0.1) }
    }

    /// Minutes left in a group's open items; `nil` when none says how long it takes.
    static func minutesLeft(_ group: StudyList.Group) -> Int? {
        let minutes = group.items.filter { !$0.done }.compactMap(minutes)
        return minutes.isEmpty ? nil : minutes.reduce(0, +)
    }

    /// Lists with something left to do, the soonest due first.
    var openLists: [StudyList] {
        (study?.lists ?? []).filter { !$0.open.isEmpty }
            .sorted { ($0.due ?? .distantFuture, $0.line) < ($1.due ?? .distantFuture, $1.line) }
    }

    /// Days to the due day, today and that day both counted: 1 on the day itself, 0 or less once it has passed.
    func daysLeft(_ list: StudyList) -> Int? {
        list.due.map { cal.days(from: today, to: $0) + 1 }
    }

    /// Today's share: in each group, its open items ÷ the days left, rounded up, so every group ends on time.
    func todaysShare(_ list: StudyList) -> [Check] {
        let days = max(1, daysLeft(list) ?? 1)
        return list.groups.flatMap { group -> [Check] in
            let open = group.items.filter { !$0.done }
            return Array(open.prefix(Int((Double(open.count) / Double(days)).rounded(.up))))
        }
    }

    /// "Due Sun 15 Nov · 4 days left · 20 to go".
    func listSubtitle(_ list: StudyList) -> String {
        let left = list.open.count
        guard let due = list.due, let days = daysLeft(list) else { return left == 0 ? "All done" : "\(left) to go" }
        if left == 0 { return "All done · due \(cal.weekdayDay(due))" }
        let when = days < 1 ? "\(Self.plural(1 - days, "day")) late" : days == 1 ? "due today" : "\(Self.plural(days, "day")) left"
        return "Due \(cal.weekdayDay(due)) · \(when) · \(left) to go"
    }

    struct StudyTarget {
        let headline: String
        let detail: String
        /// The next unticked papers or topics to do today.
        var items: [String] = []
        /// From a list: today's share, ticked straight from the card.
        var checks: [Check] = []
    }

    /// Today's target. Until a list's due day, its share for today; otherwise the paper plan, and before
    /// `plan_start` the next open topics.
    var studyTarget: StudyTarget? {
        guard let study else { return nil }
        if let list = openLists.first(where: { (daysLeft($0) ?? 0) >= 1 }), let due = list.due {
            let share = todaysShare(list)
            let video = share.compactMap(Self.minutes).reduce(0, +)
            return StudyTarget(
                headline: "\(Self.plural(share.count, "item")) today",
                detail: "\(list.open.count) left, due \(cal.format(due, "EEEE"))" + (video > 0 ? " · \(Self.durationText(video * 60)) of video today." : "."),
                checks: share
            )
        }
        let openPapers = study.papers.filter { !$0.done }
        let openTopics = (study.theory.filter { !$0.done }.map { "Theory · \($0.title)" })
        if let start = study.planStart, today < start {
            return StudyTarget(
                headline: "Plan starts \(cal.weekdayDay(start))",
                detail: "\(Self.plural(study.planPerDay, "paper")) a day from then. Until then: close the open theory.",
                items: Array(openTopics.prefix(3))
            )
        }
        let gap = plannedPapers(by: today) - papersProgress.done
        let count = min(openPapers.count, max(gap, 0))
        if openPapers.isEmpty {
            return StudyTarget(headline: "All papers done", detail: "Review the weakest topics.", items: Array(openTopics.prefix(3)))
        }
        return StudyTarget(
            headline: count == 0 ? "On plan" : "\(Self.plural(count, "paper")) today",
            detail: gap > study.planPerDay ? "Behind the plan by \(gap - study.planPerDay)." : "\(study.planPerDay) a day keeps the plan.",
            items: openPapers.prefix(max(count, 1)).map(\.title)
        )
    }

    var studyingSummary: [Phrase] {
        guard study != nil else { return [] }
        var phrases: [Phrase] = []
        if let days = examDaysLeft, let date = examDate {
            phrases += [Phrase(text: "\(Self.plural(days, "day")) to the exam", strong: true),
                        Phrase(text: " on \(cal.format(date, "EEEE d MMMM, HH:mm")). ")]
        }
        if let list = openLists.first {
            phrases += [Phrase(text: "\(list.title): \(list.items.count - list.open.count) of \(list.items.count) done", strong: true),
                        Phrase(text: list.due.map { " (due \(cal.format($0, "EEEE d MMM"))). " } ?? ". ")]
        }
        phrases += [Phrase(text: "\(theoryProgress.done + problemsProgress.done) of \(theoryProgress.total + problemsProgress.total) topic ticks", strong: true),
                    Phrase(text: " and "),
                    Phrase(text: "\(papersProgress.done) of \(papersProgress.total) papers", strong: true), Phrase(text: " done. ")]
        if examMode {
            phrases.append(Phrase(text: "Exam mode is on."))
        } else if let start = Parse.day(data.settings.exam?.modeStarts, cal), start > now {
            phrases.append(Phrase(text: "Exam mode starts \(cal.weekdayDay(start))."))
        }
        return phrases
    }
}
