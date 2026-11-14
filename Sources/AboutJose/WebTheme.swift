import SwiftUI
import DeskKit

/// `AboutJose --web-theme` prints the colours of every colourway, light and dark, as JSON.
/// `scripts/build-web.sh` hands them to the web page, so the page and the app never drift apart.
@MainActor
enum WebTheme {
    static func run() {
        var palettes: [String: Any] = [:]
        for palette in Palette.allCases {
            var schemes: [String: Any] = [:]
            for scheme in [ColorScheme.light, .dark] {
                schemes[scheme == .dark ? "dark" : "light"] = colors(Theme(scheme: scheme, palette: palette))
            }
            palettes[palette.rawValue] = ["title": palette.title, "schemes": schemes]
        }
        let story = Theme()
        let export: [String: Any] = [
            "order": Palette.allCases.map(\.rawValue),
            "palettes": palettes,
            "tideStart": story.tideStart,
            "ecg": ["seconds": story.ecgSeconds, "grid": story.ecgGrid, "baseline": story.ecgBaseline, "gain": story.ecgGain],
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: export, options: [.sortedKeys]) else { exit(1) }
        FileHandle.standardOutput.write(data)
        FileHandle.standardOutput.write(Data("\n".utf8))
    }

    /// Every colour as [red, green, blue, alpha]: 0…255 for the first three, 0…1 for alpha.
    private static func colors(_ t: Theme) -> [String: Any] {
        [
            "canvas": rgba(t.canvas),
            "field": t.fieldStops.map(rgba),
            "auroraCool": rgba(t.auroraCool),
            "auroraWarm": rgba(t.auroraWarm),
            "tideLow": rgba(t.tide(0)),
            "tideHigh": rgba(t.tide(1)),
            "tideCore": rgba(t.tideCore(1)),
            "surface": rgba(t.surface),
            "raised": rgba(t.raised),
            "line": rgba(t.line),
            "edge": rgba(t.glassEdge),
            "ink": rgba(t.ink),
            "muted": rgba(t.inkMuted),
            "focus": rgba(t.focus),
            "onFocus": rgba(t.onFocus),
            "selection": rgba(t.selection),
            "primary": rgba(t.primary),
            "onPrimary": rgba(t.onPrimary),
            "control": rgba(t.control),
            "controlInk": rgba(t.panelText),
            "tint": rgba(t.tint(.neutral)),
            "tintFocus": rgba(t.tint(.focus)),
            "tintCaution": rgba(t.tint(.caution)),
            "shape": rgba(t.shape(.neutral)),
            "deep": rgba(t.deep),
        ]
    }

    private static func rgba(_ color: Color) -> [Double] {
        guard let c = NSColor(color).usingColorSpace(.sRGB) else { return [0, 0, 0, 1] }
        func channel(_ value: CGFloat) -> Double { (Double(value) * 255).rounded() }
        return [channel(c.redComponent), channel(c.greenComponent), channel(c.blueComponent), (Double(c.alphaComponent) * 1000).rounded() / 1000]
    }
}
