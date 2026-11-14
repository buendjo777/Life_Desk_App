import SwiftUI

/// The window's background, and the one place where the day shows without reading a card:
/// - the field: two strong colours drifting slowly;
/// - the tide: a glow that rises from the bottom, and turns to the bright accent, as today's work gets done;
/// - fluted glass: vertical ribs over it all, with a column of light where the day stands (07:00 left, 22:00 right).
/// It stands still in snapshots, with Reduce Motion, in Low Power Mode and while Desk is not the active app.
struct Backdrop: View {
    @Environment(Store.self) private var store
    @Environment(\.theme) private var t
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.controlActiveState) private var activeState

    var body: some View {
        let d = store.d
        let moving = store.motion && !reduceMotion && activeState != .inactive && !ProcessInfo.processInfo.isLowPowerModeEnabled
        ZStack {
            BackdropField(tide: store.isSnapshot ? t.showcaseTide : d.dayTide, speed: d.deadlineIsClose ? t.driftUrgent : t.drift, moving: moving)
                .animation(store.motion && !reduceMotion ? .easeInOut(duration: t.tideSettle) : nil, value: d.dayTide)
            FlutedGlass(now: d.dayFraction)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
