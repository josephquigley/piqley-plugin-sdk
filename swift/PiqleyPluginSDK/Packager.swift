import Foundation
import PiqleyCore

/// Errors produced during plugin packaging.
public enum PackagerError: Error, Sendable, Equatable {
    case missingBuildManifest
    case missingManifest
    case missingConfig
    case nameMismatch(buildManifest: String, manifest: String)
    case missingPath(String)
    case zipFailed(String)
}

/// Assembles a `.piqleyplugin` archive from a plugin source directory.
public struct Packager {

    /// Packages the plugin in `directory` and returns the URL of the produced `.piqleyplugin` file.
    ///
    /// The directory must contain `piqley-build-manifest.json`, `manifest.json`, and `config.json`.
    public static func package(directory: URL) throws -> URL {
        let fm = FileManager.default

        // 1. Load build manifest
        let buildManifestURL = directory.appendingPathComponent("piqley-build-manifest.json")
        guard fm.fileExists(atPath: buildManifestURL.path) else {
            throw PackagerError.missingBuildManifest
        }
        let buildManifest = try BuildManifest.load(from: directory)

        // 2. Verify manifest.json exists and decode for name check
        let manifestURL = directory.appendingPathComponent("manifest.json")
        guard fm.fileExists(atPath: manifestURL.path) else {
            throw PackagerError.missingManifest
        }
        let manifestData = try Data(contentsOf: manifestURL)
        let manifest = try JSONDecoder().decode(PluginManifest.self, from: manifestData)

        // 3. Verify config.json exists
        let configURL = directory.appendingPathComponent("config.json")
        guard fm.fileExists(atPath: configURL.path) else {
            throw PackagerError.missingConfig
        }

        // 4. Name mismatch check
        if buildManifest.pluginName != manifest.name {
            throw PackagerError.nameMismatch(
                buildManifest: buildManifest.pluginName,
                manifest: manifest.name
            )
        }

        // 5. Verify all bin paths exist
        for bin in buildManifest.bin {
            let binURL = directory.appendingPathComponent(bin)
            guard fm.fileExists(atPath: binURL.path) else {
                throw PackagerError.missingPath(bin)
            }
        }

        // 6. Verify all data paths exist
        for dataPath in buildManifest.data {
            let dataURL = directory.appendingPathComponent(dataPath)
            guard fm.fileExists(atPath: dataURL.path) else {
                throw PackagerError.missingPath(dataPath)
            }
        }

        // 7. Stage files into a temp directory
        let pluginName = buildManifest.pluginName
        let staging = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let pluginDir = staging.appendingPathComponent(pluginName)
        try fm.createDirectory(at: pluginDir, withIntermediateDirectories: true)

        // Copy manifest.json and config.json
        try fm.copyItem(at: manifestURL, to: pluginDir.appendingPathComponent("manifest.json"))
        try fm.copyItem(at: configURL, to: pluginDir.appendingPathComponent("config.json"))

        // Copy bin files
        if !buildManifest.bin.isEmpty {
            let binDir = pluginDir.appendingPathComponent("bin")
            try fm.createDirectory(at: binDir, withIntermediateDirectories: true)
            for bin in buildManifest.bin {
                let src = directory.appendingPathComponent(bin)
                let dst = binDir.appendingPathComponent(URL(fileURLWithPath: bin).lastPathComponent)
                try fm.copyItem(at: src, to: dst)
            }
        }

        // Copy data files
        if !buildManifest.data.isEmpty {
            let dataDir = pluginDir.appendingPathComponent("data")
            try fm.createDirectory(at: dataDir, withIntermediateDirectories: true)
            for dataPath in buildManifest.data {
                let src = directory.appendingPathComponent(dataPath)
                let dst = dataDir.appendingPathComponent(URL(fileURLWithPath: dataPath).lastPathComponent)
                try fm.copyItem(at: src, to: dst)
            }
        }

        // 8. Zip the staged directory
        let outputURL = directory.appendingPathComponent("\(pluginName).piqleyplugin")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        process.arguments = ["-r", "-q", outputURL.path, pluginName]
        process.currentDirectoryURL = staging

        let pipe = Pipe()
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        // Clean up staging
        try? fm.removeItem(at: staging)

        guard process.terminationStatus == 0 else {
            let stderr = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            throw PackagerError.zipFailed(stderr)
        }

        return outputURL
    }
}
