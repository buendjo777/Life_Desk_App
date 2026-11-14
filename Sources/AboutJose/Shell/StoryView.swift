import SwiftUI
import DeskKit

/// The window: the backdrop, the scenes one under another, the chapter rail on the left and the look controls on the right.
struct StoryView: View {
    @Environment(Reader.self) private var reader
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var keysFocused: Bool

    var body: some View {
        let t = Theme(scheme: scheme, palette: reader.palette, solid: reduceTransparency || contrast == .increased)
        ZStack {
            if reader.isSnapshot {
                // Scroll views cannot be drawn offscreen: a snapshot is the one scene.
                ChapterScene(chapter: reader.chapter)
            } else {
                Pager()
            }
            ChapterRail()
                .padding(.leading, t.storyInset)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            LookControls()
                .padding(.top, t.sp16)
                .padding(.trailing, t.storyInset)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            if !reader.isLast {
                ScrollHint()
                    .padding(.bottom, t.sp16)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            }
        }
        .background { StoryBackdrop() }
        .background(t.canvas)
        .ignoresSafeArea()
        .environment(\.theme, t)
        .environment(\.motionOn, !reader.isSnapshot)
        .environment(\.offscreen, reader.isSnapshot)
        .preferredColorScheme(reader.isSnapshot ? nil : reader.appearance.scheme)
        .focusable()
        .focusEffectDisabled()
        .focused($keysFocused)
        .onAppear {
            keysFocused = true
            reader.started = true
        }
        .onKeyPress(keys: [.downArrow, .rightArrow, .pageDown, .space]) { _ in turn(1) }
        .onKeyPress(keys: [.upArrow, .leftArrow, .pageUp]) { _ in turn(-1) }
        .animation(reduceMotion ? nil : .easeInOut(duration: t.pageTurn), value: reader.chapter)
    }

    private func turn(_ by: Int) -> KeyPress.Result {
        reader.step(by)
        return .handled
    }
}

/// The scenes stacked in one scroll view that settles on a whole scene, so scroll, keys and the rail all move the same thing.
private struct Pager: View {
    @Environment(Reader.self) private var reader

    var body: some View {
        GeometryReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    ForEach(Chapter.allCases) { chapter in
                        ChapterScene(chapter: chapter)
                            .frame(width: proxy.size.width, height: proxy.size.height)
                            .id(chapter)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: Binding(get: { Optional(reader.chapter) }, set: { if let chapter = $0 { reader.chapter = chapter } }))
        }
    }
}

/// One full-height scene: its content, centred in the room the rail and the controls leave.
struct ChapterScene: View {
    @Environment(Reader.self) private var reader
    @Environment(\.theme) private var t
    let chapter: Chapter

    var body: some View {
        Group {
            switch chapter {
            case .opening: OpeningChapter(story: reader.story)
            case .thesis: ThesisChapter(thesis: reader.story.thesis)
            case .desk: DeskChapter(desk: reader.story.desk)
            case .tutoring: TutoringChapter(tutoring: reader.story.tutoring)
            case .next: NextChapter(story: reader.story)
            }
        }
        .frame(maxWidth: t.storyWidth, alignment: .leading)
        .padding(.leading, t.storyInset + t.storyRail + t.sp32)
        .padding(.trailing, t.sp32)
        .padding(.top, t.sceneTop)
        .padding(.bottom, t.sceneBottom)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .environment(\.sceneActive, reader.isSnapshot || (reader.started && reader.chapter == chapter))
    }
}

/// The backdrop: the tide is how far the reader is through the story.
private struct StoryBackdrop: View {
    @Environment(Reader.self) private var reader
    @Environment(\.theme) private var t
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.controlActiveState) private var activeState

    var body: some View {
        let tide = t.tideStart + (1 - t.tideStart) * reader.progress
        let moving = !reader.isSnapshot && !reduceMotion && activeState != .inactive && !ProcessInfo.processInfo.isLowPowerModeEnabled
        BackdropField(tide: tide, speed: t.drift, moving: moving)
            .animation(reader.isSnapshot || reduceMotion ? nil : .easeInOut(duration: t.tideSettle), value: tide)
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

/// The chapters, on the left: where the reader is, and a click away from any other.
private struct ChapterRail: View {
    @Environment(Reader.self) private var reader
    @Environment(\.theme) private var t
    @State private var hovered: Chapter?

    var body: some View {
        VStack(alignment: .leading, spacing: t.sp4) {
            ForEach(Chapter.allCases) { chapter in
                let current = chapter == reader.chapter
                Button {
                    reader.chapter = chapter
                } label: {
                    HStack(spacing: t.sp10) {
                        Text(verbatim: chapter.number).style(\.micro, current ? \.focus : \.inkMuted)
                        Text(verbatim: reader.story.rail(chapter)).style(\.nav, current ? \.ink : \.inkMuted)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, t.sp10)
                    .frame(height: t.navRow)
                    .background(current ? t.selection : hovered == chapter ? t.raised : .clear, in: RoundedRectangle(cornerRadius: t.radiusNav))
                    .contentShape(RoundedRectangle(cornerRadius: t.radiusNav))
                }
                .buttonStyle(.plain)
                .onHover { hovered = $0 ? chapter : hovered == chapter ? nil : hovered }
                .accessibilityAddTraits(current ? .isSelected : [])
            }
            ProgressBar(value: reader.progress, accent: .focus)
                .padding(.horizontal, t.sp10)
                .padding(.top, t.sp8)
        }
        .padding(t.sp10)
        .frame(width: t.storyRail)
        .glass(radius: t.radiusPanel, lifts: false)
        .deskAnimation(hovered)
    }
}

/// Top right: the three colourways and light or dark.
private struct LookControls: View {
    @Environment(Reader.self) private var reader
    @Environment(\.theme) private var t
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        HStack(spacing: t.sp8) {
            ForEach(Palette.allCases) { palette in
                let look = Theme(scheme: scheme, palette: palette)
                let current = palette == reader.palette
                Button {
                    reader.palette = palette
                } label: {
                    Circle().fill(look.deep)
                        .overlay(Circle().fill(look.focus).frame(width: t.swatchCore, height: t.swatchCore))
                        .overlay(Circle().strokeBorder(current ? t.ink : t.line, lineWidth: current ? t.stroke : t.hairline))
                        .frame(width: t.swatch, height: t.swatch)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .help(palette.title)
                .accessibilityLabel(Text(verbatim: "Colours: \(palette.title)"))
                .accessibilityAddTraits(current ? .isSelected : [])
            }
            IconButton(symbol: scheme == .dark ? "sun.max" : "moon", label: scheme == .dark ? "Switch to light" : "Switch to dark") {
                reader.appearance = scheme == .dark ? .light : .dark
            }
            .padding(.leading, t.sp4)
        }
        .deskAnimation(reader.palette)
    }
}

/// Bottom centre, on every scene but the last.
private struct ScrollHint: View {
    @Environment(Reader.self) private var reader
    @Environment(\.theme) private var t

    var body: some View {
        Text(verbatim: reader.story.hint).style(\.small, \.inkMuted)
            .accessibilityHidden(true)
    }
}
