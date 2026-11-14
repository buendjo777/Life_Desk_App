import SwiftUI
import DeskKit

/// `AboutJose --render-snapshots <dir>`: every chapter, light and dark, at the design size.
@MainActor
enum Snapshots {
    static func run(directory: String) {
        let folder = URL(fileURLWithPath: directory, isDirectory: true)
        do {
            let story = try Resources.loadStory().get()
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            for chapter in Chapter.allCases {
                for scheme in [ColorScheme.light, .dark] {
                    let reader = Reader(story: story, chapter: chapter, isSnapshot: true)
                    let name = "\(chapter.number)-\(chapter.slug)-\(scheme == .dark ? "dark" : "light").png"
                    try Snapshot.render(StoryView().environment(reader), scheme: scheme, to: folder.appendingPathComponent(name))
                }
            }
            print("Rendered \(Chapter.allCases.count * 2) snapshots to \(folder.path)")
        } catch {
            fail("Snapshot failed: \((error as? StoryError)?.message ?? error.localizedDescription)")
        }
    }

    /// `AboutJose --render-icon <dir>` writes an `.iconset` for `iconutil` (see `scripts/build-about.sh`).
    static func icon(directory: String) {
        let folder = URL(fileURLWithPath: directory, isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            for points in [16, 32, 128, 256, 512] {
                for scale in [1, 2] {
                    let renderer = ImageRenderer(content: AboutIcon(size: CGFloat(points)))
                    renderer.scale = CGFloat(scale)
                    guard let image = renderer.cgImage,
                          let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
                    else { throw CocoaError(.fileWriteUnknown) }
                    try png.write(to: folder.appendingPathComponent("icon_\(points)x\(points)\(scale == 2 ? "@2x" : "").png"))
                }
            }
        } catch {
            fail("Icon failed: \(error.localizedDescription)")
        }
    }

    private static func fail(_ message: String) -> Never {
        FileHandle.standardError.write(Data("\(message)\n".utf8))
        exit(1)
    }
}

/// The app icon, drawn from the theme: the dark field, the tide rising from the bottom edge, and a "J".
struct AboutIcon: View {
    let size: CGFloat

    var body: some View {
        let t = Theme(scheme: .dark)
        let tile = size * t.iconTile
        ZStack {
            Rectangle().fill(LinearGradient(colors: t.fieldStops, startPoint: .top, endPoint: .bottom))
            Circle().fill(t.focus)
                .frame(width: tile, height: tile)
                .offset(y: tile * 0.72)
            Text(verbatim: "J")
                .font(.system(size: tile * 0.5, weight: .semibold))
                .foregroundStyle(t.ink)
                .offset(y: -tile * 0.08)
        }
        .frame(width: tile, height: tile)
        .clipShape(RoundedRectangle(cornerRadius: tile * t.iconCorner, style: .continuous))
        .frame(width: size, height: size)
    }
}
