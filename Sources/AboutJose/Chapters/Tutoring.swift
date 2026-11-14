import SwiftUI
import DeskKit

/// 04: tutoring: how long, which subjects, and who. No names and no money.
struct TutoringChapter: View {
    @Environment(\.theme) private var t
    let tutoring: Story.Tutoring

    var body: some View {
        VStack(alignment: .leading, spacing: t.sp24) {
            ChapterHeader(chapter: .tutoring, headline: tutoring.headline).reveal(0)
            HStack(alignment: .top, spacing: t.sp16) {
                StatCard(title: tutoring.rail, accent: .focus, shape: .ring, tall: true) {
                    Spacer(minLength: 0)
                    HStack(alignment: .top, spacing: t.sp24) {
                        ForEach(tutoring.figures, id: \.self) { figure in
                            Figure(figure.value, unit: figure.spacedUnit, caption: figure.caption)
                        }
                    }
                }
                .frame(width: t.tutoringCard)
                HStack(spacing: t.sp12) {
                    ForEach(tutoring.subjects, id: \.self) { subject in
                        VStack(alignment: .leading, spacing: t.sp8) {
                            Badge(content: .symbol(subject.symbol), accent: .focus)
                            Spacer(minLength: 0)
                            Text(verbatim: subject.name).style(\.cardTitle, \.ink)
                            if let detail = subject.detail {
                                Text(verbatim: detail).style(\.small, \.inkMuted).fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .padding(t.sp16)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .glass()
                        .accessibilityElement(children: .combine)
                    }
                }
            }
            .frame(height: t.cardTall)
            .reveal(1)
            VStack(alignment: .leading, spacing: t.sp8) {
                GroupLabel(text: tutoring.factsTitle)
                HStack(spacing: t.sp12) {
                    ForEach(tutoring.facts, id: \.self) { fact in
                        ListRow(leading: .symbol(fact.symbol ?? "circle", .focus), title: fact.title, subtitle: fact.detail)
                    }
                }
            }
            .reveal(2)
        }
    }
}
