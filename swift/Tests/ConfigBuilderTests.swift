import Testing
@testable import PiqleyPluginSDK
import PiqleyCore
import Foundation

// MARK: - Test helper

private enum HashtagKeys: String, StateKey {
    static let namespace = "hashtag"
    case tags
    case caption
}

// MARK: - Build config with values

@Test func configBuilderValues() {
    let config = buildConfig {
        Values {
            "quality" => 80
            "enabled" => true
        }
    }
    #expect(config.values["quality"] == .number(80))
    #expect(config.values["enabled"] == .bool(true))
    #expect(config.rules.isEmpty)
}

// MARK: - Build config with rules (original field + dependency field)

@Test func configBuilderRules() {
    let config = buildConfig {
        Rules {
            ConfigRule(
                match: .field(.original(.model), pattern: .exact("Sony")),
                emit: [.keywords(["#sony"])]
            )
            ConfigRule(
                match: .field(.dependency(HashtagKeys.tags), pattern: .glob("*nature*")),
                emit: [.keywords(["#nature"])]
            )
        }
    }
    #expect(config.values.isEmpty)
    #expect(config.rules.count == 2)
    #expect(config.rules[0].match.field == "original:TIFF:Model")
    #expect(config.rules[0].match.pattern == "Sony")
    #expect(config.rules[0].emit[0].values == ["#sony"])
    #expect(config.rules[1].match.field == "hashtag:tags")
    #expect(config.rules[1].match.pattern == "glob:*nature*")
}

// MARK: - Build config with values and rules

@Test func configBuilderValuesAndRules() {
    let config = buildConfig {
        Values {
            "mode" => "auto"
        }
        Rules {
            ConfigRule(
                match: .field(.original(.keywords), pattern: .regex("^portrait$")),
                emit: [.keywords(["#portrait"])]
            )
        }
    }
    #expect(config.values["mode"] == .string("auto"))
    #expect(config.rules.count == 1)
    #expect(config.rules[0].match.pattern == "regex:^portrait$")
}

// MARK: - RuleEmit.keywords sets field to "keywords"

@Test func ruleEmitKeywordsField() {
    let emit = RuleEmit.keywords(["#tag1", "#tag2"])
    let emitConfig = emit.toEmitConfig()
    #expect(emitConfig.field == "keywords")
    #expect(emitConfig.values == ["#tag1", "#tag2"])
    #expect(emitConfig.action == nil)
}

// MARK: - RuleEmit.values custom field

@Test func ruleEmitValuesCustomField() {
    let emit = RuleEmit.values(field: "custom:field", ["value1", "value2"])
    let emitConfig = emit.toEmitConfig()
    #expect(emitConfig.field == "custom:field")
    #expect(emitConfig.values == ["value1", "value2"])
}

// MARK: - New emit actions

@Test func ruleEmitRemove() {
    let emit = RuleEmit.remove(field: "keywords", ["generic-camera", "glob:auto-*"])
    let config = emit.toEmitConfig()
    #expect(config.action == "remove")
    #expect(config.field == "keywords")
    #expect(config.values == ["generic-camera", "glob:auto-*"])
}

@Test func ruleEmitRemoveKeywords() {
    let emit = RuleEmit.removeKeywords(["old-tag"])
    let config = emit.toEmitConfig()
    #expect(config.action == "remove")
    #expect(config.field == "keywords")
    #expect(config.values == ["old-tag"])
}

@Test func ruleEmitReplace() {
    let emit = RuleEmit.replace(field: "tags", [
        (pattern: "regex:SONY(.+)", replacement: "Sony $1"),
    ])
    let config = emit.toEmitConfig()
    #expect(config.action == "replace")
    #expect(config.field == "tags")
    #expect(config.replacements?.count == 1)
    #expect(config.replacements?[0].pattern == "regex:SONY(.+)")
    #expect(config.replacements?[0].replacement == "Sony $1")
}

@Test func ruleEmitReplaceKeywords() {
    let emit = RuleEmit.replaceKeywords([
        (pattern: "old", replacement: "new"),
    ])
    let config = emit.toEmitConfig()
    #expect(config.action == "replace")
    #expect(config.field == "keywords")
}

@Test func ruleEmitRemoveField() {
    let emit = RuleEmit.removeField(field: "tags")
    let config = emit.toEmitConfig()
    #expect(config.action == "removeField")
    #expect(config.field == "tags")
    #expect(config.values == nil)
}

@Test func ruleEmitRemoveAllFields() {
    let emit = RuleEmit.removeAllFields
    let config = emit.toEmitConfig()
    #expect(config.action == "removeField")
    #expect(config.field == "*")
}

@Test func configRuleMultipleEmits() {
    let config = buildConfig {
        Rules {
            ConfigRule(
                match: .field(.original(.model), pattern: .exact("Canon")),
                emit: [
                    .removeField(field: "keywords"),
                    .values(field: "keywords", ["Canon"]),
                ]
            )
        }
    }
    #expect(config.rules[0].emit.count == 2)
    #expect(config.rules[0].emit[0].action == "removeField")
    #expect(config.rules[0].emit[1].field == "keywords")
    #expect(config.rules[0].emit[1].values == ["Canon"])
}

// MARK: - Write success

@Test func configBuilderWriteSuccess() throws {
    let config = buildConfig {
        Values {
            "quality" => 95
        }
    }

    let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tempDir) }

    try config.write(to: tempDir)

    let configURL = tempDir.appendingPathComponent("config.json")
    #expect(FileManager.default.fileExists(atPath: configURL.path))

    let data = try Data(contentsOf: configURL)
    let decoded = try JSONDecoder().decode(PluginConfig.self, from: data)
    #expect(decoded.values["quality"] == .number(95))
}

// MARK: - Dependency field with raw strings

@Test func configBuilderDependencyRawStrings() {
    let config = buildConfig {
        Rules {
            ConfigRule(
                match: .field(.dependency("my-plugin", key: "some-key"), pattern: .exact("value")),
                emit: [.keywords(["#result"])]
            )
        }
    }
    #expect(config.rules[0].match.field == "my-plugin:some-key")
}

// MARK: - Hook-scoped rule

@Test func configBuilderHookScopedRule() {
    let config = buildConfig {
        Rules {
            ConfigRule(
                match: .field(.original(.model), pattern: .exact("Sony"), hook: .preProcess),
                emit: [.keywords(["#sony"])]
            )
        }
    }
    #expect(config.rules[0].match.hook == "pre-process")
}
