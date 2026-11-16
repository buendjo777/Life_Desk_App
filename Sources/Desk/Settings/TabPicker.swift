import SwiftUI
import DeskKit

/// The optional tabs as a two-column grid of switches (Setup and Customise → Tabs).
/// `detailed` adds each tab's one-line purpose.
struct TabPicker: View {
    @Environment(\.theme) private var t
    var detailed = false
    let isOn: (Tab) -> Bool
    let toggle: (Tab) -> Void

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: t.sp8), GridItem(.flexible())], spacing: t.sp8) {
            ForEach(Tab.optional) { tab in
                let on = isOn(tab)
                Button { toggle(tab) } label: {
                    HStack(spacing: t.sp10) {
                        Image(systemName: tab.symbol)
                            .font(.system(size: t.symbol, weight: .medium))
                            .frame(width: t.navIcon)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(verbatim: tab.title).style(\.rowTitle).lineLimit(1).minimumScaleFactor(t.tightScale)
                            if detailed {
                                Text(verbatim: tab.blurb).style(\.small).opacity(t.captionOpacity).lineLimit(2)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        Spacer(minLength: 0)
                        Image(systemName: on ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: t.symbol, weight: .medium))
                            .foregroundStyle(on ? t.focus : t.inkMuted)
                    }
                    .foregroundStyle(t.ink.opacity(on ? 1 : t.navIdleOpacity))
                    .padding(.horizontal, t.sp12)
                    .padding(.vertical, detailed ? t.sp10 : t.sp8)
                    .frame(maxWidth: .infinity, minHeight: t.navRow, alignment: .leading)
                    .background(t.ink.opacity(on ? t.navSelectedFill : t.panelBoxFill), in: RoundedRectangle(cornerRadius: t.radiusNav))
                    .overlay(RoundedRectangle(cornerRadius: t.radiusNav).strokeBorder(on ? t.focus.opacity(t.rimLight) : .clear, lineWidth: t.hairline))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(verbatim: "\(tab.title): \(tab.blurb)"))
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
    }
}
