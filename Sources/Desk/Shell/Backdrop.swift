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
        BackdropField(tide: store.isSnapshot ? t.showcaseTide : d.dayTide, speed: d.deadlineIsClose ? t.driftUrgent : t.drift, moving: moving)
            .animation(store.motion && !reduceMotion ? .easeInOut(duration: t.tideSettle) : nil, value: d.dayTide)
            .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
