import Foundation
import PiqleyCore

// MARK: - RuleMatch

/// A typed match specification that encodes to a MatchConfig.
public struct RuleMatch: Sendable {
    let field: MatchField
    let pattern: MatchPattern
    let hook: Hook?

    private init(field: MatchField, pattern: MatchPattern, hook: Hook? = nil) {
        self.field = field
        self.pattern = pattern
        self.hook = hook
    }

    public static func field(_ field: MatchField, pattern: MatchPattern, hook: Hook? = nil) -> RuleMatch {
        RuleMatch(field: field, pattern: pattern, hook: hook)
    }

    func toMatchConfig() -> MatchConfig {
        MatchConfig(hook: hook?.rawValue, field: field.encoded, pattern: pattern.encoded)
    }
}

// MARK: - RuleEmit

/// A typed emit specification that encodes to an EmitConfig.
public enum RuleEmit: Sendable {
    case keywords([String])
    case values(field: String, [String])

    func toEmitConfig() -> EmitConfig {
        switch self {
        case let .keywords(values):
            EmitConfig(field: nil, values: values)
        case let .values(field, values):
            EmitConfig(field: field, values: values)
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
    let hook: Hook?
    let emit: RuleEmit

    public init(match: RuleMatch, hook: Hook? = nil, emit: RuleEmit) {
        self.match = match
        self.hook = hook
        self.emit = emit
    }

    func toRule() -> Rule {
        Rule(match: match.toMatchConfig(), emit: emit.toEmitConfig())
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

// MARK: - Rules block

/// A block of declarative metadata matching rules.
///
/// ```swift
/// Rules {
///     ConfigRule(
///         match: .field(.original(.model), pattern: .regex(".*a7r.*")),
///         emit: .keywords(["Sony", "A7R Life"])
///     )
/// }
/// ```
public struct Rules: ConfigComponent {
    let rules: [ConfigRule]
    public init(@RulesBuilder _ builder: () -> [ConfigRule]) {
        self.rules = builder()
    }
}

/// Backward-compatible alias.
public typealias ConfigRules = Rules

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
    var rules: [Rule] = []

    for component in components {
        if let component = component as? Values {
            for entry in component.entries {
                values[entry.key] = entry.value
            }
        } else if let component = component as? Rules {
            rules.append(contentsOf: component.rules.map { $0.toRule() })
        }
    }

    return PluginConfig(values: values, rules: rules)
}

// MARK: - PluginConfig write extension

extension PluginConfig {
    public func write(to directory: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(self)

        let fileURL = directory.appendingPathComponent("config.json")
        try data.write(to: fileURL)
    }
}
