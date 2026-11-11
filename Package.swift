// swift-tools-version:5.9
import PackageDescription

// One executable target, as SPEC.md requires. Warnings are errors, so the build stays warning-free.
let package = Package(
    name: "Desk",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Desk",
            path: "Sources/Desk",
            swiftSettings: [.unsafeFlags(["-warnings-as-errors"])]
        ),
        .testTarget(name: "DeskTests", dependencies: ["Desk"], path: "Tests/DeskTests"),
    ]
)
