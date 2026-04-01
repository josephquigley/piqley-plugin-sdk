import Foundation
import PiqleyCore

public struct UploadCache: Sendable {
    private let filePath: String
    private let fileManager: any FileSystemManager
    private var entries: [Entry]

    public struct Entry: Codable, Sendable {
        public let hash: String
        public let filename: String
        public let editorURL: String
        public let cachedAt: String

        public init(hash: String, filename: String, editorURL: String, cachedAt: String) {
            self.hash = hash
            self.filename = filename
            self.editorURL = editorURL
            self.cachedAt = cachedAt
        }
    }

    public init(filePath: String, fileManager: any FileSystemManager = FileManager.default) {
        self.filePath = filePath
        self.fileManager = fileManager
        self.entries = Self.load(from: filePath, fileManager: fileManager)
    }

    public func findMatch(for fingerprint: ImageFingerprint, threshold: Int) -> Entry? {
        entries.first { entry in
            let cached = ImageFingerprint(hash: entry.hash)
            return fingerprint.distance(to: cached) <= threshold
        }
    }

    public mutating func add(hash: String, filename: String, editorURL: String) {
        let entry = Entry(
            hash: hash,
            filename: filename,
            editorURL: editorURL,
            cachedAt: ISO8601DateFormatter().string(from: Date())
        )
        entries.append(entry)
    }

    public mutating func remove(hash: String) {
        entries.removeAll { $0.hash == hash }
    }

    public func save() throws {
        let url = URL(fileURLWithPath: filePath)
        let dir = url.deletingLastPathComponent()
        try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)

        let wrapper = CacheFile(entries: entries)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(wrapper)
        try fileManager.write(data, to: url, options: .atomic)
    }

    private struct CacheFile: Codable {
        let entries: [Entry]
    }

    private static func load(from path: String, fileManager: any FileSystemManager) -> [Entry] {
        guard let data = fileManager.contents(atPath: path),
              let file = try? JSONDecoder().decode(CacheFile.self, from: data)
        else {
            return []
        }
        return file.entries
    }
}
