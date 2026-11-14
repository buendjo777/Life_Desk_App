import SwiftUI
import DeskKit

private struct SceneActiveKey: EnvironmentKey {
    static let defaultValue = true
}

extension EnvironmentValues {
    /// True while a scene is the one being read. Its pieces come in then, and leave when the reader moves on.
    var sceneActive: Bool {
        get { self[SceneActiveKey.self] }
        set { self[SceneActiveKey.self] = newValue }
    }
}

/// A piece of a scene fading up when the reader arrives at its chapter, each a moment after the one before.
private struct Reveal: ViewModifier {
    @Environment(\.theme) private var t
    @Environment(\.motionOn) private var motionOn
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.sceneActive) private var active
    let index: Int

    func body(content: Content) -> some View {
        let animated = motionOn && !reduceMotion
        let shown = active || !animated
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : t.entranceRise + t.entranceRise)
            .animation(animated ? .easeOut(duration: t.entrance + t.entrance).delay(active ? Double(index) * t.revealStagger : 0) : nil,
                       value: active)
    }
}

extension View {
    func reveal(_ index: Int) -> some View {
        modifier(Reveal(index: index))
    }
}

/// The top of every scene after the first: its number and name, then the headline.
struct ChapterHeader: View {
    @Environment(Reader.self) private var reader
    @Environment(\.theme) private var t
    let chapter: Chapter
    let headline: String
    var note: String?

    var body: some View {
        VStack(alignment: .leading, spacing: t.sp8) {
            Eyebrow(chapter: chapter)
            Text(verbatim: headline).style(\.display, \.ink).fixedSize(horizontal: false, vertical: true)
            if let note {
                Text(verbatim: note).style(\.body, \.inkMuted)
            }
        }
        .frame(maxWidth: t.leadWidth + t.leadWidth / 4, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

/// "02 · Thesis" in the accent.
struct Eyebrow: View {
    @Environment(Reader.self) private var reader
    let chapter: Chapter

    var body: some View {
        Text(verbatim: "\(chapter.number) · \(reader.story.rail(chapter))").style(\.label, \.focus)
    }
}

/// A small uppercase title over a group.
struct GroupLabel: View {
    let text: String

    var body: some View {
        Text(verbatim: text).style(\.label, \.inkMuted)
    }
}

/// Opens a web link in the browser. Only https: the story file cannot make the app open anything else.
enum Web {
    static func url(_ text: String) -> URL? {
        guard let url = URL(string: text), url.scheme == "https", url.host != nil else { return nil }
        return url
    }

    @MainActor
    static func open(_ url: URL) {
        NSWorkspace.shared.open(url)
    }
}
