import Testing
@testable import PiqleyPluginSDK
import PiqleyCore
import Foundation

// MARK: - Mock with defaults

@Test func mockDefaults() {
    let (req, _) = PluginRequest.mock()
    #expect(req.hook == .preProcess)
    #expect(req.imageFolderPath == "/tmp/test")
    #expect(req.pluginConfig.isEmpty)
    #expect(req.secrets.isEmpty)
    #expect(req.executionLogPath == "/tmp/test/log.jsonl")
    #expect(req.dataPath == "/tmp/test/data")
    #expect(req.logPath == "/tmp/test/logs")
    #expect(req.dryRun == false)
    #expect(req.state.imageNames.isEmpty)
    #expect(req.pluginVersion == SemanticVersion(major: 1, minor: 0, patch: 0))
    #expect(req.lastExecutedVersion == nil)
}

// MARK: - Mock with custom values

@Test func mockCustomHook() {
    let (req, _) = PluginRequest.mock(hook: .publish)
    #expect(req.hook == .publish)
}

@Test func mockCustomImageFolderPath() {
    let (req, _) = PluginRequest.mock(imageFolderPath: "/Users/photo/albums")
    #expect(req.imageFolderPath == "/Users/photo/albums")
}

@Test func mockCustomConfig() {
    let (req, _) = PluginRequest.mock(pluginConfig: ["quality": .number(95)])
    #expect(req.pluginConfig["quality"] == .number(95))
}

@Test func mockCustomSecrets() {
    let (req, _) = PluginRequest.mock(secrets: ["TOKEN": "xyz"])
    #expect(req.secrets["TOKEN"] == "xyz")
}

@Test func mockCustomDryRun() {
    let (req, _) = PluginRequest.mock(dryRun: true)
    #expect(req.dryRun == true)
}

@Test func mockCustomVersions() {
    let (req, _) = PluginRequest.mock(
        pluginVersion: SemanticVersion(major: 2, minor: 1, patch: 0),
        lastExecutedVersion: SemanticVersion(major: 1, minor: 9, patch: 0)
    )
    #expect(req.pluginVersion == SemanticVersion(major: 2, minor: 1, patch: 0))
    #expect(req.lastExecutedVersion == SemanticVersion(major: 1, minor: 9, patch: 0))
}

// MARK: - Captures progress messages

@Test func capturedOutputProgressMessages() {
    let (req, output) = PluginRequest.mock()
    req.reportProgress("Step 1")
    req.reportProgress("Step 2")
    #expect(output.progressMessages == ["Step 1", "Step 2"])
}

@Test func capturedOutputProgressEmpty() {
    let (_, output) = PluginRequest.mock()
    #expect(output.progressMessages.isEmpty)
}

// MARK: - Captures image results

@Test func capturedOutputImageResultSuccess() {
    let (req, output) = PluginRequest.mock()
    req.reportImageResult("a.jpg", success: true)
    #expect(output.imageResults.count == 1)
    #expect(output.imageResults[0].filename == "a.jpg")
    #expect(output.imageResults[0].success == true)
    #expect(output.imageResults[0].error == nil)
}

@Test func capturedOutputImageResultFailure() {
    let (req, output) = PluginRequest.mock()
    req.reportImageResult("b.jxl", success: false, error: "unsupported codec")
    #expect(output.imageResults.count == 1)
    #expect(output.imageResults[0].filename == "b.jxl")
    #expect(output.imageResults[0].success == false)
    #expect(output.imageResults[0].error == "unsupported codec")
}

@Test func capturedOutputMixedLines() {
    let (req, output) = PluginRequest.mock()
    req.reportProgress("Starting")
    req.reportImageResult("c.jpg", success: true)
    req.reportImageResult("d.jpg", success: false, error: "err")
    req.reportProgress("Done")

    #expect(output.progressMessages == ["Starting", "Done"])
    #expect(output.imageResults.count == 2)
    #expect(output.allLines.count == 4)
}

// MARK: - Mock with state

@Test func mockWithState() {
    let stateData: [String: [String: [String: JSONValue]]] = [
        "photo.jpg": ["original": ["TIFF:Make": .string("Sony")]]
    ]
    let resolvedState = ResolvedState(stateData)
    let (req, _) = PluginRequest.mock(state: resolvedState)
    #expect(req.state["photo.jpg"].original.string("TIFF:Make") == "Sony")
}

@Test func mockWithEmptyState() {
    let (req, _) = PluginRequest.mock(state: .empty)
    #expect(req.state.imageNames.isEmpty)
}

// MARK: - allLines

@Test func capturedOutputAllLines() {
    let (req, output) = PluginRequest.mock()
    req.reportProgress("hello")
    req.reportImageResult("x.jpg", success: true)
    #expect(output.allLines.count == 2)
}
