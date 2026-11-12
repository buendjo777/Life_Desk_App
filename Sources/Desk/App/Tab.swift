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
        case .today: .rust
        case .studying: .ochre
        case .projects: .rust
        case .internships: .ochre
        case .uni: .steel
        case .tutoring: .ochre
        case .history: .steel
        case .health: .moss
        case .system, .portfolio: .navy
        }
    }

    var shape: CardShape {
        switch self {
        case .today: .circle
        case .studying: .triangle
        case .projects: .hexagon
        case .internships: .square
        case .uni: .chevron
        case .tutoring: .ring
        case .history: .star
        case .health: .heart
        case .system, .portfolio: .cog
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
