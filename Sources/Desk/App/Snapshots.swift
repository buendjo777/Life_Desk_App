import SwiftUI

/// `Desk --render-snapshots <dir>`: every tab, light and dark, at the design size (SPEC "Verification").
@MainActor
enum Snapshots {
    static func run(directory: String) {
        let folder = URL(fileURLWithPath: directory, isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            for tab in Tab.allCases {
                for scheme in [ColorScheme.light, .dark] {
                    let store = Store(isSnapshot: true)
                    store.tab = tab
                    let name = "\(tab.rawValue)-\(scheme == .dark ? "dark" : "light").png"
                    try render(RootView().environment(store), scheme: scheme, to: folder.appendingPathComponent(name))
                }
            }
            print("Rendered \(Tab.allCases.count * 2) snapshots to \(folder.path)")
        } catch {
            FileHandle.standardError.write(Data("Snapshot failed: \(error.localizedDescription)\n".utf8))
            exit(1)
        }
    }

    static func render(_ view: some View, scheme: ColorScheme, size: CGSize = Theme().designSize, to url: URL) throws {
        let renderer = ImageRenderer(
            content: view
                .frame(width: size.width, height: size.height)
                .environment(\.colorScheme, scheme)
        )
        renderer.scale = 2
        guard let image = renderer.nsImage,
              let tiff = image.tiffRepresentation,
              let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:])
        else { throw CocoaError(.fileWriteUnknown) }
        try png.write(to: url)
    }
}
