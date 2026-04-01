// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "PiqleyPluginSDK",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "PiqleyPluginSDK", targets: ["PiqleyPluginSDK"]),
        .library(name: "Fingerprinting", targets: ["Fingerprinting"]),
        .executable(name: "piqley-build", targets: ["piqley-build"]),
    ],
    dependencies: [
        .package(path: "../piqley-core"),
        .package(url: "https://github.com/kylef/JSONSchema.swift", .upToNextMajor(from: "0.6.0")),
    ],
    targets: [
        .target(
            name: "PiqleyPluginSDK",
            dependencies: [.product(name: "PiqleyCore", package: "piqley-core")],
            path: "swift/PiqleyPluginSDK"
        ),
        .target(
            name: "Fingerprinting",
            dependencies: [.product(name: "PiqleyCore", package: "piqley-core")],
            path: "swift/Fingerprinting"
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
        .testTarget(
            name: "FingerprintingTests",
            dependencies: ["Fingerprinting"],
            path: "swift/FingerprintingTests"
        ),
    ]
)
