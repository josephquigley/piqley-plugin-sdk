// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "__PLUGIN_PACKAGE_NAME__",
    platforms: [.macOS(.v15)],
    dependencies: [
        .package(
            url: "https://github.com/josephquigley/piqley-plugin-sdk",
            .upToNextMajor(from: "__SDK_VERSION__")
        ),
    ],
    targets: [
        .target(
            name: "PluginHooks",
            dependencies: [
                .product(name: "PiqleyPluginSDK", package: "piqley-plugin-sdk"),
            ],
            path: "Sources/PluginHooks"
        ),
        .executableTarget(
            name: "__PLUGIN_PACKAGE_NAME__",
            dependencies: ["PluginHooks"],
            path: "Sources/__PLUGIN_PACKAGE_NAME__"
        ),
        .executableTarget(
            name: "piqley-stage-gen",
            dependencies: ["PluginHooks"],
            path: "Sources/StageGen"
        ),
    ]
)
