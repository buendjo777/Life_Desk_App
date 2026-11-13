import SwiftUI

/// The app icon, drawn from the theme: a graphite tile, the focus sun from the Today card and a "D".
/// `Desk --render-icon <dir>` writes an `.iconset` for `iconutil` (see `scripts/build-app.sh`).
struct AppIconView: View {
    let size: CGFloat

    var body: some View {
        let t = Theme(scheme: .light)
        let tile = size * t.iconTile
        ZStack {
            RoundedRectangle(cornerRadius: tile * t.iconCorner, style: .continuous).fill(t.panel)
            Circle().fill(t.focus)
                .frame(width: tile * 0.62, height: tile * 0.62)
                .offset(x: tile * 0.26, y: -tile * 0.26)
            CardShapeView(shape: .triangle, color: t.caution)
                .frame(width: tile * 0.5, height: tile * 0.5)
                .rotationEffect(.degrees(14))
                .offset(x: -tile * 0.34, y: tile * 0.36)
            Text(verbatim: "D")
                .font(.system(size: tile * 0.56, weight: .bold))
                .foregroundStyle(t.panelText)
                .offset(x: -tile * 0.08, y: tile * 0.04)
        }
        .frame(width: tile, height: tile)
        .clipShape(RoundedRectangle(cornerRadius: tile * t.iconCorner, style: .continuous))
        .frame(width: size, height: size)
    }
}

@MainActor
enum AppIcon {
    static func run(directory: String) {
        let folder = URL(fileURLWithPath: directory, isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            for points in [16, 32, 128, 256, 512] {
                for scale in [1, 2] {
                    let renderer = ImageRenderer(content: AppIconView(size: CGFloat(points)))
                    renderer.scale = CGFloat(scale)
                    guard let image = renderer.cgImage else { throw CocoaError(.fileWriteUnknown) }
                    let name = "icon_\(points)x\(points)\(scale == 2 ? "@2x" : "").png"
                    guard let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else {
                        throw CocoaError(.fileWriteUnknown)
                    }
                    try png.write(to: folder.appendingPathComponent(name))
                }
            }
        } catch {
            FileHandle.standardError.write(Data("Icon failed: \(error.localizedDescription)\n".utf8))
            exit(1)
        }
    }
}
