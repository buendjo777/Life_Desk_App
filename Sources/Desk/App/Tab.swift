import SwiftUI

/// The nine sidebar tabs, in ⌘1–⌘9 order, plus the Portfolio screen (⌘0).
enum Tab: String, CaseIterable, Identifiable, Codable {
    case today, studying, projects, internships, uni, tutoring, history, health, system, portfolio

    /// The tabs shown in the sidebar.
    static let sidebar: [Tab] = [.today, .studying, .projects, .internships, .uni, .tutoring, .history, .health, .system]

    var id: String { rawValue }

    var title: String {
        switch self {
        case .today: "Today"
        case .studying: "Studying"
        case .projects: "Projects"
        case .internships: "Internship apps"
        case .uni: "Uni apps"
        case .tutoring: "Tutoring"
        case .history: "History"
        case .health: "Health"
        case .system: "System"
        case .portfolio: "Portfolio"
        }
    }

    var symbol: String {
        switch self {
        case .today: "sun.max"
        case .studying: "book.closed"
        case .projects: "square.stack.3d.up"
        case .internships: "briefcase"
        case .uni: "graduationcap"
        case .tutoring: "person.2"
        case .history: "chart.bar.xaxis"
        case .health: "heart"
        case .system: "cpu"
        case .portfolio: "rectangle.on.rectangle.angled"
        }
    }

    var accent: Accent {
        switch self {
        case .today: .focus
        case .studying: .caution
        case .projects: .focus
        case .internships: .caution
        case .uni: .info
        case .tutoring: .caution
        case .history: .info
        case .health: .good
        case .system, .portfolio: .deep
        }
    }

    /// The tabs a person may switch off. Today always stays; Health appears with its data.
    static let optional: [Tab] = [.studying, .projects, .internships, .uni, .tutoring, .history, .system]
    /// What a new desk starts with, until the person chooses.
    static let starter: Set<Tab> = [.studying, .projects]

    /// One line for Setup and Customise: what the tab is for.
    var blurb: String {
        switch self {
        case .today: "Your day at a glance"
        case .studying: "An exam, a study plan, past papers"
        case .projects: "Projects and their next step"
        case .internships: "Job and internship applications"
        case .uni: "University applications and contacts"
        case .tutoring: "Students, lessons and payments"
        case .history: "What tutoring earned, by month"
        case .health: "Training sessions"
        case .system: "Runs of a nightly Claude agent"
        case .portfolio: "The showcase"
        }
    }

    /// The ⌘ number: 1 to 9 in the sidebar, 0 for Portfolio.
    var shortcut: Int { (Tab.sidebar.firstIndex(of: self) ?? -1) + 1 }
}

/// The sidebar groups (DESIGN.md, "Sidebar").
enum TabGroup: String, CaseIterable, Identifiable {
    case focus = "Focus", pipeline = "Pipeline", life = "Life", machine = "Machine"

    var id: String { rawValue }

    var tabs: [Tab] {
        switch self {
        case .focus: [.today, .studying]
        case .pipeline: [.projects, .internships, .uni]
        case .life: [.tutoring, .history, .health]
        case .machine: [.system]
        }
    }
}
