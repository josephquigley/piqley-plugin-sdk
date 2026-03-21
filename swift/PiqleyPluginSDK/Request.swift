import Foundation
import PiqleyCore

// MARK: - PluginRequest

public struct PluginRequest: Sendable {
    public let hook: Hook
    public let imageFolderPath: String
    public let pluginConfig: [String: JSONValue]
    public let secrets: [String: String]
    public let executionLogPath: String
    public let dataPath: String
    public let logPath: String
    public let dryRun: Bool
    public let state: ResolvedState
    public let pluginVersion: SemanticVersion
    public let lastExecutedVersion: SemanticVersion?

    /// The unique identifier for the current pipeline run, if available.
    public let pipelineRunId: String?

    private let io: PluginIO
    private static let imageExtensions: Set<String> = [
        "jpg", "jpeg", "jxl", "png", "tiff", "tif", "heic", "heif", "webp",
    ]

    /// Internal init from payload.
    init(payload: PluginInputPayload, io: PluginIO) {
        self.hook = Hook(rawValue: payload.hook) ?? .preProcess
        self.imageFolderPath = payload.imageFolderPath
        self.pluginConfig = payload.pluginConfig
        self.secrets = payload.secrets
        self.executionLogPath = payload.executionLogPath
        self.dataPath = payload.dataPath
        self.logPath = payload.logPath
        self.dryRun = payload.dryRun
        self.state = ResolvedState(payload.state ?? [:])
        self.pluginVersion = payload.pluginVersion
        self.lastExecutedVersion = payload.lastExecutedVersion
        self.pipelineRunId = payload.pipelineRunId
        self.io = io
    }

    /// Lists image files in imageFolderPath matching piqley's supported extensions (.jpg, .jpeg, .jxl).
    public func imageFiles() throws -> [URL] {
        let url = URL(fileURLWithPath: imageFolderPath)
        let contents = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
        return contents.filter { Self.imageExtensions.contains($0.pathExtension.lowercased()) }
    }

    /// Writes a progress line to stdout immediately.
    public func reportProgress(_ message: String) {
        let line = PluginOutputLine(type: "progress", message: message)
        if let data = try? JSONEncoder().encode(line), let string = String(data: data, encoding: .utf8) {
            io.writeLine(string)
        }
    }

    /// Writes an imageResult line to stdout immediately.
    public func reportImageResult(_ filename: String, success: Bool, error: String? = nil) {
        let line = PluginOutputLine(type: "imageResult", filename: filename, success: success, error: error)
        if let data = try? JSONEncoder().encode(line), let string = String(data: data, encoding: .utf8) {
            io.writeLine(string)
        }
    }
}

// MARK: - Test Support

/// Result of a captured image result report.
public struct ImageResult: Sendable {
    public let filename: String
    public let success: Bool
    public let error: String?
}

/// Captures output from a mock plugin request for test assertions.
public final class CapturedOutput: Sendable {
    private let io: CapturedIO
    init(io: CapturedIO) { self.io = io }

    public var progressMessages: [String] {
        io.lines.compactMap { line -> String? in
            guard
                let data = line.data(using: .utf8),
                let decoded = try? JSONDecoder().decode(PluginOutputLine.self, from: data),
                decoded.type == "progress",
                let message = decoded.message
            else { return nil }
            return message
        }
    }

    public var imageResults: [ImageResult] {
        io.lines.compactMap { line -> ImageResult? in
            guard
                let data = line.data(using: .utf8),
                let decoded = try? JSONDecoder().decode(PluginOutputLine.self, from: data),
                decoded.type == "imageResult",
                let filename = decoded.filename,
                let success = decoded.success
            else { return nil }
            return ImageResult(filename: filename, success: success, error: decoded.error)
        }
    }

    public var allLines: [String] { io.lines }
}

extension PluginRequest {
    public static func mock(
        hook: Hook = .preProcess,
        imageFolderPath: String = "/tmp/test",
        pluginConfig: [String: JSONValue] = [:],
        secrets: [String: String] = [:],
        executionLogPath: String = "/tmp/test/log.jsonl",
        dataPath: String = "/tmp/test/data",
        logPath: String = "/tmp/test/logs",
        dryRun: Bool = false,
        state: ResolvedState = .empty,
        pluginVersion: SemanticVersion = SemanticVersion(major: 1, minor: 0, patch: 0),
        lastExecutedVersion: SemanticVersion? = nil,
        pipelineRunId: String? = nil
    ) -> (request: PluginRequest, output: CapturedOutput) {
        let io = CapturedIO()
        let payload = PluginInputPayload(
            hook: hook.rawValue,
            imageFolderPath: imageFolderPath,
            pluginConfig: pluginConfig,
            secrets: secrets,
            executionLogPath: executionLogPath,
            dataPath: dataPath,
            logPath: logPath,
            dryRun: dryRun,
            state: state.rawDict,
            pluginVersion: pluginVersion,
            lastExecutedVersion: lastExecutedVersion,
            pipelineRunId: pipelineRunId
        )
        let request = PluginRequest(payload: payload, io: io)
        return (request, CapturedOutput(io: io))
    }
}
