import SwiftUI
import AppKit

/// The Settings window (⌘,): the vault path, the mode, appearance and density.
struct SettingsView: View {
    @Environment(Store.self) private var store
    /// The path being typed; it is applied on Return or Choose, never per keystroke.
    @State private var path = ""

    var body: some View {
        let t = Theme()
        @Bindable var prefs = store.prefs
        Form {
            Section("Vault") {
                HStack {
                    TextField("Live vault folder", text: $path)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { apply() }
                    Button("Choose…") { choose() }
                }
                Toggle("Use the live vault when the folder exists", isOn: $prefs.wantsLive)
                Text(verbatim: status).font(t.small.font).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Sync now") { store.sync() }.keyboardShortcut("r", modifiers: .command)
            }
            Section("Look") {
                Picker("Appearance", selection: $prefs.appearance) {
                    ForEach(Appearance.allCases) { Text(verbatim: $0.title).tag($0) }
                }
                Picker("Density", selection: $prefs.density) {
                    ForEach(Density.allCases) { Text(verbatim: $0.title).tag($0) }
                }
                Button("Customise tabs…") { store.showCustomise = true }
            }
        }
        .formStyle(.grouped)
        .frame(width: t.settingsWidth)
        .fixedSize(horizontal: false, vertical: true)
        .onAppear { path = prefs.vaultPath }
        .onChange(of: prefs.wantsLive) { store.settingsChanged() }
    }

    private var status: String {
        switch store.mode {
        case .live:
            "Live: reading \(store.prefs.vaultURL.path). Ticks and clicks are committed and pushed; agent/ is never written."
        case .demo where !store.prefs.wantsLive:
            "Demo: the bundled demo vault. Nothing is written to disk."
        case .demo:
            "Demo: \(store.prefs.vaultURL.path) does not exist yet, so Desk shows the bundled demo vault. Nothing is written to disk."
        }
    }

    private func apply() {
        store.prefs.vaultPath = path.trimmingCharacters(in: .whitespaces)
        store.settingsChanged()
    }

    private func choose() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = store.prefs.vaultExists ? store.prefs.vaultURL : nil
        if panel.runModal() == .OK, let url = panel.url {
            path = url.path
            apply()
        }
    }
}
