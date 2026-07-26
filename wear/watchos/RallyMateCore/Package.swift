// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "RallyMateCore",
    platforms: [
        .watchOS(.v10),
        .iOS(.v16),
        .macOS(.v13), // host-side unit testing
    ],
    products: [
        .library(name: "RallyMateCore", targets: ["RallyMateCore"]),
        .library(name: "RallyMateWatchKit", targets: ["RallyMateWatchKit"]),
    ],
    targets: [
        .target(name: "RallyMateCore"),
        .target(
            name: "RallyMateWatchKit",
            dependencies: ["RallyMateCore"],
            resources: [.process("Resources")]
        ),
        .testTarget(name: "RallyMateCoreTests", dependencies: ["RallyMateCore"]),
        .testTarget(name: "RallyMateWatchKitTests", dependencies: ["RallyMateWatchKit"]),
    ]
)
