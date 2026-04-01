import Testing
@testable import PiqleyPluginSDK
import PiqleyCore
import Foundation

// MARK: - Minimal manifest

@Test func buildMinimalManifest() throws {
    let manifest = try buildManifest {
        Identifier("com.test.my-plugin")
        Name("My Plugin")
        ProtocolVersion("1.0")
    }
    #expect(manifest.identifier == "com.test.my-plugin")
    #expect(manifest.name == "My Plugin")
    #expect(manifest.description == nil)
    #expect(manifest.pluginSchemaVersion == "1.0")
    #expect(manifest.config.isEmpty)
    #expect(manifest.setup == nil)
    #expect(manifest.dependencies == nil)
}

// MARK: - Full manifest

@Test func buildFullManifest() throws {
    let manifest = try buildManifest {
        Identifier("com.test.full-plugin")
        Name("Full Plugin")
        Description("A full-featured plugin")
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
    }

    #expect(manifest.identifier == "com.test.full-plugin")
    #expect(manifest.name == "Full Plugin")
    #expect(manifest.description == "A full-featured plugin")
    #expect(manifest.pluginSchemaVersion == "2.0")
    #expect(manifest.pluginVersion == SemanticVersion(major: 1, minor: 2, patch: 3))
    #expect(manifest.config.count == 2)
    #expect(manifest.setup?.command == "setup.sh")
    #expect(manifest.setup?.args == ["--verbose"])
    #expect(manifest.dependencyIdentifiers == ["original", "hashtag"])
}

// MARK: - String dependency

@Test func buildStringDependency() throws {
    let manifest = try buildManifest {
        Identifier("com.test.dep-plugin")
        Name("Dep Plugin")
        ProtocolVersion("1.0")
        Dependencies {
            "original"
        }
    }
    #expect(manifest.dependencyIdentifiers == ["original"])
}

// MARK: - StateKey.Type dependency

@Test func buildStateKeyTypeDependency() throws {
    let manifest = try buildManifest {
        Identifier("com.test.meta-plugin")
        Name("Meta Plugin")
        ProtocolVersion("1.0")
        Dependencies {
            ImageMetadataKey.self
        }
    }
    #expect(manifest.dependencyIdentifiers == ["original"])
}

@Test func buildMixedDependencies() throws {
    let manifest = try buildManifest {
        Identifier("com.test.mixed-plugin")
        Name("Mixed Plugin")
        ProtocolVersion("1.0")
        Dependencies {
            ImageMetadataKey.self
            "hashtag"
        }
    }
    #expect(manifest.dependencyIdentifiers == ["original", "hashtag"])
}

// MARK: - Write success: creates manifest.json, round-trip decode

@Test func writeSuccessRoundTrip() throws {
    let fm = InMemoryFileManager()
    let manifest = try buildManifest {
        Identifier("com.test.write-plugin")
        Name("Write Plugin")
        ProtocolVersion("1.0")
    }

    let tempDir = URL(fileURLWithPath: "/test/manifest-write")
    try fm.createDirectory(at: tempDir, withIntermediateDirectories: true)

    try manifest.writeValidated(to: tempDir, fileManager: fm)

    let manifestURL = tempDir.appendingPathComponent("manifest.json")
    #expect(fm.fileExists(atPath: manifestURL.path))

    let data = try fm.contents(of: manifestURL)
    let decoded = try JSONDecoder.piqley.decode(PluginManifest.self, from: data)
    #expect(decoded.identifier == "com.test.write-plugin")
    #expect(decoded.name == "Write Plugin")
    #expect(decoded.pluginSchemaVersion == "1.0")
}

// MARK: - Missing identifier throws

@Test func buildManifestMissingIdentifierThrows() {
    #expect(throws: SDKError.self) {
        try buildManifest {
            Name("My Plugin")
            ProtocolVersion("1.0")
        }
    }
}

// MARK: - Missing name throws

@Test func buildManifestMissingNameThrows() {
    #expect(throws: SDKError.self) {
        try buildManifest {
            Identifier("com.test.my-plugin")
            ProtocolVersion("1.0")
        }
    }
}

// MARK: - Missing protocol version throws

@Test func buildManifestMissingProtocolVersionThrows() {
    #expect(throws: SDKError.self) {
        try buildManifest {
            Identifier("com.test.my-plugin")
            Name("My Plugin")
        }
    }
}
