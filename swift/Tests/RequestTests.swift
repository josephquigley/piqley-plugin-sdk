import Testing
@testable import PiqleyPluginSDK
import PiqleyCore
import Foundation

// MARK: - Fixtures

private func makePayload(
    hook: String = "pre-process",
    folderPath: String = "/tmp/photos",
    pluginConfig: [String: JSONValue] = ["quality": .number(80)],
    secrets: [String: String] = ["API_KEY": "abc123"],
    executionLogPath: String = "/tmp/log.jsonl",
    dataPath: String = "/tmp/data",
    logPath: String = "/tmp/logs",
    dryRun: Bool = false,
    state: [String: [String: [String: JSONValue]]]? = nil,
    pluginVersion: SemanticVersion = SemanticVersion(major: 1, minor: 2, patch: 3),
    lastExecutedVersion: SemanticVersion? = SemanticVersion(major: 1, minor: 0, patch: 0)
) -> PluginInputPayload {
    PluginInputPayload(
        hook: hook,
        folderPath: folderPath,
        pluginConfig: pluginConfig,
        secrets: secrets,
        executionLogPath: executionLogPath,
        dataPath: dataPath,
        logPath: logPath,
        dryRun: dryRun,
        state: state,
        pluginVersion: pluginVersion,
        lastExecutedVersion: lastExecutedVersion
    )
}

// MARK: - PluginRequest field mapping

@Test func requestMapsHook() {
    let req = PluginRequest(payload: makePayload(hook: "publish"), io: CapturedIO())
    #expect(req.hook == .publish)
}

@Test func requestMapsUnknownHookToPreProcess() {
    let req = PluginRequest(payload: makePayload(hook: "unknown-hook"), io: CapturedIO())
    #expect(req.hook == .preProcess)
}

@Test func requestMapsFolderPath() {
    let req = PluginRequest(payload: makePayload(folderPath: "/my/folder"), io: CapturedIO())
    #expect(req.folderPath == "/my/folder")
}

@Test func requestMapsPluginConfig() {
    let req = PluginRequest(payload: makePayload(pluginConfig: ["level": .number(5)]), io: CapturedIO())
    #expect(req.pluginConfig["level"] == .number(5))
}

@Test func requestMapsSecrets() {
    let req = PluginRequest(payload: makePayload(secrets: ["TOKEN": "secret"]), io: CapturedIO())
    #expect(req.secrets["TOKEN"] == "secret")
}

@Test func requestMapsPaths() {
    let payload = makePayload(
        executionLogPath: "/exec/log",
        dataPath: "/data/dir",
        logPath: "/log/dir"
    )
    let req = PluginRequest(payload: payload, io: CapturedIO())
    #expect(req.executionLogPath == "/exec/log")
    #expect(req.dataPath == "/data/dir")
    #expect(req.logPath == "/log/dir")
}

@Test func requestMapsDryRun() {
    let req = PluginRequest(payload: makePayload(dryRun: true), io: CapturedIO())
    #expect(req.dryRun == true)
}

@Test func requestMapsPluginVersion() {
    let req = PluginRequest(payload: makePayload(pluginVersion: SemanticVersion(major: 2, minor: 3, patch: 4)), io: CapturedIO())
    #expect(req.pluginVersion == SemanticVersion(major: 2, minor: 3, patch: 4))
}

@Test func requestMapsLastExecutedVersion() {
    let req = PluginRequest(payload: makePayload(lastExecutedVersion: SemanticVersion(major: 1, minor: 0, patch: 0)), io: CapturedIO())
    #expect(req.lastExecutedVersion == SemanticVersion(major: 1, minor: 0, patch: 0))
}

@Test func requestMapsNilLastExecutedVersion() {
    let req = PluginRequest(payload: makePayload(lastExecutedVersion: nil), io: CapturedIO())
    #expect(req.lastExecutedVersion == nil)
}

@Test func requestMapsState() {
    let stateData: [String: [String: [String: JSONValue]]] = [
        "img.jpg": ["original": ["TIFF:Make": .string("Nikon")]]
    ]
    let req = PluginRequest(payload: makePayload(state: stateData), io: CapturedIO())
    #expect(req.state["img.jpg"].original.string("TIFF:Make") == "Nikon")
}

@Test func requestMapsNilStateToEmpty() {
    let req = PluginRequest(payload: makePayload(state: nil), io: CapturedIO())
    #expect(req.state.imageNames.isEmpty)
}

// MARK: - reportProgress

@Test func reportProgressWritesJSONLine() throws {
    let io = CapturedIO()
    let req = PluginRequest(payload: makePayload(), io: io)
    req.reportProgress("Processing image")
    #expect(io.lines.count == 1)
    let line = io.lines[0]
    let data = try #require(line.data(using: .utf8))
    let decoded = try JSONDecoder().decode(PluginOutputLine.self, from: data)
    #expect(decoded.type == "progress")
    #expect(decoded.message == "Processing image")
}

// MARK: - reportImageResult

@Test func reportImageResultSuccessWritesJSONLine() throws {
    let io = CapturedIO()
    let req = PluginRequest(payload: makePayload(), io: io)
    req.reportImageResult("photo.jpg", success: true)
    #expect(io.lines.count == 1)
    let decoded = try JSONDecoder().decode(PluginOutputLine.self, from: io.lines[0].data(using: .utf8)!)
    #expect(decoded.type == "imageResult")
    #expect(decoded.filename == "photo.jpg")
    #expect(decoded.success == true)
    #expect(decoded.error == nil)
}

@Test func reportImageResultFailureWritesJSONLine() throws {
    let io = CapturedIO()
    let req = PluginRequest(payload: makePayload(), io: io)
    req.reportImageResult("photo.jpg", success: false, error: "conversion failed")
    #expect(io.lines.count == 1)
    let decoded = try JSONDecoder().decode(PluginOutputLine.self, from: io.lines[0].data(using: .utf8)!)
    #expect(decoded.type == "imageResult")
    #expect(decoded.filename == "photo.jpg")
    #expect(decoded.success == false)
    #expect(decoded.error == "conversion failed")
}

// MARK: - imageFiles()

@Test func imageFilesReturnsOnlySupportedExtensions() throws {
    let dir = FileManager.default.temporaryDirectory
        .appendingPathComponent("piqley-test-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: dir) }

    let filenames = ["a.jpg", "b.jpeg", "c.jxl", "d.png", "e.tiff", "f.txt", "g.JPG"]
    for name in filenames {
        FileManager.default.createFile(atPath: dir.appendingPathComponent(name).path, contents: nil)
    }

    let req = PluginRequest(payload: makePayload(folderPath: dir.path), io: CapturedIO())
    let found = try req.imageFiles()
    let names = Set(found.map { $0.lastPathComponent })
    #expect(names.contains("a.jpg"))
    #expect(names.contains("b.jpeg"))
    #expect(names.contains("c.jxl"))
    #expect(names.contains("g.JPG"))
    #expect(!names.contains("d.png"))
    #expect(!names.contains("e.tiff"))
    #expect(!names.contains("f.txt"))
}
