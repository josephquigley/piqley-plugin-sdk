import Testing
@testable import PiqleyPluginSDK
import PiqleyCore
import Foundation

// MARK: - Minimal manifest

@Test func buildMinimalManifest() throws {
    let manifest = try buildManifest {
        Name("my-plugin")
        ProtocolVersion("1.0")
        Hooks {
            HookEntry(.preProcess, command: "run")
        }
    }
    #expect(manifest.name == "my-plugin")
    #expect(manifest.pluginProtocolVersion == "1.0")
    #expect(manifest.hooks["pre-process"]?.command == "run")
    #expect(manifest.config.isEmpty)
    #expect(manifest.setup == nil)
    #expect(manifest.dependencies == nil)
}

// MARK: - Full manifest

@Test func buildFullManifest() throws {
    let manifest = try buildManifest {
        Name("full-plugin")
        ProtocolVersion("2.0")
        try PluginVersion("1.2.3")
        ConfigEntries {
            Value("quality", type: .int, default: .number(80))
            Secret("API_KEY", type: .string)
        }
        Setup(command: "setup.sh", args: ["--verbose"])
        Dependencies {
            "original"
            "hashtag"
        }
        Hooks {
            HookEntry(.preProcess, command: "process", timeout: 30)
            HookEntry(.publish, command: "publish", protocol: .json)
        }
    }

    #expect(manifest.name == "full-plugin")
    #expect(manifest.pluginProtocolVersion == "2.0")
    #expect(manifest.pluginVersion == SemanticVersion(major: 1, minor: 2, patch: 3))
    #expect(manifest.config.count == 2)
    #expect(manifest.setup?.command == "setup.sh")
    #expect(manifest.setup?.args == ["--verbose"])
    #expect(manifest.dependencies == ["original", "hashtag"])
    #expect(manifest.hooks["pre-process"]?.command == "process")
    #expect(manifest.hooks["pre-process"]?.timeout == 30)
    #expect(manifest.hooks["publish"]?.pluginProtocol == .json)
}

// MARK: - Rules-only hook (no command)

@Test func buildRulesOnlyHook() throws {
    let manifest = try buildManifest {
        Name("rules-plugin")
        ProtocolVersion("1.0")
        Hooks {
            HookEntry(.postProcess)
        }
    }
    #expect(manifest.hooks["post-process"]?.command == nil)
}

// MARK: - String dependency

@Test func buildStringDependency() throws {
    let manifest = try buildManifest {
        Name("dep-plugin")
        ProtocolVersion("1.0")
        Dependencies {
            "original"
        }
        Hooks {
            HookEntry(.preProcess, command: "run")
        }
    }
    #expect(manifest.dependencies == ["original"])
}

// MARK: - StateKey.Type dependency

@Test func buildStateKeyTypeDependency() throws {
    let manifest = try buildManifest {
        Name("meta-plugin")
        ProtocolVersion("1.0")
        Dependencies {
            ImageMetadataKey.self
        }
        Hooks {
            HookEntry(.preProcess, command: "run")
        }
    }
    #expect(manifest.dependencies == ["original"])
}

@Test func buildMixedDependencies() throws {
    let manifest = try buildManifest {
        Name("mixed-plugin")
        ProtocolVersion("1.0")
        Dependencies {
            ImageMetadataKey.self
            "hashtag"
        }
        Hooks {
            HookEntry(.preProcess, command: "run")
        }
    }
    #expect(manifest.dependencies == ["original", "hashtag"])
}

// MARK: - Write validation catches bad manifest (batchProxy + json)

@Test func writeValidationCatchesBadManifest() throws {
    let manifest = PluginManifest(
        name: "bad-plugin",
        pluginProtocolVersion: "1.0",
        hooks: [
            "pre-process": HookConfig(
                command: "run",
                pluginProtocol: .json,
                batchProxy: BatchProxyConfig()
            )
        ]
    )

    let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tempDir) }

    #expect(throws: SDKError.self) {
        try manifest.writeValidated(to: tempDir)
    }

    // Ensure no manifest.json was written
    let manifestURL = tempDir.appendingPathComponent("manifest.json")
    #expect(!FileManager.default.fileExists(atPath: manifestURL.path))
}

// MARK: - Write success: creates manifest.json, round-trip decode

@Test func writeSuccessRoundTrip() throws {
    let manifest = try buildManifest {
        Name("write-plugin")
        ProtocolVersion("1.0")
        Hooks {
            HookEntry(.preProcess, command: "run")
        }
    }

    let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tempDir) }

    try manifest.writeValidated(to: tempDir)

    let manifestURL = tempDir.appendingPathComponent("manifest.json")
    #expect(FileManager.default.fileExists(atPath: manifestURL.path))

    let data = try Data(contentsOf: manifestURL)
    let decoded = try JSONDecoder().decode(PluginManifest.self, from: data)
    #expect(decoded.name == "write-plugin")
    #expect(decoded.pluginProtocolVersion == "1.0")
    #expect(decoded.hooks["pre-process"]?.command == "run")
}

// MARK: - Missing name throws

@Test func buildManifestMissingNameThrows() {
    #expect(throws: SDKError.self) {
        try buildManifest {
            ProtocolVersion("1.0")
            Hooks {
                HookEntry(.preProcess, command: "run")
            }
        }
    }
}

// MARK: - Missing protocol version throws

@Test func buildManifestMissingProtocolVersionThrows() {
    #expect(throws: SDKError.self) {
        try buildManifest {
            Name("my-plugin")
            Hooks {
                HookEntry(.preProcess, command: "run")
            }
        }
    }
}
