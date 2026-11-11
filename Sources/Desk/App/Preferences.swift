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
    var layouts: [String: TabPrefs] {
        didSet { defaults?.set(try? JSONEncoder().encode(layouts), forKey: "layouts") }
    }

    init(defaults: UserDefaults?) {
        self.defaults = defaults
        vaultPath = defaults?.string(forKey: "vaultPath") ?? Self.defaultVaultPath
        wantsLive = defaults?.object(forKey: "wantsLive") as? Bool ?? true
        density = defaults?.string(forKey: "density").flatMap(Density.init) ?? .compact
        appearance = defaults?.string(forKey: "appearance").flatMap(Appearance.init) ?? .system
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
}
