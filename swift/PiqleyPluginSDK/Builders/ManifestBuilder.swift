import Foundation
import PiqleyCore

// MARK: - ManifestComponent protocol

public protocol ManifestComponent: Sendable {}

// MARK: - Top-level components

public struct Name: ManifestComponent {
    let value: String
    public init(_ value: String) { self.value = value }
}

public struct Identifier: ManifestComponent {
    let value: String
    public init(_ value: String) { self.value = value }
}

public struct Description: ManifestComponent {
    let value: String
    public init(_ value: String) { self.value = value }
}

public struct ProtocolVersion: ManifestComponent {
    let value: String
    public init(_ value: String) { self.value = value }
}

public struct PluginVersion: ManifestComponent {
    let version: SemanticVersion
    public init(_ string: String) throws {
        self.version = try SemanticVersion(string)
    }
}

// MARK: - ConfigEntries

public struct ConfigEntries: ManifestComponent {
    let entries: [ConfigEntry]
    public init(@ConfigEntryBuilder _ builder: () -> [ConfigEntry]) {
        self.entries = builder()
    }
}

public struct Value: ConfigComponent {
    let entry: ConfigEntry
    public init(_ key: String, type: ConfigValueType, default defaultValue: JSONValue = .null) {
        self.entry = .value(key: key, type: type, value: defaultValue)
    }
}

public struct Secret: ConfigComponent {
    let entry: ConfigEntry
    public init(_ secretKey: String, type: ConfigValueType) {
        self.entry = .secret(secretKey: secretKey, type: type)
    }
}

@resultBuilder
public enum ConfigEntryBuilder {
    public static func buildBlock(_ components: ConfigEntryConvertible...) -> [ConfigEntry] {
        components.map { $0.asConfigEntry() }
    }
    public static func buildExpression(_ expression: Value) -> ConfigEntryConvertible { expression }
    public static func buildExpression(_ expression: Secret) -> ConfigEntryConvertible { expression }
}

public protocol ConfigEntryConvertible {
    func asConfigEntry() -> ConfigEntry
}

extension Value: ConfigEntryConvertible {
    public func asConfigEntry() -> ConfigEntry { entry }
}

extension Secret: ConfigEntryConvertible {
    public func asConfigEntry() -> ConfigEntry { entry }
}

// MARK: - Setup

public struct Setup: ManifestComponent {
    let config: SetupConfig
    public init(command: String, args: [String] = []) {
        self.config = SetupConfig(command: command, args: args)
    }
}

// MARK: - Dependencies

public struct Dependencies: ManifestComponent {
    let deps: [PluginDependency]
    public init(@DependencyBuilder _ builder: () -> [PluginDependency]) {
        self.deps = builder()
    }
}

@resultBuilder
public enum DependencyBuilder {
    public static func buildBlock(_ components: PluginDependency...) -> [PluginDependency] {
        components
    }

    public static func buildExpression(_ expression: String) -> PluginDependency {
        PluginDependency(name: expression)
    }

    public static func buildExpression(_ expression: any StateKey.Type) -> PluginDependency {
        PluginDependency(name: expression.namespace)
    }

    public static func buildExpression(_ expression: PluginDependency) -> PluginDependency {
        expression
    }
}

// MARK: - ManifestComponentBuilder

@resultBuilder
public enum ManifestComponentBuilder {
    public static func buildBlock(_ components: (any ManifestComponent)...) -> [any ManifestComponent] {
        components
    }
    public static func buildExpression(_ expression: any ManifestComponent) -> any ManifestComponent { expression }
    public static func buildOptional(_ component: (any ManifestComponent)?) -> any ManifestComponent {
        component ?? _EmptyManifestComponent()
    }
}

private struct _EmptyManifestComponent: ManifestComponent {}

// MARK: - buildManifest

public func buildManifest(@ManifestComponentBuilder _ builder: () throws -> [any ManifestComponent]) throws -> PluginManifest {
    let components = try builder()

    var identifier: String? = nil
    var name: String? = nil
    var description: String? = nil
    var protocolVersion: String? = nil
    var pluginVersion: SemanticVersion? = nil
    var configEntries: [ConfigEntry] = []
    var setup: SetupConfig? = nil
    var dependencies: [PluginDependency]? = nil

    for component in components {
        if let component = component as? Identifier { identifier = component.value }
        else if let component = component as? Name { name = component.value }
        else if let component = component as? Description { description = component.value }
        else if let component = component as? ProtocolVersion { protocolVersion = component.value }
        else if let component = component as? PluginVersion { pluginVersion = component.version }
        else if let component = component as? ConfigEntries { configEntries = component.entries }
        else if let component = component as? Setup { setup = component.config }
        else if let component = component as? Dependencies { dependencies = component.deps }
    }

    var errors: [String] = []
    if identifier == nil || identifier!.isEmpty {
        errors.append("Plugin identifier must not be empty.")
    }
    if name == nil || name!.isEmpty {
        errors.append("Plugin name must not be empty.")
    }
    if protocolVersion == nil || protocolVersion!.isEmpty {
        errors.append("Plugin protocol version must not be empty.")
    }

    if !errors.isEmpty {
        throw SDKError.manifestValidationFailed(errors)
    }

    return PluginManifest(
        identifier: identifier!,
        name: name!,
        description: description,
        pluginSchemaVersion: protocolVersion!,
        pluginVersion: pluginVersion,
        config: configEntries,
        setup: setup,
        dependencies: dependencies.map { $0.isEmpty ? nil : $0 } ?? nil
    )
}

// MARK: - PluginManifest write extension

extension PluginManifest {
    /// Validates and writes the manifest to a directory as `manifest.json`.
    ///
    /// Runs ``ManifestValidator`` before writing. Throws ``SDKError/manifestValidationFailed(_:)``
    /// if validation fails.
    public func writeValidated(to directory: URL) throws {
        let data = try encode()
        let fileURL = directory.appendingPathComponent(PluginFile.manifest)
        try data.write(to: fileURL)
    }

    /// Validates and encodes the manifest as JSON data without writing to disk.
    ///
    /// Runs ``ManifestValidator`` before encoding. Throws ``SDKError/manifestValidationFailed(_:)``
    /// if validation fails.
    public func encode() throws -> Data {
        let errors = ManifestValidator.validate(self)
        guard errors.isEmpty else { throw SDKError.manifestValidationFailed(errors) }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }
}
