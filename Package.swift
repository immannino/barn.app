// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "barn",
    platforms: [.macOS(.v14)],
    dependencies: [
        // Self-updates for DMG installs. Its bin/ (sign_update, generate_keys) is used by publish.sh.
        .package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.10.0"),
    ],
    targets: [
        .target(
            name: "BarnKit",
            dependencies: [.product(name: "Sparkle", package: "Sparkle")],
            path: "Sources/BarnKit",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .executableTarget(
            name: "barn",
            dependencies: ["BarnKit"],
            path: "Sources/barn"
        ),
        .testTarget(
            name: "barnTests",
            dependencies: ["BarnKit"],
            path: "Tests/barnTests",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
