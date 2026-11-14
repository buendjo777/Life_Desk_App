import SwiftUI
import DeskKit

/// 05: what he is looking for, and how to reach him. An empty contact field shows as a placeholder.
struct NextChapter: View {
    @Environment(\.theme) private var t
    let story: Story

    private let shapes: [CardShape] = [.chevron, .star]

    var body: some View {
        let next = story.next
        VStack(alignment: .leading, spacing: t.sp24) {
            ChapterHeader(chapter: .next, headline: next.headline).reveal(0)
            HStack(spacing: t.sp16) {
                ForEach(Array(next.goals.enumerated()), id: \.offset) { index, goal in
                    StatCard(title: goal.title, accent: .focus, shape: shapes[index % shapes.count]) {
                        Spacer(minLength: 0)
                        Text(verbatim: goal.value).style(\.figure)
                        Text(verbatim: goal.detail).style(\.body).opacity(t.onAccentBlock).fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .frame(height: t.goalHeight)
            .reveal(1)
            VStack(alignment: .leading, spacing: t.sp8) {
                GroupLabel(text: next.contactTitle)
                ForEach(next.contact, id: \.self) { contact in
                    let url = Web.url(contact.url)
                    ListRow(leading: .symbol(contact.symbol, contact.value.isEmpty ? .caution : .focus), title: contact.label,
                            subtitle: contact.value.isEmpty ? nil : contact.value, action: url.map { url in { Web.open(url) } }) { _ in
                        if contact.value.isEmpty {
                            Chip(text: story.placeholder, accent: .caution)
                        } else if url != nil {
                            Image(systemName: "arrow.up.right").font(.system(size: t.symbolSmall, weight: .bold)).foregroundStyle(t.inkMuted)
                                .accessibilityHidden(true)
                        }
                    }
                }
            }
            .frame(maxWidth: t.contactWidth, alignment: .leading)
            .reveal(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
