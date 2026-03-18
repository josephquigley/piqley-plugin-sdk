import Testing
@testable import PiqleyPluginSDK
import PiqleyCore
import Foundation

// MARK: - Test plugin implementations

private struct SuccessPlugin: PiqleyPlugin {
    func handle(_ request: PluginRequest) async throws -> PluginResponse {
        request.reportProgress("Starting")
        request.reportProgress("Done")
        return .ok
    }
}

private struct StatePlugin: PiqleyPlugin {
    func handle(_ request: PluginRequest) async throws -> PluginResponse {
        var ps = PluginState()
        ps.set("processed", true)
        return PluginResponse(success: true, state: ["photo.jpg": ps])
    }
}

private struct FailPlugin: PiqleyPlugin {
    func handle(_ request: PluginRequest) async throws -> PluginResponse {
        throw SDKError.unknownHook("crash")
    }
}

// MARK: - Helpers

private func makePayloadData(hook: String = "pre-process") throws -> Data {
    let payload = PluginInputPayload(
        hook: hook,
        folderPath: "/tmp/photos",
        pluginConfig: [:],
        secrets: [:],
        executionLogPath: "/tmp/log.jsonl",
        dataPath: "/tmp/data",
        logPath: "/tmp/logs",
        dryRun: false,
        state: nil,
        pluginVersion: SemanticVersion(major: 1, minor: 0, patch: 0),
        lastExecutedVersion: nil
    )
    return try JSONEncoder().encode(payload)
}

private func decodeLine(_ line: String) throws -> PluginOutputLine {
    let data = try #require(line.data(using: .utf8))
    return try JSONDecoder().decode(PluginOutputLine.self, from: data)
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

@Test func pluginRunBadPayload() async {
    let plugin = SuccessPlugin()
    let io = CapturedIO()
    let exitCode = await plugin.run(input: Data("not json".utf8), io: io)

    #expect(exitCode == 1)
    #expect(io.lines.count == 1)
    let line = io.lines[0]
    let data = line.data(using: .utf8)!
    let result = try? JSONDecoder().decode(PluginOutputLine.self, from: data)
    #expect(result?.type == "result")
    #expect(result?.success == false)
    #expect(result?.error != nil)
}

@Test func pluginRunFailResponseExitOne() async throws {
    struct FailResponsePlugin: PiqleyPlugin {
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
