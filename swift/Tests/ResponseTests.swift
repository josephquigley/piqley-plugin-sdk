import Testing
@testable import PiqleyPluginSDK
import PiqleyCore

// MARK: - PluginResponse convenience

@Test func responseOkConvenience() {
    let r = PluginResponse.ok
    #expect(r.success == true)
    #expect(r.error == nil)
    #expect(r.state == nil)
}

@Test func responseWithError() {
    let r = PluginResponse(success: false, error: "something went wrong")
    #expect(r.success == false)
    #expect(r.error == "something went wrong")
    #expect(r.state == nil)
}

@Test func responseWithState() {
    var ps = PluginState()
    ps.set("score", to: 42)
    let r = PluginResponse(success: true, state: ["photo.jpg": ps])
    #expect(r.success == true)
    #expect(r.state?["photo.jpg"] != nil)
}

// MARK: - toOutputLine()

@Test func responseToOutputLineOk() {
    let line = PluginResponse.ok.toOutputLine()
    #expect(line.type == "result")
    #expect(line.success == true)
    #expect(line.error == nil)
    #expect(line.state == nil)
}

@Test func responseToOutputLineError() {
    let line = PluginResponse(success: false, error: "bad input").toOutputLine()
    #expect(line.type == "result")
    #expect(line.success == false)
    #expect(line.error == "bad input")
}

@Test func responseToOutputLineWithState() {
    var ps = PluginState()
    ps.set("caption", to: "sunset")
    let line = PluginResponse(success: true, state: ["img.jpg": ps]).toOutputLine()
    #expect(line.type == "result")
    #expect(line.state?["img.jpg"]?["caption"] == .string("sunset"))
}
