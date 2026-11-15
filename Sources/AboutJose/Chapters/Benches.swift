import SwiftUI
import DeskKit

// The benches: one small thing to play with per ICAI project. Every trace here is made up by the app
// to show the idea, and each bench says so. None of it is a measurement or Jose's own code.

/// An oscilloscope-style strip: paper squares and one trace that scrolls while its scene is being read.
struct Scope: View {
    @Environment(\.theme) private var t
    @Environment(\.motionOn) private var motionOn
    @Environment(\.sceneActive) private var active
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.controlActiveState) private var activeState
    /// Seconds across the strip, and where zero sits (0 top, 1 bottom) and how tall one unit is, as shares of the height.
    var seconds = 3.0
    var baseline: CGFloat = 0.5
    var gain: CGFloat = 0.42
    /// False holds the strip still (a card that is not facing the reader).
    var live = true
    /// The height of the trace at a time in seconds, about -1…1.
    let signal: (Double) -> Double

    var body: some View {
        Group {
            if live && motionOn && active && !reduceMotion && activeState != .inactive {
                TimelineView(.animation(minimumInterval: 1 / t.ecgFPS)) { timeline in
                    canvas(time: timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 3600))
                }
            } else {
                canvas(time: 0)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: t.radiusEvent))
        .accessibilityHidden(true)
    }

    private func canvas(time: Double) -> some View {
        Canvas { context, size in
            let perSecond = size.width / seconds
            let square = perSecond * t.ecgGrid
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

            var trace = Path()
            var px: CGFloat = 0
            while px <= size.width {
                let point = CGPoint(x: px, y: size.height * baseline - signal(time + px / perSecond) * size.height * gain)
                if px == 0 { trace.move(to: point) } else { trace.addLine(to: point) }
                px += 0.5
            }
            context.stroke(trace, with: .color(t.focus), style: StrokeStyle(lineWidth: t.stroke, lineCap: .round, lineJoin: .round))
        }
    }
}

/// The made-up signals behind the scopes.
enum BenchSignal {
    /// Fast, restless noise built from three sines, so it is the same on every run.
    static func hiss(_ time: Double) -> Double {
        sin(time * 731.3) * 0.5 + sin(time * 1213.7 + 1) * 0.3 + sin(time * 1987.1 + 2) * 0.2
    }

    /// The ultrasonic chain, one loop every `loop` seconds: 0 the burst sent, 1 the faint echo,
    /// 2 the echo amplified and band-passed, 3 its envelope.
    static func ultrasound(stage: Int, at time: Double) -> Double {
        let local = time.truncatingRemainder(dividingBy: loop)
        func window(_ centre: Double) -> Double {
            let distance = abs(local - centre) / (burst / 2)
            return distance < 1 ? 1 - pow(distance, 6) : 0
        }
        let carrier = sin(2 * .pi * carrierRate * local)
        switch stage {
        case 0: return 0.85 * window(sent) * carrier
        case 1: return 0.07 * window(echo) * carrier + 0.05 * hiss(time)
        case 2: return 0.85 * window(echo) * carrier + 0.015 * hiss(time)
        default: return 0.9 * window(echo)
        }
    }

    static let loop = 3.0
    private static let burst = 0.42
    private static let sent = 0.55
    private static let echo = 1.9
    /// Slowed far down from 40 kHz so the cycles can be seen.
    private static let carrierRate = 15.0

    /// An ECG with whatever each filter would remove still in it: 0 baseline drift, 1 mains hum, 2 high-frequency noise.
    static func biosignal(filters: Set<Int>, at time: Double) -> Double {
        var value = Rhythm.normal.value(at: time)
        if !filters.contains(0) { value += 0.38 * sin(2 * .pi * 0.31 * time) }
        if !filters.contains(1) { value += 0.09 * sin(2 * .pi * 50 * time) }
        if !filters.contains(2) { value += 0.07 * hiss(time) }
        return value
    }
}

/// A capsule that is on or off.
struct ToggleChip: View {
    @Environment(\.theme) private var t
    let title: String
    let on: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(verbatim: title)
                .style(\.chip, on ? \.onPrimary : \.ink)
                .padding(.horizontal, t.sp10)
                .padding(.vertical, t.sp4 + t.hairline)
                .background(on ? t.primary : .clear, in: Capsule())
                .overlay(Capsule().strokeBorder(on ? .clear : t.line, lineWidth: t.hairline))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
        .deskAnimation(on)
    }
}

/// A project's bench. `live` is the open one, with its controls; otherwise it is the small preview on a card.
struct Bench: View {
    @Environment(\.theme) private var t
    let project: Story.Icai.Project
    var live = false
    /// The preview moves only on the card that faces the reader.
    var moving = true
    @State private var stage = 3
    @State private var filters: Set<Int> = []
    @State private var balance = BalanceModel()
    @State private var controller = true

    var body: some View {
        let words = project.bench
        VStack(alignment: .leading, spacing: t.sp10) {
            if live {
                HStack(spacing: t.sp6) { controls(words) }
                Text(verbatim: caption(words)).style(\.small, \.ink).lineLimit(2).fixedSize(horizontal: false, vertical: true)
            }
            picture.frame(maxWidth: .infinity, maxHeight: .infinity)
            if live { Text(verbatim: words.note).style(\.caption, \.inkMuted) }
        }
    }

    @ViewBuilder private var picture: some View {
        switch project.kind {
        case "ultrasound":
            let shown = live ? stage : 2
            Scope(seconds: BenchSignal.loop, baseline: shown == 3 ? 0.84 : 0.5, gain: shown == 3 ? 0.66 : 0.44, live: moving) {
                BenchSignal.ultrasound(stage: shown, at: $0)
            }
        case "biosignal":
            let on = live ? filters : [1, 2]
            Scope(seconds: 3, baseline: 0.64, gain: 0.4, live: moving) { BenchSignal.biosignal(filters: on, at: $0) }
        default:
            BalanceView(model: balance, controller: live ? controller : true, selfPush: !live, live: moving)
        }
    }

    @ViewBuilder private func controls(_ words: Story.Icai.Bench) -> some View {
        switch project.kind {
        case "ultrasound":
            CountedTabs(items: words.labels.enumerated().map { .init(id: $0.offset, title: $0.element) }, selection: $stage)
        case "biosignal":
            ForEach(Array(words.labels.enumerated()), id: \.offset) { index, label in
                ToggleChip(title: label, on: filters.contains(index)) {
                    if filters.contains(index) { filters.remove(index) } else { filters.insert(index) }
                }
            }
        default:
            if let label = words.labels.first {
                ToggleChip(title: label, on: controller) {
                    controller.toggle()
                    if controller { balance.stand() }
                }
            }
            if words.labels.count > 1 {
                Button(words.labels[1]) { balance.push() }.buttonStyle(.deskSecondary)
            }
        }
    }

    private func caption(_ words: Story.Icai.Bench) -> String {
        func line(_ index: Int) -> String { words.captions.indices.contains(index) ? words.captions[index] : "" }
        switch project.kind {
        case "ultrasound": return line(stage)
        case "biosignal":
            return filters.isEmpty ? words.idle ?? "" : filters.sorted().map(line).joined(separator: " ")
        default: return line(controller ? 0 : 1)
        }
    }
}

/// A rod on a wheel: an inverted pendulum, with a PID loop that can be switched off. A toy, not the vehicle's code.
final class BalanceModel {
    /// Tilt from upright in radians, and how fast it is changing.
    private(set) var tilt = 0.14
    private var rate = 0.0
    private var sum = 0.0
    private var last: Date?
    private var pushes = 0
    private var sincePush = 0.0

    private let gravity = 14.0
    private let gains = (p: 70.0, i: 30.0, d: 13.0)
    private let fallen = 1.35
    private let kick = 1.9

    func push() {
        if abs(tilt) >= fallen { stand() }
        pushes += 1
        rate += pushes.isMultiple(of: 2) ? -kick : kick
    }

    /// Back on its wheel, leaning a little, so the loop has something to correct.
    func stand() {
        tilt = 0.14
        rate = 0
        sum = 0
    }

    /// Moves the model forward to `date`. `selfPush` nudges it every few seconds, for the preview.
    func advance(to date: Date, controller: Bool, selfPush: Bool) {
        defer { last = date }
        guard let last else { return }
        let elapsed = min(date.timeIntervalSince(last), 0.05)
        guard elapsed > 0 else { return }
        if selfPush {
            sincePush += elapsed
            if sincePush > 3.2 {
                sincePush = 0
                push()
            }
        }
        let steps = 4
        let dt = elapsed / Double(steps)
        for _ in 0..<steps {
            guard abs(tilt) < fallen else {
                rate = 0
                break
            }
            sum += tilt * dt
            let control = controller ? gains.p * tilt + gains.i * sum + gains.d * rate : 0
            rate += (gravity * sin(tilt) - control * cos(tilt)) * dt
            tilt += rate * dt
        }
        tilt = max(-fallen, min(fallen, tilt))
    }
}

struct BalanceView: View {
    @Environment(\.theme) private var t
    @Environment(\.motionOn) private var motionOn
    @Environment(\.sceneActive) private var active
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.controlActiveState) private var activeState
    let model: BalanceModel
    let controller: Bool
    let selfPush: Bool
    var live = true

    var body: some View {
        Group {
            if live && motionOn && active && !reduceMotion && activeState != .inactive {
                TimelineView(.animation(minimumInterval: 1 / t.ecgFPS)) { timeline in
                    let _ = model.advance(to: timeline.date, controller: controller, selfPush: selfPush)
                    canvas(tilt: model.tilt)
                }
            } else {
                canvas(tilt: model.tilt)
            }
        }
        .accessibilityHidden(true)
    }

    private func canvas(tilt: Double) -> some View {
        Canvas { context, size in
            let ground = size.height * 0.86
            let wheel = size.height * 0.11
            let rod = size.height * 0.56
            // The wheel rolls under the lean, as the real thing does to catch itself.
            let centre = CGPoint(x: size.width / 2 + sin(tilt) * wheel * 2.2, y: ground - wheel)
            let top = CGPoint(x: centre.x + sin(tilt) * rod, y: centre.y - cos(tilt) * rod)
            var floor = Path()
            floor.move(to: CGPoint(x: size.width * 0.08, y: ground))
            floor.addLine(to: CGPoint(x: size.width * 0.92, y: ground))
            context.stroke(floor, with: .color(t.line), lineWidth: t.stroke)
            // Upright, as a faint guide.
            var guide = Path()
            guide.move(to: centre)
            guide.addLine(to: CGPoint(x: centre.x, y: centre.y - rod))
            context.stroke(guide, with: .color(t.line), style: StrokeStyle(lineWidth: t.hairline, dash: [t.sp4, t.sp4]))
            var body = Path()
            body.move(to: centre)
            body.addLine(to: top)
            context.stroke(body, with: .color(t.ink), style: StrokeStyle(lineWidth: t.sp6, lineCap: .round))
            context.fill(Path(ellipseIn: CGRect(x: top.x - wheel * 0.7, y: top.y - wheel * 0.7, width: wheel * 1.4, height: wheel * 1.4)), with: .color(t.focus))
            let rim = Path(ellipseIn: CGRect(x: centre.x - wheel, y: centre.y - wheel, width: wheel * 2, height: wheel * 2))
            context.fill(rim, with: .color(t.raised))
            context.stroke(rim, with: .color(t.ink), lineWidth: t.stroke)
        }
    }
}
