// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "PiqleyPluginSDK",
    products: [
        .library(name: "PiqleyPluginSDK", targets: ["PiqleyPluginSDK"]),
    ],
    dependencies: [
        .package(path: "../piqley-core"),
        .package(url: "https://github.com/kylef/JSONSchema.swift", from: "0.6.0"),
    ],
    targets: [
        .target(
            name: "PiqleyPluginSDK",
            dependencies: [.product(name: "PiqleyCore", package: "piqley-core")],
            path: "swift/PiqleyPluginSDK"
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
