// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ClaudeCat",
    platforms: [.macOS(.v13)],
    targets: [
        .target(name: "ClaudeCatCore"),
        .executableTarget(name: "ClaudeCat", dependencies: ["ClaudeCatCore"]),
        .executableTarget(name: "claude-cat-hook", dependencies: ["ClaudeCatCore"]),
        .testTarget(name: "ClaudeCatCoreTests", dependencies: ["ClaudeCatCore"]),
    ]
)
