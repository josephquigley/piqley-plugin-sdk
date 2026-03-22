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
    /// `manifest.json` from the build manifest. If `config.json` exists it is copied;
    /// otherwise an empty one is created.
    public static func package(directory: URL) throws -> URL {
        let fm = FileManager.default

        // 1. Load build manifest
        let buildManifestURL = directory.appendingPathComponent("piqley-build-manifest.json")
        guard fm.fileExists(atPath: buildManifestURL.path) else {
            throw PackagerError.missingBuildManifest
        }
        let buildManifest = try BuildManifest.load(from: directory)

        // 2. Generate PluginManifest from build manifest
        let pluginManifest = try buildManifest.toPluginManifest()

        // 3. Verify all bin paths exist
        for bin in buildManifest.bin {
            let binURL = directory.appendingPathComponent(bin)
            guard fm.fileExists(atPath: binURL.path) else {
                throw PackagerError.missingPath(bin)
            }
        }

        // 4. Verify all data paths exist
        for dataPath in buildManifest.data {
            let dataURL = directory.appendingPathComponent(dataPath)
            guard fm.fileExists(atPath: dataURL.path) else {
                throw PackagerError.missingPath(dataPath)
            }
        }

        // 5. Stage files into a temp directory
        let pluginName = buildManifest.pluginName
        let staging = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let pluginDir = staging.appendingPathComponent(pluginName)
        try fm.createDirectory(at: pluginDir, withIntermediateDirectories: true)

        // Write generated manifest.json
        let manifestData = try pluginManifest.encode()
        try manifestData.write(to: pluginDir.appendingPathComponent("manifest.json"))

        // Copy config.json if it exists, otherwise write an empty one
        let configURL = directory.appendingPathComponent("config.json")
        if fm.fileExists(atPath: configURL.path) {
            try fm.copyItem(at: configURL, to: pluginDir.appendingPathComponent("config.json"))
        } else {
            try Data("{}".utf8).write(to: pluginDir.appendingPathComponent("config.json"))
        }

        // Copy stage-*.json files
        let dirContents = try fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        for file in dirContents {
            let fileName = file.lastPathComponent
            if fileName.hasPrefix(PluginFile.stagePrefix) && fileName.hasSuffix(PluginFile.stageSuffix) {
                try fm.copyItem(at: file, to: pluginDir.appendingPathComponent(fileName))
            }
        }

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

        // 6. Zip the staged directory
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
