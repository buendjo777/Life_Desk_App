import SwiftUI
import DeskKit

/// The two rhythms the strip can draw. Both are made up here, from a few bumps per beat: an illustration, not data.
enum Rhythm: String, CaseIterable, Identifiable {
    case normal, af

    var id: String { rawValue }

    /// Seconds from one beat to the next, repeated for ever. Normal: even. Atrial fibrillation: never the same twice.
    private var intervals: [Double] {
        switch self {
        case .normal: [0.86]
        case .af: [0.52, 0.94, 0.63, 0.47, 0.81, 0.58, 1.02, 0.68, 0.49, 0.77]
        }
    }

    private var period: Double { intervals.reduce(0, +) }

    /// When each beat of one period starts.
    private var beats: [Double] {
        var starts: [Double] = []
        var time = 0.0
        for interval in intervals {
            starts.append(time)
            time += interval
        }
        return starts
    }

    /// One bump of the trace: (seconds from the spike, width, height).
    private typealias Wave = (offset: Double, width: Double, height: Double)
    private static let q: Wave = (-0.030, 0.010, -0.10)
    private static let r: Wave = (0, 0.011, 1)
    private static let s: Wave = (0.032, 0.012, -0.20)
    private static let tWave: Wave = (0.25, 0.045, 0.26)
    /// The small bump before the spike. It is missing in atrial fibrillation.
    private static let p: Wave = (-0.17, 0.025, 0.13)
    /// The restless baseline of atrial fibrillation: two small ripples (cycles per second, height).
    private static let ripples: [(rate: Double, height: Double)] = [(6.3, 0.035), (8.1, 0.02)]
    private static let reach = 0.5

    /// The times of the spikes between `start` and `end` seconds.
    func spikes(from start: Double, to end: Double) -> [Double] {
        let (period, beats) = (period, beats)
        let first = (start / period).rounded(.down) * period
        return stride(from: first, through: end, by: period).flatMap { base in beats.map { base + $0 } }.filter { $0 >= start && $0 <= end }
    }

    /// The height of the trace at `time` seconds, about -0.2…1.
    func value(at time: Double) -> Double {
        let (period, beats) = (period, beats)
        let local = time.truncatingRemainder(dividingBy: period)
        let waves = self == .normal ? [Self.p, Self.q, Self.r, Self.s, Self.tWave] : [Self.q, Self.r, Self.s, Self.tWave]
        var value = 0.0
        for beat in beats {
            for shift in [-period, 0, period] {
                let distance = local - beat - shift
                guard abs(distance) < Self.reach else { continue }
                for wave in waves {
                    let x = (distance - wave.offset) / wave.width
                    value += wave.height * exp(-x * x / 2)
                }
            }
        }
        if self == .af {
            for ripple in Self.ripples { value += ripple.height * sin(2 * .pi * ripple.rate * time) }
        }
        return value
    }
}

/// An ECG strip on paper squares, scrolling while its scene is being read. A tick under each spike shows the rhythm.
struct ECGStrip: View {
    @Environment(\.theme) private var t
    @Environment(\.motionOn) private var motionOn
    @Environment(\.sceneActive) private var active
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.controlActiveState) private var activeState
    let rhythm: Rhythm

    var body: some View {
        Group {
            if motionOn && active && !reduceMotion && activeState != .inactive {
                TimelineView(.animation(minimumInterval: 1 / t.ecgFPS)) { timeline in
                    // An hour's worth of seconds: small numbers keep the trace exact.
                    canvas(time: timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 3600))
                }
            } else {
                canvas(time: 0)
            }
        }
        .frame(height: t.ecgHeight)
        .clipShape(RoundedRectangle(cornerRadius: t.radiusEvent))
        .accessibilityHidden(true)
    }

    private func canvas(time: Double) -> some View {
        Canvas { context, size in
            Self.draw(&context, size: size, time: time, rhythm: rhythm, theme: t)
        }
    }

    /// Pure drawing: the same inputs give the same picture, so snapshots are stable.
    static func draw(_ context: inout GraphicsContext, size: CGSize, time: Double, rhythm: Rhythm, theme t: Theme) {
        let perSecond = size.width / t.ecgSeconds
        let square = perSecond * t.ecgGrid
        // Paper squares; the vertical lines move with the trace.
        var grid = Path()
        var x = -(time.truncatingRemainder(dividingBy: t.ecgGrid)) * perSecond
        while x < size.width {
            grid.move(to: CGPoint(x: x, y: 0))
            grid.addLine(to: CGPoint(x: x, y: size.height))
            x += square
        }
        var y = square
        while y < size.height {
            grid.move(to: CGPoint(x: 0, y: y))
            grid.addLine(to: CGPoint(x: size.width, y: y))
            y += square
        }
        context.stroke(grid, with: .color(t.line), lineWidth: t.hairline)

        let baseline = size.height * t.ecgBaseline
        let gain = size.height * t.ecgGain
        var trace = Path()
        var px: CGFloat = 0
        while px <= size.width {
            let point = CGPoint(x: px, y: baseline - rhythm.value(at: time + px / perSecond) * gain)
            if px == 0 { trace.move(to: point) } else { trace.addLine(to: point) }
            px += 1
        }
        context.stroke(trace, with: .color(t.focus), style: StrokeStyle(lineWidth: t.stroke, lineCap: .round, lineJoin: .round))

        // A tick under every spike: evenly spaced, or not.
        var ticks = Path()
        for spike in rhythm.spikes(from: time, to: time + t.ecgSeconds) {
            let tick = (spike - time) * perSecond
            ticks.move(to: CGPoint(x: tick, y: size.height - t.ecgTick - t.sp4))
            ticks.addLine(to: CGPoint(x: tick, y: size.height - t.sp4))
        }
        context.stroke(ticks, with: .color(t.inkMuted), style: StrokeStyle(lineWidth: t.stroke, lineCap: .round))
    }
}
