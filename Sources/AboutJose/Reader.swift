import SwiftUI
import DeskKit

/// Light, dark, or whatever the Mac is set to.
enum Appearance: String {
    case system, light, dark

    var scheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

/// Where the reader is in the story, and how they chose to see it.
@MainActor
@Observable
final class Reader {
    let story: Story
    /// Drawing to an image: no motion, no scroll view, nothing saved.
    let isSnapshot: Bool
    var chapter: Chapter
    /// False until the window is on screen, so the first scene plays its entrance too.
    var started = false
    var palette: Palette {
        didSet { defaults?.set(palette.rawValue, forKey: Keys.palette) }
    }
    var appearance: Appearance {
        didSet { defaults?.set(appearance.rawValue, forKey: Keys.appearance) }
    }

    @ObservationIgnored private let defaults: UserDefaults?

    private enum Keys {
        static let palette = "palette"
        static let appearance = "appearance"
    }

    init(story: Story, chapter: Chapter = .opening, isSnapshot: Bool = false, defaults: UserDefaults? = nil) {
        self.story = story
        self.chapter = chapter
        self.isSnapshot = isSnapshot
        self.defaults = defaults
        palette = defaults?.string(forKey: Keys.palette).flatMap(Palette.init(rawValue:)) ?? .ember
        appearance = defaults?.string(forKey: Keys.appearance).flatMap(Appearance.init(rawValue:)) ?? .system
    }

    /// 0 on the first scene, 1 on the last: what the backdrop's tide follows.
    var progress: Double {
        Double(chapter.rawValue) / Double(max(Chapter.allCases.count - 1, 1))
    }

    var isLast: Bool { chapter == Chapter.allCases.last }

    func step(_ by: Int) {
        guard let target = Chapter(rawValue: chapter.rawValue + by) else { return }
        chapter = target
    }
}
