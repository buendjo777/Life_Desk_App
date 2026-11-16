import SwiftUI
import AppKit
import DeskKit

/// First launch on a Mac that has no vault yet. Three short steps, one decision each:
/// 1. who you are, and how to start; 2. which tabs go on your desk; 3. what Desk may connect to.
/// It is shown once; afterwards the same choices live in Customise (⌘K) and Settings (⌘,).
struct WelcomeView: View {
    @Environment(Store.self) private var store
    @Environment(\.theme) private var t
    @State private var name = NSFullUserName().split(separator: " ").first.map(String.init) ?? ""
    @State private var tabs = Tab.starter
    @State private var calendar = true
    @State private var askClaude = false
    @State private var problem: String?
    @FocusState private var nameFocused: Bool

    static let steps = 3

    var body: some View {
        let step = store.welcomeStep
        VStack(alignment: .leading, spacing: t.sp20) {
            HStack(spacing: t.sp6) {
                ForEach(0..<Self.steps, id: \.self) { index in
                    Capsule().fill(index <= step ? t.focus : t.line).frame(width: index == step ? t.sp24 : t.sp10, height: t.sp4)
                }
                Spacer()
                Text(verbatim: "Step \(step + 1) of \(Self.steps)").style(\.small, \.inkMuted)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(verbatim: "Step \(step + 1) of \(Self.steps)"))
            switch step {
            case 0: start
            case 1: chooseTabs
            default: connect
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
        .deskAnimation(step)
    }

    // MARK: Step 1

    private var start: some View {
        Group {
            header("Welcome to Desk", "One calm window for your day. Everything lives in a folder of plain text files that belongs to you.")
            VStack(alignment: .leading, spacing: t.sp6) {
                Text(verbatim: "What should Desk call you?").style(\.smallStrong, \.ink)
                TextField("Your first name", text: $name)
                    .textFieldStyle(.plain)
                    .font(t.body.font)
                    .foregroundStyle(t.ink)
                    .focused($nameFocused)
                    .onSubmit { store.welcomeStep = 1 }
                    .padding(.horizontal, t.sp12 + t.sp2)
                    .frame(height: t.searchHeight)
                    .background(t.surface, in: Capsule())
                    .overlay(Capsule().strokeBorder(t.line, lineWidth: t.hairline))
            }
            VStack(spacing: t.sp8) {
                choice("sparkles", "Set up my own desk", "Two quick choices, then it is ready.", accent: .focus) { store.welcomeStep = 1 }
                choice("folder", "Open a folder I already have", "A Desk vault, or a copy of one from GitHub.", accent: .info, action: open)
                choice("eye", "Look around first", "A demo with invented data. Nothing is saved.", accent: .neutral) { store.leaveWelcome() }
            }
        }
    }

    // MARK: Step 2

    private var chooseTabs: some View {
        Group {
            header("What goes on your desk?", "Pick what you need. Today is always there, and you can change this later in Customise (⌘K).")
            TabPicker(detailed: true, isOn: { tabs.contains($0) }) { tab in
                if tabs.contains(tab) { tabs.remove(tab) } else { tabs.insert(tab) }
            }
            footer(back: 0, next: "Continue") { store.welcomeStep = 2 }
        }
    }

    // MARK: Step 3

    private var connect: some View {
        Group {
            header("What may Desk connect to?", "Both are optional. Desk never stores a password or a token.")
            VStack(spacing: t.sp8) {
                option("calendar", "My Mac's calendar", "Shows today's events. macOS asks for permission once.", $calendar)
                option("bubble.left.and.text.bubble.right", "Fill it in with Claude",
                       "Opens claude.ai with a ready request: Claude asks about your studies, projects and deadlines, and gives you each file to save.", $askClaude)
            }
            Text(verbatim: "Your desk is created in \(StarterVault.defaultPath). To back it up later, make that folder a private GitHub repository.")
                .style(\.small, \.inkMuted).fixedSize(horizontal: false, vertical: true)
            footer(back: 1, next: "Create my desk") {
                problem = store.startOwnDesk(name: name, tabs: tabs, calendar: calendar, askClaude: askClaude)
            }
        }
    }

    // MARK: Pieces

    private func header(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: t.sp8) {
            Text(verbatim: title).style(\.title, \.ink)
            Text(verbatim: text).style(\.body, \.inkMuted).lineSpacing(t.sp4).fixedSize(horizontal: false, vertical: true)
        }
    }

    private func footer(back: Int, next: String, action: @escaping () -> Void) -> some View {
        HStack {
            Button("Back") { store.welcomeStep = back }.buttonStyle(.deskSecondary)
            Spacer()
            Button(next, action: action).buttonStyle(.deskPrimary).keyboardShortcut(.defaultAction)
        }
    }

    private func option(_ symbol: String, _ title: String, _ hint: String, _ isOn: Binding<Bool>) -> some View {
        Button { isOn.wrappedValue.toggle() } label: {
            HStack(spacing: t.sp12) {
                badge(symbol, accent: isOn.wrappedValue ? .focus : .neutral)
                VStack(alignment: .leading, spacing: t.sp2) {
                    Text(verbatim: title).style(\.bodyStrong, \.ink)
                    Text(verbatim: hint).style(\.small, \.inkMuted).fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: isOn.wrappedValue ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: t.symbol, weight: .medium))
                    .foregroundStyle(isOn.wrappedValue ? t.focus : t.inkMuted)
            }
            .modifier(Row())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(verbatim: "\(title). \(hint)"))
        .accessibilityAddTraits(isOn.wrappedValue ? .isSelected : [])
    }

    private func choice(_ symbol: String, _ title: String, _ hint: String, accent: Accent, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: t.sp12) {
                badge(symbol, accent: accent)
                VStack(alignment: .leading, spacing: t.sp2) {
                    Text(verbatim: title).style(\.bodyStrong, \.ink)
                    Text(verbatim: hint).style(\.small, \.inkMuted)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.system(size: t.symbolSmall, weight: .bold)).foregroundStyle(t.inkMuted)
            }
            .modifier(Row())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(verbatim: "\(title). \(hint)"))
    }

    private func badge(_ symbol: String, accent: Accent) -> some View {
        Image(systemName: symbol)
            .font(.system(size: t.symbol, weight: .semibold))
            .foregroundStyle(t.ink)
            .frame(width: t.iconButton, height: t.iconButton)
            .background(t.tint(accent), in: Circle())
    }

    private struct Row: ViewModifier {
        @Environment(\.theme) private var t
        func body(content: Content) -> some View {
            content
                .padding(.horizontal, t.sp12)
                .padding(.vertical, t.sp10)
                .background(t.surface, in: RoundedRectangle(cornerRadius: t.radiusRow))
                .overlay(RoundedRectangle(cornerRadius: t.radiusRow).strokeBorder(t.line, lineWidth: t.hairline))
                .contentShape(Rectangle())
        }
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
