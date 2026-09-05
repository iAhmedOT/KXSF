// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "KXSFCore",
    platforms: [
        .iOS(.v18),
        .macOS(.v14),
    ],
    products: [
        .library(name: "KXSFCore", targets: ["KXSFCore"]),
    ],
    targets: [
        .target(name: "KXSFCore"),
        .testTarget(
            name: "KXSFCoreTests",
            dependencies: ["KXSFCore"]
        ),
    ]
)
