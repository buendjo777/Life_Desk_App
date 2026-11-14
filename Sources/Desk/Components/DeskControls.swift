import SwiftUI

// Controls that need the Store or Derived. The shared ones live in DeskKit.

/// "+ 2 more" under a list: shows the hidden rows when clicked.
struct MoreLine: View {
    @Environment(\.theme) private var t
    let phrases: [Derived.Phrase]
    var action: (() -> Void)?

    var body: some View {
        Button {
            action?()
        } label: {
            PhraseText(phrases: phrases, style: \.smallStrong)
                .padding(.horizontal, t.sp4)
                .padding(.vertical, t.sp2)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(action == nil)
    }
}

/// A sentence built by code: strong pieces in ink, the rest muted.
struct PhraseText: View {
    @Environment(\.theme) private var t
    let phrases: [Derived.Phrase]
    var style: KeyPath<Theme, TextStyle> = \.body

    var body: some View {
        phrases.reduce(Text(verbatim: "")) { text, phrase in
            text + Text(verbatim: phrase.text)
                .foregroundStyle(phrase.strong ? t.ink : t.inkMuted)
                .fontWeight(phrase.strong ? .semibold : nil)
        }
        .font(t[keyPath: style].font)
    }
}

/// A status chip that opens a menu of the board's own status words. Not editable: the chip alone.
struct StatusMenu: View {
    @Environment(Store.self) private var store
    let label: String
    let accent: Accent
    let words: [String]
    let editable: Bool
    var onAccent = false
    let set: (String) -> Void

    var body: some View {
        let chip = Chip(text: label, accent: accent, onAccent: onAccent)
        if store.isSnapshot || !editable {
            chip
        } else {
            Menu {
                ForEach(words, id: \.self) { word in
                    Button {
                        set(word)
                    } label: {
                        if word == label { Label(word, systemImage: "checkmark") } else { Text(word) }
                    }
                }
            } label: {
                chip
            }
            // The button style keeps the chip drawn as the menu's face; borderless would flatten it to text.
            .menuStyle(.button)
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("Set the status")
            .accessibilityLabel(Text(verbatim: "Status: \(label). Change it"))
        }
    }
}
