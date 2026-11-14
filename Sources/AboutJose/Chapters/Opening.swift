import SwiftUI
import DeskKit

/// 01: who, what he is aiming at, where he has lived and what he speaks.
struct OpeningChapter: View {
    @Environment(\.theme) private var t
    let story: Story

    private let shapes: [CardShape] = [.hexagon, .circle, .square]

    var body: some View {
        let opening = story.opening
        VStack(alignment: .leading, spacing: t.sp32) {
            VStack(alignment: .leading, spacing: t.sp12) {
                Eyebrow(chapter: .opening).reveal(0)
                Text(verbatim: story.name).style(\.hero, \.ink).lineLimit(1).minimumScaleFactor(t.tightScale).reveal(1)
                Text(verbatim: opening.line).style(\.lead, \.ink).lineSpacing(t.sp4)
                    .frame(maxWidth: t.leadWidth, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .reveal(2)
                Text(verbatim: opening.degree).style(\.body, \.inkMuted).reveal(3)
            }
            HStack(alignment: .top, spacing: t.sp24) {
                VStack(alignment: .leading, spacing: t.sp8) {
                    GroupLabel(text: opening.livedTitle)
                    HStack(spacing: t.sp12) {
                        ForEach(Array(opening.lived.enumerated()), id: \.offset) { index, place in
                            StatCard(title: place.place, accent: .neutral, shape: shapes[index % shapes.count]) {
                                Spacer(minLength: 0)
                                Figure(place.value, unit: place.unit.map { " \($0)" }, caption: place.caption)
                            }
                        }
                    }
                    .frame(height: t.cardTall)
                }
                .reveal(4)
                VStack(alignment: .leading, spacing: t.sp8) {
                    GroupLabel(text: opening.languagesTitle)
                    ForEach(opening.languages, id: \.self) { language in
                        ListRow(leading: .initials(language.code, .focus), title: language.name) { _ in
                            Chip(text: language.level)
                        }
                    }
                }
                .frame(width: t.languagesWidth)
                .reveal(5)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
