// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "Spatia",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Spatia", targets: ["Spatia"]),
        .library(name: "SpatiaCore", targets: ["SpatiaCore"])
    ],
    targets: [
        .executableTarget(
            name: "Spatia",
            dependencies: ["SpatiaCore"],
            path: "Sources/Spatia"
        ),
        .target(
            name: "SpatiaCore",
            path: "Sources/SpatiaCore"
        ),
        .testTarget(
            name: "SpatiaCoreTests",
            dependencies: ["SpatiaCore"],
            path: "Tests/SpatiaCoreTests"
        )
    ]
)
