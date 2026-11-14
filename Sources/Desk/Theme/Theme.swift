import SwiftUI

/// Every colour, font size, radius and spacing value in the app lives here.
/// Views read tokens through `@Environment(\.theme)`; they never hold literals.
/// To restyle Desk, edit this file.
struct Theme {
    var scheme: ColorScheme = .light
    var density: Density = .compact
    var palette: Palette = .ember
    /// Opaque surfaces instead of glass: Reduce Transparency or Increase Contrast is on.
    var solid = false

    private var c: Palette.Colors { palette.colors }
    private var isDark: Bool { scheme == .dark }

    private func pick(_ light: UInt32, _ dark: UInt32) -> Color {
        Color(hex: isDark ? dark : light)
    }

    /// A signal colour, given as (dark mode, light mode).
    private func signal(_ pair: (UInt32, UInt32), shade: Double = 1) -> Color {
        Color(hex: (isDark ? pair.0 : pair.1).shaded(shade))
    }

    // MARK: Palette (Palette.swift holds the hex values; DESIGN.md explains the roles)

    /// The flat colour under the backdrop, and behind sheets.
    var canvas: Color { pick(c.fieldLight[0], c.field[0]) }
    var panel: Color { Color(hex: isDark ? c.field[0] : c.deep).opacity(solid ? 1 : isDark ? panelGlassDark : panelGlassLight) }
    /// The slim sidebar while it is open over the page: nearly solid, so the text behind does not show through.
    var panelOpen: Color { Color(hex: isDark ? c.field[0] : c.deep).opacity(solid ? 1 : sidebarOpenGlass) }
    /// The main button: a white pill on the dark field, a dark one on the light field.
    var primary: Color { ink }
    var onPrimary: Color { pick(0xFFFFFF, c.field[0]) }
    var control: Color { isDark ? Color(hex: c.field[2]).opacity(solid ? 1 : raisedGlass) : Color(hex: c.deep) }
    /// A selected row: lighter in light mode, where a strong wash would read as an error.
    private var selectionStrength: Double { isDark ? selectionWash : selectionWash * 0.6 }
    var panelText: Color { Color(hex: c.ink) }
    var panelMuted: Color { Color(hex: c.muted).opacity(captionOpacity) }
    /// Glass: a card or row over the backdrop.
    var surface: Color {
        if solid { return pick(0xFFFFFF, c.field[1]) }
        // Dark glass is smoked, not frosted: it keeps text legible where the glow sits behind a card.
        return isDark ? Color(hex: c.field[0]).opacity(surfaceGlassDark) : Color.white.opacity(surfaceGlassLight)
    }
    /// Brighter glass: search field, event cards, hover.
    var raised: Color {
        if solid { return pick(0xFFFFFF, c.field[2]) }
        return isDark ? Color(hex: c.field[1].mixed(with: c.field[2], 0.6)).opacity(raisedGlass) : Color.white.opacity(raisedGlassLight)
    }
    /// Opaque: panels that float over other content (the inspector, search results, popovers).
    var floating: Color { pick(0xFFFFFF, c.field[1].mixed(with: c.field[2], 0.5)) }
    var line: Color { isDark ? Color.white.opacity(lineGlass) : Color(hex: c.inkLight).opacity(lineGlass) }
    /// The light edge on glass: brighter at the top, as if lit from above.
    var glassEdge: Color { Color.white.opacity(isDark ? edgeGlassDark : edgeGlassLight) }
    var ink: Color { pick(c.inkLight, c.ink) }
    var inkMuted: Color { pick(c.mutedLight, c.muted) }
    /// Text on a tinted glass card: the same ink as everywhere else.
    var onAccent: Color { ink }
    /// The bright accent: today, selection, the one thing to look at.
    var focus: Color { pick(c.focusLight, c.bright) }
    var focusDeep: Color { pick(c.focusLight.shaded(deepShade), c.bright.shaded(deepShade)) }
    /// Text on a solid `focus` fill.
    var onFocus: Color { pick(0xFFFFFF, c.field[0]) }
    /// A selected row: glass washed with the accent.
    var selection: Color { focus.opacity(selectionStrength) }
    var caution: Color { signal(c.caution) }
    var cautionDeep: Color { signal(c.caution, shade: deepShade) }
    var info: Color { signal(c.info) }
    var infoDeep: Color { signal(c.info, shade: deepShade) }
    var good: Color { signal(c.good) }
    var goodDeep: Color { signal(c.good, shade: deepShade) }
    var deep: Color { pick(c.deep, c.field[2]) }
    var deepDeep: Color { pick(c.deep.shaded(deepShade), c.field[1]) }
    var alert: Color { signal(c.alert) }
    /// The sidebar and the round buttons get a hairline border.
    var panelBorder: Color { isDark ? line : .clear }
    /// The window's traffic lights, drawn only in offscreen snapshots.
    var lights: [Color] { [Color(hex: 0xFF5F57), Color(hex: 0xFEBC2E), Color(hex: 0x28C840)] }

    func fill(_ accent: Accent) -> Color {
        switch accent {
        case .caution: caution
        case .focus: focus
        case .info: info
        case .good: good
        case .deep: deep
        case .alert: alert
        case .neutral: surface
        }
    }

    func deep(_ accent: Accent) -> Color {
        switch accent {
        case .caution: cautionDeep
        case .focus: focusDeep
        case .info: infoDeep
        case .good: goodDeep
        case .deep: deepDeep
        case .alert: alert
        case .neutral: line
        }
    }

    /// The soft tint behind chips and icon badges.
    func tint(_ accent: Accent) -> Color {
        accent == .neutral ? line.opacity(tintOpacity + tintOpacity) : fill(accent).opacity(tintOpacity)
    }

    /// Text colour on a card washed with the accent.
    func on(_ accent: Accent) -> Color { ink }

    /// The wash of a stat card: the accent fading across the glass, top left to bottom right.
    func wash(_ accent: Accent) -> [Color] {
        accent == .neutral ? [.clear, .clear] : [fill(accent).opacity(isDark ? washStrongDark : washStrong), .clear]
    }

    /// The big shape in a stat card: a watermark in the ink, the same on every card.
    func shape(_ accent: Accent) -> Color {
        ink.opacity(shapeWash)
    }

    // MARK: Backdrop (Shell/Backdrop.swift)

    var fieldStops: [Color] { (isDark ? c.field : c.fieldLight).map { Color(hex: $0) } }
    /// Two slow drifts of colour in the field.
    var auroraCool: Color { Color(hex: isDark ? c.field[2].mixed(with: c.info.0, 0.45) : c.info.0).opacity(isDark ? 0.42 : 0.22) }
    var auroraWarm: Color { Color(hex: isDark ? c.glow : c.glowLight).opacity(isDark ? 0.07 : 0.22) }
    /// The day's tide: the second strong colour, rising and brightening as today's work gets done.
    func tide(_ progress: Double) -> Color {
        Color(hex: isDark ? c.glow : c.glowLight).opacity(tideFloor + tideGain * progress)
    }
    /// The tide's core: the bright accent, a sun on the horizon that only shows once work is being done.
    func tideCore(_ progress: Double) -> Color {
        Color(hex: isDark ? c.bright : c.focusLight.mixed(with: c.glowLight, 0.4)).opacity(tideCoreGain * progress)
    }
    // MARK: Glass

    let surfaceGlassDark = 0.50
    let surfaceGlassLight = 0.66
    let raisedGlass = 0.72
    let raisedGlassLight = 0.88
    let panelGlassDark = 0.55
    let panelGlassLight = 0.94
    let lineGlass = 0.13
    let edgeGlassDark = 0.24
    let edgeGlassLight = 0.95
    let selectionWash = 0.20
    /// A whisper of the card's accent in one corner; the cards are otherwise the same neutral glass.
    let washStrong = 0.10
    let washStrongDark = 0.06
    let shapeWash = 0.04
    let deepShade = 0.78
    let tideFloor = 0.34
    let tideGain = 0.30
    let tideCoreGain = 0.40

    // MARK: Opacity

    let tintOpacity = 0.32
    let shapeOpacity = 0.55
    let pastOpacity = 0.6
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

    var display: TextStyle { .init(size: 40, weight: .semibold, tracking: -1.1) }
    var title: TextStyle { .init(size: 28, weight: .semibold, tracking: -0.7) }
    var section: TextStyle { .init(size: 20, weight: .semibold, tracking: -0.2) }
    var brand: TextStyle { .init(size: 24, weight: .semibold, tracking: -0.6) }
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
    /// The slim sidebar: icons only, until the pointer is over it.
    let sidebarSlim: CGFloat = 76
    let sidebarOpenGlass = 0.94
    let sidebarDamping = 0.86
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
    /// Hover: a card rises a little and its shadow grows.
    let liftScale = 1.012
    let liftRise: CGFloat = 2
    let liftResponse = 0.3
    let liftDamping = 0.8
    /// The shape inside a stat card drifts this far towards the pointer.
    let parallax: CGFloat = 10
    /// Sections fade up one after another when a tab opens.
    let entranceRise: CGFloat = 12
    let entrance = 0.36
    let entranceStagger = 0.045
    let entranceMaxDelay = 0.27
    /// Bars and rings fill when they appear.
    let fillIn = 0.7
    /// A tick: eight sparks fly out.
    let sparks = 8
    let sparkSize: CGFloat = 4
    let sparkReach: CGFloat = 20
    let sparkTime = 0.5
    /// The backdrop: frames per second, and how fast the colours drift.
    let backdropFPS = 20.0
    let drift = 1.0
    let driftUrgent = 1.7
    /// The tide a snapshot is drawn with (the demo has no ticks made "today").
    let showcaseTide = 0.6
    let tideSettle = 1.4

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
    case caution, focus, info, good, deep, alert, neutral
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
