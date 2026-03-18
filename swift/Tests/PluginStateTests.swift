import Testing
@testable import PiqleyPluginSDK
import PiqleyCore

// MARK: - Typed key helper

private enum OutKeys: String, StateKey {
    static let namespace = "my-plugin"
    case title
    case tags
    case score
    case approved
    case confidence
    case raw
}

// MARK: - Tests

@Test func pluginStateEmptyToDict() {
    let state = PluginState()
    #expect(state.toDict().isEmpty)
}

@Test func pluginStateSetString() {
    var state = PluginState()
    state.set("title", to: "My Photo")
    #expect(state.toDict()["title"] == .string("My Photo"))
}

@Test func pluginStateSetStringArray() {
    var state = PluginState()
    state.set("tags", to: ["nature", "landscape"])
    #expect(state.toDict()["tags"] == .array([.string("nature"), .string("landscape")]))
}

@Test func pluginStateSetInt() {
    var state = PluginState()
    state.set("score", to: 9)
    #expect(state.toDict()["score"] == .number(9.0))
}

@Test func pluginStateSetBool() {
    var state = PluginState()
    state.set("approved", to: true)
    #expect(state.toDict()["approved"] == .bool(true))
}

@Test func pluginStateSetDouble() {
    var state = PluginState()
    state.set("confidence", to: 0.95)
    #expect(state.toDict()["confidence"] == .number(0.95))
}

@Test func pluginStateSetJSONValue() {
    var state = PluginState()
    state.set("raw", to: JSONValue.object(["nested": .string("value")]))
    #expect(state.toDict()["raw"] == .object(["nested": .string("value")]))
}

// MARK: - Typed key setters

@Test func pluginStateTypedSetString() {
    var state = PluginState()
    state.set(OutKeys.title, to: "My Photo")
    #expect(state.toDict()["title"] == .string("My Photo"))
}

@Test func pluginStateTypedSetStringArray() {
    var state = PluginState()
    state.set(OutKeys.tags, to: ["nature", "landscape"])
    #expect(state.toDict()["tags"] == .array([.string("nature"), .string("landscape")]))
}

@Test func pluginStateTypedSetInt() {
    var state = PluginState()
    state.set(OutKeys.score, to: 9)
    #expect(state.toDict()["score"] == .number(9.0))
}

@Test func pluginStateTypedSetBool() {
    var state = PluginState()
    state.set(OutKeys.approved, to: false)
    #expect(state.toDict()["approved"] == .bool(false))
}

@Test func pluginStateTypedSetDouble() {
    var state = PluginState()
    state.set(OutKeys.confidence, to: 0.75)
    #expect(state.toDict()["confidence"] == .number(0.75))
}

@Test func pluginStateTypedSetJSONValue() {
    var state = PluginState()
    state.set(OutKeys.raw, to: JSONValue.null)
    #expect(state.toDict()["raw"] == .null)
}

// MARK: - Overwrite

@Test func pluginStateOverwrite() {
    var state = PluginState()
    state.set("title", to: "First")
    state.set("title", to: "Second")
    #expect(state.toDict()["title"] == .string("Second"))
}
