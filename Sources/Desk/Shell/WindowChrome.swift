import SwiftUI
import AppKit

/// Moves the window's traffic lights onto the floating sidebar and keeps them there on resize.
struct WindowChrome: NSViewRepresentable {
    /// Where the first light sits, measured from the window's top-left corner.
    let origin: CGPoint
    let spacing: CGFloat

    func makeNSView(context: Context) -> NSView {
        let view = ChromeView()
        view.origin = origin
        view.spacing = spacing
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {}

    private final class ChromeView: NSView {
        var origin = CGPoint.zero
        var spacing: CGFloat = 0
        private var observers: [NSObjectProtocol] = []

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            observers.forEach(NotificationCenter.default.removeObserver)
            observers = []
            guard let window else { return }
            window.isMovableByWindowBackground = true
            let names = [NSWindow.didResizeNotification, NSWindow.didBecomeKeyNotification,
                         NSWindow.didExitFullScreenNotification, NSWindow.didEndLiveResizeNotification]
            observers = names.map { name in
                NotificationCenter.default.addObserver(forName: name, object: window, queue: .main) { [weak self] _ in
                    MainActor.assumeIsolated { self?.place() }
                }
            }
            DispatchQueue.main.async { [weak self] in self?.place() }
        }

        override func layout() {
            super.layout()
            place()
        }

        private func place() {
            guard let window, !window.styleMask.contains(.fullScreen),
                  let close = window.standardWindowButton(.closeButton),
                  let container = close.superview?.superview
            else { return }
            // Grow the title-bar container so the lights can sit lower than the system default.
            let height = (origin.y + close.frame.height / 2) * 2
            container.frame = CGRect(x: 0, y: window.frame.height - height, width: window.frame.width, height: height)
            let buttons: [NSWindow.ButtonType] = [.closeButton, .miniaturizeButton, .zoomButton]
            for (index, type) in buttons.enumerated() {
                guard let button = window.standardWindowButton(type) else { continue }
                button.setFrameOrigin(CGPoint(
                    x: origin.x + CGFloat(index) * (button.frame.width + spacing),
                    y: (height - button.frame.height) / 2
                ))
            }
        }
    }
}
