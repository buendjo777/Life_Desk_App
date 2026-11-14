import SwiftUI

/// Every colour, font size, radius and spacing value in the app lives here.
/// Views read tokens through `@Environment(\.theme)`; they never hold literals.
/// To restyle Desk, edit this file.
public struct Theme {
    public var scheme: ColorScheme = .light
    public var density: Density = .compact
    public var palette: Palette = .ember
    /// Opaque surfaces instead of glass: Reduce Transparency or Increase Contrast is on.
    public var solid = false

    public init(scheme: ColorScheme = .light, density: Density = .compact, palette: Palette = .ember, solid: Bool = false) {
        self.scheme = scheme
        self.density = density
        self.palette = palette
        self.solid = solid
    }

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
    public var canvas: Color { pick(c.fieldLight[0], c.field[0]) }
    public var panel: Color { Color(hex: isDark ? c.field[0] : c.deep).opacity(solid ? 1 : isDark ? panelGlassDark : panelGlassLight) }
    public var primary: Color { pick(c.deep, c.bright) }
    public var onPrimary: Color { pick(0xFFFFFF, c.field[0]) }
    public var control: Color { isDark ? Color(hex: c.field[2]).opacity(solid ? 1 : raisedGlass) : Color(hex: c.deep) }
    /// A selected row: lighter in light mode, where a strong wash would read as an error.
    private var selectionStrength: Double { isDark ? selectionWash : selectionWash * 0.6 }
    public var panelText: Color { Color(hex: c.ink) }
    public var panelMuted: Color { Color(hex: c.muted).opacity(captionOpacity) }
    /// Glass: a card or row over the backdrop.
    public var surface: Color {
        if solid { return pick(0xFFFFFF, c.field[1]) }
        // Dark glass is smoked, not frosted: it keeps text legible where the glow sits behind a card.
        return isDark ? Color(hex: c.field[0]).opacity(surfaceGlassDark) : Color.white.opacity(surfaceGlassLight)
    }
    /// Brighter glass: search field, event cards, hover.
    public var raised: Color {
        if solid { return pick(0xFFFFFF, c.field[2]) }
        return isDark ? Color(hex: c.field[1].mixed(with: c.field[2], 0.6)).opacity(raisedGlass) : Color.white.opacity(raisedGlassLight)
    }
    /// Opaque: panels that float over other content (the inspector, search results, popovers).
    public var floating: Color { pick(0xFFFFFF, c.field[1].mixed(with: c.field[2], 0.5)) }
    public var line: Color { isDark ? Color.white.opacity(lineGlass) : Color(hex: c.inkLight).opacity(lineGlass) }
    /// The light edge on glass: brighter at the top, as if lit from above.
    public var glassEdge: Color { Color.white.opacity(isDark ? edgeGlassDark : edgeGlassLight) }
    public var ink: Color { pick(c.inkLight, c.ink) }
    public var inkMuted: Color { pick(c.mutedLight, c.muted) }
    /// Text on a tinted glass card: the same ink as everywhere else.
    public var onAccent: Color { ink }
    /// The bright accent: today, selection, the one thing to look at.
    public var focus: Color { pick(c.focusLight, c.bright) }
    public var focusDeep: Color { pick(c.focusLight.shaded(deepShade), c.bright.shaded(deepShade)) }
    /// Text on a solid `focus` fill.
    public var onFocus: Color { pick(0xFFFFFF, c.field[0]) }
    /// A selected row: glass washed with the accent.
    public var selection: Color { focus.opacity(selectionStrength) }
    public var caution: Color { signal(c.caution) }
    public var cautionDeep: Color { signal(c.caution, shade: deepShade) }
    public var info: Color { signal(c.info) }
    public var infoDeep: Color { signal(c.info, shade: deepShade) }
    public var good: Color { signal(c.good) }
    public var goodDeep: Color { signal(c.good, shade: deepShade) }
    public var deep: Color { pick(c.deep, c.field[2]) }
    public var deepDeep: Color { pick(c.deep.shaded(deepShade), c.field[1]) }
    public var alert: Color { signal(c.alert) }
    /// The sidebar and the round buttons get a hairline border.
    public var panelBorder: Color { isDark ? line : .clear }
    /// The window's traffic lights, drawn only in offscreen snapshots.
    public var lights: [Color] { [Color(hex: 0xFF5F57), Color(hex: 0xFEBC2E), Color(hex: 0x28C840)] }

    public func fill(_ accent: Accent) -> Color {
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

    public func deep(_ accent: Accent) -> Color {
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
    public func tint(_ accent: Accent) -> Color {
        accent == .neutral ? line.opacity(tintOpacity + tintOpacity) : fill(accent).opacity(tintOpacity)
    }

    /// Text colour on a card washed with the accent.
    public func on(_ accent: Accent) -> Color { ink }

    /// The wash of a stat card: the accent fading across the glass, top left to bottom right.
    public func wash(_ accent: Accent) -> [Color] {
        accent == .neutral ? [.clear, .clear] : [fill(accent).opacity(isDark ? washStrongDark : washStrong), fill(accent).opacity(washFaint)]
    }

    /// The big shape in a stat card: a hint of the accent, never a block of colour.
    public func shape(_ accent: Accent) -> Color {
        fill(accent == .neutral ? .info : accent).opacity(isDark ? shapeWashDark : shapeWash)
    }

    // MARK: Backdrop (Shell/Backdrop.swift)

    public var fieldStops: [Color] { (isDark ? c.field : c.fieldLight).map { Color(hex: $0) } }
    /// Two slow drifts of colour in the field.
    public var auroraCool: Color { Color(hex: isDark ? c.field[2].mixed(with: c.info.0, 0.25) : c.info.0).opacity(isDark ? 0.50 : 0.28) }
    public var auroraWarm: Color { Color(hex: isDark ? c.glow : c.glowLight).opacity(isDark ? 0.14 : 0.30) }
    /// The day's tide: the second strong colour, rising and brightening as today's work gets done.
    public func tide(_ progress: Double) -> Color {
        Color(hex: isDark ? c.glow : c.glowLight).opacity(tideFloor + tideGain * progress)
    }
    /// The tide's core: the bright accent, a sun on the horizon that only shows once work is being done.
    public func tideCore(_ progress: Double) -> Color {
        Color(hex: isDark ? c.bright : c.focusLight.mixed(with: c.glowLight, 0.4)).opacity(tideCoreGain * progress)
    }
    /// The ribs of the fluted glass: a shadow line and a highlight per rib.
    public var fluteShadow: Color { Color.black.opacity(isDark ? 0.16 : 0.035) }
    public var fluteLight: Color { Color.white.opacity(isDark ? 0.045 : 0.22) }
    /// The column of light at the current time of day.
    public var nowLight: Color { Color.white.opacity(isDark ? 0.10 : 0.35) }

    // MARK: Glass

    public let surfaceGlassDark = 0.50
    public let surfaceGlassLight = 0.66
    public let raisedGlass = 0.72
    public let raisedGlassLight = 0.88
    public let panelGlassDark = 0.55
    public let panelGlassLight = 0.94
    public let lineGlass = 0.13
    public let edgeGlassDark = 0.24
    public let edgeGlassLight = 0.95
    public let selectionWash = 0.20
    public let washStrong = 0.20
    /// Bright accents over a dark field turn muddy when strong, so the wash is lighter there.
    public let washStrongDark = 0.13
    public let washFaint = 0.03
    public let shapeWash = 0.16
    public let shapeWashDark = 0.11
    public let deepShade = 0.78
    public let tideFloor = 0.55
    public let tideGain = 0.30
    public let tideCoreGain = 0.55

    // MARK: Opacity

    public let tintOpacity = 0.32
    public let shapeOpacity = 0.55
    public let pastOpacity = 0.6
    public let captionOpacity = 0.72
    public let outOfMonthOpacity = 0.32
    public let navIdleOpacity = 0.74
    public let navSelectedFill = 0.07
    public let panelBoxFill = 0.05
    public let onAccentWash = 0.12
    public let onAccentBlock = 0.82
    public let onAccentTrack = 0.35
    /// How far a one-line label may shrink before it truncates (Comfortable density).
    public let tightScale = 0.8

    // MARK: Type (DESIGN.md)

    public var display: TextStyle { .init(size: 42, weight: .semibold, tracking: -0.6, serif: true) }
    public var title: TextStyle { .init(size: 30, weight: .semibold, tracking: -0.4, serif: true) }
    public var section: TextStyle { .init(size: 20, weight: .semibold, tracking: -0.2) }
    public var brand: TextStyle { .init(size: 27, weight: .semibold, tracking: -0.4, serif: true) }
    public var cardTitle: TextStyle { .init(size: 17, weight: .semibold) }
    public var figure: TextStyle { .init(size: 26, weight: .bold, tracking: -0.4, monoDigits: true) }
    public var figureUnit: TextStyle { .init(size: 15, weight: .semibold) }
    public var bigFigure: TextStyle { .init(size: 44, weight: .bold, tracking: -1, monoDigits: true) }
    public var body: TextStyle { .init(size: 14, weight: .regular) }
    public var bodyStrong: TextStyle { .init(size: 14, weight: .semibold) }
    public var rowTitle: TextStyle { .init(size: 13.5, weight: .semibold) }
    public var nav: TextStyle { .init(size: 14, weight: .medium) }
    public var small: TextStyle { .init(size: 12, weight: .medium) }
    public var smallStrong: TextStyle { .init(size: 12, weight: .semibold) }
    public var chip: TextStyle { .init(size: 11.5, weight: .semibold) }
    public var caption: TextStyle { .init(size: 10, weight: .semibold, tracking: 0.7, uppercase: true) }
    public var label: TextStyle { .init(size: 10.5, weight: .semibold, tracking: 0.9, uppercase: true) }
    public var micro: TextStyle { .init(size: 10, weight: .semibold, monoDigits: true) }
    public var mono: TextStyle { .init(size: 12, weight: .regular, monospaced: true) }
    public var symbol: CGFloat { 15 }
    public var symbolSmall: CGFloat { 12 }
    public var symbolLarge: CGFloat { 18 }

    // MARK: Spacing (8-point grid; Comfortable multiplies by 1.25)

    private func scaled(_ value: CGFloat) -> CGFloat { (value * density.scale).rounded() }
    public var sp2: CGFloat { 2 }
    public var sp4: CGFloat { scaled(4) }
    public var sp6: CGFloat { scaled(6) }
    public var sp8: CGFloat { scaled(8) }
    public var sp10: CGFloat { scaled(10) }
    public var sp12: CGFloat { scaled(12) }
    public var sp16: CGFloat { scaled(16) }
    public var sp20: CGFloat { scaled(20) }
    public var sp24: CGFloat { scaled(24) }
    public var sp32: CGFloat { scaled(32) }

    // MARK: Radii

    public let radiusCard: CGFloat = 24
    public let radiusPanel: CGFloat = 20
    public let radiusRow: CGFloat = 18
    public let radiusEvent: CGFloat = 15
    public let radiusNav: CGFloat = 12
    public let radiusSmall: CGFloat = 6
    public let radiusBar: CGFloat = 3

    // MARK: Sizes

    public let designSize = CGSize(width: 1440, height: 900)
    public let minWindow = CGSize(width: 1280, height: 800)
    public let sidebarWidth: CGFloat = 232
    public let sidebarInset: CGFloat = 12
    public let railWidth: CGFloat = 336
    public let columnGap: CGFloat = 24
    public let navRow: CGFloat = 36
    /// Fixed in both densities: the sidebar keeps its width, so its insets do not scale.
    public let navGap: CGFloat = 12
    public let navIcon: CGFloat = 20
    public let sidebarPadding: CGFloat = 14
    public let navBar: CGFloat = 3
    public let searchHeight: CGFloat = 46
    public let iconButton: CGFloat = 44
    public let statusChip: CGFloat = 36
    public let badge: CGFloat = 34
    public let badgeSmall: CGFloat = 30
    public let dot: CGFloat = 7
    public let calendarDot: CGFloat = 5
    public let calendarCell: CGFloat = 33
    public let calendarToday: CGFloat = 31
    public let weekColumn: CGFloat = 40
    public let eventCard: CGFloat = 47
    public let timeColumn: CGFloat = 44
    public let track: CGFloat = 8
    public let hairline: CGFloat = 1
    public let stroke: CGFloat = 2
    public let runwayDot: CGFloat = 12
    public let stripBar: CGFloat = 18
    public let streakCell: CGFloat = 34
    public let donut: CGFloat = 132
    public let donutLine: CGFloat = 22
    public let ring: CGFloat = 104
    public let ringLine: CGFloat = 12
    public let chartHeight: CGFloat = 150
    public let boardCardMin: CGFloat = 96
    public let uniColumns = 3
    public let lightSize: CGFloat = 12
    public let lightGap: CGFloat = 8
    public let summaryWidth: CGFloat = 700
    public let settingsWidth: CGFloat = 520
    public let customiseSize = CGSize(width: 680, height: 640)
    /// The icon tile as a share of the canvas, and its corner as a share of the tile (macOS icon grid).
    public let iconTile: CGFloat = 0.8
    public let iconCorner: CGFloat = 0.225
    public let shadowRadius: CGFloat = 18
    public let shadowY: CGFloat = 6
    public let shadowOpacity = 0.18

    public var rowHeight: CGFloat { density == .compact ? 52 : 60 }
    public var cardTall: CGFloat { scaled(214) }
    public var cardShort: CGFloat { scaled(136) }
    /// Rows shown before "show all": Comfortable shows up to two fewer.
    public var listRows: Int { density == .compact ? 6 : 4 }
    public var todayRows: Int { density == .compact ? 3 : 2 }

    // MARK: Motion

    public let motion: Double = 0.18
    /// Hover: a card rises a little and its shadow grows.
    public let liftScale = 1.012
    public let liftRise: CGFloat = 2
    public let liftResponse = 0.3
    public let liftDamping = 0.8
    /// The shape inside a stat card drifts this far towards the pointer.
    public let parallax: CGFloat = 10
    /// Sections fade up one after another when a tab opens.
    public let entranceRise: CGFloat = 12
    public let entrance = 0.36
    public let entranceStagger = 0.045
    public let entranceMaxDelay = 0.27
    /// Bars and rings fill when they appear.
    public let fillIn = 0.7
    /// A tick: eight sparks fly out.
    public let sparks = 8
    public let sparkSize: CGFloat = 4
    public let sparkReach: CGFloat = 20
    public let sparkTime = 0.5
    /// The backdrop: frames per second, the width of a glass rib, how fast the colours drift.
    public let backdropFPS = 20.0
    public let flute: CGFloat = 18
    public let nowRibs: CGFloat = 3
    public let drift = 1.0
    public let driftUrgent = 1.7
    /// The tide a snapshot is drawn with (the demo has no ticks made "today").
    public let showcaseTide = 0.6
    public let tideSettle = 1.4

    // MARK: Timing

    public let clockTick = 60
    public let syncMinutes = 15
}

public enum Density: String, CaseIterable, Codable, Identifiable {
    case compact, comfortable
    public var id: String { rawValue }
    public var scale: CGFloat { self == .compact ? 1 : 1.25 }
    public var title: String { self == .compact ? "Compact" : "Comfortable" }
}

public enum Accent: String, CaseIterable {
    case caution, focus, info, good, deep, alert, neutral
}

public struct TextStyle {
    public var size: CGFloat
    public var weight: Font.Weight
    public var tracking: CGFloat = 0
    public var uppercase = false
    public var monoDigits = false
    public var monospaced = false
    /// Headlines are set in the system serif (New York).
    public var serif = false

    public init(size: CGFloat, weight: Font.Weight, tracking: CGFloat = 0, uppercase: Bool = false,
                monoDigits: Bool = false, monospaced: Bool = false, serif: Bool = false) {
        self.size = size
        self.weight = weight
        self.tracking = tracking
        self.uppercase = uppercase
        self.monoDigits = monoDigits
        self.monospaced = monospaced
        self.serif = serif
    }

    public var font: Font {
        let base = Font.system(size: size, weight: weight, design: monospaced ? .monospaced : serif ? .serif : .default)
        return monoDigits ? base.monospacedDigit() : base
    }
}

public extension Color {
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

public extension EnvironmentValues {
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

public extension View {
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
