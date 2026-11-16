import SwiftUI
import AppKit
import DeskKit

/// First launch on a Mac that has no vault yet: three ways in, no settings to find.
/// It is shown once; after that the same choices live in Settings (⌘,).
struct WelcomeView: View {
    @Environment(Store.self) private var store
    @Environment(\.theme) private var t
    @State private var name = NSFullUserName().split(separator: " ").first.map(String.init) ?? ""
    @State private var problem: String?
    @FocusState private var nameFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: t.sp20) {
            VStack(alignment: .leading, spacing: t.sp8) {
                Text(verbatim: "Welcome to Desk").style(\.display, \.ink)
                Text(verbatim: "One calm window for your day: tasks, study, projects and deadlines. Everything lives in a folder of plain text files that belongs to you.")
                    .style(\.body, \.inkMuted)
                    .lineSpacing(t.sp4)
                    .fixedSize(horizontal: false, vertical: true)
            }
            VStack(alignment: .leading, spacing: t.sp6) {
                Text(verbatim: "What should Desk call you?").style(\.smallStrong, \.ink)
                TextField("Your first name", text: $name)
                    .textFieldStyle(.plain)
                    .font(t.body.font)
                    .foregroundStyle(t.ink)
                    .focused($nameFocused)
                    .onSubmit(start)
                    .padding(.horizontal, t.sp12 + t.sp2)
                    .frame(height: t.searchHeight)
                    .background(t.surface, in: Capsule())
                    .overlay(Capsule().strokeBorder(t.line, lineWidth: t.hairline))
            }
            VStack(spacing: t.sp8) {
                choice("sparkles", "Start my own desk",
                       "Creates the folder \(StarterVault.defaultPath) with a few starter files.", accent: .focus, action: start)
                choice("folder", "Open a folder I already have",
                       "A Desk vault, or a copy of one from GitHub.", accent: .info, action: open)
                choice("eye", "Look around first",
                       "A demo with invented data. Nothing is saved.", accent: .neutral) { store.leaveWelcome() }
            }
            if let problem {
                Text(verbatim: problem).style(\.small, \.alert).fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(t.sp24 + t.sp8)
        .frame(width: t.welcomeWidth)
        .glass(lifts: false)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { Backdrop() }
        .background(t.canvas)
        .onAppear { nameFocused = true }
    }

    private func choice(_ symbol: String, _ title: String, _ hint: String, accent: Accent, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: t.sp12) {
                Image(systemName: symbol)
                    .font(.system(size: t.symbol, weight: .semibold))
                    .foregroundStyle(t.ink)
                    .frame(width: t.iconButton, height: t.iconButton)
                    .background(t.tint(accent), in: Circle())
                VStack(alignment: .leading, spacing: t.sp2) {
                    Text(verbatim: title).style(\.bodyStrong, \.ink)
                    Text(verbatim: hint).style(\.small, \.inkMuted)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.system(size: t.symbolSmall, weight: .bold)).foregroundStyle(t.inkMuted)
            }
            .padding(.horizontal, t.sp12)
            .padding(.vertical, t.sp10)
            .background(t.surface, in: RoundedRectangle(cornerRadius: t.radiusRow))
            .overlay(RoundedRectangle(cornerRadius: t.radiusRow).strokeBorder(t.line, lineWidth: t.hairline))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(verbatim: "\(title). \(hint)"))
    }

    private func start() {
        problem = store.startOwnDesk(name: name)
    }

    private func open() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Use this folder"
        if panel.runModal() == .OK, let url = panel.url {
            store.useVault(url.path)
        }
    }
}
