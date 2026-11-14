import SwiftUI

// The two layers of the window background. Each app decides what the tide and the column of light mean:
// in Desk, today's work and the time of day.

/// The field and the tide. `tide` is animatable, so a tick makes the glow rise smoothly instead of jumping.
public struct BackdropField: View, Animatable {
    @Environment(\.theme) private var t
    var tide: Double
    let speed: Double
    let moving: Bool

    /// `tide` 0…1: how high the glow stands. `speed`: how fast the colours drift. `moving`: false draws one still frame.
    public init(tide: Double, speed: Double = 1, moving: Bool) {
        self.tide = tide
        self.speed = speed
        self.moving = moving
    }

    public var animatableData: Double {
        get { tide }
        set { tide = newValue }
    }

    public var body: some View {
        if moving {
            TimelineView(.animation(minimumInterval: 1 / t.backdropFPS)) { timeline in
                canvas(time: timeline.date.timeIntervalSinceReferenceDate * speed)
            }
        } else {
            canvas(time: 0)
        }
    }

    private func canvas(time: Double) -> some View {
        Canvas(rendersAsynchronously: true) { context, size in
            Self.draw(&context, size: size, time: time, tide: tide, theme: t)
        }
    }

    /// Pure drawing: the same inputs give the same picture, so snapshots are stable.
    public static func draw(_ context: inout GraphicsContext, size: CGSize, time: Double, tide: Double, theme t: Theme) {
        let (w, h) = (size.width, size.height)
        context.fill(Path(CGRect(origin: .zero, size: size)),
                     with: .linearGradient(Gradient(colors: t.fieldStops), startPoint: .zero, endPoint: CGPoint(x: 0, y: h)))
        func glow(_ color: Color, x: Double, y: Double, radius: Double, stretch: Double = 1) {
            var layer = context
            layer.translateBy(x: x, y: y)
            layer.scaleBy(x: stretch, y: 1)
            layer.fill(Path(ellipseIn: CGRect(x: -radius, y: -radius, width: radius * 2, height: radius * 2)),
                       with: .radialGradient(Gradient(colors: [color, color.opacity(0)]), center: .zero, startRadius: 0, endRadius: radius))
        }
        // Two slow drifts, each on its own period so the field never repeats exactly.
        glow(t.auroraCool, x: w * (0.24 + 0.08 * sin(time * 0.11)), y: h * (0.28 + 0.07 * cos(time * 0.09)), radius: w * 0.42)
        glow(t.auroraWarm, x: w * (0.82 + 0.06 * cos(time * 0.07)), y: h * (0.16 + 0.05 * sin(time * 0.13)), radius: w * 0.34)
        // The tide: an ember under the window's edge at 0, a dawn filling the lower half at 1.
        let x = w * (0.54 + 0.04 * sin(time * 0.05))
        let y = h * (1.20 - 0.42 * tide)
        glow(t.tide(tide), x: x, y: y, radius: h * (0.50 + 0.22 * tide), stretch: 2.4)
        glow(t.tideCore(tide), x: x, y: h * (1.10 - 0.16 * tide), radius: h * (0.16 + 0.10 * tide), stretch: 3.2)
    }
}

/// Vertical ribs, like fluted glass in front of the light, with one column of light at `now` (0 left, 1 right).
/// Drawn once; redrawn only when `now` moves.
public struct FlutedGlass: View {
    @Environment(\.theme) private var t
    let now: Double

    public init(now: Double) { self.now = now }

    public var body: some View {
        Canvas { context, size in
            let rib = t.flute
            var x: CGFloat = 0
            while x < size.width {
                context.fill(
                    Path(CGRect(x: x, y: 0, width: rib, height: size.height)),
                    with: .linearGradient(
                        Gradient(stops: [.init(color: t.fluteShadow, location: 0), .init(color: .clear, location: 0.28),
                                         .init(color: t.fluteLight, location: 0.7), .init(color: .clear, location: 1)]),
                        startPoint: CGPoint(x: x, y: 0), endPoint: CGPoint(x: x + rib, y: 0)
                    )
                )
                x += rib
            }
            // Where `now` stands.
            let centre = size.width * now
            let reach = rib * t.nowRibs
            context.fill(
                Path(CGRect(x: centre - reach, y: 0, width: reach * 2, height: size.height)),
                with: .linearGradient(Gradient(colors: [.clear, t.nowLight, .clear]),
                                      startPoint: CGPoint(x: centre - reach, y: 0), endPoint: CGPoint(x: centre + reach, y: 0))
            )
        }
    }
}
