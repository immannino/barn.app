// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "barn",
    platforms: [.macOS(.v14)],
    targets: [
        .target(
            name: "BarnKit",
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
