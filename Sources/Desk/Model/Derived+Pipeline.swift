import Foundation

/// Values behind Projects, Internship apps and Uni apps.
extension Derived {
    // MARK: Projects

    func projects(_ status: ProjectStatus) -> [Project] {
        data.projects.filter { $0.status == status }
            .sorted { ($0.nextDate ?? .distantFuture, $0.title) < ($1.nextDate ?? .distantFuture, $1.title) }
    }

    var projectsSummary: [Phrase] {
        var phrases: [Phrase] = []
        for (index, status) in ProjectStatus.allCases.enumerated() {
            if index > 0 { phrases.append(Phrase(text: ", ")) }
            phrases.append(Phrase(text: "\(projects(status).count) \(status == .idea ? "ideas" : status.rawValue)", strong: status == .active))
        }
        phrases.append(Phrase(text: ". "))
        if let next = data.projects.filter({ $0.nextDate.map { $0 >= today } == true }).min(by: { ($0.nextDate ?? now) < ($1.nextDate ?? now) }),
           let date = next.nextDate {
            phrases.append(Phrase(text: "Next up: \(next.title), \(cal.weekdayDay(date))."))
        }
        return phrases
    }

    // MARK: Internships

    /// "not_contacted" → "Not contacted".
    static func label(_ raw: String) -> String {
        let text = raw.replacingOccurrences(of: "_", with: " ")
        return text.prefix(1).uppercased() + text.dropFirst()
    }

    static let targetStatuses = ["open", "applied", "interview", "rejected"]

    func targets(status: String) -> [Target] { (data.targets ?? []).filter { $0.status == status } }
    var applyNow: [Target] { sortedTargets((data.targets ?? []).filter { $0.list == "apply_now" }) }
    var allTargets: [Target] { sortedTargets(data.targets ?? []) }

    private func sortedTargets(_ targets: [Target]) -> [Target] {
        targets.sorted { ($0.deadline?.date ?? .distantFuture, $0.company) < ($1.deadline?.date ?? .distantFuture, $1.company) }
    }

    func daysLeft(_ stamp: Stamp?) -> Int? { stamp.map { cal.days(from: today, to: $0.date) } }

    var internshipsSummary: [Phrase] {
        guard let targets = data.targets else { return [] }
        var phrases = [Phrase(text: "\(targets.count) targets", strong: true), Phrase(text: ", \(applyNow.count) to apply now. ")]
        if let next = sortedTargets(targets.filter { $0.status == "open" && (daysLeft($0.deadline) ?? -1) >= 0 }).first, let days = daysLeft(next.deadline) {
            phrases.append(Phrase(text: "Nearest open deadline: \(next.company) in \(Self.plural(days, "day"))."))
        }
        return phrases
    }

    // MARK: Uni apps

    struct UniCard: Identifiable {
        let programme: UniProgramme
        /// "Alpine Institute of Technology".
        let school: String
        /// "MSc Biomedical Engineering".
        let degree: String
        let deadline: Date?
        let daysLeft: Int?
        let progress: Progress
        /// "Submitted", "In progress" or "Not started".
        let status: String
        let next: String?
        var id: String { programme.id }
    }

    var uniCards: [UniCard] {
        data.unis.map { programme in
            let deadline = data.masterDeadline(for: programme)?.date
                ?? data.rows.first { $0.id == programme.deadlineRow }?.when?.date
            let parts = programme.title.components(separatedBy: " · ")
            let progress = Self.progress(programme.items)
            let submitted = programme.items.contains { $0.done && $0.title.lowercased().hasPrefix("submitted") }
            return UniCard(
                programme: programme, school: parts[0], degree: parts.dropFirst().joined(separator: " · "),
                deadline: deadline, daysLeft: deadline.map { cal.days(from: today, to: $0) }, progress: progress,
                status: submitted ? "Submitted" : progress.done == 0 ? "Not started" : "In progress",
                next: programme.items.first { !$0.done }?.title
            )
        }
        .sorted { ($0.deadline ?? .distantFuture) < ($1.deadline ?? .distantFuture) }
    }

    /// The runway spans at least 90 days and always reaches the last programme deadline.
    var uniRunwayDays: Int {
        max(Self.runwayDays, (uniCards.compactMap(\.daysLeft).max() ?? 0) + 7)
    }

    /// That programme's section of the comparison doc (a `###` heading; trusted Markdown).
    func comparison(for programme: UniProgramme) -> String? {
        data.docs[VaultData.comparisonDoc].flatMap { Parse.section($0, heading: programme.comparisonHeading) }
    }

    static let personStatuses = ["not_contacted", "drafted", "sent", "replied", "call_booked", "no_reply"]

    func people(status: String) -> [Person] { (data.people ?? []).filter { $0.status == status } }

    var uniSummary: [Phrase] {
        let cards = uniCards
        var phrases = [Phrase(text: "\(cards.count) programmes", strong: true),
                       Phrase(text: ", \(cards.filter { $0.status == "Submitted" }.count) submitted. ")]
        if let first = cards.first(where: { ($0.daysLeft ?? -1) >= 0 && $0.status != "Submitted" }), let days = first.daysLeft {
            phrases += [Phrase(text: "\(Self.plural(days, "day")) to \(first.school)", strong: true),
                        Phrase(text: first.next.map { ": next, \($0.lowercased())." } ?? ".")]
        }
        return phrases
    }
}
