import SwiftUI
import DeskKit

/// Customise: a drawer on the right edge of the window, so every change shows on the tab behind it at once.
/// Look (appearance, colours, density, sidebar, motion) and the sections of the tab on screen: show, hide, reorder.
/// Saved as app preferences, never in the vault. It is always a dark panel, like the sidebar.
struct CustomiseView: View {
    @Environment(Store.self) private var store
    @Environment(\.theme) private var t
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        // The drawer keeps the dark tokens in light mode too: one readable panel, whatever is behind it.
        let dark = Theme(scheme: .dark, density: t.density, palette: store.prefs.palette, solid: t.solid)
        let shape = RoundedRectangle(cornerRadius: dark.radiusCard)
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(verbatim: "Customise").style(\.section, \.panelText)
                Spacer()
                IconButton(symbol: "xmark", label: "Close Customise") { store.showCustomise = false }
            }
            .padding(.bottom, dark.sp12)
            Scroller {
                VStack(alignment: .leading, spacing: dark.sp20) {
                    look
                    tabs
                    sections
                }
                .padding(.bottom, dark.sp12)
            }
            HStack(spacing: dark.sp8) {
                Button("Reset layout") { store.prefs.resetLayout() }.buttonStyle(.deskSecondary)
                Spacer()
                Button("Vault and sync…") { openSettings() }.buttonStyle(.deskSecondary)
            }
            .padding(.top, dark.sp12)
        }
        .padding(dark.sp20)
        .frame(width: dark.customiseWidth)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(dark.canvas, in: shape)
        .overlay(shape.strokeBorder(dark.line, lineWidth: dark.hairline))
        .shadow(color: .black.opacity(dark.shadowOpacity), radius: dark.shadowRadius, y: dark.shadowY)
        .environment(\.theme, dark)
        .environment(\.colorScheme, .dark)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Customise")
    }

    // MARK: Look

    private var look: some View {
        @Bindable var prefs = store.prefs
        return VStack(alignment: .leading, spacing: t.sp12) {
            heading("Look")
            field("Appearance") {
                CountedTabs(items: Appearance.allCases.map { .init(id: $0, title: $0.title) }, selection: $prefs.appearance)
            }
            field("Colours") {
                VStack(spacing: t.sp6) {
                    ForEach(Palette.allCases) { palette in
                        PaletteRow(palette: palette, chosen: prefs.palette == palette) { prefs.palette = palette }
                    }
                }
            }
            field("Density") {
                CountedTabs(items: Density.allCases.map { .init(id: $0, title: $0.title) }, selection: $prefs.density)
            }
            VStack(spacing: t.sp6) {
                switchRow("Slim sidebar", "Icons only; it opens under the pointer.", $prefs.slimSidebar)
                switchRow("Motion", "The living background, hover lift and entrances.", $prefs.motion)
            }
        }
    }

    // MARK: Tabs

    private var tabs: some View {
        VStack(alignment: .leading, spacing: t.sp12) {
            heading("Tabs")
            TabPicker(isOn: { store.prefs.shows($0) }) { tab in store.setTab(tab, shown: !store.prefs.shows(tab)) }
        }
    }

    // MARK: Sections of the tab on screen

    private var sections: some View {
        let tab = store.visibleTabs.contains(store.tab) ? store.tab : .today
        let saved = store.prefs.layouts[tab.rawValue]
        let ordered = TabLayout.ordered(tab, prefs: saved)
        return VStack(alignment: .leading, spacing: t.sp12) {
            HStack {
                heading("Sections on")
                Menu {
                    ForEach(store.visibleTabs) { other in
                        Button(other.title) { store.show(other) }
                    }
                } label: {
                    HStack(spacing: t.sp4) {
                        Text(verbatim: tab.title).style(\.smallStrong, \.panelText)
                        Image(systemName: "chevron.down").font(.system(size: t.symbolSmall, weight: .bold)).foregroundStyle(t.panelText)
                    }
                    .padding(.horizontal, t.sp10)
                    .padding(.vertical, t.sp6)
                    .background(t.control, in: Capsule())
                    .contentShape(Capsule())
                }
                .menuStyle(.button)
                .buttonStyle(.plain)
                .fixedSize()
                .accessibilityLabel("Tab to customise")
                Spacer()
            }
            VStack(spacing: t.sp6) {
                ForEach(Array(ordered.enumerated()), id: \.element.id) { index, section in
                    let hidden = saved?.hidden.contains(section.id) == true
                    HStack(spacing: t.sp10) {
                        Button {
                            store.prefs.setHidden(!hidden, section: section.id, tab: tab)
                        } label: {
                            Image(systemName: hidden ? "eye.slash" : "eye")
                                .font(.system(size: t.symbol, weight: .medium))
                                .foregroundStyle(hidden ? t.panelMuted : t.panelText)
                                .frame(width: t.badgeSmall, height: t.badgeSmall)
                                .background(t.tint(hidden ? .neutral : .good), in: Circle())
                                .contentShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text(verbatim: hidden ? "Show \(section.title)" : "Hide \(section.title)"))
                        VStack(alignment: .leading, spacing: 0) {
                            Text(verbatim: section.title).style(\.rowTitle, hidden ? \.panelMuted : \.panelText).lineLimit(1)
                            Text(verbatim: section.slot == .rail ? "Right rail" : "Main column").style(\.small, \.panelMuted)
                        }
                        Spacer(minLength: 0)
                        mover("chevron.up", "Move \(section.title) up", enabled: index > 0) {
                            store.prefs.move(section.id, by: -1, tab: tab, current: ordered.map(\.id))
                        }
                        mover("chevron.down", "Move \(section.title) down", enabled: index < ordered.count - 1) {
                            store.prefs.move(section.id, by: 1, tab: tab, current: ordered.map(\.id))
                        }
                    }
                    .padding(.horizontal, t.sp10)
                    .frame(height: t.rowHeight - t.sp4)
                    .background(Color.white.opacity(t.panelBoxFill), in: RoundedRectangle(cornerRadius: t.radiusNav))
                }
            }
        }
    }

    // MARK: Pieces

    private func heading(_ text: String) -> some View {
        Text(verbatim: text).style(\.label, \.panelMuted)
    }

    private func field(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: t.sp6) {
            Text(verbatim: title).style(\.smallStrong, \.panelText)
            content()
        }
    }

    private func switchRow(_ title: String, _ hint: String, _ isOn: Binding<Bool>) -> some View {
        HStack(spacing: t.sp10) {
            VStack(alignment: .leading, spacing: 0) {
                Text(verbatim: title).style(\.rowTitle, \.panelText)
                Text(verbatim: hint).style(\.small, \.panelMuted).lineLimit(2).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Toggle(isOn: isOn) { EmptyView() }
                .toggleStyle(.switch).controlSize(.small).labelsHidden()
                .accessibilityLabel(title)
        }
        .padding(.horizontal, t.sp12)
        .padding(.vertical, t.sp8)
        .background(Color.white.opacity(t.panelBoxFill), in: RoundedRectangle(cornerRadius: t.radiusNav))
    }

    private func mover(_ symbol: String, _ label: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: t.symbolSmall, weight: .bold))
                .foregroundStyle(t.panelText)
                .frame(width: t.sp24, height: t.sp24)
                .background(t.line, in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : t.outOfMonthOpacity)
        .accessibilityLabel(label)
    }
}

/// One colourway: its two strong colours and its accent as dots, then its name.
private struct PaletteRow: View {
    @Environment(\.theme) private var t
    let palette: Palette
    let chosen: Bool
    let action: () -> Void

    var body: some View {
        let c = palette.colors
        Button(action: action) {
            HStack(spacing: t.sp10) {
                HStack(spacing: -t.sp4) {
                    ForEach([c.deep, c.glow, c.bright], id: \.self) { hex in
                        Circle().fill(Color(hex: hex))
                            .frame(width: t.swatch, height: t.swatch)
                            .overlay(Circle().strokeBorder(Color.white.opacity(t.lineGlass), lineWidth: t.hairline))
                    }
                }
                Text(verbatim: palette.title).style(\.rowTitle, \.panelText)
                Spacer(minLength: 0)
                Image(systemName: "checkmark")
                    .font(.system(size: t.symbolSmall, weight: .bold))
                    .foregroundStyle(t.panelText)
                    .opacity(chosen ? 1 : 0)
            }
            .padding(.horizontal, t.sp12)
            .frame(height: t.navRow)
            .background(Color.white.opacity(chosen ? t.navSelectedFill : t.panelBoxFill), in: RoundedRectangle(cornerRadius: t.radiusNav))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(palette.title)
        .accessibilityAddTraits(chosen ? .isSelected : [])
    }
}
