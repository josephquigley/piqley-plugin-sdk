import Foundation
import PiqleyCore

/// Describes build inputs for packaging a plugin into a `.piqleyplugin` archive.
///
/// The build manifest is the single source of truth: it contains both the build-specific
/// fields (bin, data) and all the metadata that goes into the runtime `manifest.json`.
public struct BuildManifest: Codable, Sendable, Equatable {
    /// Reverse-TLD identifier (e.g. "com.piqley.ghost").
    public let identifier: String
    public let pluginName: String
    public let pluginSchemaVersion: String
    public let description: String?
    public let pluginVersion: String?
    public let config: [ConfigEntry]?
    public let setup: SetupConfig?
    public let supportedFormats: [String]?
    public let conversionFormat: String?
    public let bin: [String]
    public let data: [String]
    public let dependencies: [PluginDependency]?

    public init(
        identifier: String,
        pluginName: String,
        pluginSchemaVersion: String,
        description: String? = nil,
        pluginVersion: String? = nil,
        config: [ConfigEntry]? = nil,
        setup: SetupConfig? = nil,
        supportedFormats: [String]? = nil,
        conversionFormat: String? = nil,
        bin: [String],
        data: [String] = [],
        dependencies: [PluginDependency]? = nil
    ) {
        self.identifier = identifier
        self.pluginName = pluginName
        self.pluginSchemaVersion = pluginSchemaVersion
        self.description = description
        self.pluginVersion = pluginVersion
        self.config = config
        self.setup = setup
        self.supportedFormats = supportedFormats
        self.conversionFormat = conversionFormat
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

    /// Builds a `PluginManifest` from this build manifest's fields.
    public func toPluginManifest() throws -> PluginManifest {
        let semver: SemanticVersion? = try pluginVersion.map { try SemanticVersion($0) }
        return PluginManifest(
            identifier: identifier,
            name: pluginName,
            description: description,
            pluginSchemaVersion: pluginSchemaVersion,
            pluginVersion: semver,
            config: config ?? [],
            setup: setup,
            dependencies: dependencies,
            supportedFormats: supportedFormats,
            conversionFormat: conversionFormat
        )
    }

    // Custom decoding to provide defaults for fields that may not exist in older build manifests.
    private enum CodingKeys: String, CodingKey {
        case identifier, pluginName, pluginSchemaVersion
        case description, pluginVersion
        case config, setup
        case supportedFormats, conversionFormat
        case bin, data, dependencies
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.identifier = try container.decode(String.self, forKey: .identifier)
        self.pluginName = try container.decode(String.self, forKey: .pluginName)
        self.pluginSchemaVersion = try container.decode(String.self, forKey: .pluginSchemaVersion)
        self.description = try container.decodeIfPresent(String.self, forKey: .description)
        self.pluginVersion = try container.decodeIfPresent(String.self, forKey: .pluginVersion)
        self.config = try container.decodeIfPresent([ConfigEntry].self, forKey: .config)
        self.setup = try container.decodeIfPresent(SetupConfig.self, forKey: .setup)
        self.supportedFormats = try container.decodeIfPresent([String].self, forKey: .supportedFormats)
        self.conversionFormat = try container.decodeIfPresent(String.self, forKey: .conversionFormat)
        self.bin = try container.decode([String].self, forKey: .bin)
        self.data = try container.decodeIfPresent([String].self, forKey: .data) ?? []
        if let structured = try? container.decodeIfPresent([PluginDependency].self, forKey: .dependencies) {
            self.dependencies = structured
        } else if let names = try? container.decodeIfPresent([String].self, forKey: .dependencies) {
            self.dependencies = names.map { PluginDependency(name: $0) }
        } else {
            self.dependencies = nil
        }
    }
}
