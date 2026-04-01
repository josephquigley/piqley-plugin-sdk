import Foundation

public struct UploadCache: Sendable {
    private let filePath: String
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

    public init(filePath: String) {
        self.filePath = filePath
        self.entries = Self.load(from: filePath)
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

    public func save() throws {
        let url = URL(fileURLWithPath: filePath)
        let dir = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let wrapper = CacheFile(entries: entries)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(wrapper)
        try data.write(to: url, options: .atomic)
    }

    private struct CacheFile: Codable {
        let entries: [Entry]
    }

    private static func load(from path: String) -> [Entry] {
        guard let data = FileManager.default.contents(atPath: path),
              let file = try? JSONDecoder().decode(CacheFile.self, from: data)
        else {
            return []
        }
        return file.entries
    }
}
