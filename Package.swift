// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "PiqleyPluginSDK",
    products: [
        .library(name: "PiqleyPluginSDK", targets: ["PiqleyPluginSDK"]),
    ],
    dependencies: [
        .package(url: "https://github.com/josephquigley/piqley-core.git", from: "0.2.0"),
    ],
    targets: [
        .target(
            name: "PiqleyPluginSDK",
            dependencies: [.product(name: "PiqleyCore", package: "piqley-core")],
            path: "swift/PiqleyPluginSDK"
        ),
        .testTarget(
            name: "PiqleyPluginSDKTests",
            dependencies: ["PiqleyPluginSDK"],
            path: "swift/Tests"
        ),
    ]
)
