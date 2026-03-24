import Foundation
import PiqleyCore

// MARK: - Config typealias

/// Alias for `Value` when used in a `ConfigRegistry` DSL.
/// Creates a `ConfigEntry.value` entry.
public typealias Config = Value

// MARK: - ConfigRegistry

/// A registry of config entries built with a result builder DSL.
///
/// Plugin authors declare config values and secrets alongside their `HookRegistry`:
/// ```swift
/// public let pluginConfig = ConfigRegistry {
///     Config("siteUrl", type: .string, default: "https://example.com")
///     Config("outputQuality", type: .int, default: 85)
///     Secret("API_KEY", type: .string)
/// }
/// ```
public struct ConfigRegistry: Sendable {
    public let entries: [ConfigEntry]

    public init(@ConfigComponentBuilder _ builder: () -> [any ConfigComponent]) {
        self.entries = builder().compactMap { component in
            switch component {
            case let value as Value:
                return value.entry
            case let secret as Secret:
                return secret.entry
            default:
                return nil
            }
        }
    }

    /// Writes the registry's config entries to `config-entries.json` in the given directory.
    public func writeConfigEntries(to directory: URL) throws {
        let data = try JSONEncoder.piqleyPrettyPrint.encode(entries)
        try data.write(
            to: directory.appendingPathComponent("config-entries.json"),
            options: .atomic
        )
    }
}
