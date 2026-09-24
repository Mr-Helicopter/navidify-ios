// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "NavidifyKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "NavidifyKit",
            targets: ["NavidifyKit"]
        ),
    ],
    targets: [
        .target(
            name: "NavidifyKit",
            dependencies: [],
            path: "Sources/NavidifyKit"
        ),
        .testTarget(
            name: "NavidifyKitTests",
            dependencies: ["NavidifyKit"],
            path: "Tests/NavidifyKitTests"
        ),
    ]
)
