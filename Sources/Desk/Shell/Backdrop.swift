import SwiftUI

/// The window's background, and the one place where the day shows without reading a card:
/// - the field: one deep colour with a slow, soft light in it;
/// - the tide: a glow on the horizon that rises and warms as today's work gets done.
/// It stands still in snapshots, with Reduce Motion, in Low Power Mode and while Desk is not the active app.
struct Backdrop: View {
    @Environment(Store.self) private var store
    @Environment(\.theme) private var t
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.controlActiveState) private var activeState

    var body: some View {
        let d = store.d
        let moving = store.motion && !reduceMotion && activeState != .inactive && !ProcessInfo.processInfo.isLowPowerModeEnabled
        Field(tide: store.isSnapshot ? t.showcaseTide : d.dayTide, speed: d.deadlineIsClose ? t.driftUrgent : t.drift, moving: moving)
            .animation(store.motion && !reduceMotion ? .easeInOut(duration: t.tideSettle) : nil, value: d.dayTide)
            .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// The field and the tide. `tide` is animatable, so a tick makes the glow rise smoothly instead of jumping.
private struct Field: View, Animatable {
    @Environment(\.theme) private var t
    var tide: Double
    let speed: Double
    let moving: Bool

    var animatableData: Double {
        get { tide }
        set { tide = newValue }
    }

    var body: some View {
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
    static func draw(_ context: inout GraphicsContext, size: CGSize, time: Double, tide: Double, theme t: Theme) {
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
        glow(t.auroraCool, x: w * (0.42 + 0.06 * sin(time * 0.11)), y: h * (0.10 + 0.05 * cos(time * 0.09)), radius: w * 0.55, stretch: 1.4)
        glow(t.auroraWarm, x: w * (0.86 + 0.05 * cos(time * 0.07)), y: h * (0.22 + 0.05 * sin(time * 0.13)), radius: w * 0.30)
        // The tide: an ember under the window's edge at 0, a dawn filling the lower half at 1.
        let x = w * (0.54 + 0.04 * sin(time * 0.05))
        let y = h * (1.24 - 0.30 * tide)
        glow(t.tide(tide), x: x, y: y, radius: h * (0.46 + 0.16 * tide), stretch: 2.8)
        glow(t.tideCore(tide), x: x, y: h * (1.12 - 0.10 * tide), radius: h * (0.14 + 0.06 * tide), stretch: 3.6)
    }
}
