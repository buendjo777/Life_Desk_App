import XCTest
import SwiftUI
@testable import Desk

/// Real mouse events sent to the real view tree in an offscreen window:
/// the things offscreen snapshots cannot show.
@MainActor
final class ClickTests: XCTestCase {
    private func makeWindow(_ store: Store) -> NSWindow {
        let size = Theme().designSize
        let window = NSWindow(contentRect: NSRect(x: -10_000, y: -10_000, width: size.width, height: size.height),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        // Far off screen and transparent: the window exists for hit-testing only.
        window.alphaValue = 0
        window.ignoresMouseEvents = false
        window.contentView = NSHostingView(rootView: RootView().environment(store).environment(\.colorScheme, .light))
        _ = NSApplication.shared
        window.orderFrontRegardless()
        window.contentView?.layoutSubtreeIfNeeded()
        settle()
        return window
    }

    private func settle() {
        RunLoop.main.run(until: Date().addingTimeInterval(0.4))
    }

    /// Clicks at a point given in design coordinates (origin top-left, as in the mockup).
    private func click(_ window: NSWindow, x: CGFloat, y: CGFloat) {
        let point = NSPoint(x: x, y: (window.contentView?.bounds.height ?? 0) - y)
        for type in [NSEvent.EventType.leftMouseDown, .leftMouseUp] {
            let event = NSEvent.mouseEvent(with: type, location: point, modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
                                           windowNumber: window.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 1)
            if let event { window.sendEvent(event) }
        }
        settle()
    }

    func testClickingAnEmailRowOpensTheInspector() {
        let store = Store()
        let window = makeWindow(store)
        defer { window.close() }
        XCTAssertFalse(store.inspectorOpen)
        // The first row of "Important emails" in the 1440×900 design.
        click(window, x: 857, y: 666)
        XCTAssertEqual(store.selection, .row("email-1"))
        XCTAssertTrue(store.inspectorOpen)
    }

    func testClickingASidebarRowSwitchesTab() {
        let store = Store()
        let window = makeWindow(store)
        defer { window.close() }
        // "Projects" in the sidebar.
        click(window, x: 120, y: 268)
        XCTAssertEqual(store.tab, .projects)
    }

    func testDismissingAProposalIsAMemoryOnlyClickInDemo() throws {
        let store = Store()
        let window = makeWindow(store)
        defer { window.close() }
        let file = DemoVault.url.appendingPathComponent(VaultData.decisionsFile)
        let before = try Data(contentsOf: file)
        XCTAssertEqual(store.d.toConfirm.count, 2)
        // "Dismiss" on the confirmation card in the right rail.
        click(window, x: 1265, y: 518)
        XCTAssertEqual(store.d.toConfirm.map(\.id), ["confirm-tick-pulsewave"])
        XCTAssertEqual(try Data(contentsOf: file), before, "Demo mode must never write to disk")
    }
}
