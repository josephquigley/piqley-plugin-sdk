// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "PiqleyPluginSDK",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "PiqleyPluginSDK", targets: ["PiqleyPluginSDK"]),
        .executable(name: "piqley-build", targets: ["piqley-build"]),
    ],
    dependencies: [
        .package(url: "https://github.com/josephquigley/piqley-core", .upToNextMajor(from: "0.5.0")),
        .package(url: "https://github.com/kylef/JSONSchema.swift", .upToNextMajor(from: "0.6.0")),
    ],
    targets: [
        .target(
            name: "PiqleyPluginSDK",
            dependencies: [.product(name: "PiqleyCore", package: "piqley-core")],
            path: "swift/PiqleyPluginSDK"
        ),
        .executableTarget(
            name: "piqley-build",
            dependencies: ["PiqleyPluginSDK"],
            path: "swift/PiqleyBuild"
        ),
        .testTarget(
            name: "PiqleyPluginSDKTests",
            dependencies: [
                "PiqleyPluginSDK",
                .product(name: "JSONSchema", package: "JSONSchema.swift"),
            ],
            path: "swift/Tests",
            resources: [.copy("schemas")]
        ),
    ]
)
