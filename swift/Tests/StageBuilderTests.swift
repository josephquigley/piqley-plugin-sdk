import Testing
@testable import PiqleyPluginSDK
import PiqleyCore
import Foundation

@Test func buildStageWithAllSections() throws {
    let stage = buildStage {
        PreRules {
            ConfigRule(
                match: .field(.original(.model), pattern: .glob("Canon*")),
                emit: [.keywords(["canon"])]
            )
        }
        Binary(command: "./bin/my-plugin", args: ["--quality", "high"], timeout: 60)
        PostRules {
            ConfigRule(
                match: .field(.dependency("my-plugin", key: "status"), pattern: .exact("done")),
                emit: [.keywords(["processed"])],
                write: [.values(field: "IPTC:Keywords", ["processed"])]
            )
        }
    }
    #expect(stage.preRules?.count == 1)
    #expect(stage.preRules?[0].match.field == "original:TIFF:Model")
    #expect(stage.binary?.command == "./bin/my-plugin")
    #expect(stage.binary?.args == ["--quality", "high"])
    #expect(stage.binary?.timeout == 60)
    #expect(stage.postRules?.count == 1)
    #expect(stage.postRules?[0].write.count == 1)
}

@Test func buildStageBinaryOnly() {
    let stage = buildStage {
        Binary(command: "./bin/tool")
    }
    #expect(stage.preRules == nil)
    #expect(stage.binary?.command == "./bin/tool")
    #expect(stage.postRules == nil)
}

@Test func buildStagePreRulesOnly() {
    let stage = buildStage {
        PreRules {
            ConfigRule(
                match: .field(.original(.model), pattern: .exact("Sony")),
                emit: [.keywords(["sony"])]
            )
        }
    }
    #expect(stage.preRules?.count == 1)
    #expect(stage.binary == nil)
    #expect(stage.postRules == nil)
}

@Test func buildStagePostRulesOnly() {
    let stage = buildStage {
        PostRules {
            ConfigRule(
                match: .field(.original(.make), pattern: .glob("*Nikon*")),
                emit: [.values(field: "tags", ["Nikon"])]
            )
        }
    }
    #expect(stage.preRules == nil)
    #expect(stage.binary == nil)
    #expect(stage.postRules?.count == 1)
}

@Test func buildStageBinaryWithProtocol() {
    let stage = buildStage {
        Binary(command: "./bin/tool", protocol: .pipe, timeout: 120)
    }
    #expect(stage.binary?.pluginProtocol == .pipe)
    #expect(stage.binary?.timeout == 120)
}

@Test func buildStageEmpty() {
    let stage = buildStage {}
    #expect(stage.isEmpty)
}

@Test func buildStageWriteAndRoundTrip() throws {
    let stage = buildStage {
        PreRules {
            ConfigRule(
                match: .field(.original(.model), pattern: .exact("Canon")),
                emit: [.keywords(["canon"])]
            )
        }
        Binary(command: "./bin/tool")
    }

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(stage)
    let decoded = try JSONDecoder().decode(StageConfig.self, from: data)
    #expect(decoded.preRules?.count == 1)
    #expect(decoded.binary?.command == "./bin/tool")
    #expect(decoded.postRules == nil)
}

@Test func buildStageMultiplePreRules() {
    let stage = buildStage {
        PreRules {
            ConfigRule(
                match: .field(.original(.model), pattern: .exact("Canon")),
                emit: [.keywords(["canon"])]
            )
            ConfigRule(
                match: .field(.original(.make), pattern: .glob("*Sony*")),
                emit: [.keywords(["sony"])]
            )
        }
    }
    #expect(stage.preRules?.count == 2)
}
