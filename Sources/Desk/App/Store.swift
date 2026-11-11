import SwiftUI

enum Mode: String, Codable, CaseIterable, Identifiable {
    case demo, live
    var id: String { rawValue }
    var label: String { rawValue.uppercased() }
}

/// The app's single source of truth: what is selected and what the vault holds.
@Observable
@MainActor
final class Store {
    var tab: Tab = .today
    var mode: Mode = .demo
    /// True while drawing offscreen snapshots: views swap AppKit-backed controls for stand-ins.
    let isSnapshot: Bool

    init(isSnapshot: Bool = false) {
        self.isSnapshot = isSnapshot
    }
}
