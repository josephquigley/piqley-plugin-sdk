import Foundation
import PiqleyCore

// MARK: - StageComponent protocol

public protocol StageComponent: Sendable {}

// MARK: - PreRules

public struct PreRules: StageComponent {
    let rules: [ConfigRule]
    public init(@RulesBuilder _ builder: () -> [ConfigRule]) {
        self.rules = builder()
    }
}

// MARK: - PostRules

public struct PostRules: StageComponent {
    let rules: [ConfigRule]
    public init(@RulesBuilder _ builder: () -> [ConfigRule]) {
        self.rules = builder()
    }
}

// MARK: - Binary

public struct Binary: StageComponent {
    let config: HookConfig

    public init(
        command: String,
        args: [String] = [],
        `protocol`: PluginProtocol? = nil,
        timeout: Int? = nil,
        successCodes: [Int32]? = nil,
        warningCodes: [Int32]? = nil,
        criticalCodes: [Int32]? = nil,
        batchProxy: BatchProxyConfig? = nil
    ) {
        self.config = HookConfig(
            command: command,
            args: args,
            timeout: timeout,
            pluginProtocol: `protocol`,
            successCodes: successCodes,
            warningCodes: warningCodes,
            criticalCodes: criticalCodes,
            batchProxy: batchProxy
        )
    }
}

// MARK: - StageComponentBuilder

@resultBuilder
public enum StageComponentBuilder {
    public static func buildBlock(_ components: (any StageComponent)...) -> [any StageComponent] {
        components
    }
    public static func buildExpression(_ expression: any StageComponent) -> any StageComponent { expression }
}

// MARK: - buildStage

public func buildStage(@StageComponentBuilder _ builder: () -> [any StageComponent]) -> StageConfig {
    let components = builder()

    var preRules: [Rule]? = nil
    var binary: HookConfig? = nil
    var postRules: [Rule]? = nil

    for component in components {
        if let component = component as? PreRules {
            preRules = component.rules.map { $0.toRule() }
        } else if let component = component as? Binary {
            binary = component.config
        } else if let component = component as? PostRules {
            postRules = component.rules.map { $0.toRule() }
        }
    }

    return StageConfig(preRules: preRules, binary: binary, postRules: postRules)
}

// MARK: - StageConfig write extension

extension StageConfig {
    /// Writes the stage config to a directory as `stage-<hookName>.json`.
    public func write(to directory: URL, hookName: String) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(self)
        let fileName = "\(PluginFile.stagePrefix)\(hookName)\(PluginFile.stageSuffix)"
        try data.write(to: directory.appendingPathComponent(fileName))
    }
}
