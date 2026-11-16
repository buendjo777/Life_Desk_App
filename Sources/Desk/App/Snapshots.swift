import SwiftUI

/// `Desk --render-snapshots <dir>`: every tab, light and dark, at the design size (SPEC "Verification").
@MainActor
enum Snapshots {
    static func run(directory: String) {
        let folder = URL(fileURLWithPath: directory, isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            for tab in Tab.allCases {
                for scheme in [ColorScheme.light, .dark] {
                    let store = Store(isSnapshot: true)
                    store.tab = tab
                    let name = "\(tab.rawValue)-\(scheme == .dark ? "dark" : "light").png"
                    try render(RootView().environment(store), scheme: scheme, to: folder.appendingPathComponent(name))
                }
            }
            // One extra pair with the inspector open, to check the panel and the Markdown view.
            for scheme in [ColorScheme.light, .dark] {
                let store = Store(isSnapshot: true)
                store.tab = .projects
                if let project = store.d.projects(.active).first { store.open(.project(project.path)) }
                try render(RootView().environment(store), scheme: scheme,
                           to: folder.appendingPathComponent("inspector-\(scheme == .dark ? "dark" : "light").png"))
            }
            // The Customise drawer over Today, then Comfortable density on the Today tab behind it for comparison.
            for scheme in [ColorScheme.light, .dark] {
                let store = Store(isSnapshot: true)
                store.showCustomise = true
                try render(RootView().environment(store), scheme: scheme,
                           to: folder.appendingPathComponent("customise-\(scheme == .dark ? "dark" : "light").png"))
                store.showCustomise = false
                store.prefs.density = .comfortable
                try render(RootView().environment(store), scheme: scheme,
                           to: folder.appendingPathComponent("comfortable-\(scheme == .dark ? "dark" : "light").png"))
            }
            // The Welcome screen a new person sees on first launch.
            for scheme in [ColorScheme.light, .dark] {
                let store = Store(isSnapshot: true)
                store.showWelcome = true
                for step in 0..<WelcomeView.steps {
                    store.welcomeStep = step
                    try render(RootView().environment(store), scheme: scheme,
                               to: folder.appendingPathComponent("welcome-\(step + 1)-\(scheme == .dark ? "dark" : "light").png"))
                }
            }
            print("Rendered \(Tab.allCases.count * 2 + 6 + WelcomeView.steps * 2) snapshots to \(folder.path)")
        } catch {
            FileHandle.standardError.write(Data("Snapshot failed: \(error.localizedDescription)\n".utf8))
            exit(1)
        }
    }

    static func render(_ view: some View, scheme: ColorScheme, size: CGSize = Theme().designSize, to url: URL) throws {
        try Snapshot.render(view, scheme: scheme, size: size, to: url)
    }
}
