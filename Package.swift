// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "Spatia",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Spatia", targets: ["Spatia"]),
        .executable(name: "SpatiaBenchmarks", targets: ["SpatiaBenchmarks"]),
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
        .executableTarget(
            name: "SpatiaBenchmarks",
            dependencies: ["SpatiaCore"],
            path: "Sources/SpatiaBenchmarks"
        ),
        .testTarget(
            name: "SpatiaCoreTests",
            dependencies: ["SpatiaCore"],
            path: "Tests/SpatiaCoreTests"
        ),
        .testTarget(
            name: "SpatiaTests",
            dependencies: ["Spatia", "SpatiaCore"],
            path: "Tests/SpatiaTests"
        )
    ]
)
