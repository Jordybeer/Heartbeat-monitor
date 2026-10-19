// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "HeartbeatCore",
    platforms: [.iOS("26.0"), .macOS(.v13)],
    products: [.library(name: "HeartbeatCore", targets: ["HeartbeatCore"])],
    targets: [
        .target(name: "HeartbeatCore"),
        .testTarget(name: "HeartbeatCoreTests", dependencies: ["HeartbeatCore"])
    ]
)
