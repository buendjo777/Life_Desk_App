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

    /// The status words Jose picks from in Desk; they are the board's own.
    static let boardStatuses = ["Not started", "Researching", "Applied", "Interviewing", "Offer", "Rejected / closed"]

    /// Added by the scan in the last week.
    func isNew(_ target: Target) -> Bool {
        target.added.map { cal.days(from: $0, to: today) < 7 } == true
    }

    /// The status cards count applications: the openings when there are any, else every target.
    func targets(status: String) -> [Target] {
        let openings = (data.targets ?? []).filter { $0.list == "apply_now" }
        return (openings.isEmpty ? data.targets ?? [] : openings).filter { $0.status == status }
    }

    /// Openings to apply to first, nearest deadline first; then interviews and applications; closed ones last.
    /// Ties keep the board's own order.
    var applyNow: [Target] {
        let rank = ["open": 0, "interview": 1, "offer": 1, "applied": 2, "rejected": 3]
        return (data.targets ?? []).filter { $0.list == "apply_now" }.sorted {
            (rank[$0.status] ?? 0, $0.deadline?.date ?? .distantFuture, $0.order ?? 0, $0.company)
                < (rank[$1.status] ?? 0, $1.deadline?.date ?? .distantFuture, $1.order ?? 0, $1.company)
        }
    }

    /// The rows behind a status card, in the Apply now order.
    func filteredTargets(status: String) -> [Target] {
        let picked = Set(targets(status: status).map(\.id))
        let openings = applyNow.filter { picked.contains($0.id) }
        return openings.isEmpty ? allTargets.filter { picked.contains($0.id) } : openings
    }

    /// The board's targets (companies and labs), priority A first, then by place; without the board, every target.
    var allTargets: [Target] {
        let targets = (data.targets ?? []).filter { $0.list != "apply_now" }
        guard !targets.isEmpty, targets.contains(where: { $0.priority != nil }) else { return sortedTargets(data.targets ?? []) }
        return targets.sorted { ($0.priority ?? "Z", $0.order ?? 0, $0.company) < ($1.priority ?? "Z", $1.order ?? 0, $1.company) }
    }

    private func sortedTargets(_ targets: [Target]) -> [Target] {
        targets.sorted { ($0.deadline?.date ?? .distantFuture, $0.company) < ($1.deadline?.date ?? .distantFuture, $1.company) }
    }

    func daysLeft(_ stamp: Stamp?) -> Int? { stamp.map { cal.days(from: today, to: $0.date) } }

    var internshipsSummary: [Phrase] {
        guard let targets = data.targets else { return [] }
        let live = applyNow.filter { $0.status != "rejected" }.count
        var phrases = [Phrase(text: "\(live) openings to apply to", strong: true),
                       Phrase(text: ", across \(Self.plural(allTargets.count, "target")). ")]
        if let next = sortedTargets(targets.filter { $0.status == "open" && (daysLeft($0.deadline) ?? -1) >= 0 }).first, let days = daysLeft(next.deadline) {
            phrases.append(Phrase(text: "Nearest open deadline: \(next.company) in \(Self.plural(days, "day"))."))
        }
        return phrases
    }

    // MARK: Uni apps

    /// One mark on the deadline runway. Programmes of one school closing the same day share it ("ETH").
    struct RunwayMark: Identifiable {
        let title: String
        let daysLeft: Int
        let deadline: Date?
        let submitted: Bool
        var id: String { "\(title)-\(daysLeft)" }
    }

    /// Marks for deadlines still ahead, nearest first.
    var uniRunwayMarks: [RunwayMark] {
        var marks: [RunwayMark] = []
        for card in uniCards.sorted(by: { ($0.daysLeft ?? .max) < ($1.daysLeft ?? .max) }) {
            guard let days = card.daysLeft, days >= 0 else { continue }
            let title = card.school.split(separator: " ").first.map(String.init) ?? card.school
            if let index = marks.firstIndex(where: { $0.title == title && $0.daysLeft == days }) {
                // Shared mark: submitted only when every programme behind it is.
                marks[index] = RunwayMark(title: title, daysLeft: days, deadline: marks[index].deadline,
                                          submitted: marks[index].submitted && card.status == "Submitted")
            } else {
                marks.append(RunwayMark(title: title, daysLeft: days, deadline: card.deadline, submitted: card.status == "Submitted"))
            }
        }
        return marks
    }

    /// Puts each label in the first lane where it does not touch the label before it: below the line, then above,
    /// then a second row below, then above. `occupied` reserves the start of the first lane (the "Today" label).
    /// `centres` must be in increasing order.
    static func runwayLanes(_ centres: [Double], labelWidth: Double, gap: Double, occupied: Double, lanes: Int = 4) -> [Int] {
        var ends = [Double](repeating: -.infinity, count: lanes)
        ends[0] = occupied
        return centres.map { x in
            let left = x - labelWidth / 2
            let lane = ends.indices.first { ends[$0] + gap <= left } ?? ends.indices.min { ends[$0] < ends[$1] } ?? 0
            ends[lane] = x + labelWidth / 2
            return lane
        }
    }

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
