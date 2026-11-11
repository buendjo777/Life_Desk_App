import SwiftUI

/// Every colour, font size, radius and spacing value in the app lives here.
/// Views read tokens through `@Environment(\.theme)`; they never hold literals.
/// To restyle Desk, edit this file.
struct Theme {
    var scheme: ColorScheme = .light
    var density: Density = .compact

    private func pick(_ light: UInt32, _ dark: UInt32) -> Color {
        Color(hex: scheme == .dark ? dark : light)
    }

    // MARK: Palette (DESIGN.md)

    var canvas: Color { pick(0xECE8E1, 0x101215) }
    var panel: Color { pick(0x16181C, 0x08090B) }
    var primary: Color { pick(0x16181C, 0xECE8E1) }
    var onPrimary: Color { pick(0xECE8E1, 0x101215) }
    var control: Color { pick(0x16181C, 0x23272D) }
    var panelText: Color { Color(hex: 0xECE8E1) }
    var panelMuted: Color { pick(0x8C8A84, 0x77756F) }
    var surface: Color { pick(0xE2DDD4, 0x1A1D22) }
    var raised: Color { pick(0xF7F4EF, 0x23272D) }
    var line: Color { pick(0xD2CCC1, 0x2E333A) }
    var ink: Color { pick(0x16181C, 0xECE8E1) }
    var inkMuted: Color { pick(0x5F5D57, 0x9C9990) }
    var onAccent: Color { Color(hex: 0x16181C) }
    var ochre: Color { Color(hex: 0xD4A23F) }
    var ochreDeep: Color { Color(hex: 0xB4842A) }
    var rust: Color { Color(hex: 0xC8763C) }
    var rustDeep: Color { Color(hex: 0xA35A2A) }
    var steel: Color { Color(hex: 0x8EA6BE) }
    var steelDeep: Color { Color(hex: 0x6C88A5) }
    var moss: Color { Color(hex: 0x8A9A5B) }
    var mossDeep: Color { Color(hex: 0x6B7A41) }
    var navy: Color { pick(0x1F2C3B, 0x2A3B4F) }
    var navyDeep: Color { pick(0x101A26, 0x1B2836) }
    var alert: Color { pick(0xA8432F, 0xC9573F) }
    /// The sidebar and the round buttons get a hairline border in dark mode only.
    var panelBorder: Color { scheme == .dark ? line : .clear }
    /// The window's traffic lights, drawn only in offscreen snapshots.
    var lights: [Color] { [Color(hex: 0xFF5F57), Color(hex: 0xFEBC2E), Color(hex: 0x28C840)] }

    func fill(_ accent: Accent) -> Color {
        switch accent {
        case .ochre: ochre
        case .rust: rust
        case .steel: steel
        case .moss: moss
        case .navy: navy
        case .alert: alert
        case .neutral: surface
        }
    }

    func deep(_ accent: Accent) -> Color {
        switch accent {
        case .ochre: ochreDeep
        case .rust: rustDeep
        case .steel: steelDeep
        case .moss: mossDeep
        case .navy: navyDeep
        case .alert: alert
        case .neutral: line
        }
    }

    /// The soft tint behind chips and icon badges.
    func tint(_ accent: Accent) -> Color {
        accent == .neutral ? line.opacity(tintOpacity + tintOpacity) : fill(accent).opacity(tintOpacity)
    }

    /// Text colour on a card filled with the accent.
    func on(_ accent: Accent) -> Color {
        switch accent {
        case .navy, .alert: panelText
        case .neutral: ink
        default: onAccent
        }
    }

    // MARK: Opacity

    let tintOpacity = 0.32
    let shapeOpacity = 0.55
    let pastOpacity = 0.45
    let captionOpacity = 0.72
    let outOfMonthOpacity = 0.32
    let navIdleOpacity = 0.74
    let navSelectedFill = 0.07
    let panelBoxFill = 0.05
    let onAccentWash = 0.12
    let onAccentBlock = 0.82
    let onAccentTrack = 0.35
    /// How far a one-line label may shrink before it truncates (Comfortable density).
    let tightScale = 0.8

    // MARK: Type (DESIGN.md)

    var display: TextStyle { .init(size: 40, weight: .bold, tracking: -0.8) }
    var title: TextStyle { .init(size: 28, weight: .bold, tracking: -0.5) }
    var section: TextStyle { .init(size: 20, weight: .semibold, tracking: -0.2) }
    var brand: TextStyle { .init(size: 26, weight: .bold, tracking: -0.6) }
    var cardTitle: TextStyle { .init(size: 17, weight: .semibold) }
    var figure: TextStyle { .init(size: 26, weight: .bold, tracking: -0.4, monoDigits: true) }
    var figureUnit: TextStyle { .init(size: 15, weight: .semibold) }
    var bigFigure: TextStyle { .init(size: 44, weight: .bold, tracking: -1, monoDigits: true) }
    var body: TextStyle { .init(size: 14, weight: .regular) }
    var bodyStrong: TextStyle { .init(size: 14, weight: .semibold) }
    var rowTitle: TextStyle { .init(size: 13.5, weight: .semibold) }
    var nav: TextStyle { .init(size: 14, weight: .medium) }
    var small: TextStyle { .init(size: 12, weight: .medium) }
    var smallStrong: TextStyle { .init(size: 12, weight: .semibold) }
    var chip: TextStyle { .init(size: 11.5, weight: .semibold) }
    var caption: TextStyle { .init(size: 10, weight: .semibold, tracking: 0.7, uppercase: true) }
    var label: TextStyle { .init(size: 10.5, weight: .semibold, tracking: 0.9, uppercase: true) }
    var micro: TextStyle { .init(size: 10, weight: .semibold, monoDigits: true) }
    var mono: TextStyle { .init(size: 12, weight: .regular, monospaced: true) }
    var symbol: CGFloat { 15 }
    var symbolSmall: CGFloat { 12 }
    var symbolLarge: CGFloat { 18 }

    // MARK: Spacing (8-point grid; Comfortable multiplies by 1.25)

    private func scaled(_ value: CGFloat) -> CGFloat { (value * density.scale).rounded() }
    var sp2: CGFloat { 2 }
    var sp4: CGFloat { scaled(4) }
    var sp6: CGFloat { scaled(6) }
    var sp8: CGFloat { scaled(8) }
    var sp10: CGFloat { scaled(10) }
    var sp12: CGFloat { scaled(12) }
    var sp16: CGFloat { scaled(16) }
    var sp20: CGFloat { scaled(20) }
    var sp24: CGFloat { scaled(24) }
    var sp32: CGFloat { scaled(32) }

    // MARK: Radii

    let radiusCard: CGFloat = 24
    let radiusPanel: CGFloat = 20
    let radiusRow: CGFloat = 18
    let radiusEvent: CGFloat = 15
    let radiusNav: CGFloat = 12
    let radiusSmall: CGFloat = 6
    let radiusBar: CGFloat = 3

    // MARK: Sizes

    let designSize = CGSize(width: 1440, height: 900)
    let minWindow = CGSize(width: 1280, height: 800)
    let sidebarWidth: CGFloat = 232
    let sidebarInset: CGFloat = 12
    let railWidth: CGFloat = 336
    let columnGap: CGFloat = 24
    let navRow: CGFloat = 36
    /// Fixed in both densities: the sidebar keeps its width, so its insets do not scale.
    let navGap: CGFloat = 12
    let navIcon: CGFloat = 20
    let sidebarPadding: CGFloat = 14
    let navBar: CGFloat = 3
    let searchHeight: CGFloat = 46
    let iconButton: CGFloat = 44
    let statusChip: CGFloat = 36
    let badge: CGFloat = 34
    let badgeSmall: CGFloat = 30
    let dot: CGFloat = 7
    let calendarDot: CGFloat = 5
    let calendarCell: CGFloat = 33
    let calendarToday: CGFloat = 31
    let weekColumn: CGFloat = 40
    let eventCard: CGFloat = 47
    let timeColumn: CGFloat = 44
    let track: CGFloat = 8
    let hairline: CGFloat = 1
    let stroke: CGFloat = 2
    let runwayDot: CGFloat = 12
    let stripBar: CGFloat = 18
    let streakCell: CGFloat = 34
    let donut: CGFloat = 132
    let donutLine: CGFloat = 22
    let ring: CGFloat = 104
    let ringLine: CGFloat = 12
    let chartHeight: CGFloat = 150
    let boardCardMin: CGFloat = 96
    let uniColumns = 3
    let lightSize: CGFloat = 12
    let lightGap: CGFloat = 8
    let summaryWidth: CGFloat = 700
    let settingsWidth: CGFloat = 520
    let customiseSize = CGSize(width: 680, height: 640)
    /// The icon tile as a share of the canvas, and its corner as a share of the tile (macOS icon grid).
    let iconTile: CGFloat = 0.8
    let iconCorner: CGFloat = 0.225
    let shadowRadius: CGFloat = 18
    let shadowY: CGFloat = 6
    let shadowOpacity = 0.18

    var rowHeight: CGFloat { density == .compact ? 52 : 60 }
    var cardTall: CGFloat { scaled(214) }
    var cardShort: CGFloat { scaled(136) }
    /// Rows shown before "show all": Comfortable shows up to two fewer.
    var listRows: Int { density == .compact ? 6 : 4 }
    var todayRows: Int { density == .compact ? 3 : 2 }

    // MARK: Motion

    let motion: Double = 0.18

    // MARK: Timing

    let clockTick = 60
    let syncMinutes = 15
}

enum Density: String, CaseIterable, Codable, Identifiable {
    case compact, comfortable
    var id: String { rawValue }
    var scale: CGFloat { self == .compact ? 1 : 1.25 }
    var title: String { self == .compact ? "Compact" : "Comfortable" }
}

enum Accent: String, CaseIterable {
    case ochre, rust, steel, moss, navy, alert, neutral
}

struct TextStyle {
    var size: CGFloat
    var weight: Font.Weight
    var tracking: CGFloat = 0
    var uppercase = false
    var monoDigits = false
    var monospaced = false

    var font: Font {
        let base = Font.system(size: size, weight: weight, design: monospaced ? .monospaced : .default)
        return monoDigits ? base.monospacedDigit() : base
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

private struct ThemeKey: EnvironmentKey {
    static let defaultValue = Theme()
}

extension EnvironmentValues {
    var theme: Theme {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}

private struct Styled: ViewModifier {
    @Environment(\.theme) private var t
    let style: KeyPath<Theme, TextStyle>
    let color: KeyPath<Theme, Color>?

    func body(content: Content) -> some View {
        let s = t[keyPath: style]
        let styled = content
            .font(s.font)
            .tracking(s.tracking)
            .textCase(s.uppercase ? .uppercase : nil)
        if let color {
            styled.foregroundStyle(t[keyPath: color])
        } else {
            styled
        }
    }
}

extension View {
    /// Applies a type token and, optionally, a colour token.
    /// Without a colour the text inherits the foreground of its card.
    func style(_ style: KeyPath<Theme, TextStyle>, _ color: KeyPath<Theme, Color>? = nil) -> some View {
        modifier(Styled(style: style, color: color))
    }

    /// 180 ms ease-out on selection changes; nothing when Reduce Motion is on.
    func deskAnimation<V: Equatable>(_ value: V) -> some View {
        modifier(DeskAnimation(value: value))
    }
}

private struct DeskAnimation<V: Equatable>: ViewModifier {
    @Environment(\.theme) private var t
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let value: V

    func body(content: Content) -> some View {
        content.animation(reduceMotion ? nil : .easeOut(duration: t.motion), value: value)
    }
}
