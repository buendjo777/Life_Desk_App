import SwiftUI
import DeskKit

/// The tokens only this app needs. Colours, glass and the rest come from DeskKit's `Theme`.
extension Theme {
    // MARK: Type

    var hero: TextStyle { .init(size: 68, weight: .semibold, tracking: -2) }
    var headline: TextStyle { .init(size: 32, weight: .semibold, tracking: -0.8) }
    var lead: TextStyle { .init(size: 21, weight: .regular, tracking: -0.2) }
    var stepNumber: TextStyle { .init(size: 13, weight: .bold, monoDigits: true) }

    // MARK: Layout

    /// The widest a scene's content grows.
    var storyWidth: CGFloat { 1060 }
    var storyRail: CGFloat { 156 }
    var storyInset: CGFloat { 24 }
    /// Room above a scene for the window's lights and the controls, and below it for the hint.
    var sceneTop: CGFloat { 64 }
    var sceneBottom: CGFloat { 52 }
    var leadWidth: CGFloat { 760 }
    var languagesWidth: CGFloat { 330 }
    var swatch: CGFloat { 26 }
    var swatchCore: CGFloat { 10 }
    var stepBadge: CGFloat { 28 }
    var ecgHeight: CGFloat { 150 }
    var screenHeight: CGFloat { 330 }
    /// Desk is drawn at 1440 × 900.
    var screenAspect: CGFloat { designSize.width / designSize.height }
    var stepHeight: CGFloat { 96 }
    var contactWidth: CGFloat { 560 }
    var tutoringCard: CGFloat { 300 }
    var goalHeight: CGFloat { 168 }

    // MARK: Story

    /// The tide on the first scene; it reaches 1 on the last.
    var tideStart: Double { 0.14 }
    var pageTurn: Double { 0.55 }
    var revealStagger: Double { 0.08 }

    // MARK: ECG strip

    var ecgSeconds: Double { 6 }
    var ecgFPS: Double { 30 }
    /// One square of ECG paper, in seconds.
    var ecgGrid: Double { 0.2 }
    var ecgBaseline: CGFloat { 0.66 }
    var ecgGain: CGFloat { 0.5 }
    var ecgTick: CGFloat { 8 }
}
