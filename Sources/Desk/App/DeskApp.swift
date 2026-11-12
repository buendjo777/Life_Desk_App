import SwiftUI

struct DeskApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var store = Store(prefs: Preferences(defaults: .standard), calendar: EventKitCalendar())

    var body: some Scene {
        Window("Desk", id: "main") {
            RootView()
                .environment(store)
                .frame(minWidth: Theme().minWindow.width, minHeight: Theme().minWindow.height)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(Theme().designSize)
        .commands { DeskCommands(store: store) }

        Settings {
            SettingsView().environment(store)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Needed when the binary runs outside its bundle (swift run).
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

/// Menu commands: ⌘1–⌘9 switch tabs (⌘0 Portfolio), ⌘R syncs and reads the Classes note, ⌘F searches,
/// View → Customise….
struct DeskCommands: Commands {
    let store: Store

    var body: some Commands {
        CommandGroup(replacing: .newItem) {}
        CommandGroup(after: .sidebar) {
            Button("Customise…") { store.showCustomise = true }
            Divider()
            Button("Sync Now") {
                store.sync()
                store.importClasses(explicit: true)
            }
            .keyboardShortcut("r", modifiers: .command)
            Button("Find") { store.searchFocus += 1 }.keyboardShortcut("f", modifiers: .command)
            Divider()
        }
        CommandMenu("Go") {
            ForEach(Tab.sidebar) { tab in
                Button(tab.title) { store.show(tab) }
                    .keyboardShortcut(KeyEquivalent(Character(String(tab.shortcut))), modifiers: .command)
            }
            Divider()
            Button(Tab.portfolio.title) { store.show(.portfolio) }
                .keyboardShortcut("0", modifiers: .command)
        }
    }
}
