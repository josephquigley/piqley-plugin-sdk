import Testing
@testable import PiqleyPluginSDK
import PiqleyCore

// MARK: - Fixture data

private let sampleStorage: [String: [String: [String: JSONValue]]] = [
    "photo1.jpg": [
        "original": [
            "TIFF:Make": .string("Canon"),
            "TIFF:Model": .string("EOS R5"),
            "EXIF:FNumber": .number(2.8),
            "EXIF:ISOSpeedRatings": .number(400),
            "EXIF:Flash": .bool(false),
            "IPTC:Keywords": .array([.string("nature"), .string("landscape")]),
            "mixed-array": .array([.string("a"), .number(1)]),
        ],
        "my-plugin": [
            "score": .number(9),
            "approved": .bool(true),
            "tags": .array([.string("featured")]),
        ],
    ],
]

// MARK: - ResolvedState tests

@Test func resolvedStateImageNames() {
    let state = ResolvedState(sampleStorage)
    #expect(state.imageNames == ["photo1.jpg"])
}

@Test func resolvedStateSubscriptPresent() {
    let state = ResolvedState(sampleStorage)
    let imageState = state["photo1.jpg"]
    #expect(imageState.original.string("TIFF:Make") == "Canon")
}

@Test func resolvedStateSubscriptMissing() {
    let state = ResolvedState(sampleStorage)
    let imageState = state["missing.jpg"]
    #expect(imageState.original.string("TIFF:Make") == nil)
}

@Test func resolvedStateEmpty() {
    let state = ResolvedState.empty
    #expect(state.imageNames.isEmpty)
    #expect(state["photo1.jpg"].original.string("TIFF:Make") == nil)
}

// MARK: - Original namespace — string key access

@Test func namespaceStringKey() {
    let ns = ResolvedState(sampleStorage)["photo1.jpg"].original
    #expect(ns.string("TIFF:Make") == "Canon")
    #expect(ns.string("TIFF:Model") == "EOS R5")
}

@Test func namespaceStringKeyMissing() {
    let ns = ResolvedState(sampleStorage)["photo1.jpg"].original
    #expect(ns.string("nonexistent") == nil)
}

// MARK: - Original namespace — typed key access

@Test func namespaceTypedStringKey() {
    let ns = ResolvedState(sampleStorage)["photo1.jpg"].original
    #expect(ns.string(ImageMetadataKey.make) == "Canon")
    #expect(ns.string(ImageMetadataKey.model) == "EOS R5")
}

// MARK: - Numeric accessors

@Test func namespaceDoubleKey() {
    let ns = ResolvedState(sampleStorage)["photo1.jpg"].original
    #expect(ns.double("EXIF:FNumber") == 2.8)
    #expect(ns.double(ImageMetadataKey.fNumber) == 2.8)
}

@Test func namespaceIntKey() {
    let ns = ResolvedState(sampleStorage)["photo1.jpg"].original
    #expect(ns.int("EXIF:ISOSpeedRatings") == 400)
    #expect(ns.int(ImageMetadataKey.iso) == 400)
}

@Test func namespaceBoolKey() {
    let ns = ResolvedState(sampleStorage)["photo1.jpg"].original
    #expect(ns.bool("EXIF:Flash") == false)
    #expect(ns.bool(ImageMetadataKey.flash) == false)
}

// MARK: - Array accessor

@Test func namespaceStringsKey() {
    let ns = ResolvedState(sampleStorage)["photo1.jpg"].original
    #expect(ns.strings("IPTC:Keywords") == ["nature", "landscape"])
    #expect(ns.strings(ImageMetadataKey.keywords) == ["nature", "landscape"])
}

@Test func namespaceStringsKeyMixedReturnNil() {
    let ns = ResolvedState(sampleStorage)["photo1.jpg"].original
    #expect(ns.strings("mixed-array") == nil)
}

// MARK: - Raw accessor

@Test func namespaceRawKey() {
    let ns = ResolvedState(sampleStorage)["photo1.jpg"].original
    #expect(ns.raw("TIFF:Make") == .string("Canon"))
    #expect(ns.raw(ImageMetadataKey.make) == .string("Canon"))
    #expect(ns.raw("nonexistent") == nil)
}

// MARK: - Wrong type returns nil

@Test func namespaceWrongTypeReturnsNil() {
    let ns = ResolvedState(sampleStorage)["photo1.jpg"].original
    // TIFF:Make is a string, not a number
    #expect(ns.int("TIFF:Make") == nil)
    #expect(ns.double("TIFF:Make") == nil)
    #expect(ns.bool("TIFF:Make") == nil)
    #expect(ns.strings("TIFF:Make") == nil)
}

// MARK: - Helpers for dependency typed key test

private enum DepKeys: String, StateKey {
    static let namespace = "my-plugin"
    case score
    case approved
    case tags
}

// MARK: - Dependency namespace

@Test func dependencyNamespaceStringKey() {
    let imageState = ResolvedState(sampleStorage)["photo1.jpg"]
    let dep = imageState.dependency("my-plugin")
    #expect(dep.int("score") == 9)
    #expect(dep.bool("approved") == true)
    #expect(dep.strings("tags") == ["featured"])
}

@Test func dependencyNamespaceTypedKey() {
    let dep = ResolvedState(sampleStorage)["photo1.jpg"].dependency("my-plugin")
    #expect(dep.int(DepKeys.score) == 9)
    #expect(dep.bool(DepKeys.approved) == true)
}

@Test func dependencyNamespaceMissing() {
    let imageState = ResolvedState(sampleStorage)["photo1.jpg"]
    let dep = imageState.dependency("nonexistent-plugin")
    #expect(dep.string("any") == nil)
}
