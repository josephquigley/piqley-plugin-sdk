import Foundation
import PiqleyCore

// MARK: - PluginRequest

public struct PluginRequest: @unchecked Sendable {
    public let hook: any Hook
    public let imageFolderPath: String
    public let pluginConfig: [String: JSONValue]
    public let secrets: [String: String]
    public let executionLogPath: String
    public let dataPath: String
    public let logPath: String
    /// Whether this is a dry run (preview mode).
    ///
    /// When `true`, the plugin should skip all destructive or external operations
    /// (API calls, file writes, uploads) and instead report what it *would* do
    /// via ``reportProgress(_:)``.
    ///
    /// For CLI tool plugins using the pipe protocol, this value is passed as
    /// the `PIQLEY_DRY_RUN` environment variable (`"1"` when active, `"0"` otherwise).
    ///
    /// For JSON protocol plugins, this value is the `dryRun` field in the input payload.
    public let dryRun: Bool
    /// Whether debug output is enabled.
    ///
    /// When `true`, the plugin should emit additional diagnostic information
    /// via ``reportProgress(_:)`` to help with troubleshooting.
    ///
    /// For CLI tool plugins using the pipe protocol, this value is passed as
    /// the `PIQLEY_DEBUG` environment variable (`"1"` when active, `"0"` otherwise).
    ///
    /// For JSON protocol plugins, this value is the `debug` field in the input payload.
    public let debug: Bool
    public let state: ResolvedState
    public let pluginVersion: SemanticVersion
    public let lastExecutedVersion: SemanticVersion?

    /// The unique identifier for the current pipeline run, if available.
    public let pipelineRunId: String?

    private let io: PluginIO
    private let fileManager: any FileSystemManager
    private static let imageExtensions: Set<String> = [
        "jpg", "jpeg", "jxl", "png", "tiff", "tif", "heic", "heif", "webp",
    ]

    /// Internal init from payload. Throws if the hook string is unrecognized.
    init(payload: PluginInputPayload, io: PluginIO, registry: HookRegistry, fileManager: any FileSystemManager = FileManager.default) throws {
        guard let hook = registry.resolve(payload.hook) else {
            throw SDKError.unknownHook(payload.hook)
        }
        self.hook = hook
        self.imageFolderPath = payload.imageFolderPath
        self.pluginConfig = payload.pluginConfig
        self.secrets = payload.secrets
        self.executionLogPath = payload.executionLogPath
        self.dataPath = payload.dataPath
        self.logPath = payload.logPath
        self.dryRun = payload.dryRun
        self.debug = payload.debug
        self.state = ResolvedState(payload.state ?? [:])
        self.pluginVersion = payload.pluginVersion
        self.lastExecutedVersion = payload.lastExecutedVersion
        self.pipelineRunId = payload.pipelineRunId
        self.io = io
        self.fileManager = fileManager
    }

    /// Lists image files in imageFolderPath matching piqley's supported extensions (.jpg, .jpeg, .jxl).
    public func imageFiles() throws -> [URL] {
        let url = URL(fileURLWithPath: imageFolderPath)
        let contents = try fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
        return contents.filter { Self.imageExtensions.contains($0.pathExtension.lowercased()) }
    }

    /// Writes a progress line to stdout immediately.
    public func reportProgress(_ message: String) {
        let line = PluginOutputLine(type: "progress", message: message)
        if let data = try? JSONEncoder.piqley.encode(line), let string = String(data: data, encoding: .utf8) {
            io.writeLine(string)
        }
    }

    /// Writes an imageResult line to stdout immediately.
    public func reportImageResult(_ filename: String, outcome: ImageOutcome, message: String? = nil) {
        let line = PluginOutputLine(type: "imageResult", filename: filename, status: outcome, error: message)
        if let data = try? JSONEncoder.piqley.encode(line), let string = String(data: data, encoding: .utf8) {
            io.writeLine(string)
        }
    }
}

// MARK: - Test Support

/// Result of a captured image result report.
public struct ImageResult: Sendable {
    public let filename: String
    public let outcome: ImageOutcome
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
                let decoded = try? JSONDecoder.piqley.decode(PluginOutputLine.self, from: data),
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
                let decoded = try? JSONDecoder.piqley.decode(PluginOutputLine.self, from: data),
                decoded.type == "imageResult",
                let filename = decoded.filename,
                let status = decoded.status
            else { return nil }
            return ImageResult(filename: filename, outcome: status, error: decoded.error)
        }
    }

    public var allLines: [String] { io.lines }
}

extension PluginRequest {
    /// Creates a mock request for testing. Uses ``StandardHook`` by default.
    public static func mock(
        hook: any Hook = StandardHook.preProcess,
        imageFolderPath: String = "/tmp/test",
        pluginConfig: [String: JSONValue] = [:],
        secrets: [String: String] = [:],
        executionLogPath: String = "/tmp/test/log.jsonl",
        dataPath: String = "/tmp/test/data",
        logPath: String = "/tmp/test/logs",
        dryRun: Bool = false,
        debug: Bool = false,
        state: ResolvedState = .empty,
        pluginVersion: SemanticVersion = SemanticVersion(major: 1, minor: 0, patch: 0),
        lastExecutedVersion: SemanticVersion? = nil,
        pipelineRunId: String? = nil,
        fileManager: any FileSystemManager = FileManager.default
    ) -> (request: PluginRequest, output: CapturedOutput) {
        let io = CapturedIO()
        let request = PluginRequest(
            hook: hook,
            imageFolderPath: imageFolderPath,
            pluginConfig: pluginConfig,
            secrets: secrets,
            executionLogPath: executionLogPath,
            dataPath: dataPath,
            logPath: logPath,
            dryRun: dryRun,
            debug: debug,
            state: state,
            pluginVersion: pluginVersion,
            lastExecutedVersion: lastExecutedVersion,
            pipelineRunId: pipelineRunId,
            io: io,
            fileManager: fileManager
        )
        return (request, CapturedOutput(io: io))
    }

    /// Direct init for mock/test use (bypasses registry resolution).
    private init(
        hook: any Hook,
        imageFolderPath: String,
        pluginConfig: [String: JSONValue],
        secrets: [String: String],
        executionLogPath: String,
        dataPath: String,
        logPath: String,
        dryRun: Bool,
        debug: Bool,
        state: ResolvedState,
        pluginVersion: SemanticVersion,
        lastExecutedVersion: SemanticVersion?,
        pipelineRunId: String?,
        io: PluginIO,
        fileManager: any FileSystemManager = FileManager.default
    ) {
        self.hook = hook
        self.imageFolderPath = imageFolderPath
        self.pluginConfig = pluginConfig
        self.secrets = secrets
        self.executionLogPath = executionLogPath
        self.dataPath = dataPath
        self.logPath = logPath
        self.dryRun = dryRun
        self.debug = debug
        self.state = state
        self.pluginVersion = pluginVersion
        self.lastExecutedVersion = lastExecutedVersion
        self.pipelineRunId = pipelineRunId
        self.io = io
        self.fileManager = fileManager
    }
}
