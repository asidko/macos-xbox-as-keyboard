// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "XboxAsKeyboard",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "XboxAsKeyboard",
            path: "Sources",
            linkerSettings: [
                .linkedFramework("GameController"),
                .linkedFramework("AppKit"),
                .linkedFramework("CoreGraphics"),
            ]
        )
    ]
)
