import SwiftUI

/// A colourway: two strong colours (the field and the glow), one bright accent, and four signal colours.
/// Theme.swift turns these into the tokens the views read. To add a colourway, add a case here.
public enum Palette: String, CaseIterable, Codable, Identifiable {
    case ember, oxblood, saffron

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .ember: "Midnight Ember"
        case .oxblood: "Oxblood Marigold"
        case .saffron: "Ink Saffron"
        }
    }

    public struct Colors {
        /// The dark field, top to bottom, and the light one.
        public let field: [UInt32]
        public let fieldLight: [UInt32]
        /// Strong colour one: the sidebar and the primary button in light mode.
        public let deep: UInt32
        /// Strong colour two: the glow that rises from the bottom of the window.
        public let glow: UInt32
        public let glowLight: UInt32
        /// The bright accent: focus, selection and the full tide. On a light field its stand-in is `focusLight`.
        public let bright: UInt32
        public let focusLight: UInt32
        public let ink: UInt32
        public let muted: UInt32
        public let inkLight: UInt32
        public let mutedLight: UInt32
        /// Signals as (dark mode, light mode): light mode needs darker tones to stay legible on white glass.
        public let good: (UInt32, UInt32)
        public let caution: (UInt32, UInt32)
        public let alert: (UInt32, UInt32)
        public let info: (UInt32, UInt32)
    }

    public var colors: Colors {
        switch self {
        case .ember:
            Colors(field: [0x06051A, 0x0D0B38, 0x1B1668], fieldLight: [0xF3F1FF, 0xE4DEFF, 0xFFE0D6],
                   deep: 0x14124A, glow: 0xFF5A3C, glowLight: 0xFFAE99, bright: 0xE8FF6A, focusLight: 0xE8432A,
                   ink: 0xFFFFFF, muted: 0xDAD7F6, inkLight: 0x14124A, mutedLight: 0x4A4780,
                   good: (0x6EE7B7, 0x1F9D6B), caution: (0xFFD166, 0xB87D0A), alert: (0xFF7A7A, 0xD43D3D), info: (0x9CB8FF, 0x4B6FD6))
        case .oxblood:
            Colors(field: [0x0B0709, 0x1E0811, 0x4A0E22], fieldLight: [0xF6EEE8, 0xEFDDD6, 0xEBC7BF],
                   deep: 0x6E1230, glow: 0xC8324A, glowLight: 0xE9A0A0, bright: 0xFFC21A, focusLight: 0x9E1B3F,
                   ink: 0xFFF7F0, muted: 0xE6D5D0, inkLight: 0x1E0B12, mutedLight: 0x5A3A44,
                   good: (0x7FD6A0, 0x2B8F5A), caution: (0xFFA94D, 0xB86A0A), alert: (0xFF6B6B, 0xC93434), info: (0x8EC5FF, 0x3A78C2))
        case .saffron:
            Colors(field: [0x080A0C, 0x0A2A2C, 0x0E4D4F], fieldLight: [0xEEF3F0, 0xD9E9E3, 0xF7E3C0],
                   deep: 0x0E4D4F, glow: 0xE8742A, glowLight: 0xF7C56B, bright: 0xFF9E1B, focusLight: 0xC76A00,
                   ink: 0xF2FAF7, muted: 0xCBDFD9, inkLight: 0x0A1F20, mutedLight: 0x3F5C5A,
                   good: (0x5EEAD4, 0x0F8F7C), caution: (0xFFD166, 0xA87408), alert: (0xFF6B6B, 0xC93434), info: (0x93C5FD, 0x3B73C4))
        }
    }
}

extension UInt32 {
    private var rgb: (Double, Double, Double) {
        (Double((self >> 16) & 0xFF), Double((self >> 8) & 0xFF), Double(self & 0xFF))
    }

    private static func hex(_ r: Double, _ g: Double, _ b: Double) -> UInt32 {
        func channel(_ value: Double) -> UInt32 { UInt32(Swift.max(0, Swift.min(255, value.rounded()))) }
        return channel(r) << 16 | channel(g) << 8 | channel(b)
    }

    /// This colour moved `amount` (0…1) of the way to `other`.
    func mixed(with other: UInt32, _ amount: Double) -> UInt32 {
        let (a, b) = (rgb, other.rgb)
        let t = Swift.max(0, Swift.min(1, amount))
        return Self.hex(a.0 + (b.0 - a.0) * t, a.1 + (b.1 - a.1) * t, a.2 + (b.2 - a.2) * t)
    }

    /// A darker tone of this colour: `factor` 0.8 keeps 80% of each channel.
    func shaded(_ factor: Double) -> UInt32 {
        Self.hex(rgb.0 * factor, rgb.1 * factor, rgb.2 * factor)
    }
}
