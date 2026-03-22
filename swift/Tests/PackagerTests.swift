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
        "bin": ["build/my-plugin"],
        "data": ["templates/default.json"],
        "dependencies": []
    }
    """
    let data = Data(json.utf8)
    let manifest = try JSONDecoder().decode(BuildManifest.self, from: data)

    #expect(manifest.identifier == "com.test.my-plugin")
    #expect(manifest.pluginName == "my-plugin")
    #expect(manifest.pluginSchemaVersion == "1")
    #expect(manifest.bin == ["build/my-plugin"])
    #expect(manifest.data == ["templates/default.json"])
    #expect(manifest.dependencies?.isEmpty ?? true)
}

@Test func decodesBuildManifestWithoutIdentifier() throws {
    let json = """
    {
        "pluginName": "my-plugin",
        "pluginSchemaVersion": "1",
        "bin": ["build/my-plugin"],
        "data": [],
        "dependencies": []
    }
    """
    let data = Data(json.utf8)
    let manifest = try JSONDecoder().decode(BuildManifest.self, from: data)

    // identifier defaults to pluginName
    #expect(manifest.identifier == "my-plugin")
}

// MARK: - Packager Tests

/// Creates a minimal valid plugin directory for testing.
private func makePluginDirectory(
    pluginName: String = "test-plugin",
    identifier: String? = nil,
    includeBin: Bool = true,
    includeConfig: Bool = false
) throws -> URL {
    let fm = FileManager.default
    let dir = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try fm.createDirectory(at: dir, withIntermediateDirectories: true)

    // Build manifest
    let buildManifestDict: [String: Any] = [
        "identifier": identifier ?? "com.test.\(pluginName)",
        "pluginName": pluginName,
        "pluginSchemaVersion": "1",
        "bin": includeBin ? ["my-binary"] : ["missing-binary"],
        "data": [] as [String],
        "dependencies": [] as [Any],
    ]
    let buildManifestData = try JSONSerialization.data(withJSONObject: buildManifestDict)
    try buildManifestData.write(to: dir.appendingPathComponent("piqley-build-manifest.json"))

    // config.json (optional)
    if includeConfig {
        let configData = Data("{}".utf8)
        try configData.write(to: dir.appendingPathComponent("config.json"))
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

    #expect(output.lastPathComponent == "test-plugin.piqleyplugin")
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
        .appendingPathComponent("manifest.json")
    #expect(fm.fileExists(atPath: manifestURL.path))

    let data = try Data(contentsOf: manifestURL)
    let manifest = try JSONDecoder().decode(PluginManifest.self, from: data)
    #expect(manifest.identifier == "com.test.gen-test")
    #expect(manifest.name == "gen-test")
    #expect(manifest.pluginSchemaVersion == "1")
}

@Test func packagerGeneratesEmptyConfigWhenMissing() throws {
    let dir = try makePluginDirectory(includeConfig: false)
    defer { try? FileManager.default.removeItem(at: dir) }

    // Should not throw even without config.json
    let output = try Packager.package(directory: dir)
    defer { try? FileManager.default.removeItem(at: output) }

    // Unzip and verify config.json exists
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
        .appendingPathComponent("config.json")
    #expect(fm.fileExists(atPath: configURL.path))
}

@Test func packagerFailsOnMissingBinPath() throws {
    let dir = try makePluginDirectory(includeBin: false)
    defer { try? FileManager.default.removeItem(at: dir) }

    #expect(throws: PackagerError.missingPath("missing-binary")) {
        try Packager.package(directory: dir)
    }
}
