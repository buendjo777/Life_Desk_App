import SwiftUI

enum Mode: String, Codable, CaseIterable, Identifiable {
    case demo, live
    var id: String { rawValue }
    var label: String { rawValue.uppercased() }
}

/// What the inspector is showing.
enum InspectorItem: Hashable {
    case row(String)
    case task(Int)
    case project(String)
    case uni(String)
    case target(String)
    case person(String)
    case student(String)
}

/// The app's single source of truth: the mode, the parsed vault, the clock and the selection.
@Observable
@MainActor
final class Store {
    let prefs: Preferences
    /// True while drawing offscreen snapshots: views swap AppKit-backed controls for stand-ins.
    let isSnapshot: Bool
    @ObservationIgnored private let demoVault: URL

    var tab: Tab = .today
    private(set) var mode: Mode = .demo
    /// The vault and everything derived from it at `now`.
    private(set) var d = Derived(data: VaultData(), now: Date())
    /// The highlighted row, by id.
    var selection: String?
    var inspector: InspectorItem?
    var banner: String?
    private(set) var lastSync: Date?

    /// Demo "writes" live here and never reach the disk.
    @ObservationIgnored private var overlay: [String: String] = [:]

    init(prefs: Preferences? = nil, isSnapshot: Bool = false, demoVault: URL = DemoVault.url) {
        self.prefs = prefs ?? Preferences(defaults: nil)
        self.isSnapshot = isSnapshot
        self.demoVault = demoVault
        resolveMode()
        // In exam mode Studying is the first screen.
        tab = d.examMode ? .studying : .today
        selection = d.focus.first?.id
    }

    var data: VaultData { d.data }
    var now: Date { d.now }
    var vaultURL: URL { mode == .live ? prefs.vaultURL : demoVault }
    var vaultName: String { vaultURL.lastPathComponent }

    /// Demo is the default until a live vault path is set and exists. Snapshots are always Demo.
    func resolveMode() {
        let next: Mode = !isSnapshot && prefs.wantsLive && prefs.vaultExists ? .live : .demo
        if next != mode { overlay = [:] }
        mode = next
        reload()
    }

    /// Re-reads the vault and recomputes everything. Demo pins the clock to `demo_today`.
    func reload() {
        let reader = VaultReader(root: vaultURL, overlay: mode == .demo ? overlay : [:])
        let data = VaultData.load(reader)
        let pinned = mode == .demo ? Parse.day(data.settings.demoToday, data.cal) : nil
        d = Derived(data: data, now: pinned ?? Date())
        if mode == .demo { lastSync = cal.calendar.date(byAdding: .minute, value: -2, to: d.now) }
    }

    /// Live only: moves the clock forward. The demo clock stays pinned.
    func tick() {
        guard mode == .live else { return }
        d = Derived(data: d.data, now: Date())
    }

    var cal: DeskCalendar { d.cal }
}
