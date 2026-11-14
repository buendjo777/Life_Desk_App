import SwiftUI

/// The floating panel: wordmark, mode chip, tab groups and the sync box.
/// Slim (the default), it shows icons only and opens under the pointer, over the content.
struct Sidebar: View {
    @Environment(Store.self) private var store
    @Environment(\.theme) private var t
    @State private var hovering = false

    var body: some View {
        let slim = store.prefs.slimSidebar
        let open = !slim || hovering
        let shape = RoundedRectangle(cornerRadius: t.radiusCard)
        VStack(alignment: .leading, spacing: 0) {
            lights
            brand.opacity(open ? 1 : 0)
            ForEach(TabGroup.allCases) { group in
                Text(verbatim: group.rawValue)
                    .style(\.label, \.panelMuted)
                    .padding(.leading, t.sp12)
                    .padding(.top, t.sp20 + t.sp2)
                    .padding(.bottom, t.sp6)
                    .opacity(open ? 1 : 0)
                // Health waits for its data (an activity export).
                ForEach(group.tabs.filter { $0 != .health || store.d.hasHealthData }) { tab in
                    NavRow(tab: tab, open: open)
                }
            }
            Spacer(minLength: t.sp16)
            SyncBox(open: open)
        }
        .padding(.horizontal, t.sidebarPadding)
        .padding(.vertical, t.sp16 + t.sp2)
        .frame(width: open ? t.sidebarWidth : t.sidebarSlim, alignment: .leading)
        .frame(maxHeight: .infinity, alignment: .top)
        // Open over the content it is nearly opaque, so the cards behind do not show through.
        .background(slim && open ? t.panelOpen : t.panel, in: shape)
        .clipShape(shape)
        .shadow(color: .black.opacity(slim && open ? t.shadowOpacity : 0), radius: t.shadowRadius, y: t.shadowY)
        .onHover { hovering = $0 }
        .animation(.spring(response: t.liftResponse, dampingFraction: t.sidebarDamping), value: open)
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
                .style(\.caption, \.caution)
                .padding(.horizontal, t.sp8)
                .padding(.vertical, t.sp4)
                .background(t.caution.opacity(t.tintOpacity / 2), in: Capsule())
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
    /// Closed: the icon alone.
    let open: Bool

    var body: some View {
        let selected = store.tab == tab
        Button {
            store.show(tab)
        } label: {
            HStack(spacing: t.navGap) {
                Image(systemName: tab.symbol)
                    .font(.system(size: t.symbol, weight: .medium))
                    .frame(width: t.navIcon)
                if open {
                    Text(verbatim: tab.title).style(selected ? \.bodyStrong : \.nav).lineLimit(1).minimumScaleFactor(t.tightScale)
                    Spacer(minLength: 0)
                    Text(verbatim: "⌘\(tab.shortcut)").style(\.small, \.panelMuted)
                }
            }
            .foregroundStyle(t.panelText.opacity(selected ? 1 : t.navIdleOpacity))
            .padding(.leading, t.navGap)
            .padding(.trailing, t.sp8)
            .frame(height: t.navRow)
            .background(Color.white.opacity(selected ? t.navSelectedFill : 0), in: RoundedRectangle(cornerRadius: t.radiusNav))
            .overlay(alignment: .leading) {
                Capsule()
                    .fill(selected ? t.focus : .clear)
                    .frame(width: t.navBar)
                    .padding(.vertical, t.sp8 + t.hairline)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .deskAnimation(selected)
        .help(open ? "" : tab.title)
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// Sync time, vault and run status at the foot of the sidebar.
private struct SyncBox: View {
    @Environment(Store.self) private var store
    @Environment(\.theme) private var t
    /// Closed: the status dot alone.
    let open: Bool

    var body: some View {
        let status = store.d.runStatus
        VStack(alignment: .leading, spacing: t.sp4) {
            HStack(spacing: t.sp6) {
                Circle().fill(store.banner == nil ? t.good : t.alert).frame(width: t.dot, height: t.dot)
                if open {
                    Text(verbatim: store.lastSync.map { "Synced \(store.cal.time($0))" } ?? "Not synced yet").style(\.small, \.panelText).lineLimit(1)
                }
            }
            if open {
                Text(verbatim: "Vault · \(store.vaultName)").style(\.small, \.panelMuted).lineLimit(1)
                Text(verbatim: status.lastRunText.map { "Last run \($0) · \(status.level.rawValue)" } ?? "No run yet · red")
                    .style(\.small, \.panelMuted).lineLimit(1)
            }
        }
        .padding(.horizontal, t.sp12 + t.sp2)
        .padding(.vertical, t.sp12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(t.panelBoxFill), in: RoundedRectangle(cornerRadius: t.radiusPanel - t.sp4))
    }
}
