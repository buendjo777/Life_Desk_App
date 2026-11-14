import SwiftUI
import DeskKit

/// 02: the atrial fibrillation thesis: what the signal looks like, the pipeline in three steps, and the result as it was.
struct ThesisChapter: View {
    @Environment(\.theme) private var t
    @State private var rhythm = Rhythm.af
    let thesis: Story.Thesis

    var body: some View {
        VStack(alignment: .leading, spacing: t.sp16) {
            ChapterHeader(chapter: .thesis, headline: thesis.headline, note: thesis.context).reveal(0)
            strip.reveal(1)
            steps.reveal(2)
            result.reveal(3)
        }
    }

    private var strip: some View {
        VStack(alignment: .leading, spacing: t.sp10) {
            HStack(spacing: t.sp12) {
                CountedTabs(items: [.init(id: Rhythm.normal, title: thesis.strip.normal), .init(id: Rhythm.af, title: thesis.strip.af)],
                            selection: $rhythm)
                Text(verbatim: rhythm == .normal ? thesis.strip.normalNote : thesis.strip.afNote).style(\.small, \.ink).lineLimit(1)
                Spacer(minLength: t.sp8)
                Text(verbatim: thesis.strip.disclaimer).style(\.caption, \.inkMuted).lineLimit(1)
            }
            ECGStrip(rhythm: rhythm)
        }
        .padding(t.sp16)
        .glass(lifts: false)
    }

    private var steps: some View {
        HStack(spacing: t.sp8) {
            ForEach(Array(thesis.steps.enumerated()), id: \.offset) { index, step in
                if index > 0 {
                    Image(systemName: "arrow.right").font(.system(size: t.symbol, weight: .bold)).foregroundStyle(t.inkMuted)
                        .accessibilityHidden(true)
                }
                VStack(alignment: .leading, spacing: t.sp6) {
                    HStack(spacing: t.sp8) {
                        Text(verbatim: String(index + 1)).style(\.stepNumber, \.onFocus)
                            .frame(width: t.stepBadge, height: t.stepBadge)
                            .background(t.focus, in: Circle())
                        Text(verbatim: step.title).style(\.cardTitle, \.ink).lineLimit(1)
                    }
                    Text(verbatim: step.detail).style(\.small, \.inkMuted).lineSpacing(t.sp2).fixedSize(horizontal: false, vertical: true)
                }
                .padding(t.sp16)
                .frame(maxWidth: .infinity, minHeight: t.stepHeight, maxHeight: .infinity, alignment: .topLeading)
                .glass(radius: t.radiusRow)
                .accessibilityElement(children: .combine)
            }
        }
        // Every step as tall as the tallest.
        .fixedSize(horizontal: false, vertical: true)
    }

    private var result: some View {
        HStack(alignment: .center, spacing: t.sp24) {
            Text(verbatim: thesis.resultTitle).style(\.label, \.focus)
            ForEach(thesis.figures, id: \.self) { figure in
                Figure(figure.value, unit: figure.spacedUnit, caption: figure.caption)
            }
            Text(verbatim: thesis.finding).style(\.bodyStrong, \.ink).lineSpacing(t.sp4)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let url = Web.url(thesis.repoUrl) {
                Button(thesis.repoLabel) { Web.open(url) }.buttonStyle(.deskPrimary)
            }
        }
        .foregroundStyle(t.ink)
        .padding(t.sp20)
        .glass()
    }
}
