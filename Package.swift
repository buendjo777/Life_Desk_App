// swift-tools-version:5.9
import PackageDescription

// Two apps on one platform. DeskKit holds what they share (theme, palettes, glass, motion, backdrop);
// Desk is the dashboard, AboutJose the storytelling portfolio. Warnings are errors, so the build stays warning-free.
let settings: [SwiftSetting] = [
    .enableUpcomingFeature("BareSlashRegexLiterals"),
    .unsafeFlags(["-warnings-as-errors"]),
]

let package = Package(
    name: "Desk",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "DeskKit", path: "Sources/DeskKit", swiftSettings: settings),
        .executableTarget(name: "Desk", dependencies: ["DeskKit"], path: "Sources/Desk", swiftSettings: settings),
        .executableTarget(name: "AboutJose", dependencies: ["DeskKit"], path: "Sources/AboutJose", swiftSettings: settings),
        .testTarget(name: "DeskTests", dependencies: ["Desk"], path: "Tests/DeskTests"),
        .testTarget(name: "AboutJoseTests", dependencies: ["AboutJose"], path: "Tests/AboutJoseTests"),
    ]
)
