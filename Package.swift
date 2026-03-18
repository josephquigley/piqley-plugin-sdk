// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "PiqleyPluginSDK",
    products: [
        .library(name: "PiqleyPluginSDK", targets: ["PiqleyPluginSDK"]),
    ],
    targets: [
        .target(name: "PiqleyPluginSDK", path: "swift/PiqleyPluginSDK"),
    ]
)
