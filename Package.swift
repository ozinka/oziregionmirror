// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "OziRegionMirror",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "OziRegionMirror", targets: ["OziRegionMirror"])],
    targets: [
        .target(name: "RegionCore"),
        .executableTarget(name: "OziRegionMirror", dependencies: ["RegionCore"]),
        .testTarget(name: "RegionCoreTests", dependencies: ["RegionCore"])
    ]
)
