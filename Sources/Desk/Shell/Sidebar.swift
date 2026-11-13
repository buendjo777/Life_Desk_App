import SwiftUI

/// The floating graphite panel: wordmark, mode chip, tab groups and the sync box.
struct Sidebar: View {
    @Environment(Store.self) private var store
    @Environment(\.theme) private var t

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            lights
            brand
            ForEach(TabGroup.allCases) { group in
                Text(verbatim: group.rawValue)
                    .style(\.label, \.panelMuted)
                    .padding(.leading, t.sp12)
                    .padding(.top, t.sp20 + t.sp2)
                    .padding(.bottom, t.sp6)
                // Health waits for its data (an activity export).
                ForEach(group.tabs.filter { $0 != .health || store.d.hasHealthData }) { tab in
                    NavRow(tab: tab)
                }
            }
            Spacer(minLength: t.sp16)
            SyncBox()
        }
        .padding(.horizontal, t.sidebarPadding)
        .padding(.vertical, t.sp16 + t.sp2)
        .frame(width: t.sidebarWidth)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(t.panel, in: RoundedRectangle(cornerRadius: t.radiusCard))
        .overlay(RoundedRectangle(cornerRadius: t.radiusCard).strokeBorder(t.panelBorder, lineWidth: t.hairline))
    }

    /// The real traffic lights are window chrome; offscreen snapshots draw stand-ins.
    private var lights: some View {
        HStack(spacing: t.lightGap) {
            ForEach(Array(t.lights.enumerated()), id: \.offset) { _, color in
                Circle().fill(store.isSnapshot ? color : .clear).frame(width: t.lightSize, height: t.lightSize)
            }
        }
        .padding(.leading, t.sp6)
        .accessibilityHidden(true)
    }

    private var brand: some View {
        HStack(spacing: t.sp10) {
            Text(verbatim: "Desk").style(\.brand, \.panelText)
            Text(verbatim: store.mode.label)
                .style(\.caption, \.ochre)
                .padding(.horizontal, t.sp8)
                .padding(.vertical, t.sp4)
                .background(t.ochre.opacity(t.tintOpacity / 2), in: Capsule())
        }
        .padding(.leading, t.sp10)
        .padding(.top, t.sp20 + t.sp2)
        .padding(.bottom, t.sp2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(verbatim: "Desk, \(store.mode.rawValue) mode"))
    }
}

private struct NavRow: View {
    @Environment(Store.self) private var store
    @Environment(\.theme) private var t
    let tab: Tab

    var body: some View {
        let selected = store.tab == tab
        Button {
            store.show(tab)
        } label: {
            HStack(spacing: t.navGap) {
                Image(systemName: tab.symbol)
                    .font(.system(size: t.symbol, weight: .medium))
                    .frame(width: t.navIcon)
                Text(verbatim: tab.title).style(selected ? \.bodyStrong : \.nav).lineLimit(1).minimumScaleFactor(t.tightScale)
                Spacer(minLength: 0)
                Text(verbatim: "⌘\(tab.shortcut)").style(\.small, \.panelMuted)
            }
            .foregroundStyle(t.panelText.opacity(selected ? 1 : t.navIdleOpacity))
            .padding(.leading, t.navGap)
            .padding(.trailing, t.sp8)
            .frame(height: t.navRow)
            .background(Color.white.opacity(selected ? t.navSelectedFill : 0), in: RoundedRectangle(cornerRadius: t.radiusNav))
            .overlay(alignment: .leading) {
                Capsule()
                    .fill(selected ? t.rust : .clear)
                    .frame(width: t.navBar)
                    .padding(.vertical, t.sp8 + t.hairline)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .deskAnimation(selected)
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// Sync time, vault and run status at the foot of the sidebar.
private struct SyncBox: View {
    @Environment(Store.self) private var store
    @Environment(\.theme) private var t

    var body: some View {
        let status = store.d.runStatus
        VStack(alignment: .leading, spacing: t.sp4) {
            HStack(spacing: t.sp6) {
                Circle().fill(store.banner == nil ? t.moss : t.alert).frame(width: t.dot, height: t.dot)
                Text(verbatim: store.lastSync.map { "Synced \(store.cal.time($0))" } ?? "Not synced yet").style(\.small, \.panelText)
            }
            Text(verbatim: "Vault · \(store.vaultName)").style(\.small, \.panelMuted).lineLimit(1)
            Text(verbatim: status.lastRunText.map { "Last run \($0) · \(status.level.rawValue)" } ?? "No run yet · red")
                .style(\.small, \.panelMuted).lineLimit(1)
        }
        .padding(.horizontal, t.sp12 + t.sp2)
        .padding(.vertical, t.sp12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(t.panelBoxFill), in: RoundedRectangle(cornerRadius: t.radiusPanel - t.sp4))
    }
}
