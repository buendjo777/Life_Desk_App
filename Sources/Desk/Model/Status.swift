import Foundation

/// "not_contacted" → "Not contacted".
private func spaced(_ raw: String) -> String {
    let text = raw.replacingOccurrences(of: "_", with: " ")
    return text.prefix(1).uppercased() + text.dropFirst()
}

/// An internship target's status, in Desk's words. The board has its own (`boardWord`).
enum TargetStatus: String, CaseIterable, Hashable {
    case open, applied, interview, offer, rejected

    var label: String { spaced(rawValue) }

    var accent: Accent {
        switch self {
        case .open: .caution
        case .applied: .info
        case .interview, .offer: .good
        case .rejected: .deep
        }
    }

    /// The word the board uses for this status.
    var boardWord: String {
        switch self {
        case .open: "Not started"
        case .applied: "Applied"
        case .interview: "Interviewing"
        case .offer: "Offer"
        case .rejected: "Rejected / closed"
        }
    }

    /// Apply now order: open first, then interviews and offers, applications, closed last.
    var sortRank: Int {
        switch self {
        case .open: 0
        case .interview, .offer: 1
        case .applied: 2
        case .rejected: 3
        }
    }

    /// The words Jose picks from in Desk; they are the board's own ("Researching" counts as open).
    static let pickerWords = ["Not started", "Researching", "Applied", "Interviewing", "Offer", "Rejected / closed"]

    /// The board's words in Desk's four: rejected or closed, an interview, a call or an offer, applied, else open.
    init(boardWord raw: String) {
        let text = raw.lowercased()
        if ["reject", "closed", "declin", "no longer"].contains(where: text.contains) { self = .rejected }
        else if ["interview", "call", "offer"].contains(where: text.contains) { self = .interview }
        else if ["applied", "submitted", "sent"].contains(where: text.contains) { self = .applied }
        else { self = .open }
    }
}

/// Which list of the internship board a target sits in.
enum TargetList: String, CaseIterable, Hashable {
    case applyNow = "apply_now"
    case target

    var label: String { self == .applyNow ? "Apply now" : "Target" }
    var accent: Accent { self == .applyNow ? .focus : .neutral }
}

/// A contact's status, in Desk's words. The board has its own (`boardWord`).
enum PersonStatus: String, CaseIterable, Hashable {
    case notContacted = "not_contacted"
    case drafted, sent, replied
    case callBooked = "call_booked"
    case noReply = "no_reply"

    var label: String { spaced(rawValue) }

    var accent: Accent {
        switch self {
        case .replied, .callBooked: .good
        case .sent, .drafted: .info
        case .noReply: .alert
        case .notContacted: .neutral
        }
    }

    /// The word the board uses for this status.
    var boardWord: String {
        switch self {
        case .notContacted: "Not contacted"
        case .drafted: "Email drafted"
        case .sent: "Email sent"
        case .replied: "Replied"
        case .callBooked: "Call booked"
        case .noReply: "No reply"
        }
    }

    /// The contacts board's words in Desk's statuses.
    init(boardWord words: String) {
        let text = words.lowercased()
        if text.contains("drafted") { self = .drafted }
        else if text.contains("sent") { self = .sent }
        else if text.contains("replied") { self = .replied }
        else if text.contains("call") { self = .callBooked }
        else if text.contains("no reply") { self = .noReply }
        else { self = .notContacted }
    }
}
