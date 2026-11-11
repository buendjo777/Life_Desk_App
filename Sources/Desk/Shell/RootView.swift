import SwiftUI

/// The three-part layout: floating sidebar, content column, right rail or inspector.
struct RootView: View {
    @Environment(Store.self) private var store
    @Environment(\.colorScheme) private var scheme
    @FocusState private var keysFocused: Bool

    var body: some View {
        let t = Theme(scheme: scheme, density: store.prefs.density)
        HStack(spacing: 0) {
            Sidebar().padding(t.sidebarInset)
            TabHost()
                .padding(.leading, t.columnGap - t.sidebarInset)
                .padding(.trailing, t.columnGap)
                .padding(.top, t.columnGap)
        }
        .background(t.canvas)
        .background {
            if !store.isSnapshot {
                WindowChrome(
                    origin: CGPoint(x: t.sidebarInset + t.sp12 + t.sp2 + t.sp6, y: t.sidebarInset + t.sp16 + t.sp2),
                    spacing: t.lightGap - t.sp2
                )
            }
        }
        .ignoresSafeArea()
        .sheet(isPresented: Binding(get: { store.showCustomise }, set: { store.showCustomise = $0 })) {
            CustomiseView().environment(store).environment(\.theme, t)
        }
        .environment(\.theme, t)
        .preferredColorScheme(store.isSnapshot ? nil : store.prefs.appearance.scheme)
        .task {
            // Launch, then every 15 minutes: pull the vault (Live). The clock moves every minute.
            guard !store.isSnapshot else { return }
            store.sync()
            var minutes = 0
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(t.clockTick))
                minutes += 1
                if minutes % t.syncMinutes == 0 { store.sync() } else { store.tick() }
            }
        }
        .focusable()
        .focusEffectDisabled()
        .focused($keysFocused)
        .onAppear { keysFocused = true }
        .onKeyPress(.escape) {
            guard store.inspectorOpen else { return .ignored }
            store.inspectorOpen = false
            return .handled
        }
        .onKeyPress(.space) {
            store.tickSelection()
            return .handled
        }
        .onKeyPress(.return) {
            guard store.selection != nil else { return .ignored }
            store.inspectorOpen = true
            return .handled
        }
    }
}

/// The top bar, then the selected tab's main column and rail, with the inspector sliding over the rail.
struct TabHost: View {
    @Environment(Store.self) private var store
    @Environment(\.theme) private var t

    var body: some View {
        let prefs = store.prefs.layouts[store.tab.rawValue]
        let main = TabLayout.arranged(store.tab, .main, prefs: prefs)
        let rail = TabLayout.arranged(store.tab, .rail, prefs: prefs)
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: t.columnGap) {
                SearchBar()
                RailTop()
            }
            .zIndex(1)
            .overlay(alignment: .topLeading) {
                if !store.query.isEmpty {
                    SearchResults()
                        .padding(.trailing, t.railWidth + t.columnGap)
                        .offset(y: t.searchHeight + t.sp8)
                }
            }
            if let banner = store.banner {
                BannerView(message: banner).padding(.top, t.sp12)
            }
            HStack(alignment: .top, spacing: t.columnGap) {
                Scroller {
                    VStack(alignment: .leading, spacing: t.sp20 + t.sp2) {
                        TabHeader()
                        if let empty = store.d.emptyState(for: store.tab) {
                            EmptyState(line: empty.line, hint: empty.hint)
                        } else {
                            SectionFlow(sections: main)
                        }
                    }
                    .padding(.top, t.sp8)
                    .padding(.bottom, t.columnGap)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                if !rail.isEmpty {
                    Scroller {
                        VStack(alignment: .leading, spacing: t.sp12 + t.sp2) {
                            ForEach(rail) { $0.view }
                        }
                        .padding(.bottom, t.columnGap)
                    }
                    .frame(width: t.railWidth)
                }
            }
            .padding(.top, t.sp20 + t.sp2)
            .overlay(alignment: .topTrailing) {
                if let item = store.inspector {
                    Inspector(item: item)
                        .frame(width: t.railWidth)
                        .padding(.top, t.sp20 + t.sp2)
                        .padding(.bottom, t.columnGap)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            .deskAnimation(store.inspector)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

/// The greeting on Today; the tab title and a summary sentence elsewhere.
struct TabHeader: View {
    @Environment(Store.self) private var store
    @Environment(\.theme) private var t

    var body: some View {
        VStack(alignment: .leading, spacing: t.sp8) {
            if store.tab == .today {
                Text(verbatim: store.d.greeting).style(\.display, \.ink)
            } else {
                Text(verbatim: store.tab.title).style(\.title, \.ink)
            }
            PhraseText(phrases: store.d.summary(for: store.tab))
                .lineSpacing(t.sp4)
                .frame(maxWidth: t.summaryWidth, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
