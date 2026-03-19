import Testing
@testable import PiqleyPluginSDK
import Foundation

// MARK: - BuildManifest Tests

@Test func decodesBuildManifest() throws {
    let json = """
    {
        "pluginName": "my-plugin",
        "pluginSchemaVersion": "1",
        "bin": ["build/my-plugin"],
        "data": ["templates/default.json"],
        "dependencies": []
    }
    """
    let data = Data(json.utf8)
    let manifest = try JSONDecoder().decode(BuildManifest.self, from: data)

    #expect(manifest.pluginName == "my-plugin")
    #expect(manifest.pluginSchemaVersion == "1")
    #expect(manifest.bin == ["build/my-plugin"])
    #expect(manifest.data == ["templates/default.json"])
    #expect(manifest.dependencies.isEmpty)
}

// MARK: - Packager Tests

/// Creates a minimal valid plugin directory for testing.
private func makePluginDirectory(
    pluginName: String = "test-plugin",
    manifestName: String? = nil,
    includeBin: Bool = true,
    includeConfig: Bool = true
) throws -> URL {
    let fm = FileManager.default
    let dir = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try fm.createDirectory(at: dir, withIntermediateDirectories: true)

    // Build manifest
    let buildManifest: [String: Any] = [
        "pluginName": pluginName,
        "pluginSchemaVersion": "1",
        "bin": includeBin ? ["my-binary"] : ["missing-binary"],
        "data": [] as [String],
        "dependencies": [] as [Any],
    ]
    let buildManifestData = try JSONSerialization.data(withJSONObject: buildManifest)
    try buildManifestData.write(to: dir.appendingPathComponent("piqley-build-manifest.json"))

    // manifest.json
    let manifest: [String: Any] = [
        "identifier": "com.test.\(manifestName ?? pluginName)",
        "name": manifestName ?? pluginName,
        "pluginSchemaVersion": "1",
    ]
    let manifestData = try JSONSerialization.data(withJSONObject: manifest)
    try manifestData.write(to: dir.appendingPathComponent("manifest.json"))

    // config.json
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

@Test func packagerFailsOnNameMismatch() throws {
    let dir = try makePluginDirectory(pluginName: "alpha", manifestName: "beta")
    defer { try? FileManager.default.removeItem(at: dir) }

    #expect(throws: PackagerError.nameMismatch(buildManifest: "alpha", manifest: "beta")) {
        try Packager.package(directory: dir)
    }
}

@Test func packagerFailsOnMissingBinPath() throws {
    let dir = try makePluginDirectory(includeBin: false)
    defer { try? FileManager.default.removeItem(at: dir) }

    #expect(throws: PackagerError.missingPath("missing-binary")) {
        try Packager.package(directory: dir)
    }
}
