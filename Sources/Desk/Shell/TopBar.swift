import SwiftUI

/// The search field across the top, with scope chips and ⌘F.
struct SearchBar: View {
    @Environment(Store.self) private var store
    @Environment(\.theme) private var t
    @FocusState private var focused: Bool

    var body: some View {
        @Bindable var store = store
        HStack(spacing: t.sp10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: t.symbol, weight: .semibold))
                .foregroundStyle(t.onAccent)
                .frame(width: t.badge, height: t.badge)
                .background(t.rust, in: Circle())
                .accessibilityHidden(true)
            field
            Text(verbatim: "In:").style(\.small, \.inkMuted)
            ForEach(Derived.SearchScope.allCases) { scope in
                scopeChip(scope)
            }
            Text(verbatim: "⌘F")
                .style(\.small, \.inkMuted)
                .padding(.horizontal, t.sp6)
                .padding(.vertical, t.sp2)
                .overlay(RoundedRectangle(cornerRadius: t.radiusSmall).strokeBorder(t.line, lineWidth: t.hairline))
                .padding(.trailing, t.sp4)
        }
        .padding(.leading, t.sp6)
        .padding(.trailing, t.sp8)
        .frame(height: t.searchHeight)
        .background(t.raised, in: Capsule())
        .overlay(Capsule().strokeBorder(t.line, lineWidth: t.hairline))
        .onChange(of: store.searchFocus) { focused = true }
    }

    @ViewBuilder private var field: some View {
        @Bindable var store = store
        let placeholder = "Search tasks, emails, projects, people…"
        if store.isSnapshot {
            Text(verbatim: placeholder).style(\.body, \.inkMuted).lineLimit(1)
            Spacer(minLength: 0)
        } else {
            TextField(placeholder, text: $store.query)
                .textFieldStyle(.plain)
                .font(t.body.font)
                .foregroundStyle(t.ink)
                .focused($focused)
                .onExitCommand {
                    store.query = ""
                    focused = false
                }
                .accessibilityLabel("Search")
        }
    }

    private func scopeChip(_ scope: Derived.SearchScope) -> some View {
        let active = store.searchScope == scope
        return Button {
            store.searchScope = scope
        } label: {
            Text(verbatim: scope.rawValue)
                .style(\.chip, active ? \.onPrimary : \.ink)
                .padding(.horizontal, t.sp10)
                .padding(.vertical, t.sp4 + t.hairline)
                .background(active ? t.primary : .clear, in: Capsule())
                .overlay(Capsule().strokeBorder(active ? .clear : t.line, style: StrokeStyle(lineWidth: t.hairline, dash: [t.sp4 - t.hairline, t.sp2])))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Search in \(scope.rawValue)")
        .accessibilityAddTraits(active ? .isSelected : [])
    }
}

/// Search results, shown under the search field while there is a query.
struct SearchResults: View {
    @Environment(Store.self) private var store
    @Environment(\.theme) private var t

    var body: some View {
        let hits = store.d.search(store.query, scope: store.searchScope)
        VStack(alignment: .leading, spacing: t.sp6) {
            if hits.isEmpty {
                Text(verbatim: "Nothing matches “\(store.query)”.").style(\.body, \.inkMuted).padding(t.sp8)
            }
            ForEach(hits.prefix(t.listRows + t.listRows)) { hit in
                Button {
                    store.query = ""
                    store.tab = hit.tab
                    store.open(hit.item)
                } label: {
                    HStack(spacing: t.sp10) {
                        VStack(alignment: .leading, spacing: t.sp2) {
                            Text(verbatim: hit.title).style(\.rowTitle, \.ink).lineLimit(1)
                            Text(verbatim: hit.subtitle).style(\.small, \.inkMuted).lineLimit(1)
                        }
                        Spacer()
                        Chip(text: hit.scope.rawValue)
                    }
                    .padding(.horizontal, t.sp12)
                    .padding(.vertical, t.sp8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(t.sp8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .raisedPanel(shadow: true)
    }
}

/// The run-status chip: a colour and always a word.
struct StatusChip: View {
    @Environment(Store.self) private var store
    @Environment(\.theme) private var t

    var body: some View {
        let status = store.d.runStatus
        HStack(spacing: t.sp8) {
            Circle().fill(t.fill(status.level.accent)).frame(width: t.sp8, height: t.sp8)
            Text(verbatim: "\(status.level.word) · \(status.lastRunText.map { "last run \($0)" } ?? "no run yet")")
                .style(\.smallStrong, \.ink)
                .lineLimit(1)
                .minimumScaleFactor(t.tightScale)
        }
        .padding(.horizontal, t.sp12 + t.hairline)
        .frame(height: t.statusChip)
        .raisedPanel(radius: t.statusChip / 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Run status \(status.level.word)")
    }
}

extension Derived.RunLevel {
    var accent: Accent {
        switch self {
        case .green: .moss
        case .amber: .ochre
        case .red: .alert
        }
    }
}

/// The status chip and the round buttons: sync, Run now, settings.
struct RailTop: View {
    @Environment(Store.self) private var store
    @Environment(\.theme) private var t
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        HStack(spacing: t.sp8) {
            StatusChip()
            Spacer(minLength: 0)
            IconButton(symbol: "arrow.triangle.2.circlepath", label: "Sync now") { store.sync() }
            IconButton(symbol: "play.fill", label: "Run now") { Links.open(Links.web(store.data.settings.links.runNow)) }
            IconButton(symbol: "gearshape", label: "Settings") { openSettings() }
        }
        .frame(width: t.railWidth, height: t.searchHeight)
    }
}

/// A banner for sync or write failures: never a silently stale view.
struct BannerView: View {
    @Environment(Store.self) private var store
    @Environment(\.theme) private var t
    let message: String

    var body: some View {
        HStack(spacing: t.sp10) {
            Image(systemName: "exclamationmark.triangle.fill").font(.system(size: t.symbol))
            Text(verbatim: message).style(\.smallStrong).lineLimit(2)
            Spacer()
            Button("Retry") { store.sync() }.buttonStyle(.deskSecondary)
            Button("Dismiss") { store.banner = nil }.buttonStyle(.deskSecondary)
        }
        .foregroundStyle(t.panelText)
        .padding(.horizontal, t.sp16)
        .padding(.vertical, t.sp10)
        .background(t.alert, in: RoundedRectangle(cornerRadius: t.radiusRow))
        .environment(\.theme, Theme(scheme: .dark, density: t.density))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Problem: \(message)")
    }
}
