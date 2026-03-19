import Foundation
import PiqleyCore

/// Describes build inputs for packaging a plugin into a `.piqleyplugin` archive.
public struct BuildManifest: Codable, Sendable, Equatable {
    public let pluginName: String
    public let pluginSchemaVersion: String
    public let bin: [String]
    public let data: [String]
    public let dependencies: [PluginDependency]

    public init(
        pluginName: String,
        pluginSchemaVersion: String,
        bin: [String],
        data: [String] = [],
        dependencies: [PluginDependency] = []
    ) {
        self.pluginName = pluginName
        self.pluginSchemaVersion = pluginSchemaVersion
        self.bin = bin
        self.data = data
        self.dependencies = dependencies
    }

    /// Loads a `BuildManifest` from `piqley-build-manifest.json` in the given directory.
    public static func load(from directory: URL) throws -> BuildManifest {
        let url = directory.appendingPathComponent("piqley-build-manifest.json")
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(BuildManifest.self, from: data)
    }
}
