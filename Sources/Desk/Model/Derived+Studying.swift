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
        let days = cal.days(from: start, to: day) + 1
        return min(study.papers.count, max(0, days) * study.planPerDay)
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

    /// Done against plan, from the first paper (or the plan start) to the exam.
    var planChart: PlanChart? {
        guard let study, !study.papers.isEmpty, let end = examDate.map(cal.startOfDay) else { return nil }
        let firsts = [study.planStart, study.papers.compactMap(\.date).min(), today].compactMap { $0 }
        guard let start = firsts.min().map(cal.startOfDay), start < end else { return nil }
        let span = cal.days(from: start, to: end)
        let upToToday = min(span, max(0, cal.days(from: start, to: today)))
        return PlanChart(
            start: start, end: end,
            plan: (0...span).map { plannedPapers(by: cal.add(days: $0, to: start)) },
            done: (0...upToToday).map { donePapers(by: cal.add(days: $0, to: start)) },
            total: study.papers.count
        )
    }

    struct StudyTarget {
        let headline: String
        let detail: String
        /// The next unticked papers or topics to do today.
        let items: [String]
    }

    /// Today's target, worked out from the plan. Before `plan_start` it points at the next open topics.
    var studyTarget: StudyTarget? {
        guard let study else { return nil }
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
