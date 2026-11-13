import SwiftUI

// Depth and movement, in one place. Everything here is off in snapshots, with Reduce Motion,
// and when Motion is switched off in Customise.

/// Glass: a translucent fill, a lit edge, and on hover a small rise with a shadow.
struct Glass: ViewModifier {
    @Environment(Store.self) private var store
    @Environment(\.theme) private var t
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hovering = false
    var radius: CGFloat?
    var fill: Color?
    /// Rises under the pointer.
    var lifts = true

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius ?? t.radiusCard)
        let lifted = lifts && hovering && store.motion && !reduceMotion
        content
            .background(fill ?? t.surface, in: shape)
            .overlay(shape.strokeBorder(LinearGradient(colors: [t.glassEdge.opacity(lifted ? 1 : 0.55), t.line.opacity(0.4)],
                                                       startPoint: .top, endPoint: .bottom), lineWidth: t.hairline))
            .shadow(color: .black.opacity(lifted ? t.shadowOpacity : 0), radius: lifted ? t.shadowRadius : 0, y: lifted ? t.shadowY : 0)
            .scaleEffect(lifted ? t.liftScale : 1)
            .offset(y: lifted ? -t.liftRise : 0)
            .onHover { hovering = $0 }
            .animation(.spring(response: t.liftResponse, dampingFraction: t.liftDamping), value: lifted)
    }
}

/// A section fading up when its tab opens, each a moment after the one before.
struct Entrance: ViewModifier {
    @Environment(Store.self) private var store
    @Environment(\.theme) private var t
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false
    let index: Int

    func body(content: Content) -> some View {
        let animated = store.motion && !reduceMotion
        content
            .opacity(shown || !animated ? 1 : 0)
            .offset(y: shown || !animated ? 0 : t.entranceRise)
            .onAppear {
                guard animated else { return }
                withAnimation(.easeOut(duration: t.entrance).delay(min(Double(index) * t.entranceStagger, t.entranceMaxDelay))) { shown = true }
            }
    }
}

/// Sparks flying out from a tick. Invisible at rest; plays once each time `trigger` changes.
struct Sparks: View {
    @Environment(\.theme) private var t
    let trigger: Int

    private struct Flight {
        var distance: CGFloat = 0
        var opacity = 0.0
    }

    var body: some View {
        ZStack {
            ForEach(0..<t.sparks, id: \.self) { index in
                let angle = Double(index) / Double(t.sparks) * 2 * .pi
                Circle()
                    .fill(index.isMultiple(of: 2) ? t.focus : t.good)
                    .frame(width: t.sparkSize, height: t.sparkSize)
                    .keyframeAnimator(initialValue: Flight(), trigger: trigger) { spark, flight in
                        spark.offset(x: cos(angle) * flight.distance, y: sin(angle) * flight.distance).opacity(flight.opacity)
                    } keyframes: { _ in
                        KeyframeTrack(\.distance) {
                            CubicKeyframe(t.sparkReach, duration: t.sparkTime)
                            LinearKeyframe(0, duration: 0.01)
                        }
                        KeyframeTrack(\.opacity) {
                            LinearKeyframe(1, duration: t.sparkTime * 0.15)
                            LinearKeyframe(0, duration: t.sparkTime * 0.85)
                        }
                    }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

extension View {
    /// A glass surface with a lit edge. `lifts`: it rises under the pointer.
    func glass(radius: CGFloat? = nil, fill: Color? = nil, lifts: Bool = true) -> some View {
        modifier(Glass(radius: radius, fill: fill, lifts: lifts))
    }

    func entrance(_ index: Int) -> some View {
        modifier(Entrance(index: index))
    }
}

/// A bar or a ring drawn from a 0…1 value: it grows from empty when it appears, then follows its value.
/// `FilledIn(progress) { shown in Capsule().frame(width: shown * width) }`
struct FilledIn<Content: View>: View {
    @Environment(Store.self) private var store
    @Environment(\.theme) private var t
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false
    let value: Double
    @ViewBuilder var content: (Double) -> Content

    init(_ value: Double, @ViewBuilder content: @escaping (Double) -> Content) {
        self.value = value
        self.content = content
    }

    var body: some View {
        let animated = store.motion && !reduceMotion
        content(shown || !animated ? value : 0)
            .onAppear {
                guard animated else { return }
                withAnimation(.easeOut(duration: t.fillIn)) { shown = true }
            }
            .animation(animated ? .spring(response: t.liftResponse + t.liftResponse, dampingFraction: t.liftDamping) : nil, value: value)
    }
}
