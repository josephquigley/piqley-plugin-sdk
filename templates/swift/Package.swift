// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "__PLUGIN_NAME__",
    platforms: [.macOS(.v15)],
    dependencies: [
        .package(
            url: "https://github.com/josephquigley/piqley-plugin-sdk",
            .upToNextMajor(from: "__SDK_VERSION__")
        ),
    ],
    targets: [
        .executableTarget(
            name: "__PLUGIN_IDENTIFIER__",
            dependencies: [
                .product(name: "PiqleyPluginSDK", package: "piqley-plugin-sdk"),
            ]
        ),
    ]
)
