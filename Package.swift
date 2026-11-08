// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "MagicMousePad",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "MagicMousePad", targets: ["MagicMousePad"])
    ],
    targets: [
        // Thin C bridge that loads Apple's MultitouchSupport framework at runtime.
        .target(
            name: "CMultitouch",
            path: "Sources/CMultitouch"
        ),
        // Pure-Swift gesture model + recognizer. No AppKit, fully unit-tested.
        .target(
            name: "MagicMousePadCore",
            path: "Sources/MagicMousePadCore"
        ),
        // The menu-bar app.
        .executableTarget(
            name: "MagicMousePad",
            dependencies: ["CMultitouch", "MagicMousePadCore"],
            path: "Sources/MagicMousePad"
        ),
        .testTarget(
            name: "MagicMousePadCoreTests",
            dependencies: ["MagicMousePadCore"],
            path: "Tests/MagicMousePadCoreTests"
        ),
    ]
)
