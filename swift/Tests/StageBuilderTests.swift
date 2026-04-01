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
    #expect(stage.preRules?[0].match?.field == "original:TIFF:Model")
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

    let data = try JSONEncoder.piqleyPrettyPrint.encode(stage)
    let decoded = try JSONDecoder.piqley.decode(StageConfig.self, from: data)
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

@Test func writeStageFilesUsesOverrideCache() throws {
    let fm = InMemoryFileManager()
    let registry = HookRegistry { r in
        r.register(StandardHook.self) { hook in
            switch hook {
            case .publish:
                return buildStage {
                    Binary(command: "bin/test-plugin", protocol: .json)
                }
            default:
                return nil
            }
        }
    }

    let tempDir = URL(fileURLWithPath: "/test/stages")
    try fm.createDirectory(at: tempDir, withIntermediateDirectories: true)

    try registry.writeStageFiles(to: tempDir, fileManager: fm)

    // Only publish should have a stage file
    let files = try fm.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
    #expect(files.count == 1)
    #expect(files[0].lastPathComponent == "stage-publish.json")

    let data = try fm.contents(of: files[0])
    let config = try JSONDecoder.piqley.decode(StageConfig.self, from: data)
    #expect(config.binary?.command == "bin/test-plugin")
    #expect(config.binary?.pluginProtocol == .json)
}

@Test func writeStageFilesFallbackProducesNothingForEmptyStageConfig() throws {
    let fm = InMemoryFileManager()
    // StandardHook.stageConfig returns empty configs, so no files should be written
    let registry = HookRegistry { r in
        r.register(StandardHook.self)
    }

    let tempDir = URL(fileURLWithPath: "/test/stages-empty")
    try fm.createDirectory(at: tempDir, withIntermediateDirectories: true)

    try registry.writeStageFiles(to: tempDir, fileManager: fm)

    let files = try fm.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
    #expect(files.isEmpty)
}

@Test func writeStageFilesSkipsEffectivelyEmpty() throws {
    let fm = InMemoryFileManager()
    let registry = HookRegistry { r in
        r.register(StandardHook.self) { hook in
            switch hook {
            case .publish:
                return StageConfig(binary: HookConfig(command: ""))
            default:
                return nil
            }
        }
    }

    let tempDir = URL(fileURLWithPath: "/test/stages-skip")
    try fm.createDirectory(at: tempDir, withIntermediateDirectories: true)

    try registry.writeStageFiles(to: tempDir, fileManager: fm)

    let files = try fm.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
    #expect(files.isEmpty)
}
