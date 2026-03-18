import Testing
@testable import PiqleyPluginSDK
import PiqleyCore
import Foundation

// MARK: - Helper

private func tempLogPath() -> String {
    FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathComponent("test.jsonl")
        .path
}

// MARK: - Append and query

@Test func executionLogAppendAndQuery() throws {
    let path = tempLogPath()
    defer { try? FileManager.default.removeItem(atPath: path) }

    let log = try ExecutionLog(path: path)
    let entry = ExecutionLogEntry(filename: "photo.jpg", hook: .preProcess, success: true)
    try log.append(entry)

    let results = try log.entries(for: "photo.jpg")
    #expect(results.count == 1)
    #expect(results[0].filename == "photo.jpg")
    #expect(results[0].hook == .preProcess)
    #expect(results[0].success == true)
    #expect(results[0].metadata == nil)
}

// MARK: - Contains

@Test func executionLogContains() throws {
    let path = tempLogPath()
    defer { try? FileManager.default.removeItem(atPath: path) }

    let log = try ExecutionLog(path: path)
    try log.append(ExecutionLogEntry(filename: "img.jpg", hook: .publish, success: true))

    #expect(try log.contains(filename: "img.jpg") == true)
    #expect(try log.contains(filename: "other.jpg") == false)
}

// MARK: - Multiple entries for different files

@Test func executionLogMultipleFiles() throws {
    let path = tempLogPath()
    defer { try? FileManager.default.removeItem(atPath: path) }

    let log = try ExecutionLog(path: path)
    try log.append(ExecutionLogEntry(filename: "a.jpg", hook: .preProcess, success: true))
    try log.append(ExecutionLogEntry(filename: "b.jpg", hook: .postProcess, success: false))
    try log.append(ExecutionLogEntry(filename: "a.jpg", hook: .publish, success: true))

    let aEntries = try log.entries(for: "a.jpg")
    #expect(aEntries.count == 2)
    #expect(aEntries[0].hook == .preProcess)
    #expect(aEntries[1].hook == .publish)

    let bEntries = try log.entries(for: "b.jpg")
    #expect(bEntries.count == 1)
    #expect(bEntries[0].hook == .postProcess)
    #expect(bEntries[0].success == false)
}

// MARK: - Entry with metadata

@Test func executionLogEntryWithMetadata() throws {
    let path = tempLogPath()
    defer { try? FileManager.default.removeItem(atPath: path) }

    let log = try ExecutionLog(path: path)
    let metadata: [String: JSONValue] = ["score": .number(42), "label": .string("portrait")]
    let entry = ExecutionLogEntry(filename: "meta.jpg", hook: .postProcess, success: true, metadata: metadata)
    try log.append(entry)

    let results = try log.entries(for: "meta.jpg")
    #expect(results.count == 1)
    #expect(results[0].metadata?["score"] == .number(42))
    #expect(results[0].metadata?["label"] == .string("portrait"))
}

// MARK: - Creates file if missing

@Test func executionLogCreatesFileIfMissing() throws {
    let path = tempLogPath()
    defer { try? FileManager.default.removeItem(atPath: path) }

    #expect(!FileManager.default.fileExists(atPath: path))

    let log = try ExecutionLog(path: path)
    try log.append(ExecutionLogEntry(filename: "new.jpg", hook: .preProcess, success: true))

    #expect(FileManager.default.fileExists(atPath: path))
}

// MARK: - Timestamp is set

@Test func executionLogTimestampIsSet() throws {
    let path = tempLogPath()
    defer { try? FileManager.default.removeItem(atPath: path) }

    let before = Date().addingTimeInterval(-1) // allow 1s slack for ISO 8601 second truncation
    let log = try ExecutionLog(path: path)
    let entry = ExecutionLogEntry(filename: "ts.jpg", hook: .schedule, success: true)
    try log.append(entry)
    let after = Date().addingTimeInterval(1)

    let results = try log.entries(for: "ts.jpg")
    #expect(results.count == 1)
    #expect(results[0].timestamp >= before)
    #expect(results[0].timestamp <= after)
}

// MARK: - Empty query when file missing

@Test func executionLogEmptyWhenFileMissing() throws {
    let path = tempLogPath()
    let log = try ExecutionLog(path: path)
    let results = try log.entries(for: "ghost.jpg")
    #expect(results.isEmpty)
}
