import SwiftUI

enum Appearance: String, CaseIterable, Identifiable, Codable {
    case system, light, dark
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var scheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

/// What was open in the study plan when the day began: today's ticks are counted against it.
struct DayStart: Codable, Equatable {
    var day: String
    var key: String
    var open: Int
}

/// A tab's saved layout: section order and the hidden ones.
struct TabPrefs: Codable, Equatable {
    var order: [String] = []
    var hidden: Set<String> = []
}

/// App preferences. They live in `UserDefaults`, never in the vault.
/// With `defaults == nil` (tests, snapshots) nothing is read or saved.
@Observable
@MainActor
final class Preferences {
    @ObservationIgnored private let defaults: UserDefaults?

    static let defaultVaultPath = "~/jose-brain"

    var vaultPath: String { didSet { defaults?.set(vaultPath, forKey: "vaultPath") } }
    /// Live is used when this is on and the vault folder exists; otherwise Demo.
    var wantsLive: Bool { didSet { defaults?.set(wantsLive, forKey: "wantsLive") } }
    var density: Density { didSet { defaults?.set(density.rawValue, forKey: "density") } }
    var appearance: Appearance { didSet { defaults?.set(appearance.rawValue, forKey: "appearance") } }
    var palette: Palette { didSet { defaults?.set(palette.rawValue, forKey: "palette") } }
    /// The living backdrop, hover lift, entrances and sparks. Reduce Motion switches them off as well.
    var motion: Bool { didSet { defaults?.set(motion, forKey: "motion") } }
    /// The sidebar shows icons only and opens under the pointer.
    var slimSidebar: Bool { didSet { defaults?.set(slimSidebar, forKey: "slimSidebar") } }
    var dayStart: DayStart? { didSet { defaults?.set(try? JSONEncoder().encode(dayStart), forKey: "dayStart") } }
    var layouts: [String: TabPrefs] {
        didSet { defaults?.set(try? JSONEncoder().encode(layouts), forKey: "layouts") }
    }

    init(defaults: UserDefaults?) {
        self.defaults = defaults
        vaultPath = defaults?.string(forKey: "vaultPath") ?? Self.defaultVaultPath
        // Without stored preferences (tests, snapshots) Desk is always Demo: an in-memory store
        // must never pick up the real vault just because ~/jose-brain exists on this Mac.
        wantsLive = defaults.map { $0.object(forKey: "wantsLive") as? Bool ?? true } ?? false
        density = defaults?.string(forKey: "density").flatMap(Density.init) ?? .compact
        appearance = defaults?.string(forKey: "appearance").flatMap(Appearance.init) ?? .system
        palette = defaults?.string(forKey: "palette").flatMap(Palette.init) ?? .ember
        // Without stored preferences (tests, snapshots) nothing moves: clicks land where the layout says.
        motion = defaults.map { $0.object(forKey: "motion") as? Bool ?? true } ?? false
        slimSidebar = defaults.map { $0.object(forKey: "slimSidebar") as? Bool ?? true } ?? false
        dayStart = defaults?.data(forKey: "dayStart").flatMap { try? JSONDecoder().decode(DayStart.self, from: $0) }
        layouts = defaults?.data(forKey: "layouts").flatMap { try? JSONDecoder().decode([String: TabPrefs].self, from: $0) } ?? [:]
    }

    var vaultURL: URL {
        URL(fileURLWithPath: (vaultPath as NSString).expandingTildeInPath, isDirectory: true)
    }

    var vaultExists: Bool {
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: vaultURL.path, isDirectory: &isDirectory) && isDirectory.boolValue
    }

    /// Restores the default layout and density (Customise → Reset).
    func resetLayout() {
        layouts = [:]
        density = .compact
    }

    /// Customise: show or hide one section of a tab.
    func setHidden(_ hidden: Bool, section: String, tab: Tab) {
        var layout = layouts[tab.rawValue] ?? TabPrefs()
        if hidden { layout.hidden.insert(section) } else { layout.hidden.remove(section) }
        layouts[tab.rawValue] = layout
    }

    /// Customise: move a section up (-1) or down (+1) within `current`, the tab's present order.
    func move(_ section: String, by offset: Int, tab: Tab, current: [String]) {
        guard let index = current.firstIndex(of: section), current.indices.contains(index + offset) else { return }
        var order = current
        order.swapAt(index, index + offset)
        var layout = layouts[tab.rawValue] ?? TabPrefs()
        layout.order = order
        layouts[tab.rawValue] = layout
    }
}
