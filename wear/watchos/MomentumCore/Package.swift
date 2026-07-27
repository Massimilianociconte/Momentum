// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MomentumCore",
    platforms: [
        .watchOS(.v10),
        .iOS(.v16),
        .macOS(.v13), // host-side unit testing
    ],
    products: [
        .library(name: "MomentumCore", targets: ["MomentumCore"]),
        .library(name: "MomentumWatchKit", targets: ["MomentumWatchKit"]),
    ],
    targets: [
        .target(name: "MomentumCore"),
        .target(
            name: "MomentumWatchKit",
            dependencies: ["MomentumCore"],
            resources: [.process("Resources")]
        ),
        .testTarget(name: "MomentumCoreTests", dependencies: ["MomentumCore"]),
        .testTarget(name: "MomentumWatchKitTests", dependencies: ["MomentumWatchKit"]),
    ]
)
