import SwiftUI
// The theme, the glass and motion components and the backdrop layers live in DeskKit, shared with AboutJose.
// Exported once here, so every file in Desk (and the tests) sees them as before.
@_exported import DeskKit

private struct PlatformFlags: ViewModifier {
    let store: Store

    func body(content: Content) -> some View {
        content
            .environment(store)
            .environment(\.motionOn, store.motion)
            .environment(\.offscreen, store.isSnapshot)
    }
}

extension View {
    /// Hands a view the store, and tells DeskKit's components whether motion is on and whether this is a snapshot.
    func platform(_ store: Store) -> some View {
        modifier(PlatformFlags(store: store))
    }
}
