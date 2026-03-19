import Foundation
import PiqleyCore

// MARK: - RuleMatch

/// A typed match specification that encodes to a MatchConfig.
public struct RuleMatch: Sendable {
    let field: MatchField
    let pattern: MatchPattern

    private init(field: MatchField, pattern: MatchPattern) {
        self.field = field
        self.pattern = pattern
    }

    public static func field(_ field: MatchField, pattern: MatchPattern) -> RuleMatch {
        RuleMatch(field: field, pattern: pattern)
    }

    func toMatchConfig() -> MatchConfig {
        MatchConfig(field: field.encoded, pattern: pattern.encoded)
    }
}

// MARK: - RuleEmit

/// A typed emit specification that encodes to an EmitConfig.
public enum RuleEmit: Sendable {
    case keywords([String])
    case values(field: String, [String])
    case remove(field: String, [String])
    case removeKeywords([String])
    case replace(field: String, [(pattern: String, replacement: String)])
    case replaceKeywords([(pattern: String, replacement: String)])
    case removeField(field: String)
    case removeAllFields

    func toEmitConfig() -> EmitConfig {
        switch self {
        case let .keywords(values):
            EmitConfig(field: "keywords", values: values)
        case let .values(field, values):
            EmitConfig(field: field, values: values)
        case let .remove(field, values):
            EmitConfig(action: "remove", field: field, values: values)
        case let .removeKeywords(values):
            EmitConfig(action: "remove", field: "keywords", values: values)
        case let .replace(field, pairs):
            EmitConfig(action: "replace", field: field, replacements: pairs.map {
                Replacement(pattern: $0.pattern, replacement: $0.replacement)
            })
        case let .replaceKeywords(pairs):
            EmitConfig(action: "replace", field: "keywords", replacements: pairs.map {
                Replacement(pattern: $0.pattern, replacement: $0.replacement)
            })
        case let .removeField(field):
            EmitConfig(action: "removeField", field: field)
        case .removeAllFields:
            EmitConfig(action: "removeField", field: "*")
        }
    }
}

// MARK: - ConfigValue

/// A key-value pair for plugin configuration.
///
/// Use the `=>` operator for ergonomic construction inside a `Values` block:
/// ```swift
/// Values {
///     "url" => "https://example.com"
///     "quality" => 85
///     "enabled" => true
/// }
/// ```
public struct ConfigValue: Sendable {
    let key: String
    let value: JSONValue

    public init(_ key: String, _ value: JSONValue) {
        self.key = key
        self.value = value
    }
}

/// Operator for creating config value pairs inside a `Values` block.
infix operator =>: AssignmentPrecedence

/// Creates a config value pair. Use inside a `Values` block.
///
/// Supports `JSONValue` literals via `ExpressibleBy*Literal` conformances:
/// `"key" => 85` works because `85` becomes `JSONValue.number(85)`.
public func => (key: String, value: JSONValue) -> ConfigValue {
    ConfigValue(key, value)
}

// MARK: - ConfigRule

/// A typed declarative rule for a plugin config.
public struct ConfigRule: Sendable {
    let match: RuleMatch
    let emit: [RuleEmit]
    let write: [RuleEmit]

    public init(match: RuleMatch, emit: [RuleEmit] = [], write: [RuleEmit] = []) {
        self.match = match
        self.emit = emit
        self.write = write
    }

    func toRule() -> Rule {
        Rule(
            match: match.toMatchConfig(),
            emit: emit.map { $0.toEmitConfig() },
            write: write.map { $0.toEmitConfig() }
        )
    }
}

// MARK: - ConfigComponent protocol

public protocol ConfigComponent: Sendable {}

// MARK: - Values block

/// A block of key-value config entries.
///
/// ```swift
/// Values {
///     "url" => "https://example.com"
///     "quality" => 85
/// }
/// ```
public struct Values: ConfigComponent {
    let entries: [ConfigValue]
    public init(@ValuesBuilder _ builder: () -> [ConfigValue]) {
        self.entries = builder()
    }
}

/// Backward-compatible alias.
public typealias ConfigValues = Values

@resultBuilder
public enum ValuesBuilder {
    public static func buildBlock(_ components: ConfigValue...) -> [ConfigValue] {
        components
    }
    public static func buildExpression(_ expression: ConfigValue) -> ConfigValue { expression }
}

/// Backward-compatible alias.
public typealias ConfigValuesBuilder = ValuesBuilder

// MARK: - RulesBuilder

@resultBuilder
public enum RulesBuilder {
    public static func buildBlock(_ components: ConfigRule...) -> [ConfigRule] {
        components
    }
    public static func buildExpression(_ expression: ConfigRule) -> ConfigRule { expression }
}

/// Backward-compatible alias.
public typealias ConfigRulesBuilder = RulesBuilder

// MARK: - ConfigComponentBuilder

@resultBuilder
public enum ConfigComponentBuilder {
    public static func buildBlock(_ components: (any ConfigComponent)...) -> [any ConfigComponent] {
        components
    }
    public static func buildExpression(_ expression: any ConfigComponent) -> any ConfigComponent { expression }
}

// MARK: - buildConfig

public func buildConfig(@ConfigComponentBuilder _ builder: () -> [any ConfigComponent]) -> PluginConfig {
    let components = builder()

    var values: [String: JSONValue] = [:]

    for component in components {
        if let component = component as? Values {
            for entry in component.entries {
                values[entry.key] = entry.value
            }
        }
    }

    return PluginConfig(values: values)
}

// MARK: - PluginConfig write extension

extension PluginConfig {
    public func write(to directory: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(self)

        let fileURL = directory.appendingPathComponent(PluginFile.config)
        try data.write(to: fileURL)
    }
}
