import Testing
@testable import PiqleyPluginSDK
import PiqleyCore
import Foundation

// MARK: - Fixtures

private let standardRegistry = HookRegistry { r in
    r.register(StandardHook.self)
}

private func makePayload(
    hook: String = "pre-process",
    imageFolderPath: String = "/tmp/photos",
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
        imageFolderPath: imageFolderPath,
        pluginConfig: pluginConfig,
        secrets: secrets,
        executionLogPath: executionLogPath,
        dataPath: dataPath,
        logPath: logPath,
        dryRun: dryRun,
        debug: false,
        state: state,
        pluginVersion: pluginVersion,
        lastExecutedVersion: lastExecutedVersion
    )
}

// MARK: - PluginRequest field mapping

@Test func requestMapsHook() throws {
    let req = try PluginRequest(payload: makePayload(hook: "publish"), io: CapturedIO(), registry: standardRegistry)
    #expect(req.hook as? StandardHook == .publish)
}

@Test func requestThrowsOnUnknownHook() {
    #expect(throws: SDKError.self) {
        _ = try PluginRequest(payload: makePayload(hook: "unknown-hook"), io: CapturedIO(), registry: standardRegistry)
    }
}

@Test func requestMapsImageFolderPath() throws {
    let req = try PluginRequest(payload: makePayload(imageFolderPath: "/my/folder"), io: CapturedIO(), registry: standardRegistry)
    #expect(req.imageFolderPath == "/my/folder")
}

@Test func requestMapsPluginConfig() throws {
    let req = try PluginRequest(payload: makePayload(pluginConfig: ["level": .number(5)]), io: CapturedIO(), registry: standardRegistry)
    #expect(req.pluginConfig["level"] == .number(5))
}

@Test func requestMapsSecrets() throws {
    let req = try PluginRequest(payload: makePayload(secrets: ["TOKEN": "secret"]), io: CapturedIO(), registry: standardRegistry)
    #expect(req.secrets["TOKEN"] == "secret")
}

@Test func requestMapsPaths() throws {
    let payload = makePayload(
        executionLogPath: "/exec/log",
        dataPath: "/data/dir",
        logPath: "/log/dir"
    )
    let req = try PluginRequest(payload: payload, io: CapturedIO(), registry: standardRegistry)
    #expect(req.executionLogPath == "/exec/log")
    #expect(req.dataPath == "/data/dir")
    #expect(req.logPath == "/log/dir")
}

@Test func requestMapsDryRun() throws {
    let req = try PluginRequest(payload: makePayload(dryRun: true), io: CapturedIO(), registry: standardRegistry)
    #expect(req.dryRun == true)
}

@Test func requestMapsPluginVersion() throws {
    let req = try PluginRequest(payload: makePayload(pluginVersion: SemanticVersion(major: 2, minor: 3, patch: 4)), io: CapturedIO(), registry: standardRegistry)
    #expect(req.pluginVersion == SemanticVersion(major: 2, minor: 3, patch: 4))
}

@Test func requestMapsLastExecutedVersion() throws {
    let req = try PluginRequest(payload: makePayload(lastExecutedVersion: SemanticVersion(major: 1, minor: 0, patch: 0)), io: CapturedIO(), registry: standardRegistry)
    #expect(req.lastExecutedVersion == SemanticVersion(major: 1, minor: 0, patch: 0))
}

@Test func requestMapsNilLastExecutedVersion() throws {
    let req = try PluginRequest(payload: makePayload(lastExecutedVersion: nil), io: CapturedIO(), registry: standardRegistry)
    #expect(req.lastExecutedVersion == nil)
}

@Test func requestMapsState() throws {
    let stateData: [String: [String: [String: JSONValue]]] = [
        "img.jpg": ["original": ["TIFF:Make": .string("Nikon")]]
    ]
    let req = try PluginRequest(payload: makePayload(state: stateData), io: CapturedIO(), registry: standardRegistry)
    #expect(req.state["img.jpg"].original.string("TIFF:Make") == "Nikon")
}

@Test func requestMapsNilStateToEmpty() throws {
    let req = try PluginRequest(payload: makePayload(state: nil), io: CapturedIO(), registry: standardRegistry)
    #expect(req.state.imageNames.isEmpty)
}

// MARK: - reportProgress

@Test func reportProgressWritesJSONLine() throws {
    let io = CapturedIO()
    let req = try PluginRequest(payload: makePayload(), io: io, registry: standardRegistry)
    req.reportProgress("Processing image")
    #expect(io.lines.count == 1)
    let line = io.lines[0]
    let data = try #require(line.data(using: .utf8))
    let decoded = try JSONDecoder.piqley.decode(PluginOutputLine.self, from: data)
    #expect(decoded.type == "progress")
    #expect(decoded.message == "Processing image")
}

// MARK: - reportImageResult

@Test func reportImageResultSuccessWritesJSONLine() throws {
    let io = CapturedIO()
    let req = try PluginRequest(payload: makePayload(), io: io, registry: standardRegistry)
    req.reportImageResult("photo.jpg", outcome: .success)
    #expect(io.lines.count == 1)
    let decoded = try JSONDecoder.piqley.decode(PluginOutputLine.self, from: io.lines[0].data(using: .utf8)!)
    #expect(decoded.type == "imageResult")
    #expect(decoded.filename == "photo.jpg")
    #expect(decoded.status == .success)
    #expect(decoded.error == nil)
}

@Test func reportImageResultFailureWritesJSONLine() throws {
    let io = CapturedIO()
    let req = try PluginRequest(payload: makePayload(), io: io, registry: standardRegistry)
    req.reportImageResult("photo.jpg", outcome: .failure, message: "conversion failed")
    #expect(io.lines.count == 1)
    let decoded = try JSONDecoder.piqley.decode(PluginOutputLine.self, from: io.lines[0].data(using: .utf8)!)
    #expect(decoded.type == "imageResult")
    #expect(decoded.filename == "photo.jpg")
    #expect(decoded.status == .failure)
    #expect(decoded.error == "conversion failed")
}

@Test func reportImageResultWarningWritesJSONLine() throws {
    let io = CapturedIO()
    let req = try PluginRequest(payload: makePayload(), io: io, registry: standardRegistry)
    req.reportImageResult("photo.jpg", outcome: .warning, message: "missing GPS data")
    #expect(io.lines.count == 1)
    let decoded = try JSONDecoder.piqley.decode(PluginOutputLine.self, from: io.lines[0].data(using: .utf8)!)
    #expect(decoded.type == "imageResult")
    #expect(decoded.filename == "photo.jpg")
    #expect(decoded.status == .warning)
    #expect(decoded.error == "missing GPS data")
}

@Test func reportImageResultSkipWritesJSONLine() throws {
    let io = CapturedIO()
    let req = try PluginRequest(payload: makePayload(), io: io, registry: standardRegistry)
    req.reportImageResult("photo.jpg", outcome: .skip, message: "not a RAW file")
    #expect(io.lines.count == 1)
    let decoded = try JSONDecoder.piqley.decode(PluginOutputLine.self, from: io.lines[0].data(using: .utf8)!)
    #expect(decoded.type == "imageResult")
    #expect(decoded.filename == "photo.jpg")
    #expect(decoded.status == .skip)
    #expect(decoded.error == "not a RAW file")
}

// MARK: - imageFiles()

@Test func imageFilesReturnsOnlySupportedExtensions() throws {
    let fm = InMemoryFileManager()
    let dir = URL(fileURLWithPath: "/test/photos")
    try fm.createDirectory(at: dir, withIntermediateDirectories: true)

    let filenames = ["a.jpg", "b.jpeg", "c.jxl", "d.png", "e.tiff", "f.txt", "g.JPG", "h.heic", "i.webp"]
    for name in filenames {
        fm.createFile(atPath: dir.appendingPathComponent(name).path, contents: nil, attributes: nil)
    }

    let req = try PluginRequest(payload: makePayload(imageFolderPath: dir.path), io: CapturedIO(), registry: standardRegistry, fileManager: fm)
    let found = try req.imageFiles()
    let names = Set(found.map { $0.lastPathComponent })
    #expect(names.contains("a.jpg"))
    #expect(names.contains("b.jpeg"))
    #expect(names.contains("c.jxl"))
    #expect(names.contains("g.JPG"))
    #expect(names.contains("d.png"))
    #expect(names.contains("e.tiff"))
    #expect(names.contains("h.heic"))
    #expect(names.contains("i.webp"))
    #expect(!names.contains("f.txt"))
}

// MARK: - HookRegistry

@Test func hookRegistryResolvesStandardHook() {
    let registry = HookRegistry { r in
        r.register(StandardHook.self)
    }
    let hook = registry.resolve("pre-process")
    #expect(hook as? StandardHook == .preProcess)
}

@Test func hookRegistryReturnsNilForUnknown() {
    let registry = HookRegistry { r in
        r.register(StandardHook.self)
    }
    #expect(registry.resolve("unknown") == nil)
}

@Test func hookRegistryAllHooks() {
    let registry = HookRegistry { r in
        r.register(StandardHook.self)
    }
    #expect(registry.allHooks.count == 6)
}
