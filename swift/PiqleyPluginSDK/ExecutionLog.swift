import Foundation
import PiqleyCore

// MARK: - ExecutionLogEntry

public struct ExecutionLogEntry: Codable, Sendable {
    public let filename: String
    public let timestamp: Date
    public let hook: String
    public let success: Bool
    public let metadata: [String: JSONValue]?

    public init(filename: String, hook: any Hook, success: Bool, metadata: [String: JSONValue]? = nil) {
        self.filename = filename
        self.timestamp = Date()
        self.hook = hook.rawValue
        self.success = success
        self.metadata = metadata
    }

    public init(filename: String, hookName: String, success: Bool, metadata: [String: JSONValue]? = nil) {
        self.filename = filename
        self.timestamp = Date()
        self.hook = hookName
        self.success = success
        self.metadata = metadata
    }
}

// MARK: - ExecutionLog

public struct ExecutionLog: Sendable {
    private let path: String
    private let fileManager: any FileSystemManager

    private static var iso8601Decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    private static var iso8601Encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    public init(path: String, fileManager: any FileSystemManager = FileManager.default) throws {
        self.path = path
        self.fileManager = fileManager
    }

    public func append(_ entry: ExecutionLogEntry) throws {
        let fileURL = URL(fileURLWithPath: path)

        // Create parent directories if needed
        let parentDir = fileURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: parentDir, withIntermediateDirectories: true)

        let data = try Self.iso8601Encoder.encode(entry)
        // Force-unwrap is safe: JSONEncoder always produces valid UTF-8
        let line = String(data: data, encoding: .utf8)!

        let lineWithNewline = line + "\n"
        let lineData = Data(lineWithNewline.utf8)

        if fileManager.fileExists(atPath: path) {
            let existing = try fileManager.contents(of: fileURL)
            var combined = existing
            combined.append(lineData)
            try fileManager.write(combined, to: fileURL)
        } else {
            try fileManager.write(lineData, to: fileURL, options: .atomic)
        }
    }

    public func entries(for filename: String) throws -> [ExecutionLogEntry] {
        guard fileManager.fileExists(atPath: path) else {
            return []
        }

        let fileURL = URL(fileURLWithPath: path)
        let rawData = try fileManager.contents(of: fileURL)
        let content = String(data: rawData, encoding: .utf8) ?? ""
        let decoder = Self.iso8601Decoder

        return try content
            .components(separatedBy: "\n")
            .filter { !$0.isEmpty }
            .compactMap { line -> ExecutionLogEntry? in
                guard let data = line.data(using: .utf8) else { return nil }
                let entry = try decoder.decode(ExecutionLogEntry.self, from: data)
                return entry.filename == filename ? entry : nil
            }
    }

    public func contains(filename: String) throws -> Bool {
        let found = try entries(for: filename)
        return !found.isEmpty
    }
}
