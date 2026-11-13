import SwiftUI

/// A stat card: glass washed with its accent, a title, figures, and one large shape in the accent,
/// anchored to a corner and clipped by the card. The shape drifts towards the pointer, which gives the card depth.
struct StatCard<Content: View>: View {
    @Environment(Store.self) private var store
    @Environment(\.theme) private var t
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// The pointer's place over the card, -1…1 from its centre.
    @State private var pointer = CGSize.zero
    @State private var size = CGSize.zero
    let title: String
    var subtitle: String?
    let accent: Accent
    let shape: CardShape
    var tall = false
    @ViewBuilder var content: Content

    var body: some View {
        let placement = shape.placement
        VStack(alignment: .leading, spacing: t.sp16) {
            HStack(alignment: .firstTextBaseline, spacing: t.sp10) {
                Text(verbatim: title).style(\.cardTitle).lineLimit(1)
                if let subtitle {
                    Text(verbatim: subtitle).style(\.small).opacity(t.captionOpacity).lineLimit(1)
                }
            }
            content
        }
        .foregroundStyle(t.on(accent))
        .padding(t.sp20)
        .frame(maxWidth: .infinity, minHeight: tall ? t.cardTall : t.cardShort, maxHeight: .infinity, alignment: .topLeading)
        .background(alignment: placement.anchor) {
            CardShapeView(shape: shape, color: t.fill(accent == .neutral ? .info : accent).opacity(t.shapeWash))
                .frame(width: placement.size.width, height: placement.size.height)
                .rotationEffect(.degrees(placement.degrees))
                .offset(placement.offset)
                .offset(x: pointer.width * t.parallax, y: pointer.height * t.parallax)
        }
        .background(LinearGradient(colors: t.wash(accent), startPoint: .topLeading, endPoint: .bottomTrailing))
        .clipShape(RoundedRectangle(cornerRadius: t.radiusCard))
        .glass()
        .onContinuousHover(coordinateSpace: .local) { phase in
            guard store.motion, !reduceMotion else { return }
            withAnimation(.spring(response: t.liftResponse, dampingFraction: t.liftDamping)) {
                switch phase {
                case .active(let point): pointer = CGSize(width: point.x / max(size.width, 1) * 2 - 1, height: point.y / max(size.height, 1) * 2 - 1)
                case .ended: pointer = .zero
                }
            }
        }
        .background(GeometryReader { proxy in Color.clear.onAppear { size = proxy.size }.onChange(of: proxy.size) { size = proxy.size } })
        .accessibilityElement(children: .contain)
        .accessibilityLabel(title)
    }
}

/// A big number with an uppercase caption. Units ("d", "h", "km") are drawn smaller.
struct Figure: View {
    struct Part: Hashable {
        let text: String
        var unit = false
    }

    @Environment(\.theme) private var t
    let parts: [Part]
    let caption: String

    init(_ value: String, unit: String? = nil, caption: String) {
        parts = [Part(text: value)] + (unit.map { [Part(text: $0, unit: true)] } ?? [])
        self.caption = caption
    }

    init(parts: [Part], caption: String) {
        self.parts = parts
        self.caption = caption
    }

    var body: some View {
        VStack(alignment: .leading, spacing: t.sp4 - t.hairline) {
            HStack(alignment: .firstTextBaseline, spacing: t.sp2) {
                ForEach(Array(parts.enumerated()), id: \.offset) { _, part in
                    // Digits roll to their new value when the number changes.
                    Text(verbatim: part.text).style(part.unit ? \.figureUnit : \.figure).contentTransition(.numericText())
                }
            }
            Text(verbatim: caption)
                .style(\.caption)
                .opacity(t.captionOpacity)
                .lineSpacing(t.sp2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .fixedSize()
        .deskAnimation(parts)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(verbatim: "\(parts.map(\.text).joined()) \(caption)"))
    }
}

/// A neutral card on `surface`, for content that is not a colour-block stat.
struct SurfaceCard<Content: View>: View {
    @Environment(\.theme) private var t
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(t.sp20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .glass()
    }
}

/// What sits at the left of a list row.
enum RowLeading {
    case symbol(String, Accent)
    case initials(String, Accent)
    /// A tick circle; tapping it calls `toggle`.
    case tick(done: Bool, toggle: (() -> Void)?)
}

/// A list row: icon badge, semibold title, muted subtitle, chip on the right.
/// It brightens under the pointer; the selected row is washed with the accent and edged in it.
struct ListRow<Trailing: View>: View {
    @Environment(\.theme) private var t
    @State private var hovering = false
    let leading: RowLeading
    let title: String
    var subtitle: String?
    var selected = false
    var done = false
    var action: (() -> Void)?
    @ViewBuilder var trailing: (_ selected: Bool) -> Trailing

    var body: some View {
        HStack(spacing: t.sp10 + t.hairline) {
            leadingView
            VStack(alignment: .leading, spacing: t.sp2) {
                Text(verbatim: title)
                    .style(\.rowTitle, selected ? \.onAccent : \.ink)
                    .strikethrough(done)
                    .lineLimit(1)
                if let subtitle, !subtitle.isEmpty {
                    Text(verbatim: subtitle)
                        .style(\.small, selected ? \.onAccent : \.inkMuted)
                        .opacity(selected ? t.captionOpacity : 1)
                        .lineLimit(1)
                }
            }
            .opacity(done ? t.pastOpacity : 1)
            Spacer(minLength: t.sp4)
            trailing(selected)
        }
        .padding(.leading, t.sp8 + t.hairline)
        .padding(.trailing, t.sp12)
        .frame(height: t.rowHeight)
        .background(selected ? t.selection : hovering && action != nil ? t.raised : t.surface, in: RoundedRectangle(cornerRadius: t.radiusRow))
        .overlay(RoundedRectangle(cornerRadius: t.radiusRow).strokeBorder(selected ? t.focus : .clear, lineWidth: t.hairline))
        .contentShape(RoundedRectangle(cornerRadius: t.radiusRow))
        .onHover { hovering = $0 }
        .deskAnimation(hovering)
        .onTapGesture { action?() }
        .accessibilityAction { action?() }
        .deskAnimation(selected)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }

    @ViewBuilder private var leadingView: some View {
        switch leading {
        case .symbol(let name, let accent):
            Badge(content: .symbol(name), accent: accent, onAccent: selected)
        case .initials(let text, let accent):
            Badge(content: .initials(text), accent: accent, onAccent: selected)
        case .tick(let isDone, let toggle):
            Button {
                toggle?()
            } label: {
                Badge(content: .symbol(isDone ? "checkmark.circle.fill" : "circle"), accent: isDone ? .good : .neutral, onAccent: selected)
            }
            .buttonStyle(.plain)
            .disabled(toggle == nil)
            .accessibilityLabel(Text(verbatim: isDone ? "Untick \(title)" : "Tick \(title)"))
        }
    }
}

extension ListRow where Trailing == EmptyView {
    init(leading: RowLeading, title: String, subtitle: String? = nil, selected: Bool = false, done: Bool = false, action: (() -> Void)? = nil) {
        self.init(leading: leading, title: title, subtitle: subtitle, selected: selected, done: done, action: action) { _ in EmptyView() }
    }
}

/// Initials for a badge: "Maya Chen · Corvid MedTech" → "MC".
func initials(of name: String) -> String {
    let words = name.split(whereSeparator: { !$0.isLetter && $0 != "." })
        .filter { !["Prof.", "Dr.", "Mr.", "Ms.", "Mrs."].contains(String($0)) }
    return words.prefix(2).compactMap(\.first).map { String($0).uppercased() }.joined()
}
