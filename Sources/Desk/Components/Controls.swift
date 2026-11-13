import SwiftUI

// Small shared controls: chips, buttons, counted tabs, badges, progress bars, empty states.

/// A capsule chip, tinted with its accent. Status chips always say the status in words.
struct Chip: View {
    @Environment(\.theme) private var t
    let text: String
    var accent: Accent = .neutral
    /// On a selected (focus) row the chip sits on a dark wash instead of a tint.
    var onAccent = false

    var body: some View {
        Text(verbatim: text)
            .style(\.chip, onAccent ? \.onAccent : \.ink)
            .lineLimit(1)
            .padding(.horizontal, t.sp8 + t.hairline)
            .padding(.vertical, t.sp4)
            .background(onAccent ? t.onAccent.opacity(t.onAccentWash) : t.tint(accent), in: Capsule())
            .fixedSize()
    }
}

/// Primary: a `primary` capsule. Secondary: an outlined capsule.
struct DeskButtonStyle: ButtonStyle {
    enum Kind { case primary, secondary }
    @Environment(\.theme) private var t
    @Environment(\.isEnabled) private var isEnabled
    var kind: Kind = .primary

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .style(\.smallStrong, kind == .primary ? \.onPrimary : \.ink)
            .lineLimit(1)
            .padding(.horizontal, t.sp16 - t.hairline)
            .padding(.vertical, t.sp8)
            .background(kind == .primary ? t.primary : .clear, in: Capsule())
            .overlay(Capsule().strokeBorder(kind == .primary ? .clear : t.line, lineWidth: t.hairline))
            .opacity(!isEnabled ? t.pastOpacity : configuration.isPressed ? t.captionOpacity : 1)
            .contentShape(Capsule())
    }
}

extension ButtonStyle where Self == DeskButtonStyle {
    static var deskPrimary: DeskButtonStyle { DeskButtonStyle(kind: .primary) }
    static var deskSecondary: DeskButtonStyle { DeskButtonStyle(kind: .secondary) }
}

/// A 44 pt round `control` button with a symbol. Always carries a VoiceOver label.
struct IconButton: View {
    @Environment(\.theme) private var t
    let symbol: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: t.symbol, weight: .semibold))
                .foregroundStyle(t.panelText)
                .frame(width: t.iconButton, height: t.iconButton)
                .background(t.control, in: Circle())
                .overlay(Circle().strokeBorder(t.panelBorder, lineWidth: t.hairline))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .help(label)
    }
}

/// Capsule tabs with counts, e.g. "Focus 3 · Due 4 · Leftovers 3".
struct CountedTabs<ID: Hashable>: View {
    struct Item: Identifiable {
        let id: ID
        let title: String
        var count: Int?
    }

    @Environment(\.theme) private var t
    let items: [Item]
    @Binding var selection: ID

    var body: some View {
        HStack(spacing: t.sp6) {
            ForEach(items) { item in
                let active = item.id == selection
                Button {
                    selection = item.id
                } label: {
                    HStack(spacing: t.sp4) {
                        Text(verbatim: item.title)
                        if let count = item.count {
                            Text(verbatim: String(count)).opacity(t.captionOpacity)
                        }
                    }
                    .style(\.chip, active ? \.onPrimary : \.ink)
                    .padding(.horizontal, t.sp10)
                    .padding(.vertical, t.sp4 + t.hairline)
                    .background(active ? t.primary : .clear, in: Capsule())
                    .overlay(Capsule().strokeBorder(active ? .clear : t.line, lineWidth: t.hairline))
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(verbatim: item.count.map { "\(item.title), \($0)" } ?? item.title))
                .accessibilityAddTraits(active ? .isSelected : [])
            }
        }
        .fixedSize()
        .deskAnimation(selection)
    }
}

/// A round badge: a symbol or initials on an accent tint.
struct Badge: View {
    enum Content {
        case symbol(String)
        case initials(String)
    }

    @Environment(\.theme) private var t
    let content: Content
    var accent: Accent = .neutral
    var small = false
    /// On a selected (focus) row.
    var onAccent = false

    var body: some View {
        let size = small ? t.badgeSmall : t.badge
        Group {
            switch content {
            case .symbol(let name):
                Image(systemName: name).font(.system(size: small ? t.symbolSmall + t.sp2 : t.symbol, weight: .medium))
            case .initials(let text):
                Text(verbatim: text).style(\.chip)
            }
        }
        .foregroundStyle(onAccent ? t.onAccent : t.ink)
        .frame(width: size, height: size)
        .background(onAccent ? t.onAccent.opacity(t.onAccentWash) : t.tint(accent), in: Circle())
        .accessibilityHidden(true)
    }
}

/// An 8 pt capsule track with an accent fill.
struct ProgressBar: View {
    @Environment(\.theme) private var t
    /// 0…1.
    let value: Double
    var accent: Accent = .good
    /// On an accent card the track and fill are drawn in the card's ink.
    var onCard = false

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(onCard ? t.onAccent.opacity(t.onAccentWash + t.onAccentWash) : t.line)
                Capsule()
                    .fill(onCard ? t.onAccent.opacity(t.onAccentBlock) : t.fill(accent))
                    .frame(width: max(0, min(1, value)) * proxy.size.width)
            }
        }
        .frame(height: t.track)
        .accessibilityElement()
        .accessibilityLabel("Progress")
        .accessibilityValue(Text(verbatim: "\(Int((value * 100).rounded())) percent"))
    }
}

/// A labelled progress bar: label on the left, value on the right.
struct LabelledProgress: View {
    @Environment(\.theme) private var t
    let label: String
    let value: Double
    let valueText: String
    var accent: Accent = .good

    var body: some View {
        VStack(alignment: .leading, spacing: t.sp6) {
            HStack {
                Text(verbatim: label).style(\.smallStrong, \.ink)
                Spacer()
                Text(verbatim: valueText).style(\.small, \.inkMuted)
            }
            ProgressBar(value: value, accent: accent)
        }
    }
}

/// One muted line plus a hint, e.g. "No exam set — add one in desk/settings.json."
struct EmptyState: View {
    @Environment(\.theme) private var t
    let line: String
    var hint: String?

    var body: some View {
        VStack(alignment: .leading, spacing: t.sp4) {
            Text(verbatim: line).style(\.body, \.inkMuted)
            if let hint {
                Text(verbatim: hint).style(\.small, \.inkMuted)
            }
        }
        .padding(.horizontal, t.sp12)
        .padding(.vertical, t.sp12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(t.surface.opacity(t.pastOpacity), in: RoundedRectangle(cornerRadius: t.radiusRow))
    }
}

/// A section title with optional controls on the right.
struct SectionHeader<Trailing: View>: View {
    @Environment(\.theme) private var t
    let title: String
    var subtitle: String?
    @ViewBuilder var trailing: Trailing

    var body: some View {
        // Side by side when it fits; when the controls are too wide (Comfortable), they drop under the title.
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: t.sp10) {
                titles
                Spacer(minLength: t.sp8)
                trailing
            }
            VStack(alignment: .leading, spacing: t.sp8) {
                HStack(alignment: .firstTextBaseline, spacing: t.sp10) { titles }
                trailing
            }
        }
        .frame(maxWidth: .infinity, minHeight: t.sp32, alignment: .leading)
    }

    @ViewBuilder private var titles: some View {
        Text(verbatim: title).style(\.section, \.ink).lineLimit(1).fixedSize()
        if let subtitle {
            Text(verbatim: subtitle).style(\.small, \.inkMuted).lineLimit(1)
        }
    }
}

extension SectionHeader where Trailing == EmptyView {
    init(title: String, subtitle: String? = nil) {
        self.init(title: title, subtitle: subtitle) { EmptyView() }
    }
}

/// A scroll view on screen; plain content in offscreen snapshots, where scroll views cannot be drawn.
struct Scroller<Content: View>: View {
    @Environment(Store.self) private var store
    @ViewBuilder var content: Content

    var body: some View {
        if store.isSnapshot {
            Color.clear.overlay(alignment: .top) { content.fixedSize(horizontal: false, vertical: true) }.clipped()
        } else {
            ScrollView(.vertical, showsIndicators: false) { content }
        }
    }
}

/// A raised panel: the inspector, confirm cards, popovers. The only surfaces with a soft shadow.
struct RaisedPanel: ViewModifier {
    @Environment(\.theme) private var t
    var radius: CGFloat?
    var shadow = false

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius ?? t.radiusPanel)
        content
            .background(t.raised, in: shape)
            .overlay(shape.strokeBorder(t.line, lineWidth: t.hairline))
            .shadow(color: .black.opacity(shadow ? t.shadowOpacity : 0), radius: shadow ? t.shadowRadius : 0, y: shadow ? t.shadowY : 0)
    }
}

extension View {
    func raisedPanel(radius: CGFloat? = nil, shadow: Bool = false) -> some View {
        modifier(RaisedPanel(radius: radius, shadow: shadow))
    }
}

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
