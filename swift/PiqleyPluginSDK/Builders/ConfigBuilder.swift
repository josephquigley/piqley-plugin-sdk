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
public struct ConfigValue: Sendable {
    let key: String
    let value: JSONValue

    public init(_ key: String, _ value: JSONValue) {
        self.key = key
        self.value = value
    }
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

// MARK: - ConfigValues block

public struct ConfigValues: ConfigComponent {
    let entries: [ConfigValue]
    public init(@ConfigValuesBuilder _ builder: () -> [ConfigValue]) {
        self.entries = builder()
    }
}

@resultBuilder
public enum ConfigValuesBuilder {
    public static func buildBlock(_ components: ConfigValue...) -> [ConfigValue] {
        components
    }
    public static func buildExpression(_ expression: ConfigValue) -> ConfigValue { expression }
}

// MARK: - ConfigRules block

public struct ConfigRules: ConfigComponent {
    let rules: [ConfigRule]
    public init(@ConfigRulesBuilder _ builder: () -> [ConfigRule]) {
        self.rules = builder()
    }
}

@resultBuilder
public enum ConfigRulesBuilder {
    public static func buildBlock(_ components: ConfigRule...) -> [ConfigRule] {
        components
    }
    public static func buildExpression(_ expression: ConfigRule) -> ConfigRule { expression }
}

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
        if let c = component as? ConfigValues {
            for entry in c.entries {
                values[entry.key] = entry.value
            }
        } else if let c = component as? ConfigRules {
            rules.append(contentsOf: c.rules.map { $0.toRule() })
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
