import SwiftUI

// What an app tells the shared components about itself, through the environment.

private struct MotionOnKey: EnvironmentKey {
    static let defaultValue = true
}

private struct OffscreenKey: EnvironmentKey {
    static let defaultValue = false
}

public extension EnvironmentValues {
    /// Hover lift, entrances and fill-ins play. An app sets it to false in snapshots or when the reader switches motion off.
    var motionOn: Bool {
        get { self[MotionOnKey.self] }
        set { self[MotionOnKey.self] = newValue }
    }

    /// The view is being drawn to an image, where scroll views cannot be drawn.
    var offscreen: Bool {
        get { self[OffscreenKey.self] }
        set { self[OffscreenKey.self] = newValue }
    }
}

/// Draws a view to a PNG at twice its size, without a window. Both apps make their snapshots with it.
@MainActor
public enum Snapshot {
    public static func render(_ view: some View, scheme: ColorScheme, size: CGSize = Theme().designSize, to url: URL) throws {
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
