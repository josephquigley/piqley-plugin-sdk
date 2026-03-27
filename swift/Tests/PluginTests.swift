import Testing
@testable import PiqleyPluginSDK
import PiqleyCore
import Foundation

// MARK: - Test plugin implementations

private struct SuccessPlugin: PiqleyPlugin {
    let registry = HookRegistry { r in
        r.register(StandardHook.self)
    }

    func handle(_ request: PluginRequest) async throws -> PluginResponse {
        request.reportProgress("Starting")
        request.reportProgress("Done")
        return .ok
    }
}

private struct StatePlugin: PiqleyPlugin {
    let registry = HookRegistry { r in
        r.register(StandardHook.self)
    }

    func handle(_ request: PluginRequest) async throws -> PluginResponse {
        var ps = PluginState()
        ps.set("processed", to: true)
        return PluginResponse(success: true, state: ["photo.jpg": ps])
    }
}

private struct FailPlugin: PiqleyPlugin {
    let registry = HookRegistry { r in
        r.register(StandardHook.self)
    }

    func handle(_ request: PluginRequest) async throws -> PluginResponse {
        throw SDKError.unknownHook("crash")
    }
}

// MARK: - Helpers

private func makePayloadData(hook: String = "pre-process") throws -> Data {
    let payload = PluginInputPayload(
        hook: hook,
        imageFolderPath: "/tmp/photos",
        pluginConfig: [:],
        secrets: [:],
        executionLogPath: "/tmp/log.jsonl",
        dataPath: "/tmp/data",
        logPath: "/tmp/logs",
        dryRun: false,
        debug: false,
        state: nil,
        pluginVersion: SemanticVersion(major: 1, minor: 0, patch: 0),
        lastExecutedVersion: nil
    )
    return try JSONEncoder.piqley.encode(payload)
}

private func decodeLine(_ line: String) throws -> PluginOutputLine {
    let data = try #require(line.data(using: .utf8))
    return try JSONDecoder.piqley.decode(PluginOutputLine.self, from: data)
}

// MARK: - Tests

@Test func pluginRunSuccess() async throws {
    let plugin = SuccessPlugin()
    let input = try makePayloadData()
    let io = CapturedIO()
    let exitCode = await plugin.run(input: input, io: io)

    #expect(exitCode == 0)
    #expect(io.lines.count == 3) // 2 progress + 1 result
    let result = try decodeLine(io.lines[2])
    #expect(result.type == "result")
    #expect(result.success == true)
}

@Test func pluginRunSuccessProgressLines() async throws {
    let plugin = SuccessPlugin()
    let input = try makePayloadData()
    let io = CapturedIO()
    _ = await plugin.run(input: input, io: io)

    let p1 = try decodeLine(io.lines[0])
    let p2 = try decodeLine(io.lines[1])
    #expect(p1.type == "progress")
    #expect(p1.message == "Starting")
    #expect(p2.type == "progress")
    #expect(p2.message == "Done")
}

@Test func pluginRunWithState() async throws {
    let plugin = StatePlugin()
    let input = try makePayloadData()
    let io = CapturedIO()
    let exitCode = await plugin.run(input: input, io: io)

    #expect(exitCode == 0)
    #expect(io.lines.count == 1)
    let result = try decodeLine(io.lines[0])
    #expect(result.type == "result")
    #expect(result.success == true)
    #expect(result.state?["photo.jpg"]?["processed"] == .bool(true))
}

@Test func pluginRunHandleThrow() async throws {
    let plugin = FailPlugin()
    let input = try makePayloadData()
    let io = CapturedIO()
    let exitCode = await plugin.run(input: input, io: io)

    #expect(exitCode == 1)
    #expect(io.lines.count == 1)
    let result = try decodeLine(io.lines[0])
    #expect(result.type == "result")
    #expect(result.success == false)
    #expect(result.error != nil)
}

@Test func pluginRunUnknownHookReturnsError() async throws {
    let plugin = SuccessPlugin()
    let input = try makePayloadData(hook: "unknown-hook")
    let io = CapturedIO()
    let exitCode = await plugin.run(input: input, io: io)

    #expect(exitCode == 1)
    #expect(io.lines.count == 1)
    let result = try decodeLine(io.lines[0])
    #expect(result.type == "result")
    #expect(result.success == false)
    #expect(result.error?.contains("unknown-hook") == true)
}

@Test func piqleyInfoResponse() throws {
    let json = #"{"piqleyPlugin":true,"schemaVersion":"1"}"#
    let data = json.data(using: .utf8)!
    let parsed = try JSONSerialization.jsonObject(with: data) as! [String: Any]
    #expect(parsed["piqleyPlugin"] as? Bool == true)
    #expect(parsed["schemaVersion"] as? String == "1")
}

@Test func pluginRunBadPayload() async {
    let plugin = SuccessPlugin()
    let io = CapturedIO()
    let exitCode = await plugin.run(input: Data("not json".utf8), io: io)

    #expect(exitCode == 1)
    #expect(io.lines.count == 1)
    let line = io.lines[0]
    let data = line.data(using: .utf8)!
    let result = try? JSONDecoder.piqley.decode(PluginOutputLine.self, from: data)
    #expect(result?.type == "result")
    #expect(result?.success == false)
    #expect(result?.error != nil)
}

@Test func pluginRunFailResponseExitOne() async throws {
    struct FailResponsePlugin: PiqleyPlugin {
        let registry = HookRegistry { r in
            r.register(StandardHook.self)
        }
        func handle(_ request: PluginRequest) async throws -> PluginResponse {
            PluginResponse(success: false, error: "intentional failure")
        }
    }
    let plugin = FailResponsePlugin()
    let input = try makePayloadData()
    let io = CapturedIO()
    let exitCode = await plugin.run(input: input, io: io)

    #expect(exitCode == 1)
    let result = try decodeLine(io.lines[0])
    #expect(result.success == false)
    #expect(result.error == "intentional failure")
}
