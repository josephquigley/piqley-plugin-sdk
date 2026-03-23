import Testing
@testable import PiqleyPluginSDK
import PiqleyCore
import Foundation

// MARK: - BuildManifest Tests

@Test func decodesBuildManifest() throws {
    let json = """
    {
        "identifier": "com.test.my-plugin",
        "pluginName": "my-plugin",
        "pluginSchemaVersion": "1",
        "bin": {
            "macos-arm64": ["build/my-plugin"]
        },
        "data": {
            "macos-arm64": ["templates/default.json"]
        }
    }
    """
    let data = Data(json.utf8)
    let manifest = try JSONDecoder().decode(BuildManifest.self, from: data)

    #expect(manifest.identifier == "com.test.my-plugin")
    #expect(manifest.pluginName == "my-plugin")
    #expect(manifest.pluginSchemaVersion == "1")
    #expect(manifest.bin == ["macos-arm64": ["build/my-plugin"]])
    #expect(manifest.data == ["macos-arm64": ["templates/default.json"]])
    #expect(manifest.dependencies?.isEmpty ?? true)
}

@Test func decodesBuildManifestWithoutIdentifierThrows() {
    let json = """
    {
        "pluginName": "my-plugin",
        "pluginSchemaVersion": "1",
        "bin": { "macos-arm64": ["build/my-plugin"] },
        "data": {}
    }
    """
    let data = Data(json.utf8)
    #expect(throws: (any Error).self) {
        try JSONDecoder().decode(BuildManifest.self, from: data)
    }
}

@Test func decodesPlatformKeyedBuildManifest() throws {
    let json = """
    {
        "identifier": "com.test.multi-arch",
        "pluginName": "multi-arch",
        "pluginSchemaVersion": "1",
        "bin": {
            "macos-arm64": [".build/release/multi-arch"],
            "linux-amd64": ["dist/multi-arch"]
        },
        "data": {
            "macos-arm64": ["models/mac.bin"],
            "linux-amd64": ["models/linux.bin"]
        }
    }
    """
    let data = Data(json.utf8)
    let manifest = try JSONDecoder().decode(BuildManifest.self, from: data)

    #expect(manifest.identifier == "com.test.multi-arch")
    #expect(manifest.pluginSchemaVersion == "1")
    #expect(manifest.bin == [
        "macos-arm64": [".build/release/multi-arch"],
        "linux-amd64": ["dist/multi-arch"]
    ])
    #expect(manifest.data == [
        "macos-arm64": ["models/mac.bin"],
        "linux-amd64": ["models/linux.bin"]
    ])
}

// MARK: - Packager Tests

/// Creates a minimal valid plugin directory for testing.
private func makePluginDirectory(
    pluginName: String = "test-plugin",
    identifier: String? = nil,
    includeBin: Bool = true,
    includeConfig: Bool = false,
    configEntries: [ConfigEntry]? = nil
) throws -> URL {
    let fm = FileManager.default
    let dir = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try fm.createDirectory(at: dir, withIntermediateDirectories: true)

    // Build manifest
    let binValue: [String: Any] = includeBin
        ? ["macos-arm64": ["my-binary"]]
        : ["macos-arm64": ["missing-binary"]]

    let buildManifestDict: [String: Any] = [
        "identifier": identifier ?? "com.test.\(pluginName)",
        "pluginName": pluginName,
        "pluginSchemaVersion": "1",
        "bin": binValue,
        "data": [:] as [String: Any],
        "dependencies": [] as [Any],
    ]
    let buildManifestData = try JSONSerialization.data(withJSONObject: buildManifestDict)
    try buildManifestData.write(to: dir.appendingPathComponent("piqley-build-manifest.json"))

    // config.json (optional, legacy)
    if includeConfig {
        let configData = Data("{}".utf8)
        try configData.write(to: dir.appendingPathComponent(PluginFile.config))
    }

    // config-entries.json (optional)
    if let configEntries {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(configEntries)
        try data.write(to: dir.appendingPathComponent("config-entries.json"))
    }

    // Binary file
    if includeBin {
        let binData = Data("#!/bin/sh\necho hello".utf8)
        try binData.write(to: dir.appendingPathComponent("my-binary"))
    }

    return dir
}

@Test func packagerProducesZip() throws {
    let dir = try makePluginDirectory()
    defer { try? FileManager.default.removeItem(at: dir) }

    let output = try Packager.package(directory: dir)

    #expect(output.lastPathComponent == "com.test.test-plugin.piqleyplugin")
    #expect(output.deletingLastPathComponent().lastPathComponent == ".build")
    #expect(FileManager.default.fileExists(atPath: output.path))

    // Clean up output
    try? FileManager.default.removeItem(at: output)
}

@Test func packagerGeneratesManifestJson() throws {
    let dir = try makePluginDirectory(pluginName: "gen-test", identifier: "com.test.gen-test")
    defer { try? FileManager.default.removeItem(at: dir) }

    let output = try Packager.package(directory: dir)
    defer { try? FileManager.default.removeItem(at: output) }

    // Unzip and verify manifest.json was generated
    let fm = FileManager.default
    let unzipDir = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try fm.createDirectory(at: unzipDir, withIntermediateDirectories: true)
    defer { try? fm.removeItem(at: unzipDir) }

    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
    process.arguments = ["-q", output.path, "-d", unzipDir.path]
    try process.run()
    process.waitUntilExit()

    let manifestURL = unzipDir
        .appendingPathComponent("gen-test")
        .appendingPathComponent(PluginFile.manifest)
    #expect(fm.fileExists(atPath: manifestURL.path))

    let data = try Data(contentsOf: manifestURL)
    let manifest = try JSONDecoder().decode(PluginManifest.self, from: data)
    #expect(manifest.identifier == "com.test.gen-test")
    #expect(manifest.name == "gen-test")
    #expect(manifest.pluginSchemaVersion == "1")
    #expect(manifest.supportedPlatforms == ["macos-arm64"])
}

@Test func packagerDoesNotIncludeConfigJson() throws {
    let dir = try makePluginDirectory(includeConfig: false)
    defer { try? FileManager.default.removeItem(at: dir) }

    let output = try Packager.package(directory: dir)
    defer { try? FileManager.default.removeItem(at: output) }

    // Unzip and verify config.json is NOT in the archive
    let fm = FileManager.default
    let unzipDir = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try fm.createDirectory(at: unzipDir, withIntermediateDirectories: true)
    defer { try? fm.removeItem(at: unzipDir) }

    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
    process.arguments = ["-q", output.path, "-d", unzipDir.path]
    try process.run()
    process.waitUntilExit()

    let configURL = unzipDir
        .appendingPathComponent("test-plugin")
        .appendingPathComponent(PluginFile.config)
    #expect(!fm.fileExists(atPath: configURL.path))
}

@Test func packagerUsesConfigEntriesInManifest() throws {
    let entries: [ConfigEntry] = [
        .value(key: "siteUrl", type: .string, value: .string("https://example.com")),
        .secret(secretKey: "API_KEY", type: .string),
    ]
    let dir = try makePluginDirectory(
        pluginName: "config-test",
        identifier: "com.test.config-test",
        configEntries: entries
    )
    defer { try? FileManager.default.removeItem(at: dir) }

    let output = try Packager.package(directory: dir)
    defer { try? FileManager.default.removeItem(at: output) }

    // Unzip and read manifest.json
    let fm = FileManager.default
    let unzipDir = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try fm.createDirectory(at: unzipDir, withIntermediateDirectories: true)
    defer { try? fm.removeItem(at: unzipDir) }

    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
    process.arguments = ["-q", output.path, "-d", unzipDir.path]
    try process.run()
    process.waitUntilExit()

    let manifestURL = unzipDir
        .appendingPathComponent("config-test")
        .appendingPathComponent(PluginFile.manifest)
    let data = try Data(contentsOf: manifestURL)
    let manifest = try JSONDecoder().decode(PluginManifest.self, from: data)
    #expect(manifest.config == entries)
}

@Test func packagerFailsOnMissingBinPath() throws {
    let dir = try makePluginDirectory(includeBin: false)
    defer { try? FileManager.default.removeItem(at: dir) }

    #expect(throws: PackagerError.missingPath("missing-binary")) {
        try Packager.package(directory: dir)
    }
}
