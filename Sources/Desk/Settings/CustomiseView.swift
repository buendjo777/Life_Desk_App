import SwiftUI

/// View → Customise…: per tab, show or hide and reorder its cards and sections, and pick the density.
/// Saved as app preferences, never in the vault. Reset restores the defaults.
struct CustomiseView: View {
    @Environment(Store.self) private var store
    @Environment(\.theme) private var t
    @State private var tab: Tab = .today

    var body: some View {
        @Bindable var prefs = store.prefs
        let saved = prefs.layouts[tab.rawValue]
        let sections = TabLayout.ordered(tab, prefs: saved)
        VStack(alignment: .leading, spacing: t.sp16) {
            HStack {
                Text(verbatim: "Customise").style(\.title, \.ink)
                Spacer()
                Button("Reset") { prefs.resetLayout() }.buttonStyle(.deskSecondary)
                Button("Done") { store.showCustomise = false }.buttonStyle(.deskPrimary).keyboardShortcut(.defaultAction)
            }
            HStack(spacing: t.sp12) {
                Text(verbatim: "Density").style(\.smallStrong, \.ink)
                CountedTabs(items: Density.allCases.map { .init(id: $0, title: $0.title) }, selection: $prefs.density)
                Spacer()
                Text(verbatim: prefs.density == .compact ? "The mockup's spacing." : "More space, fewer rows.").style(\.small, \.inkMuted)
            }
            CountedTabs(items: Tab.sidebar.map { .init(id: $0, title: $0.title) }, selection: $tab)
            Scroller {
                VStack(spacing: t.sp6) {
                    ForEach(Array(sections.enumerated()), id: \.element.id) { index, section in
                        let hidden = saved?.hidden.contains(section.id) == true
                        HStack(spacing: t.sp10) {
                            Button {
                                prefs.setHidden(!hidden, section: section.id, tab: tab)
                            } label: {
                                Image(systemName: hidden ? "eye.slash" : "eye")
                                    .font(.system(size: t.symbol, weight: .medium))
                                    .foregroundStyle(hidden ? t.inkMuted : t.ink)
                                    .frame(width: t.badgeSmall, height: t.badgeSmall)
                                    .background(t.tint(hidden ? .neutral : .good), in: Circle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(Text(verbatim: hidden ? "Show \(section.title)" : "Hide \(section.title)"))
                            VStack(alignment: .leading, spacing: 0) {
                                Text(verbatim: section.title).style(\.rowTitle, hidden ? \.inkMuted : \.ink)
                                Text(verbatim: section.slot == .rail ? "Right rail" : "Main column").style(\.small, \.inkMuted)
                            }
                            Spacer()
                            mover("chevron.up", "Move \(section.title) up", enabled: index > 0) {
                                prefs.move(section.id, by: -1, tab: tab, current: sections.map(\.id))
                            }
                            mover("chevron.down", "Move \(section.title) down", enabled: index < sections.count - 1) {
                                prefs.move(section.id, by: 1, tab: tab, current: sections.map(\.id))
                            }
                        }
                        .padding(.horizontal, t.sp10)
                        .frame(height: t.rowHeight - t.sp8)
                        .background(t.surface, in: RoundedRectangle(cornerRadius: t.radiusNav))
                    }
                }
            }
        }
        .padding(t.sp24)
        .frame(width: t.customiseSize.width, height: t.customiseSize.height)
        .background(t.canvas)
    }

    private func mover(_ symbol: String, _ label: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: t.symbolSmall, weight: .bold))
                .foregroundStyle(t.ink)
                .frame(width: t.sp24, height: t.sp24)
                .background(t.line, in: Circle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : t.outOfMonthOpacity)
        .accessibilityLabel(label)
    }
}
