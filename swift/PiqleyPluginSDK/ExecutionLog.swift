import Foundation
import PiqleyCore

// MARK: - ExecutionLogEntry

public struct ExecutionLogEntry: Codable, Sendable {
    public let filename: String
    public let timestamp: Date
    public let hook: Hook
    public let success: Bool
    public let metadata: [String: JSONValue]?

    public init(filename: String, hook: Hook, success: Bool, metadata: [String: JSONValue]? = nil) {
        self.filename = filename
        self.timestamp = Date()
        self.hook = hook
        self.success = success
        self.metadata = metadata
    }
}

// MARK: - ExecutionLog

public struct ExecutionLog: Sendable {
    private let path: String

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

    public init(path: String) throws {
        self.path = path
    }

    public func append(_ entry: ExecutionLogEntry) throws {
        let fileURL = URL(fileURLWithPath: path)

        // Create parent directories if needed
        let parentDir = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true)

        let data = try Self.iso8601Encoder.encode(entry)
        guard let line = String(data: data, encoding: .utf8) else {
            throw CocoaError(.fileWriteUnknown)
        }

        let lineWithNewline = line + "\n"
        let lineData = Data(lineWithNewline.utf8)

        if FileManager.default.fileExists(atPath: path) {
            let fileHandle = try FileHandle(forWritingTo: fileURL)
            defer { fileHandle.closeFile() }
            fileHandle.seekToEndOfFile()
            fileHandle.write(lineData)
        } else {
            try lineData.write(to: fileURL, options: .atomic)
        }
    }

    public func entries(for filename: String) throws -> [ExecutionLogEntry] {
        guard FileManager.default.fileExists(atPath: path) else {
            return []
        }

        let content = try String(contentsOfFile: path, encoding: .utf8)
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
