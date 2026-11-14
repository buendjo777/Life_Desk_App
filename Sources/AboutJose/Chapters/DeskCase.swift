import SwiftUI
import DeskKit

/// 03: Desk as a case study: what it does, its screens, and how the pieces fit.
struct DeskChapter: View {
    @Environment(\.theme) private var t
    @Environment(\.colorScheme) private var scheme
    @State private var screen: String?
    let desk: Story.DeskCase

    var body: some View {
        let shown = screen ?? desk.screens.first?.file ?? ""
        VStack(alignment: .leading, spacing: t.sp16) {
            ChapterHeader(chapter: .desk, headline: desk.headline).reveal(0)
            HStack(alignment: .top, spacing: t.sp24) {
                VStack(alignment: .leading, spacing: t.sp16) {
                    Text(verbatim: desk.summary).style(\.body, \.ink).lineSpacing(t.sp4).fixedSize(horizontal: false, vertical: true)
                    HStack(alignment: .top, spacing: t.sp24) {
                        ForEach(desk.figures, id: \.self) { figure in
                            Figure(figure.value, unit: figure.spacedUnit, caption: figure.caption)
                        }
                    }
                    .foregroundStyle(t.ink)
                    Spacer(minLength: 0)
                    Text(verbatim: desk.platformNote).style(\.small, \.inkMuted).fixedSize(horizontal: false, vertical: true)
                    if let url = Web.url(desk.repoUrl) {
                        Button(desk.repoLabel) { Web.open(url) }.buttonStyle(.deskPrimary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .reveal(1)
                VStack(alignment: .leading, spacing: t.sp8) {
                    HStack(spacing: t.sp12) {
                        CountedTabs(items: desk.screens.map { .init(id: $0.file, title: $0.label) },
                                    selection: Binding(get: { shown }, set: { screen = $0 }))
                        Spacer(minLength: 0)
                    }
                    DeskScreen(url: Resources.screen(shown, dark: scheme == .dark))
                        .frame(width: t.screenHeight * t.screenAspect, height: t.screenHeight)
                    Text(verbatim: desk.screensNote).style(\.caption, \.inkMuted)
                }
                .reveal(2)
            }
            .fixedSize(horizontal: false, vertical: true)
            architecture.reveal(3)
        }
    }

    private var architecture: some View {
        VStack(alignment: .leading, spacing: t.sp10) {
            HStack(alignment: .firstTextBaseline) {
                Text(verbatim: desk.architectureTitle).style(\.label, \.focus)
                Spacer()
                Text(verbatim: desk.architectureNote).style(\.small, \.inkMuted)
            }
            HStack(spacing: t.sp8) {
                ForEach(Array(desk.architecture.enumerated()), id: \.offset) { index, box in
                    if index > 0 {
                        Image(systemName: "arrow.right").font(.system(size: t.symbol, weight: .bold)).foregroundStyle(t.inkMuted)
                            .accessibilityHidden(true)
                    }
                    VStack(alignment: .leading, spacing: t.sp4) {
                        Text(verbatim: box.title).style(\.bodyStrong, \.ink)
                        Text(verbatim: box.detail).style(\.small, \.inkMuted).fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(t.sp12)
                    .frame(maxWidth: .infinity, minHeight: t.sp32 + t.sp32, maxHeight: .infinity, alignment: .topLeading)
                    .glass(radius: t.radiusRow, fill: t.raised)
                    .accessibilityElement(children: .combine)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(t.sp16)
        .glass(lifts: false)
    }
}

/// One Desk snapshot in a glass frame. The pictures come from `design/screenshots/`, drawn from the demo vault.
private struct DeskScreen: View {
    @Environment(\.theme) private var t
    let url: URL

    var body: some View {
        Group {
            if let image = ScreenCache.shared.image(url) {
                Image(nsImage: image).resizable().interpolation(.high).aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: t.radiusNav))
                    .accessibilityLabel(Text(verbatim: "A screenshot of Desk"))
            } else {
                EmptyState(line: "This screenshot is missing.", hint: url.lastPathComponent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(t.sp4)
        .glass(radius: t.radiusRow)
        .id(url)
        .transition(.opacity)
        .deskAnimation(url)
    }
}

/// Each picture is read from disk once.
@MainActor
private final class ScreenCache {
    static let shared = ScreenCache()
    private var images: [URL: NSImage] = [:]

    func image(_ url: URL) -> NSImage? {
        if let image = images[url] { return image }
        let image = NSImage(contentsOf: url)
        images[url] = image
        return image
    }
}
