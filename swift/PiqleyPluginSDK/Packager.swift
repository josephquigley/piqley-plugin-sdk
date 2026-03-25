import Foundation
import PiqleyCore

/// Errors produced during plugin packaging.
public enum PackagerError: Error, Sendable, Equatable {
    case missingBuildManifest
    case missingPath(String)
    case zipFailed(String)
}

/// Assembles a `.piqleyplugin` archive from a plugin source directory.
public struct Packager {

    /// Packages the plugin in `directory` and returns the URL of the produced `.piqleyplugin` file.
    ///
    /// The directory must contain `piqley-build-manifest.json`. The packager generates
    /// `manifest.json` from the build manifest. If `config-entries.json` exists, its
    /// entries are used as the manifest's config; otherwise the build manifest's config
    /// field is used.
    public static func package(directory: URL, outputPath: URL? = nil) throws -> URL {
        let fm = FileManager.default

        // 1. Load build manifest
        let buildManifestURL = directory.appendingPathComponent("piqley-build-manifest.json")
        guard fm.fileExists(atPath: buildManifestURL.path) else {
            throw PackagerError.missingBuildManifest
        }
        let buildManifest = try BuildManifest.load(from: directory)

        // 2. Load config-entries.json and consumed-fields.json if they exist
        let configEntriesURL = directory.appendingPathComponent("config-entries.json")
        let configOverride: [ConfigEntry]?
        if fm.fileExists(atPath: configEntriesURL.path) {
            let configData = try Data(contentsOf: configEntriesURL)
            configOverride = try JSONDecoder.piqley.decode([ConfigEntry].self, from: configData)
        } else {
            configOverride = nil
        }

        let consumedFieldsURL = directory.appendingPathComponent("consumed-fields.json")
        let consumedFieldsOverride: [ConsumedField]?
        if fm.fileExists(atPath: consumedFieldsURL.path) {
            let consumedData = try Data(contentsOf: consumedFieldsURL)
            consumedFieldsOverride = try JSONDecoder.piqley.decode([ConsumedField].self, from: consumedData)
        } else {
            consumedFieldsOverride = nil
        }

        let pluginManifest = try buildManifest.toPluginManifest(
            configOverride: configOverride,
            consumedFieldsOverride: consumedFieldsOverride
        )

        // 3. Verify all bin paths exist
        for (_, paths) in buildManifest.bin {
            for bin in paths {
                let binURL = directory.appendingPathComponent(bin)
                guard fm.fileExists(atPath: binURL.path) else {
                    throw PackagerError.missingPath(bin)
                }
            }
        }

        // 4. Verify all data paths exist
        for (_, paths) in buildManifest.data {
            for dataPath in paths {
                let dataURL = directory.appendingPathComponent(dataPath)
                guard fm.fileExists(atPath: dataURL.path) else {
                    throw PackagerError.missingPath(dataPath)
                }
            }
        }

        // 5. Stage files into a temp directory
        let pluginName = buildManifest.pluginName
        let staging = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let pluginDir = staging.appendingPathComponent(pluginName)
        try fm.createDirectory(at: pluginDir, withIntermediateDirectories: true)

        // Write generated manifest.json
        let manifestData = try pluginManifest.encode()
        try manifestData.write(to: pluginDir.appendingPathComponent(PluginFile.manifest))

        // Copy stage-*.json files
        let dirContents = try fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        for file in dirContents {
            let fileName = file.lastPathComponent
            if fileName.hasPrefix(PluginFile.stagePrefix) && fileName.hasSuffix(PluginFile.stageSuffix) {
                try fm.copyItem(at: file, to: pluginDir.appendingPathComponent(fileName))
            }
        }

        // Copy bin files into platform subdirectories
        if !buildManifest.bin.isEmpty {
            let binDir = pluginDir.appendingPathComponent(PluginDirectory.bin)
            for (platform, paths) in buildManifest.bin {
                let platformDir = binDir.appendingPathComponent(platform)
                try fm.createDirectory(at: platformDir, withIntermediateDirectories: true)
                for bin in paths {
                    let src = directory.appendingPathComponent(bin)
                    let dst = platformDir.appendingPathComponent(URL(fileURLWithPath: bin).lastPathComponent)
                    try fm.copyItem(at: src, to: dst)
                }
            }
        }

        // Copy data files into platform subdirectories
        if !buildManifest.data.isEmpty {
            let dataDir = pluginDir.appendingPathComponent(PluginDirectory.data)
            for (platform, paths) in buildManifest.data {
                let platformDir = dataDir.appendingPathComponent(platform)
                try fm.createDirectory(at: platformDir, withIntermediateDirectories: true)
                for dataPath in paths {
                    let src = directory.appendingPathComponent(dataPath)
                    let dst = dataDir.appendingPathComponent(URL(fileURLWithPath: dataPath).lastPathComponent)
                    try fm.copyItem(at: src, to: dst)
                }
            }
        }

        // 6. Zip the staged directory
        let outputURL: URL
        if let outputPath {
            let parent = outputPath.deletingLastPathComponent()
            try fm.createDirectory(at: parent, withIntermediateDirectories: true)
            outputURL = outputPath
        } else {
            let buildDir = directory.appendingPathComponent(".build")
            try fm.createDirectory(at: buildDir, withIntermediateDirectories: true)
            outputURL = buildDir.appendingPathComponent("\(buildManifest.identifier).piqleyplugin")
        }
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
