import SwiftUI

struct DeskApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var store = Store()

    var body: some Scene {
        Window("Desk", id: "main") {
            RootView()
                .environment(store)
                .frame(minWidth: Theme().minWindow.width, minHeight: Theme().minWindow.height)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(Theme().designSize)
        .commands { DeskCommands(store: store) }
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

/// Menu commands: ⌘1–⌘8 switch tabs.
struct DeskCommands: Commands {
    let store: Store

    var body: some Commands {
        CommandMenu("Go") {
            ForEach(Tab.eight) { tab in
                Button(tab.title) { store.tab = tab }
                    .keyboardShortcut(KeyEquivalent(Character(String(tab.shortcut))), modifiers: .command)
            }
        }
    }
}
