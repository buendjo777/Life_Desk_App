import SwiftUI

/// The three-part layout: floating sidebar, content column, right rail or inspector.
struct RootView: View {
    @Environment(Store.self) private var store
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let t = Theme(scheme: scheme)
        HStack(spacing: 0) {
            Sidebar().padding(t.sidebarInset)
            Text(verbatim: store.tab.title)
                .style(\.title, \.ink)
                .padding(.leading, t.columnGap - t.sidebarInset)
                .padding(.top, t.columnGap)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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
        .environment(\.theme, t)
    }
}
