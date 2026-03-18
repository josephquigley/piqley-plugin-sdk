# PiqleyPluginSDK Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the Swift SDK that plugin authors use to create piqley plugins with typed APIs, builder DSLs, and test support.

**Architecture:** PiqleyPluginSDK depends on PiqleyCore for wire types. It provides a `PiqleyPlugin` protocol with a `run()` entry point that handles stdin/stdout, typed request/response wrappers, state access with `StateKey` generics, result builder DSLs for manifests/configs, and a mock factory for testing. All public API gets DocC symbol documentation.

**Tech Stack:** Swift 6.0, Swift Package Manager, Swift Testing, PiqleyCore

**Spec:** `docs/superpowers/specs/2026-03-18-piqley-plugin-sdk-design.md` (Sections 2-10)

**Prerequisite:** PiqleyCore must be implemented and tagged (see `docs/superpowers/plans/2026-03-18-piqley-core-plan.md`)

**Repo:** `/Users/wash/Developer/tools/piqley/piqley-plugin-sdk/`

---

## File Structure

```
swift/PiqleyPluginSDK/
├── Plugin.swift                # PiqleyPlugin protocol, run() entry point
├── Request.swift               # PluginRequest with typed accessors
├── Response.swift              # PluginResponse
├── Errors.swift                # SDKError type
├── IO.swift                    # PluginIO protocol, StdoutIO, CapturedIO
├── State/
│   ├── StateKey.swift          # StateKey protocol
│   ├── ImageMetadataKey.swift  # Curated EXIF/IPTC/TIFF/XMP keys
│   ├── ResolvedState.swift     # ResolvedState, ImageState, Namespace
│   └── PluginState.swift       # PluginState (write-side)
├── Builders/
│   ├── ManifestBuilder.swift   # Result builder for PluginManifest
│   ├── ConfigBuilder.swift     # Result builder for PluginConfig
│   ├── MatchField.swift        # Typed rule match field
│   └── MatchPattern.swift      # Typed rule match pattern
└── ExecutionLog.swift          # JSONL execution log helper

swift/Tests/
├── PluginTests.swift
├── RequestTests.swift
├── ResponseTests.swift
├── StateKeyTests.swift
├── ResolvedStateTests.swift
├── PluginStateTests.swift
├── ManifestBuilderTests.swift
├── ConfigBuilderTests.swift
├── MatchFieldTests.swift
├── ExecutionLogTests.swift
└── MockTests.swift
```

---

### Task 1: Update Package.swift

**Files:**
- Modify: `Package.swift`

- [ ] **Step 1: Update Package.swift to add PiqleyCore dependency and test target**

Replace contents of `Package.swift`:
```swift
// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "PiqleyPluginSDK",
    products: [
        .library(name: "PiqleyPluginSDK", targets: ["PiqleyPluginSDK"]),
    ],
    dependencies: [
        .package(url: "https://github.com/josephquigley/piqley-core.git", from: "0.1.0"),
    ],
    targets: [
        .target(
            name: "PiqleyPluginSDK",
            dependencies: [.product(name: "PiqleyCore", package: "piqley-core")],
            path: "swift/PiqleyPluginSDK"
        ),
        .testTarget(
            name: "PiqleyPluginSDKTests",
            dependencies: ["PiqleyPluginSDK"],
            path: "swift/Tests"
        ),
    ]
)
```

- [ ] **Step 2: Create test directory and placeholder**

Create `swift/Tests/PiqleyPluginSDKTests.swift`:
```swift
import Testing
@testable import PiqleyPluginSDK
import PiqleyCore

@Test func sdkImportsCore() {
    // Verify PiqleyCore types are accessible through the SDK.
    let hook = Hook.publish
    #expect(hook.rawValue == "publish")
}
```

- [ ] **Step 3: Update the main source file to re-export PiqleyCore**

Replace `swift/PiqleyPluginSDK/PiqleyPluginSDK.swift`:
```swift
// PiqleyPluginSDK — Swift SDK for building piqley plugins.
@_exported import PiqleyCore
```

- [ ] **Step 4: Verify build and test**

Run: `swift build && swift test`
Expected: BUILD SUCCEEDED, test passes

- [ ] **Step 5: Commit**

```bash
git add Package.swift swift/PiqleyPluginSDK/PiqleyPluginSDK.swift swift/Tests/
git commit -m "chore: add PiqleyCore dependency and test target"
```

---

### Task 2: StateKey protocol and ImageMetadataKey

**Files:**
- Create: `swift/PiqleyPluginSDK/State/StateKey.swift`
- Create: `swift/PiqleyPluginSDK/State/ImageMetadataKey.swift`
- Create: `swift/Tests/StateKeyTests.swift`

- [ ] **Step 1: Write failing tests**

Create `swift/Tests/StateKeyTests.swift`:
```swift
import Testing
@testable import PiqleyPluginSDK
import PiqleyCore

// Test custom StateKey conformance
enum TestKeys: String, StateKey {
    static let namespace = "test-plugin"
    case title
    case count
    case dashKey = "dash-key"
}

@Test func stateKeyNamespace() {
    #expect(TestKeys.namespace == "test-plugin")
}

@Test func stateKeyRawValue() {
    #expect(TestKeys.title.rawValue == "title")
    #expect(TestKeys.dashKey.rawValue == "dash-key")
}

@Test func imageMetadataKeyNamespace() {
    #expect(ImageMetadataKey.namespace == "original")
}

@Test func imageMetadataKeyEXIF() {
    #expect(ImageMetadataKey.model.rawValue == "TIFF:Model")
    #expect(ImageMetadataKey.lensModel.rawValue == "EXIF:LensModel")
    #expect(ImageMetadataKey.iso.rawValue == "EXIF:ISOSpeedRatings")
    #expect(ImageMetadataKey.dateTimeOriginal.rawValue == "EXIF:DateTimeOriginal")
    #expect(ImageMetadataKey.fNumber.rawValue == "EXIF:FNumber")
}

@Test func imageMetadataKeyIPTC() {
    #expect(ImageMetadataKey.keywords.rawValue == "IPTC:Keywords")
    #expect(ImageMetadataKey.caption.rawValue == "IPTC:CaptionAbstract")
    #expect(ImageMetadataKey.city.rawValue == "IPTC:City")
    #expect(ImageMetadataKey.country.rawValue == "IPTC:CountryPrimaryLocationName")
}

@Test func imageMetadataKeyXMP() {
    #expect(ImageMetadataKey.title.rawValue == "XMP:Title")
    #expect(ImageMetadataKey.rating.rawValue == "XMP:Rating")
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test 2>&1 | head -20`
Expected: FAIL

- [ ] **Step 3: Implement StateKey and ImageMetadataKey**

Create `swift/PiqleyPluginSDK/State/StateKey.swift`:
```swift
/// A typed key for reading from or writing to plugin state.
///
/// Conform your own string-backed enum to `StateKey` to get compile-time
/// safety when accessing state fields:
///
/// ```swift
/// enum MyKeys: String, StateKey {
///     static let namespace = "my-plugin"
///     case keywords
///     case caption
/// }
/// ```
public protocol StateKey: RawRepresentable, Sendable where RawValue == String {
    /// The namespace this key belongs to (plugin name, or "original" for image metadata).
    static var namespace: String { get }
}
```

Create `swift/PiqleyPluginSDK/State/ImageMetadataKey.swift`:
```swift
/// Curated keys for common EXIF, IPTC, TIFF, and XMP metadata fields
/// extracted by piqley core into the `original` namespace.
///
/// Use these with state accessors for compile-time safety:
/// ```swift
/// let model = request.state[image]?.original.string(.model)
/// ```
///
/// For fields not covered by this enum, use the string-based accessor instead.
public enum ImageMetadataKey: String, StateKey, CaseIterable, Sendable {
    public static let namespace = "original"

    // MARK: TIFF

    /// Camera manufacturer.
    case make = "TIFF:Make"
    /// Camera model name.
    case model = "TIFF:Model"
    /// Image orientation.
    case orientation = "TIFF:Orientation"
    /// Software used to create the image.
    case software = "TIFF:Software"
    /// Horizontal resolution.
    case xResolution = "TIFF:XResolution"
    /// Vertical resolution.
    case yResolution = "TIFF:YResolution"

    // MARK: EXIF

    /// Date and time the original image was taken.
    case dateTimeOriginal = "EXIF:DateTimeOriginal"
    /// Date and time the image was digitized.
    case dateTimeDigitized = "EXIF:DateTimeDigitized"
    /// Exposure time in seconds.
    case exposureTime = "EXIF:ExposureTime"
    /// F-number (aperture).
    case fNumber = "EXIF:FNumber"
    /// ISO speed rating.
    case iso = "EXIF:ISOSpeedRatings"
    /// Focal length in millimeters.
    case focalLength = "EXIF:FocalLength"
    /// 35mm equivalent focal length.
    case focalLengthIn35mm = "EXIF:FocalLenIn35mmFilm"
    /// Lens model name.
    case lensModel = "EXIF:LensModel"
    /// Shutter speed value (APEX).
    case shutterSpeed = "EXIF:ShutterSpeedValue"
    /// Aperture value (APEX).
    case aperture = "EXIF:ApertureValue"
    /// Exposure program (manual, aperture priority, etc.).
    case exposureProgram = "EXIF:ExposureProgram"
    /// Metering mode.
    case meteringMode = "EXIF:MeteringMode"
    /// Flash status.
    case flash = "EXIF:Flash"
    /// White balance mode.
    case whiteBalance = "EXIF:WhiteBalance"
    /// Exposure compensation in EV.
    case exposureCompensation = "EXIF:ExposureBiasValue"
    /// Camera body serial number.
    case bodySerialNumber = "EXIF:BodySerialNumber"
    /// Lens serial number.
    case lensSerialNumber = "EXIF:LensSerialNumber"
    /// Color space.
    case colorSpace = "EXIF:ColorSpace"
    /// Image width in pixels.
    case pixelXDimension = "EXIF:PixelXDimension"
    /// Image height in pixels.
    case pixelYDimension = "EXIF:PixelYDimension"

    // MARK: IPTC

    /// Keywords/tags assigned to the image.
    case keywords = "IPTC:Keywords"
    /// Image caption/description.
    case caption = "IPTC:CaptionAbstract"
    /// Object/title name.
    case objectName = "IPTC:ObjectName"
    /// City where the image was taken.
    case city = "IPTC:City"
    /// Country where the image was taken.
    case country = "IPTC:CountryPrimaryLocationName"
    /// State or province.
    case provinceState = "IPTC:ProvinceState"
    /// Sublocation (neighborhood, landmark).
    case sublocation = "IPTC:SubLocation"
    /// Photographer name.
    case byline = "IPTC:Byline"
    /// Copyright notice.
    case copyrightNotice = "IPTC:CopyrightNotice"
    /// Credit line.
    case credit = "IPTC:Credit"
    /// Source.
    case source = "IPTC:Source"
    /// Headline.
    case headline = "IPTC:Headline"
    /// Special instructions.
    case specialInstructions = "IPTC:SpecialInstructions"
    /// Date the content was created.
    case dateCreated = "IPTC:DateCreated"

    // MARK: XMP

    /// XMP title.
    case title = "XMP:Title"
    /// XMP description.
    case xmpDescription = "XMP:Description"
    /// XMP creator.
    case creator = "XMP:Creator"
    /// XMP rights.
    case rights = "XMP:Rights"
    /// Star rating (0-5).
    case rating = "XMP:Rating"
    /// Color label.
    case label = "XMP:Label"
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test`
Expected: All tests pass

- [ ] **Step 5: Commit**

```bash
git add swift/PiqleyPluginSDK/State/ swift/Tests/StateKeyTests.swift
git commit -m "feat: add StateKey protocol and ImageMetadataKey enum"
```

---

### Task 3: IO layer

**Files:**
- Create: `swift/PiqleyPluginSDK/IO.swift`
- Create: `swift/PiqleyPluginSDK/Errors.swift`

No dedicated tests for IO — it's internal. Tested indirectly through Plugin/Request tests.

- [ ] **Step 1: Implement PluginIO protocol and implementations**

Create `swift/PiqleyPluginSDK/IO.swift`:
```swift
import Foundation
import PiqleyCore

/// Internal protocol for writing JSON lines to output.
protocol PluginIO: Sendable {
    func writeLine(_ line: String)
}

/// Writes to stdout with immediate flushing.
struct StdoutIO: PluginIO {
    func writeLine(_ line: String) {
        print(line)
        fflush(stdout)
    }
}

/// Captures output lines for testing.
final class CapturedIO: PluginIO, Sendable {
    private let lock = NSLock()
    private var _lines: [String] = []

    func writeLine(_ line: String) {
        lock.lock()
        defer { lock.unlock() }
        _lines.append(line)
    }

    var lines: [String] {
        lock.lock()
        defer { lock.unlock() }
        return _lines
    }
}
```

Create `swift/PiqleyPluginSDK/Errors.swift`:
```swift
import Foundation

/// Errors thrown by the PiqleyPluginSDK.
public enum SDKError: Error, Sendable {
    /// Failed to read input from stdin.
    case stdinReadFailed
    /// Failed to decode the JSON payload from stdin.
    case payloadDecodeFailed(String)
    /// The hook value in the payload is not a recognized pipeline stage.
    case unknownHook(String)
    /// Manifest validation failed.
    case manifestValidationFailed([String])
}
```

- [ ] **Step 2: Verify build**

Run: `swift build`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add swift/PiqleyPluginSDK/IO.swift swift/PiqleyPluginSDK/Errors.swift
git commit -m "feat: add PluginIO layer and SDKError types"
```

---

### Task 4: ResolvedState and Namespace (read-side state)

**Files:**
- Create: `swift/PiqleyPluginSDK/State/ResolvedState.swift`
- Create: `swift/Tests/ResolvedStateTests.swift`

- [ ] **Step 1: Write failing tests**

Create `swift/Tests/ResolvedStateTests.swift`:
```swift
import Testing
@testable import PiqleyPluginSDK
import PiqleyCore

enum TestPluginKeys: String, StateKey {
    static let namespace = "hashtag"
    case tags
    case caption
}

@Test func resolvedStateImageNames() {
    let state = ResolvedState(raw: [
        "IMG_001.jpg": ["original": ["TIFF:Model": .string("Canon")]],
        "IMG_002.jpg": ["original": ["TIFF:Model": .string("Sony")]],
    ])
    #expect(state.imageNames.sorted() == ["IMG_001.jpg", "IMG_002.jpg"])
}

@Test func resolvedStateSubscript() {
    let state = ResolvedState(raw: [
        "IMG_001.jpg": ["original": ["TIFF:Model": .string("Canon")]],
    ])
    #expect(state["IMG_001.jpg"] != nil)
    #expect(state["nonexistent.jpg"] == nil)
}

@Test func imageStateOriginalStringAccess() {
    let state = ResolvedState(raw: [
        "IMG_001.jpg": ["original": ["TIFF:Model": .string("Canon EOS R5")]],
    ])
    let model = state["IMG_001.jpg"]?.original.string("TIFF:Model")
    #expect(model == "Canon EOS R5")
}

@Test func imageStateOriginalTypedAccess() {
    let state = ResolvedState(raw: [
        "IMG_001.jpg": ["original": ["TIFF:Model": .string("Canon EOS R5")]],
    ])
    let model = state["IMG_001.jpg"]?.original.string(.model)
    #expect(model == "Canon EOS R5")
}

@Test func imageStateDependencyAccess() {
    let state = ResolvedState(raw: [
        "IMG_001.jpg": [
            "original": ["TIFF:Model": .string("Canon")],
            "hashtag": ["tags": .array([.string("#Canon"), .string("#Photo")])],
        ],
    ])
    let tags = state["IMG_001.jpg"]?.dependency("hashtag").strings("tags")
    #expect(tags == ["#Canon", "#Photo"])
}

@Test func imageStateDependencyTypedAccess() {
    let state = ResolvedState(raw: [
        "IMG_001.jpg": [
            "hashtag": ["tags": .array([.string("#Canon")])],
        ],
    ])
    let tags = state["IMG_001.jpg"]?.dependency("hashtag").strings(TestPluginKeys.tags)
    #expect(tags == ["#Canon"])
}

@Test func namespaceIntAccess() {
    let state = ResolvedState(raw: [
        "IMG_001.jpg": ["original": ["EXIF:ISOSpeedRatings": .number(400)]],
    ])
    let iso = state["IMG_001.jpg"]?.original.int("EXIF:ISOSpeedRatings")
    #expect(iso == 400)
}

@Test func namespaceDoubleAccess() {
    let state = ResolvedState(raw: [
        "IMG_001.jpg": ["original": ["EXIF:FNumber": .number(2.8)]],
    ])
    let f = state["IMG_001.jpg"]?.original.double("EXIF:FNumber")
    #expect(f == 2.8)
}

@Test func namespaceBoolAccess() {
    let state = ResolvedState(raw: [
        "IMG_001.jpg": ["test": ["flag": .bool(true)]],
    ])
    let flag = state["IMG_001.jpg"]?.dependency("test").bool("flag")
    #expect(flag == true)
}

@Test func namespaceRawAccess() {
    let state = ResolvedState(raw: [
        "IMG_001.jpg": ["original": ["complex": .object(["nested": .string("value")])]],
    ])
    let raw = state["IMG_001.jpg"]?.original.raw("complex")
    #expect(raw == .object(["nested": .string("value")]))
}

@Test func namespaceMissingKeyReturnsNil() {
    let state = ResolvedState(raw: [
        "IMG_001.jpg": ["original": ["TIFF:Model": .string("Canon")]],
    ])
    #expect(state["IMG_001.jpg"]?.original.string("nonexistent") == nil)
}

@Test func namespaceWrongTypeReturnsNil() {
    let state = ResolvedState(raw: [
        "IMG_001.jpg": ["original": ["TIFF:Model": .string("Canon")]],
    ])
    #expect(state["IMG_001.jpg"]?.original.int("TIFF:Model") == nil)
}

@Test func emptyResolvedState() {
    let state = ResolvedState.empty
    #expect(state.imageNames.isEmpty)
    #expect(state["anything"] == nil)
}

@Test func namespaceMissingDependencyReturnsEmptyNamespace() {
    let state = ResolvedState(raw: [
        "IMG_001.jpg": ["original": ["TIFF:Model": .string("Canon")]],
    ])
    // Accessing a dependency that doesn't exist returns empty namespace
    #expect(state["IMG_001.jpg"]?.dependency("nonexistent").string("anything") == nil)
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test 2>&1 | head -20`
Expected: FAIL

- [ ] **Step 3: Implement ResolvedState, ImageState, Namespace**

Create `swift/PiqleyPluginSDK/State/ResolvedState.swift`:
```swift
import Foundation
import PiqleyCore

/// Read-only view of state resolved from plugin dependencies.
///
/// State is organized per-image, then per-namespace (plugin name or "original").
/// Access values through typed or string-based accessors on ``Namespace``.
public struct ResolvedState: Sendable {
    private let raw: [String: [String: [String: JSONValue]]]

    /// Create from the raw state dictionary (image → namespace → field → value).
    public init(raw: [String: [String: [String: JSONValue]]]) {
        self.raw = raw
    }

    /// An empty state with no images.
    public static let empty = ResolvedState(raw: [:])

    /// All image filenames that have state.
    public var imageNames: [String] {
        Array(raw.keys)
    }

    /// Access state for a specific image.
    public subscript(image: String) -> ImageState? {
        guard let namespaces = raw[image] else { return nil }
        return ImageState(namespaces: namespaces)
    }
}

/// State for a single image, providing access to namespaces.
public struct ImageState: Sendable {
    private let namespaces: [String: [String: JSONValue]]

    init(namespaces: [String: [String: JSONValue]]) {
        self.namespaces = namespaces
    }

    /// Access the "original" namespace (core-extracted EXIF/IPTC/XMP metadata).
    public var original: Namespace {
        Namespace(fields: namespaces["original"] ?? [:])
    }

    /// Access a dependency plugin's namespace by name.
    public func dependency(_ name: String) -> Namespace {
        Namespace(fields: namespaces[name] ?? [:])
    }
}

/// A namespace containing key-value pairs, with typed accessors.
///
/// Provides both string-keyed and ``StateKey``-keyed access:
/// ```swift
/// // String-keyed
/// let model = namespace.string("TIFF:Model")
/// // Typed key
/// let model = namespace.string(.model)
/// ```
public struct Namespace: Sendable {
    private let fields: [String: JSONValue]

    init(fields: [String: JSONValue]) {
        self.fields = fields
    }

    // MARK: String-keyed access

    /// Get a string value, or nil if missing or wrong type.
    public func string(_ key: String) -> String? {
        guard case let .string(value) = fields[key] else { return nil }
        return value
    }

    /// Get an integer value, or nil if missing or wrong type.
    public func int(_ key: String) -> Int? {
        guard case let .number(value) = fields[key] else { return nil }
        guard value.truncatingRemainder(dividingBy: 1) == 0 else { return nil }
        return Int(value)
    }

    /// Get a double value, or nil if missing or wrong type.
    public func double(_ key: String) -> Double? {
        guard case let .number(value) = fields[key] else { return nil }
        return value
    }

    /// Get a bool value, or nil if missing or wrong type.
    public func bool(_ key: String) -> Bool? {
        guard case let .bool(value) = fields[key] else { return nil }
        return value
    }

    /// Get a string array, or nil if missing or wrong type.
    public func strings(_ key: String) -> [String]? {
        guard case let .array(values) = fields[key] else { return nil }
        let strings = values.compactMap { value -> String? in
            guard case let .string(s) = value else { return nil }
            return s
        }
        guard strings.count == values.count else { return nil }
        return strings
    }

    /// Get the raw JSONValue for advanced use.
    public func raw(_ key: String) -> JSONValue? {
        fields[key]
    }

    // MARK: Typed key access

    /// Get a string value using a typed key.
    public func string<K: StateKey>(_ key: K) -> String? {
        string(key.rawValue)
    }

    /// Get an integer value using a typed key.
    public func int<K: StateKey>(_ key: K) -> Int? {
        int(key.rawValue)
    }

    /// Get a double value using a typed key.
    public func double<K: StateKey>(_ key: K) -> Double? {
        double(key.rawValue)
    }

    /// Get a bool value using a typed key.
    public func bool<K: StateKey>(_ key: K) -> Bool? {
        bool(key.rawValue)
    }

    /// Get a string array using a typed key.
    public func strings<K: StateKey>(_ key: K) -> [String]? {
        strings(key.rawValue)
    }

    /// Get the raw JSONValue using a typed key.
    public func raw<K: StateKey>(_ key: K) -> JSONValue? {
        raw(key.rawValue)
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test`
Expected: All tests pass

- [ ] **Step 5: Commit**

```bash
git add swift/PiqleyPluginSDK/State/ResolvedState.swift swift/Tests/ResolvedStateTests.swift
git commit -m "feat: add ResolvedState, ImageState, and Namespace for typed state access"
```

---

### Task 5: PluginState (write-side state)

**Files:**
- Create: `swift/PiqleyPluginSDK/State/PluginState.swift`
- Create: `swift/Tests/PluginStateTests.swift`

- [ ] **Step 1: Write failing tests**

Create `swift/Tests/PluginStateTests.swift`:
```swift
import Testing
@testable import PiqleyPluginSDK
import PiqleyCore

enum WriteTestKeys: String, StateKey {
    static let namespace = "writer"
    case keywords
    case caption
    case count
}

@Test func setStringValue() {
    var state = PluginState()
    state.set("title", to: "Hello")
    #expect(state.toDict()["title"] == .string("Hello"))
}

@Test func setStringArrayValue() {
    var state = PluginState()
    state.set("tags", to: ["a", "b", "c"])
    #expect(state.toDict()["tags"] == .array([.string("a"), .string("b"), .string("c")]))
}

@Test func setIntValue() {
    var state = PluginState()
    state.set("count", to: 42)
    #expect(state.toDict()["count"] == .number(42))
}

@Test func setBoolValue() {
    var state = PluginState()
    state.set("active", to: true)
    #expect(state.toDict()["active"] == .bool(true))
}

@Test func setDoubleValue() {
    var state = PluginState()
    state.set("ratio", to: 1.5)
    #expect(state.toDict()["ratio"] == .number(1.5))
}

@Test func setRawJSONValue() {
    var state = PluginState()
    state.set("complex", to: JSONValue.object(["nested": .string("value")]))
    #expect(state.toDict()["complex"] == .object(["nested": .string("value")]))
}

@Test func setTypedKey() {
    var state = PluginState()
    state.set(WriteTestKeys.keywords, to: ["Sony", "A7R"])
    state.set(WriteTestKeys.caption, to: "Golden hour")
    state.set(WriteTestKeys.count, to: 5)
    #expect(state.toDict()["keywords"] == .array([.string("Sony"), .string("A7R")]))
    #expect(state.toDict()["caption"] == .string("Golden hour"))
    #expect(state.toDict()["count"] == .number(5))
}

@Test func overwriteValue() {
    var state = PluginState()
    state.set("key", to: "first")
    state.set("key", to: "second")
    #expect(state.toDict()["key"] == .string("second"))
}

@Test func emptyState() {
    let state = PluginState()
    #expect(state.toDict().isEmpty)
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test 2>&1 | head -20`
Expected: FAIL

- [ ] **Step 3: Implement PluginState**

Create `swift/PiqleyPluginSDK/State/PluginState.swift`:
```swift
import Foundation
import PiqleyCore

/// Mutable state that a plugin writes to its own namespace.
///
/// ```swift
/// var imageState = PluginState()
/// imageState.set(MyKeys.keywords, to: ["Sony", "A7R"])
/// imageState.set(MyKeys.caption, to: "Golden hour")
/// ```
public struct PluginState: Sendable {
    private var fields: [String: JSONValue] = [:]

    public init() {}

    /// Returns the internal dictionary for serialization.
    public func toDict() -> [String: JSONValue] {
        fields
    }

    // MARK: String-keyed setters

    /// Set a string value.
    public mutating func set(_ key: String, to value: String) {
        fields[key] = .string(value)
    }

    /// Set a string array value.
    public mutating func set(_ key: String, to values: [String]) {
        fields[key] = .array(values.map { .string($0) })
    }

    /// Set an integer value.
    public mutating func set(_ key: String, to value: Int) {
        fields[key] = .number(Double(value))
    }

    /// Set a bool value.
    public mutating func set(_ key: String, to value: Bool) {
        fields[key] = .bool(value)
    }

    /// Set a double value.
    public mutating func set(_ key: String, to value: Double) {
        fields[key] = .number(value)
    }

    /// Set a raw JSONValue.
    public mutating func set(_ key: String, to value: JSONValue) {
        fields[key] = value
    }

    // MARK: Typed key setters

    /// Set a string value using a typed key.
    public mutating func set<K: StateKey>(_ key: K, to value: String) {
        set(key.rawValue, to: value)
    }

    /// Set a string array value using a typed key.
    public mutating func set<K: StateKey>(_ key: K, to values: [String]) {
        set(key.rawValue, to: values)
    }

    /// Set an integer value using a typed key.
    public mutating func set<K: StateKey>(_ key: K, to value: Int) {
        set(key.rawValue, to: value)
    }

    /// Set a bool value using a typed key.
    public mutating func set<K: StateKey>(_ key: K, to value: Bool) {
        set(key.rawValue, to: value)
    }

    /// Set a double value using a typed key.
    public mutating func set<K: StateKey>(_ key: K, to value: Double) {
        set(key.rawValue, to: value)
    }

    /// Set a raw JSONValue using a typed key.
    public mutating func set<K: StateKey>(_ key: K, to value: JSONValue) {
        set(key.rawValue, to: value)
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test`
Expected: All tests pass

- [ ] **Step 5: Commit**

```bash
git add swift/PiqleyPluginSDK/State/PluginState.swift swift/Tests/PluginStateTests.swift
git commit -m "feat: add PluginState for typed state writing"
```

---

### Task 6: PluginRequest and PluginResponse

**Files:**
- Create: `swift/PiqleyPluginSDK/Request.swift`
- Create: `swift/PiqleyPluginSDK/Response.swift`
- Create: `swift/Tests/RequestTests.swift`
- Create: `swift/Tests/ResponseTests.swift`

- [ ] **Step 1: Write failing tests for Request**

Create `swift/Tests/RequestTests.swift`:
```swift
import Testing
@testable import PiqleyPluginSDK
import PiqleyCore
import Foundation

@Test func requestFromPayload() throws {
    let payload = PluginInputPayload(
        hook: "publish",
        folderPath: "/tmp/test/",
        pluginConfig: ["url": .string("https://example.com")],
        secrets: ["api-key": "secret"],
        executionLogPath: "/log.jsonl",
        dataPath: "/data",
        logPath: "/logs",
        dryRun: true,
        state: [
            "IMG_001.jpg": ["original": ["TIFF:Model": .string("Canon")]],
        ],
        pluginVersion: SemanticVersion(1, 0, 0),
        lastExecutedVersion: nil
    )
    let io = CapturedIO()
    let request = PluginRequest(payload: payload, io: io)

    #expect(request.hook == .publish)
    #expect(request.folderPath == "/tmp/test/")
    #expect(request.pluginConfig["url"] == .string("https://example.com"))
    #expect(request.secrets["api-key"] == "secret")
    #expect(request.executionLogPath == "/log.jsonl")
    #expect(request.dataPath == "/data")
    #expect(request.logPath == "/logs")
    #expect(request.dryRun == true)
    #expect(request.pluginVersion == SemanticVersion(1, 0, 0))
    #expect(request.lastExecutedVersion == nil)
    #expect(request.state["IMG_001.jpg"]?.original.string(.model) == "Canon")
}

@Test func requestReportProgress() throws {
    let payload = PluginInputPayload(
        hook: "publish", folderPath: "/tmp/", pluginConfig: [:], secrets: [:],
        executionLogPath: "/log", dataPath: "/data", logPath: "/logs",
        dryRun: false, state: nil,
        pluginVersion: SemanticVersion(1, 0, 0), lastExecutedVersion: nil
    )
    let io = CapturedIO()
    let request = PluginRequest(payload: payload, io: io)
    request.reportProgress("Uploading...")

    let lines = io.lines
    #expect(lines.count == 1)
    let decoded = try JSONDecoder().decode(PluginOutputLine.self, from: Data(lines[0].utf8))
    #expect(decoded.type == "progress")
    #expect(decoded.message == "Uploading...")
}

@Test func requestReportImageResult() throws {
    let payload = PluginInputPayload(
        hook: "publish", folderPath: "/tmp/", pluginConfig: [:], secrets: [:],
        executionLogPath: "/log", dataPath: "/data", logPath: "/logs",
        dryRun: false, state: nil,
        pluginVersion: SemanticVersion(1, 0, 0), lastExecutedVersion: nil
    )
    let io = CapturedIO()
    let request = PluginRequest(payload: payload, io: io)
    request.reportImageResult("photo.jpg", success: true)
    request.reportImageResult("fail.jpg", success: false, error: "Timeout")

    let lines = io.lines
    #expect(lines.count == 2)

    let line1 = try JSONDecoder().decode(PluginOutputLine.self, from: Data(lines[0].utf8))
    #expect(line1.type == "imageResult")
    #expect(line1.filename == "photo.jpg")
    #expect(line1.success == true)

    let line2 = try JSONDecoder().decode(PluginOutputLine.self, from: Data(lines[1].utf8))
    #expect(line2.filename == "fail.jpg")
    #expect(line2.success == false)
    #expect(line2.error == "Timeout")
}

@Test func requestImageFiles() throws {
    // Create a temp directory with test files
    let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tempDir) }

    // Create test image files
    try Data().write(to: tempDir.appendingPathComponent("photo.jpg"))
    try Data().write(to: tempDir.appendingPathComponent("image.jpeg"))
    try Data().write(to: tempDir.appendingPathComponent("new.jxl"))
    try Data().write(to: tempDir.appendingPathComponent("readme.txt")) // not an image

    let payload = PluginInputPayload(
        hook: "publish", folderPath: tempDir.path, pluginConfig: [:], secrets: [:],
        executionLogPath: "/log", dataPath: "/data", logPath: "/logs",
        dryRun: false, state: nil,
        pluginVersion: SemanticVersion(1, 0, 0), lastExecutedVersion: nil
    )
    let io = CapturedIO()
    let request = PluginRequest(payload: payload, io: io)
    let files = try request.imageFiles()

    let filenames = files.map { $0.lastPathComponent }.sorted()
    #expect(filenames == ["image.jpeg", "new.jxl", "photo.jpg"])
}
```

- [ ] **Step 2: Write failing tests for Response**

Create `swift/Tests/ResponseTests.swift`:
```swift
import Testing
@testable import PiqleyPluginSDK
import PiqleyCore
import Foundation

@Test func responseOk() {
    let response = PluginResponse.ok
    #expect(response.success == true)
    #expect(response.error == nil)
    #expect(response.state == nil)
}

@Test func responseWithState() {
    var imageState = PluginState()
    imageState.set("keywords", to: ["Sony"])
    let response = PluginResponse(success: true, state: ["IMG_001.jpg": imageState])
    #expect(response.success == true)
    #expect(response.state?["IMG_001.jpg"]?.toDict()["keywords"] == .array([.string("Sony")]))
}

@Test func responseWithError() {
    let response = PluginResponse(success: false, error: "Upload failed")
    #expect(response.success == false)
    #expect(response.error == "Upload failed")
}

@Test func responseToOutputLine() throws {
    var imageState = PluginState()
    imageState.set("keywords", to: ["Sony"])
    let response = PluginResponse(success: true, state: ["IMG_001.jpg": imageState])

    let line = response.toOutputLine()
    #expect(line.type == "result")
    #expect(line.success == true)
    #expect(line.state?["IMG_001.jpg"]?["keywords"] == .array([.string("Sony")]))
}

@Test func responseToOutputLineNoState() throws {
    let response = PluginResponse.ok
    let line = response.toOutputLine()
    #expect(line.type == "result")
    #expect(line.success == true)
    #expect(line.state == nil)
}
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `swift test 2>&1 | head -20`
Expected: FAIL

- [ ] **Step 4: Implement PluginRequest**

Create `swift/PiqleyPluginSDK/Request.swift`:
```swift
import Foundation
import PiqleyCore

/// The parsed request passed to a plugin's ``PiqleyPlugin/handle(_:)`` method.
///
/// Contains the hook stage, folder path, config, secrets, state, and methods
/// for reporting progress and image results back to piqley.
public struct PluginRequest: Sendable {
    /// Which pipeline stage this invocation is for.
    public let hook: Hook
    /// Path to the temp folder containing images.
    public let folderPath: String
    /// Resolved config values from config.json.
    public let pluginConfig: [String: JSONValue]
    /// Resolved secrets from keychain.
    public let secrets: [String: String]
    /// Path to the plugin's execution log file.
    public let executionLogPath: String
    /// Path to the plugin's writable data directory.
    public let dataPath: String
    /// Path to the plugin's writable log directory.
    public let logPath: String
    /// Whether this is a dry run.
    public let dryRun: Bool
    /// Resolved state from dependencies, keyed by image filename.
    public let state: ResolvedState
    /// The plugin's version from its manifest.
    public let pluginVersion: SemanticVersion
    /// The version of this plugin that last ran successfully, or nil on first run.
    public let lastExecutedVersion: SemanticVersion?

    private let io: PluginIO

    /// Supported image file extensions.
    private static let imageExtensions: Set<String> = ["jpg", "jpeg", "jxl"]

    init(payload: PluginInputPayload, io: PluginIO) {
        self.hook = Hook(rawValue: payload.hook) ?? .preProcess
        self.folderPath = payload.folderPath
        self.pluginConfig = payload.pluginConfig
        self.secrets = payload.secrets
        self.executionLogPath = payload.executionLogPath
        self.dataPath = payload.dataPath
        self.logPath = payload.logPath
        self.dryRun = payload.dryRun
        self.state = ResolvedState(raw: payload.state ?? [:])
        self.pluginVersion = payload.pluginVersion
        self.lastExecutedVersion = payload.lastExecutedVersion
        self.io = io
    }

    /// Lists image files in ``folderPath`` matching piqley's supported extensions.
    public func imageFiles() throws -> [URL] {
        let url = URL(fileURLWithPath: folderPath)
        let contents = try FileManager.default.contentsOfDirectory(
            at: url, includingPropertiesForKeys: nil
        )
        return contents.filter {
            Self.imageExtensions.contains($0.pathExtension.lowercased())
        }
    }

    /// Writes a progress line to stdout immediately.
    public func reportProgress(_ message: String) {
        let line = PluginOutputLine(type: "progress", message: message)
        if let data = try? JSONEncoder().encode(line),
           let string = String(data: data, encoding: .utf8)
        {
            io.writeLine(string)
        }
    }

    /// Writes an imageResult line to stdout immediately.
    public func reportImageResult(_ filename: String, success: Bool, error: String? = nil) {
        let line = PluginOutputLine(
            type: "imageResult", filename: filename, success: success, error: error
        )
        if let data = try? JSONEncoder().encode(line),
           let string = String(data: data, encoding: .utf8)
        {
            io.writeLine(string)
        }
    }
}
```

- [ ] **Step 5: Implement PluginResponse**

Create `swift/PiqleyPluginSDK/Response.swift`:
```swift
import Foundation
import PiqleyCore

/// The response returned from a plugin's ``PiqleyPlugin/handle(_:)`` method.
public struct PluginResponse: Sendable {
    /// Whether the plugin succeeded.
    public let success: Bool
    /// Error description if the plugin failed.
    public let error: String?
    /// Per-image state to write to this plugin's namespace.
    public let state: [String: PluginState]?

    public init(success: Bool, error: String? = nil, state: [String: PluginState]? = nil) {
        self.success = success
        self.error = error
        self.state = state
    }

    /// Convenience for a simple success with no state.
    public static let ok = PluginResponse(success: true)

    /// Converts to a PluginOutputLine for serialization.
    func toOutputLine() -> PluginOutputLine {
        let stateDict: [String: [String: JSONValue]]? = state?.mapValues { $0.toDict() }
        return PluginOutputLine(
            type: "result",
            success: success,
            error: error,
            state: stateDict
        )
    }
}
```

- [ ] **Step 6: Run tests to verify they pass**

Run: `swift test`
Expected: All tests pass

- [ ] **Step 7: Commit**

```bash
git add swift/PiqleyPluginSDK/Request.swift swift/PiqleyPluginSDK/Response.swift swift/Tests/RequestTests.swift swift/Tests/ResponseTests.swift
git commit -m "feat: add PluginRequest and PluginResponse with typed accessors"
```

---

### Task 7: PiqleyPlugin protocol and run() entry point

**Files:**
- Create: `swift/PiqleyPluginSDK/Plugin.swift`
- Create: `swift/Tests/PluginTests.swift`

- [ ] **Step 1: Write failing tests**

Create `swift/Tests/PluginTests.swift`:
```swift
import Testing
@testable import PiqleyPluginSDK
import PiqleyCore
import Foundation

struct SuccessPlugin: PiqleyPlugin {
    func handle(_ request: PluginRequest) async throws -> PluginResponse {
        request.reportProgress("Working...")
        return .ok
    }
}

struct StatePlugin: PiqleyPlugin {
    func handle(_ request: PluginRequest) async throws -> PluginResponse {
        var state: [String: PluginState] = [:]
        var imageState = PluginState()
        imageState.set("keywords", to: ["test"])
        state["IMG_001.jpg"] = imageState
        return PluginResponse(success: true, state: state)
    }
}

struct FailPlugin: PiqleyPlugin {
    func handle(_ request: PluginRequest) async throws -> PluginResponse {
        throw SDKError.payloadDecodeFailed("test error")
    }
}

@Test func pluginRunSuccess() async throws {
    let payload = PluginInputPayload(
        hook: "publish", folderPath: "/tmp/", pluginConfig: [:], secrets: [:],
        executionLogPath: "/log", dataPath: "/data", logPath: "/logs",
        dryRun: false, state: nil,
        pluginVersion: SemanticVersion(1, 0, 0), lastExecutedVersion: nil
    )
    let payloadData = try JSONEncoder().encode(payload)

    let output = CapturedIO()
    let exitCode = await SuccessPlugin().run(input: payloadData, io: output)

    #expect(exitCode == 0)
    let lines = output.lines
    // Should have progress line + result line
    #expect(lines.count == 2)

    let resultLine = try JSONDecoder().decode(PluginOutputLine.self, from: Data(lines.last!.utf8))
    #expect(resultLine.type == "result")
    #expect(resultLine.success == true)
}

@Test func pluginRunWithState() async throws {
    let payload = PluginInputPayload(
        hook: "publish", folderPath: "/tmp/", pluginConfig: [:], secrets: [:],
        executionLogPath: "/log", dataPath: "/data", logPath: "/logs",
        dryRun: false, state: nil,
        pluginVersion: SemanticVersion(1, 0, 0), lastExecutedVersion: nil
    )
    let payloadData = try JSONEncoder().encode(payload)

    let output = CapturedIO()
    let exitCode = await StatePlugin().run(input: payloadData, io: output)

    #expect(exitCode == 0)
    let resultLine = try JSONDecoder().decode(PluginOutputLine.self, from: Data(output.lines.last!.utf8))
    #expect(resultLine.state?["IMG_001.jpg"]?["keywords"] == .array([.string("test")]))
}

@Test func pluginRunHandlesThrow() async throws {
    let payload = PluginInputPayload(
        hook: "publish", folderPath: "/tmp/", pluginConfig: [:], secrets: [:],
        executionLogPath: "/log", dataPath: "/data", logPath: "/logs",
        dryRun: false, state: nil,
        pluginVersion: SemanticVersion(1, 0, 0), lastExecutedVersion: nil
    )
    let payloadData = try JSONEncoder().encode(payload)

    let output = CapturedIO()
    let exitCode = await FailPlugin().run(input: payloadData, io: output)

    #expect(exitCode == 1)
    let resultLine = try JSONDecoder().decode(PluginOutputLine.self, from: Data(output.lines.last!.utf8))
    #expect(resultLine.type == "result")
    #expect(resultLine.success == false)
    #expect(resultLine.error != nil)
}

@Test func pluginRunBadPayload() async {
    let output = CapturedIO()
    let exitCode = await SuccessPlugin().run(input: Data("not json".utf8), io: output)
    #expect(exitCode == 1)
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test 2>&1 | head -20`
Expected: FAIL

- [ ] **Step 3: Implement PiqleyPlugin protocol**

Create `swift/PiqleyPluginSDK/Plugin.swift`:
```swift
import Foundation
import PiqleyCore

/// The main protocol a plugin conforms to.
///
/// Implement ``handle(_:)`` to process a plugin invocation. Use ``run()``
/// from your `@main` entry point:
///
/// ```swift
/// @main struct MyPlugin: PiqleyPlugin {
///     func handle(_ request: PluginRequest) async throws -> PluginResponse {
///         // plugin logic
///         return .ok
///     }
///     static func main() async {
///         await MyPlugin().run()
///     }
/// }
/// ```
public protocol PiqleyPlugin: Sendable {
    /// Handle a plugin invocation from piqley.
    func handle(_ request: PluginRequest) async throws -> PluginResponse
}

extension PiqleyPlugin {
    /// Reads stdin, parses the request, calls handle(), writes response to stdout.
    ///
    /// Call this from your `@main static func main() async`.
    /// Returns the exit code (0 for success, 1 for failure).
    public func run() async {
        let inputData = FileHandle.standardInput.readDataToEndOfFile()
        let exitCode = await run(input: inputData, io: StdoutIO())
        exit(Int32(exitCode))
    }

    /// Internal run with injectable IO for testing.
    func run(input: Data, io: PluginIO) async -> Int {
        let payload: PluginInputPayload
        do {
            payload = try JSONDecoder().decode(PluginInputPayload.self, from: input)
        } catch {
            let errorLine = PluginOutputLine(
                type: "result", success: false, error: "Failed to decode input: \(error)"
            )
            if let data = try? JSONEncoder().encode(errorLine),
               let string = String(data: data, encoding: .utf8)
            {
                io.writeLine(string)
            }
            return 1
        }

        let request = PluginRequest(payload: payload, io: io)

        do {
            let response = try await handle(request)
            let outputLine = response.toOutputLine()
            if let data = try? JSONEncoder().encode(outputLine),
               let string = String(data: data, encoding: .utf8)
            {
                io.writeLine(string)
            }
            return response.success ? 0 : 1
        } catch {
            let errorLine = PluginOutputLine(
                type: "result", success: false, error: "\(error)"
            )
            if let data = try? JSONEncoder().encode(errorLine),
               let string = String(data: data, encoding: .utf8)
            {
                io.writeLine(string)
            }
            return 1
        }
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test`
Expected: All tests pass

- [ ] **Step 5: Commit**

```bash
git add swift/PiqleyPluginSDK/Plugin.swift swift/Tests/PluginTests.swift
git commit -m "feat: add PiqleyPlugin protocol with run() entry point"
```

---

### Task 8: Mock factory for testing

**Files:**
- Create: `swift/Tests/MockTests.swift`

The mock factory is an extension on `PluginRequest`. `CapturedOutput` wraps `CapturedIO`.

- [ ] **Step 1: Write failing tests**

Create `swift/Tests/MockTests.swift`:
```swift
import Testing
@testable import PiqleyPluginSDK
import PiqleyCore
import Foundation

@Test func mockFactoryDefaults() {
    let (request, output) = PluginRequest.mock()
    #expect(request.hook == .preProcess)
    #expect(request.folderPath == "/tmp/test")
    #expect(request.dryRun == false)
    #expect(request.state.imageNames.isEmpty)
    #expect(output.progressMessages.isEmpty)
    #expect(output.imageResults.isEmpty)
}

@Test func mockFactoryCustomValues() {
    let (request, _) = PluginRequest.mock(
        hook: .publish,
        folderPath: "/custom/path",
        pluginConfig: ["url": .string("https://example.com")],
        secrets: ["key": "value"],
        dryRun: true,
        pluginVersion: SemanticVersion(2, 0, 0),
        lastExecutedVersion: SemanticVersion(1, 0, 0)
    )
    #expect(request.hook == .publish)
    #expect(request.folderPath == "/custom/path")
    #expect(request.pluginConfig["url"] == .string("https://example.com"))
    #expect(request.secrets["key"] == "value")
    #expect(request.dryRun == true)
    #expect(request.pluginVersion == SemanticVersion(2, 0, 0))
    #expect(request.lastExecutedVersion == SemanticVersion(1, 0, 0))
}

@Test func mockCapturesProgress() {
    let (request, output) = PluginRequest.mock()
    request.reportProgress("Step 1")
    request.reportProgress("Step 2")
    #expect(output.progressMessages == ["Step 1", "Step 2"])
}

@Test func mockCapturesImageResults() {
    let (request, output) = PluginRequest.mock()
    request.reportImageResult("photo.jpg", success: true)
    request.reportImageResult("fail.jpg", success: false, error: "Timeout")
    #expect(output.imageResults.count == 2)
    #expect(output.imageResults[0].filename == "photo.jpg")
    #expect(output.imageResults[0].success == true)
    #expect(output.imageResults[1].filename == "fail.jpg")
    #expect(output.imageResults[1].success == false)
    #expect(output.imageResults[1].error == "Timeout")
}

@Test func mockWithState() {
    let state = ResolvedState(raw: [
        "IMG_001.jpg": ["original": ["TIFF:Model": .string("Canon")]],
    ])
    let (request, _) = PluginRequest.mock(state: state)
    #expect(request.state["IMG_001.jpg"]?.original.string(.model) == "Canon")
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test 2>&1 | head -20`
Expected: FAIL

- [ ] **Step 3: Add mock factory and CapturedOutput to Request.swift**

Add to `swift/PiqleyPluginSDK/Request.swift`:
```swift
// MARK: - Test Support

/// Result of a captured image result report.
public struct ImageResult: Sendable {
    public let filename: String
    public let success: Bool
    public let error: String?
}

/// Captures output from a mock plugin request for test assertions.
public final class CapturedOutput: Sendable {
    private let io: CapturedIO

    init(io: CapturedIO) {
        self.io = io
    }

    /// All progress messages reported.
    public var progressMessages: [String] {
        io.lines.compactMap { line in
            guard let data = line.data(using: .utf8),
                  let obj = try? JSONDecoder().decode(PluginOutputLine.self, from: data),
                  obj.type == "progress"
            else { return nil }
            return obj.message
        }
    }

    /// All image results reported.
    public var imageResults: [ImageResult] {
        io.lines.compactMap { line in
            guard let data = line.data(using: .utf8),
                  let obj = try? JSONDecoder().decode(PluginOutputLine.self, from: data),
                  obj.type == "imageResult",
                  let filename = obj.filename,
                  let success = obj.success
            else { return nil }
            return ImageResult(filename: filename, success: success, error: obj.error)
        }
    }

    /// All raw output lines.
    public var allLines: [String] {
        io.lines
    }
}

extension PluginRequest {
    /// Create a request for testing. No real stdin/stdout involved.
    ///
    /// Returns a tuple of the request and a ``CapturedOutput`` to assert against:
    /// ```swift
    /// let (request, output) = PluginRequest.mock(hook: .publish)
    /// let response = try await myPlugin.handle(request)
    /// #expect(response.success)
    /// #expect(output.progressMessages.count == 2)
    /// ```
    public static func mock(
        hook: Hook = .preProcess,
        folderPath: String = "/tmp/test",
        pluginConfig: [String: JSONValue] = [:],
        secrets: [String: String] = [:],
        executionLogPath: String = "/tmp/test/log.jsonl",
        dataPath: String = "/tmp/test/data",
        logPath: String = "/tmp/test/logs",
        dryRun: Bool = false,
        state: ResolvedState = .empty,
        pluginVersion: SemanticVersion = SemanticVersion(1, 0, 0),
        lastExecutedVersion: SemanticVersion? = nil
    ) -> (request: PluginRequest, output: CapturedOutput) {
        let io = CapturedIO()
        let payload = PluginInputPayload(
            hook: hook.rawValue,
            folderPath: folderPath,
            pluginConfig: pluginConfig,
            secrets: secrets,
            executionLogPath: executionLogPath,
            dataPath: dataPath,
            logPath: logPath,
            dryRun: dryRun,
            state: state.rawDict,
            pluginVersion: pluginVersion,
            lastExecutedVersion: lastExecutedVersion
        )
        let request = PluginRequest(payload: payload, io: io)
        return (request, CapturedOutput(io: io))
    }
}
```

Note: This requires adding a `rawDict` accessor to `ResolvedState`:

Add to `swift/PiqleyPluginSDK/State/ResolvedState.swift`:
```swift
/// Internal accessor for the raw state dictionary.
var rawDict: [String: [String: [String: JSONValue]]]? {
    raw.isEmpty ? nil : raw
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test`
Expected: All tests pass

- [ ] **Step 5: Commit**

```bash
git add swift/PiqleyPluginSDK/Request.swift swift/PiqleyPluginSDK/State/ResolvedState.swift swift/Tests/MockTests.swift
git commit -m "feat: add mock factory and CapturedOutput for testing"
```

---

### Task 9: MatchField and MatchPattern

**Files:**
- Create: `swift/PiqleyPluginSDK/Builders/MatchField.swift`
- Create: `swift/PiqleyPluginSDK/Builders/MatchPattern.swift`
- Create: `swift/Tests/MatchFieldTests.swift`

- [ ] **Step 1: Write failing tests**

Create `swift/Tests/MatchFieldTests.swift`:
```swift
import Testing
@testable import PiqleyPluginSDK
import PiqleyCore

enum HashtagKeys: String, StateKey {
    static let namespace = "hashtag"
    case tags
    case caption
}

@Test func matchFieldOriginal() {
    let field = MatchField.original(.model)
    #expect(field.encoded == "original:TIFF:Model")
}

@Test func matchFieldOriginalKeywords() {
    let field = MatchField.original(.keywords)
    #expect(field.encoded == "original:IPTC:Keywords")
}

@Test func matchFieldDependencyTyped() {
    let field = MatchField.dependency(HashtagKeys.tags)
    #expect(field.encoded == "hashtag:tags")
}

@Test func matchFieldDependencyString() {
    let field = MatchField.dependency("other-plugin", key: "some-field")
    #expect(field.encoded == "other-plugin:some-field")
}

@Test func matchPatternExact() {
    let pattern = MatchPattern.exact("Canon EOS R5")
    #expect(pattern.encoded == "Canon EOS R5")
}

@Test func matchPatternGlob() {
    let pattern = MatchPattern.glob("*a7r*")
    #expect(pattern.encoded == "glob:*a7r*")
}

@Test func matchPatternRegex() {
    let pattern = MatchPattern.regex(".*a7r.*")
    #expect(pattern.encoded == "regex:.*a7r.*")
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test 2>&1 | head -20`
Expected: FAIL

- [ ] **Step 3: Implement MatchField and MatchPattern**

Create `swift/PiqleyPluginSDK/Builders/MatchField.swift`:
```swift
import PiqleyCore

/// A typed reference to a state field for use in rule matching.
///
/// Use static factories to construct:
/// ```swift
/// .original(.model)                    // "original:TIFF:Model"
/// .dependency(HashtagKeys.tags)        // "hashtag:tags"
/// .dependency("plugin", key: "field")  // "plugin:field"
/// ```
public struct MatchField: Sendable {
    /// The wire-format encoded field string ("namespace:field").
    public let encoded: String

    /// Match against core-extracted image metadata.
    public static func original(_ key: ImageMetadataKey) -> MatchField {
        MatchField(encoded: "\(ImageMetadataKey.namespace):\(key.rawValue)")
    }

    /// Match against a dependency's state using a typed key.
    public static func dependency<K: StateKey>(_ key: K) -> MatchField {
        MatchField(encoded: "\(K.namespace):\(key.rawValue)")
    }

    /// Match against a dependency's state with raw strings.
    public static func dependency(_ plugin: String, key: String) -> MatchField {
        MatchField(encoded: "\(plugin):\(key)")
    }
}
```

Create `swift/PiqleyPluginSDK/Builders/MatchPattern.swift`:
```swift
import PiqleyCore

/// A typed match pattern that encodes to the wire format.
///
/// ```swift
/// .exact("Canon EOS R5")    // bare string, case-insensitive
/// .glob("*a7r*")            // fnmatch-style glob
/// .regex(".*a7r.*")         // regular expression
/// ```
public enum MatchPattern: Sendable {
    /// Bare string — exact match, case-insensitive.
    case exact(String)
    /// fnmatch-style glob pattern.
    case glob(String)
    /// Regular expression pattern.
    case regex(String)

    /// The wire-format encoded pattern string.
    public var encoded: String {
        switch self {
        case let .exact(value): value
        case let .glob(value): "glob:\(value)"
        case let .regex(value): "regex:\(value)"
        }
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test`
Expected: All tests pass

- [ ] **Step 5: Commit**

```bash
git add swift/PiqleyPluginSDK/Builders/ swift/Tests/MatchFieldTests.swift
git commit -m "feat: add MatchField and MatchPattern for typed rule construction"
```

---

### Task 10: Manifest builder DSL

**Files:**
- Create: `swift/PiqleyPluginSDK/Builders/ManifestBuilder.swift`
- Create: `swift/Tests/ManifestBuilderTests.swift`

- [ ] **Step 1: Write failing tests**

Create `swift/Tests/ManifestBuilderTests.swift`:
```swift
import Testing
@testable import PiqleyPluginSDK
import PiqleyCore
import Foundation

@Test func buildMinimalManifest() throws {
    let manifest = try buildManifest {
        Name("my-plugin")
        ProtocolVersion("1")
        PluginVersion("1.0.0")
        Hooks {
            HookEntry(.publish, command: "./bin/publish", protocol: .json)
        }
    }
    #expect(manifest.name == "my-plugin")
    #expect(manifest.pluginProtocolVersion == "1")
    #expect(manifest.pluginVersion == SemanticVersion(1, 0, 0))
    #expect(manifest.hooks["publish"]?.command == "./bin/publish")
    #expect(manifest.hooks["publish"]?.pluginProtocol == .json)
}

@Test func buildFullManifest() throws {
    let manifest = try buildManifest {
        Name("full-plugin")
        ProtocolVersion("1")
        PluginVersion("2.1.0")
        ConfigEntries {
            Value("url", type: .string)
            Value("quality", type: .int, default: 80)
            Secret("api-key", type: .string)
        }
        Setup(command: "./bin/setup", args: ["--init"])
        Dependencies {
            ImageMetadataKey.self
            HashtagKeys.self
        }
        Hooks {
            HookEntry(.publish, command: "./bin/publish", protocol: .json)
            HookEntry(.postProcess, command: "./bin/process", protocol: .json, timeout: 60)
            HookEntry(.preProcess)
        }
    }
    #expect(manifest.config.count == 3)
    #expect(manifest.setup?.command == "./bin/setup")
    #expect(manifest.dependencies == ["original", "hashtag"])
    #expect(manifest.hooks.count == 3)
    #expect(manifest.hooks["pre-process"]?.command == nil)
}

@Test func buildManifestRulesOnlyHook() throws {
    let manifest = try buildManifest {
        Name("rules-only")
        ProtocolVersion("1")
        PluginVersion("1.0.0")
        Hooks {
            HookEntry(.preProcess)
        }
    }
    #expect(manifest.hooks["pre-process"]?.command == nil)
}

@Test func buildManifestStringDependency() throws {
    let manifest = try buildManifest {
        Name("test")
        ProtocolVersion("1")
        PluginVersion("1.0.0")
        Dependencies {
            "some-plugin"
        }
        Hooks {
            HookEntry(.publish, command: "./run")
        }
    }
    #expect(manifest.dependencies == ["some-plugin"])
}

@Test func manifestWriteValidation() throws {
    // batchProxy with json protocol should fail validation on write
    let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tempDir) }

    let manifest = PluginManifest(
        name: "bad",
        pluginProtocolVersion: "1",
        pluginVersion: SemanticVersion(1, 0, 0),
        hooks: ["publish": HookConfig(
            command: "./run",
            pluginProtocol: .json,
            batchProxy: BatchProxyConfig()
        )]
    )

    #expect(throws: SDKError.self) {
        try manifest.writeValidated(to: tempDir)
    }
}

@Test func manifestWriteSuccess() throws {
    let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tempDir) }

    let manifest = try buildManifest {
        Name("write-test")
        ProtocolVersion("1")
        PluginVersion("1.0.0")
        Hooks {
            HookEntry(.publish, command: "./run", protocol: .json)
        }
    }
    try manifest.writeValidated(to: tempDir)

    let manifestURL = tempDir.appendingPathComponent("manifest.json")
    #expect(FileManager.default.fileExists(atPath: manifestURL.path))

    let data = try Data(contentsOf: manifestURL)
    let decoded = try JSONDecoder().decode(PluginManifest.self, from: data)
    #expect(decoded.name == "write-test")
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test 2>&1 | head -20`
Expected: FAIL

- [ ] **Step 3: Implement ManifestBuilder**

Create `swift/PiqleyPluginSDK/Builders/ManifestBuilder.swift`:
```swift
import Foundation
import PiqleyCore

// MARK: - Builder Components

/// Sets the plugin name.
public struct Name: Sendable {
    let value: String
    public init(_ value: String) { self.value = value }
}

/// Sets the plugin protocol version.
public struct ProtocolVersion: Sendable {
    let value: String
    public init(_ value: String) { self.value = value }
}

/// Sets the plugin version.
public struct PluginVersion: Sendable {
    let value: SemanticVersion
    public init(_ string: String) {
        self.value = try! SemanticVersion(string)
    }
}

/// Defines config entries for the manifest.
public struct ConfigEntries: Sendable {
    let entries: [ConfigEntry]
    public init(@ConfigEntriesBuilder _ builder: () -> [ConfigEntry]) {
        self.entries = builder()
    }
}

/// A config value entry.
public struct Value: Sendable {
    let entry: ConfigEntry
    public init(_ key: String, type: ConfigValueType, default defaultValue: JSONValue = .null) {
        self.entry = .value(key: key, type: type, value: defaultValue)
    }
}

/// A config secret entry.
public struct Secret: Sendable {
    let entry: ConfigEntry
    public init(_ secretKey: String, type: ConfigValueType) {
        self.entry = .secret(secretKey: secretKey, type: type)
    }
}

/// Defines the setup command.
public struct Setup: Sendable {
    let config: SetupConfig
    public init(command: String, args: [String] = []) {
        self.config = SetupConfig(command: command, args: args)
    }
}

/// Defines plugin dependencies.
public struct Dependencies: Sendable {
    let names: [String]
    public init(@DependencyBuilder _ builder: () -> [String]) {
        self.names = builder()
    }
}

/// Defines plugin hooks.
public struct Hooks: Sendable {
    let entries: [(String, HookConfig)]
    public init(@HookEntriesBuilder _ builder: () -> [(String, HookConfig)]) {
        self.entries = builder()
    }
}

/// A single hook entry in the builder.
public struct HookEntry: Sendable {
    let hookName: String
    let config: HookConfig

    public init(
        _ hook: Hook,
        command: String? = nil,
        protocol proto: PluginProtocol? = nil,
        timeout: Int? = nil,
        args: [String] = [],
        successCodes: [Int32]? = nil,
        warningCodes: [Int32]? = nil,
        criticalCodes: [Int32]? = nil,
        batchProxy: BatchProxyConfig? = nil
    ) {
        self.hookName = hook.rawValue
        self.config = HookConfig(
            command: command,
            args: args,
            timeout: timeout,
            pluginProtocol: proto,
            successCodes: successCodes,
            warningCodes: warningCodes,
            criticalCodes: criticalCodes,
            batchProxy: batchProxy
        )
    }
}

// MARK: - Result Builders

@resultBuilder
public struct ConfigEntriesBuilder {
    public static func buildBlock(_ components: any ConfigEntryConvertible...) -> [ConfigEntry] {
        components.map { $0.toConfigEntry() }
    }
}

public protocol ConfigEntryConvertible {
    func toConfigEntry() -> ConfigEntry
}

extension Value: ConfigEntryConvertible {
    public func toConfigEntry() -> ConfigEntry { entry }
}

extension Secret: ConfigEntryConvertible {
    public func toConfigEntry() -> ConfigEntry { entry }
}

@resultBuilder
public struct DependencyBuilder {
    public static func buildBlock(_ components: any DependencyConvertible...) -> [String] {
        components.map { $0.toDependencyName() }
    }
}

public protocol DependencyConvertible {
    func toDependencyName() -> String
}

extension String: DependencyConvertible {
    public func toDependencyName() -> String { self }
}

/// Allow StateKey metatypes as dependencies.
public struct StateKeyDependency<K: StateKey>: DependencyConvertible {
    public func toDependencyName() -> String { K.namespace }
}

extension StateKey {
    /// Use `MyKeys.self` in a Dependencies block to declare a dependency.
    public static var dependency: StateKeyDependency<Self> {
        StateKeyDependency()
    }
}

/// Allows `ImageMetadataKey.self` and similar in Dependencies blocks.
extension (any StateKey.Type): DependencyConvertible {
    public func toDependencyName() -> String {
        // Access the static namespace through the metatype
        (self as any StateKey.Type).namespace
    }
}

@resultBuilder
public struct HookEntriesBuilder {
    public static func buildBlock(_ components: HookEntry...) -> [(String, HookConfig)] {
        components.map { ($0.hookName, $0.config) }
    }
}

// MARK: - Manifest Component Protocol

protocol ManifestComponent {}
extension Name: ManifestComponent {}
extension ProtocolVersion: ManifestComponent {}
extension PluginVersion: ManifestComponent {}
extension ConfigEntries: ManifestComponent {}
extension Setup: ManifestComponent {}
extension Dependencies: ManifestComponent {}
extension Hooks: ManifestComponent {}

@resultBuilder
public struct ManifestComponentBuilder {
    public static func buildBlock(_ components: ManifestComponent...) -> [ManifestComponent] {
        components
    }
}

// MARK: - Build Function

/// Build a PluginManifest using the DSL.
///
/// ```swift
/// let manifest = try buildManifest {
///     Name("my-plugin")
///     ProtocolVersion("1")
///     PluginVersion("1.0.0")
///     Hooks {
///         HookEntry(.publish, command: "./bin/publish", protocol: .json)
///     }
/// }
/// ```
public func buildManifest(@ManifestComponentBuilder _ builder: () -> [ManifestComponent]) throws -> PluginManifest {
    let components = builder()
    var name: String?
    var protocolVersion: String?
    var pluginVersion: SemanticVersion?
    var config: [ConfigEntry] = []
    var setup: SetupConfig?
    var dependencies: [String]?
    var hooks: [String: HookConfig] = [:]

    for component in components {
        switch component {
        case let n as Name: name = n.value
        case let pv as ProtocolVersion: protocolVersion = pv.value
        case let v as PluginVersion: pluginVersion = v.value
        case let c as ConfigEntries: config = c.entries
        case let s as Setup: setup = s.config
        case let d as Dependencies: dependencies = d.names
        case let h as Hooks:
            for (hookName, hookConfig) in h.entries {
                hooks[hookName] = hookConfig
            }
        default: break
        }
    }

    guard let name else {
        throw SDKError.manifestValidationFailed(["Name is required"])
    }
    guard let protocolVersion else {
        throw SDKError.manifestValidationFailed(["ProtocolVersion is required"])
    }

    return PluginManifest(
        name: name,
        pluginProtocolVersion: protocolVersion,
        pluginVersion: pluginVersion,
        config: config,
        setup: setup,
        dependencies: dependencies,
        hooks: hooks
    )
}

// MARK: - Write Extension

extension PluginManifest {
    /// Validates and writes the manifest to a directory as `manifest.json`.
    ///
    /// Runs ``ManifestValidator`` before writing. Throws ``SDKError/manifestValidationFailed(_:)``
    /// if validation fails.
    public func writeValidated(to directory: URL) throws {
        let errors = ManifestValidator.validate(self)
        guard errors.isEmpty else {
            throw SDKError.manifestValidationFailed(errors)
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(self)
        let url = directory.appendingPathComponent("manifest.json")
        try data.write(to: url)
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test`
Expected: All tests pass

Note: The `StateKey.Type` as `DependencyConvertible` may need adjustment depending on Swift 6 metatype conformance rules. If it doesn't compile, use an alternative approach where `Dependencies` accepts `StateKeyDependency` wrapper types directly:
```swift
Dependencies {
    ImageMetadataKey.dependency
    HashtagKeys.dependency
}
```
And update tests accordingly.

- [ ] **Step 5: Commit**

```bash
git add swift/PiqleyPluginSDK/Builders/ManifestBuilder.swift swift/Tests/ManifestBuilderTests.swift
git commit -m "feat: add manifest builder DSL with validation"
```

---

### Task 11: Config builder DSL

**Files:**
- Create: `swift/PiqleyPluginSDK/Builders/ConfigBuilder.swift`
- Create: `swift/Tests/ConfigBuilderTests.swift`

- [ ] **Step 1: Write failing tests**

Create `swift/Tests/ConfigBuilderTests.swift`:
```swift
import Testing
@testable import PiqleyPluginSDK
import PiqleyCore
import Foundation

@Test func buildConfigWithValues() throws {
    let config = buildConfig {
        ConfigValues {
            ConfigValue("url", .string("https://example.com"))
            ConfigValue("quality", 85)
        }
    }
    #expect(config.values["url"] == .string("https://example.com"))
    #expect(config.values["quality"] == .number(85))
}

@Test func buildConfigWithRules() throws {
    let config = buildConfig {
        ConfigRules {
            ConfigRule(
                match: .field(.original(.model), pattern: .regex(".*a7r.*")),
                emit: .keywords(["Sony", "A7R Life"])
            )
            ConfigRule(
                match: .field(.dependency(HashtagKeys.tags), pattern: .glob("*Cat*")),
                hook: .preProcess,
                emit: .values(field: "keywords", ["Cat Photography"])
            )
        }
    }
    #expect(config.rules.count == 2)
    #expect(config.rules[0].match.field == "original:TIFF:Model")
    #expect(config.rules[0].match.pattern == "regex:.*a7r.*")
    #expect(config.rules[0].emit.values == ["Sony", "A7R Life"])
    #expect(config.rules[1].match.hook == "pre-process")
    #expect(config.rules[1].emit.field == "keywords")
}

@Test func buildConfigWithValuesAndRules() throws {
    let config = buildConfig {
        ConfigValues {
            ConfigValue("url", .string("https://example.com"))
        }
        ConfigRules {
            ConfigRule(
                match: .field(.original(.model), pattern: .exact("Canon EOS R5")),
                emit: .keywords(["Canon"])
            )
        }
    }
    #expect(config.values.count == 1)
    #expect(config.rules.count == 1)
}

@Test func ruleEmitKeywordsDefault() {
    let emit = RuleEmit.keywords(["a", "b"])
    #expect(emit.toEmitConfig().field == "keywords")
    #expect(emit.toEmitConfig().values == ["a", "b"])
}

@Test func ruleEmitCustomField() {
    let emit = RuleEmit.values(field: "tags", ["x", "y"])
    #expect(emit.toEmitConfig().field == "tags")
    #expect(emit.toEmitConfig().values == ["x", "y"])
}

@Test func configWriteSuccess() throws {
    let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tempDir) }

    let config = buildConfig {
        ConfigValues {
            ConfigValue("url", .string("https://example.com"))
        }
    }
    try config.write(to: tempDir)

    let configURL = tempDir.appendingPathComponent("config.json")
    #expect(FileManager.default.fileExists(atPath: configURL.path))

    let data = try Data(contentsOf: configURL)
    let decoded = try JSONDecoder().decode(PluginConfig.self, from: data)
    #expect(decoded.values["url"] == .string("https://example.com"))
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test 2>&1 | head -20`
Expected: FAIL

- [ ] **Step 3: Implement ConfigBuilder**

Create `swift/PiqleyPluginSDK/Builders/ConfigBuilder.swift`:
```swift
import Foundation
import PiqleyCore

// MARK: - Typed Rule Match

/// Typed match specification for a rule.
public struct RuleMatch: Sendable {
    let matchConfig: MatchConfig

    /// Match a state field against a pattern.
    public static func field(_ field: MatchField, pattern: MatchPattern) -> RuleMatch {
        RuleMatch(matchConfig: MatchConfig(field: field.encoded, pattern: pattern.encoded))
    }
}

/// Typed emit specification for a rule.
public enum RuleEmit: Sendable {
    /// Emit to the default "keywords" field.
    case keywords([String])
    /// Emit to a named field.
    case values(field: String, [String])

    func toEmitConfig() -> EmitConfig {
        switch self {
        case let .keywords(values):
            EmitConfig(field: "keywords", values: values)
        case let .values(field, values):
            EmitConfig(field: field, values: values)
        }
    }
}

// MARK: - Config Builder Components

/// A config value entry in the builder.
public struct ConfigValue: Sendable {
    let key: String
    let value: JSONValue
    public init(_ key: String, _ value: JSONValue) {
        self.key = key
        self.value = value
    }
}

/// A typed rule entry in the builder.
public struct ConfigRule: Sendable {
    let rule: Rule

    public init(match: RuleMatch, hook: Hook? = nil, emit: RuleEmit) {
        let emitConfig = emit.toEmitConfig()
        var matchConfig = match.matchConfig
        if let hook {
            matchConfig = MatchConfig(hook: hook.rawValue, field: matchConfig.field, pattern: matchConfig.pattern)
        }
        self.rule = Rule(match: matchConfig, emit: emitConfig)
    }
}

/// Values block.
public struct ConfigValues: Sendable {
    let values: [ConfigValue]
    public init(@ConfigValuesBuilder _ builder: () -> [ConfigValue]) {
        self.values = builder()
    }
}

/// Rules block.
public struct ConfigRules: Sendable {
    let rules: [ConfigRule]
    public init(@ConfigRulesBuilder _ builder: () -> [ConfigRule]) {
        self.rules = builder()
    }
}

// MARK: - Result Builders

@resultBuilder
public struct ConfigValuesBuilder {
    public static func buildBlock(_ components: ConfigValue...) -> [ConfigValue] {
        components
    }
}

@resultBuilder
public struct ConfigRulesBuilder {
    public static func buildBlock(_ components: ConfigRule...) -> [ConfigRule] {
        components
    }
}

protocol ConfigComponent {}
extension ConfigValues: ConfigComponent {}
extension ConfigRules: ConfigComponent {}

@resultBuilder
public struct ConfigComponentBuilder {
    public static func buildBlock(_ components: ConfigComponent...) -> [ConfigComponent] {
        components
    }
}

// MARK: - Build Function

/// Build a PluginConfig using the DSL.
///
/// ```swift
/// let config = buildConfig {
///     ConfigValues {
///         ConfigValue("url", .string("https://example.com"))
///     }
///     ConfigRules {
///         ConfigRule(
///             match: .field(.original(.model), pattern: .regex(".*a7r.*")),
///             emit: .keywords(["Sony"])
///         )
///     }
/// }
/// ```
public func buildConfig(@ConfigComponentBuilder _ builder: () -> [ConfigComponent]) -> PluginConfig {
    let components = builder()
    var values: [String: JSONValue] = [:]
    var rules: [Rule] = []

    for component in components {
        switch component {
        case let v as ConfigValues:
            for entry in v.values {
                values[entry.key] = entry.value
            }
        case let r as ConfigRules:
            rules = r.rules.map { $0.rule }
        default: break
        }
    }

    return PluginConfig(values: values, rules: rules)
}

// MARK: - Write Extension

extension PluginConfig {
    /// Writes the config to a directory as `config.json`.
    public func write(to directory: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(self)
        let url = directory.appendingPathComponent("config.json")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try data.write(to: url)
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test`
Expected: All tests pass

- [ ] **Step 5: Commit**

```bash
git add swift/PiqleyPluginSDK/Builders/ConfigBuilder.swift swift/Tests/ConfigBuilderTests.swift
git commit -m "feat: add config builder DSL with typed rule construction"
```

---

### Task 12: ExecutionLog

**Files:**
- Create: `swift/PiqleyPluginSDK/ExecutionLog.swift`
- Create: `swift/Tests/ExecutionLogTests.swift`

- [ ] **Step 1: Write failing tests**

Create `swift/Tests/ExecutionLogTests.swift`:
```swift
import Testing
@testable import PiqleyPluginSDK
import PiqleyCore
import Foundation

@Test func executionLogAppendAndQuery() throws {
    let tempFile = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathExtension("jsonl")
    defer { try? FileManager.default.removeItem(at: tempFile) }

    let log = try ExecutionLog(path: tempFile.path)
    let entry = ExecutionLogEntry(filename: "photo.jpg", hook: .publish, success: true)
    try log.append(entry)

    let entries = try log.entries(for: "photo.jpg")
    #expect(entries.count == 1)
    #expect(entries[0].filename == "photo.jpg")
    #expect(entries[0].hook == .publish)
    #expect(entries[0].success == true)
    #expect(entries[0].metadata == nil)
}

@Test func executionLogContains() throws {
    let tempFile = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathExtension("jsonl")
    defer { try? FileManager.default.removeItem(at: tempFile) }

    let log = try ExecutionLog(path: tempFile.path)
    try log.append(ExecutionLogEntry(filename: "photo.jpg", hook: .publish, success: true))

    #expect(try log.contains(filename: "photo.jpg") == true)
    #expect(try log.contains(filename: "other.jpg") == false)
}

@Test func executionLogMultipleEntries() throws {
    let tempFile = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathExtension("jsonl")
    defer { try? FileManager.default.removeItem(at: tempFile) }

    let log = try ExecutionLog(path: tempFile.path)
    try log.append(ExecutionLogEntry(filename: "a.jpg", hook: .publish, success: true))
    try log.append(ExecutionLogEntry(filename: "b.jpg", hook: .postProcess, success: false))
    try log.append(ExecutionLogEntry(filename: "a.jpg", hook: .postPublish, success: true))

    let aEntries = try log.entries(for: "a.jpg")
    #expect(aEntries.count == 2)

    let bEntries = try log.entries(for: "b.jpg")
    #expect(bEntries.count == 1)
    #expect(bEntries[0].success == false)
}

@Test func executionLogWithMetadata() throws {
    let tempFile = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathExtension("jsonl")
    defer { try? FileManager.default.removeItem(at: tempFile) }

    let log = try ExecutionLog(path: tempFile.path)
    let entry = ExecutionLogEntry(
        filename: "photo.jpg",
        hook: .publish,
        success: true,
        metadata: ["url": .string("https://example.com/photo.jpg")]
    )
    try log.append(entry)

    let entries = try log.entries(for: "photo.jpg")
    #expect(entries[0].metadata?["url"] == .string("https://example.com/photo.jpg"))
}

@Test func executionLogCreatesFileIfMissing() throws {
    let tempFile = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathExtension("jsonl")
    defer { try? FileManager.default.removeItem(at: tempFile) }

    #expect(!FileManager.default.fileExists(atPath: tempFile.path))

    let log = try ExecutionLog(path: tempFile.path)
    try log.append(ExecutionLogEntry(filename: "test.jpg", hook: .publish, success: true))

    #expect(FileManager.default.fileExists(atPath: tempFile.path))
}

@Test func executionLogTimestampIsSet() throws {
    let tempFile = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathExtension("jsonl")
    defer { try? FileManager.default.removeItem(at: tempFile) }

    let before = Date()
    let log = try ExecutionLog(path: tempFile.path)
    try log.append(ExecutionLogEntry(filename: "test.jpg", hook: .publish, success: true))
    let after = Date()

    let entries = try log.entries(for: "test.jpg")
    #expect(entries[0].timestamp >= before)
    #expect(entries[0].timestamp <= after)
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test 2>&1 | head -20`
Expected: FAIL

- [ ] **Step 3: Implement ExecutionLog**

Create `swift/PiqleyPluginSDK/ExecutionLog.swift`:
```swift
import Foundation
import PiqleyCore

/// A single entry in the execution log.
public struct ExecutionLogEntry: Codable, Sendable {
    /// Image filename.
    public let filename: String
    /// Timestamp of the entry (set automatically on append).
    public let timestamp: Date
    /// Which hook stage this was logged from.
    public let hook: Hook
    /// Whether processing succeeded.
    public let success: Bool
    /// Optional metadata associated with this entry.
    public let metadata: [String: JSONValue]?

    /// Create an entry. Timestamp is set to now.
    public init(
        filename: String,
        hook: Hook,
        success: Bool,
        metadata: [String: JSONValue]? = nil
    ) {
        self.filename = filename
        self.timestamp = Date()
        self.hook = hook
        self.success = success
        self.metadata = metadata
    }
}

/// Helper for reading and writing the plugin's JSONL execution log.
///
/// Each line in the log is a JSON-encoded ``ExecutionLogEntry``.
/// Use this for deduplication across pipeline runs.
///
/// ```swift
/// let log = try ExecutionLog(path: request.executionLogPath)
/// if try !log.contains(filename: "photo.jpg") {
///     // process photo.jpg
///     try log.append(ExecutionLogEntry(filename: "photo.jpg", hook: request.hook, success: true))
/// }
/// ```
public struct ExecutionLog: Sendable {
    private let path: String
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    /// Opens or creates the log at the given path.
    public init(path: String) throws {
        self.path = path
        self.encoder = JSONEncoder()
        self.encoder.dateEncodingStrategy = .iso8601
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601
    }

    /// Appends an entry to the log.
    public func append(_ entry: ExecutionLogEntry) throws {
        let data = try encoder.encode(entry)
        guard var line = String(data: data, encoding: .utf8) else {
            return
        }
        line += "\n"

        let fileURL = URL(fileURLWithPath: path)
        if FileManager.default.fileExists(atPath: path) {
            let handle = try FileHandle(forWritingTo: fileURL)
            defer { handle.closeFile() }
            handle.seekToEndOfFile()
            handle.write(Data(line.utf8))
        } else {
            // Create parent directory if needed
            let parent = fileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
            try Data(line.utf8).write(to: fileURL)
        }
    }

    /// Returns all entries matching the given filename.
    public func entries(for filename: String) throws -> [ExecutionLogEntry] {
        try allEntries().filter { $0.filename == filename }
    }

    /// Returns true if the filename has been logged previously.
    public func contains(filename: String) throws -> Bool {
        try allEntries().contains { $0.filename == filename }
    }

    private func allEntries() throws -> [ExecutionLogEntry] {
        let fileURL = URL(fileURLWithPath: path)
        guard FileManager.default.fileExists(atPath: path) else { return [] }
        let contents = try String(contentsOf: fileURL, encoding: .utf8)
        return contents
            .split(separator: "\n")
            .compactMap { line in
                guard let data = line.data(using: .utf8) else { return nil }
                return try? decoder.decode(ExecutionLogEntry.self, from: data)
            }
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test`
Expected: All tests pass

- [ ] **Step 5: Commit**

```bash
git add swift/PiqleyPluginSDK/ExecutionLog.swift swift/Tests/ExecutionLogTests.swift
git commit -m "feat: add ExecutionLog JSONL helper for deduplication"
```

---

### Task 13: Cleanup and final verification

- [ ] **Step 1: Remove placeholder test**

Remove the initial `sdkImportsCore` placeholder test from `swift/Tests/PiqleyPluginSDKTests.swift` if it's no longer needed, or keep it as a smoke test.

- [ ] **Step 2: Run full test suite**

Run: `swift test`
Expected: All tests pass

- [ ] **Step 3: Run build in release mode**

Run: `swift build -c release`
Expected: BUILD SUCCEEDED with no warnings

- [ ] **Step 4: Verify DocC symbol documentation compiles**

Run: `swift package generate-documentation --target PiqleyPluginSDK 2>&1 | tail -5`
Expected: Documentation generated (warnings about missing docs are expected at this stage — the actual doc comments are written inline with the implementation above)

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "chore: final cleanup and verification"
```

---

## Execution Order

Task 1 (Package.swift) must be first.

Tasks 2 (StateKey), 3 (IO/Errors) are independent.

Task 4 (ResolvedState) depends on Task 2.

Task 5 (PluginState) depends on Task 2.

Task 6 (Request/Response) depends on Tasks 3, 4, 5.

Task 7 (Plugin protocol) depends on Task 6.

Task 8 (Mock factory) depends on Tasks 6, 7.

Task 9 (MatchField/MatchPattern) depends on Task 2.

Task 10 (Manifest builder) depends on Tasks 2, 9.

Task 11 (Config builder) depends on Tasks 9, 10.

Task 12 (ExecutionLog) is independent of all except Task 1.

Task 13 depends on all.

```
1 (Package.swift)
├── 2 (StateKey, ImageMetadataKey)
│   ├── 4 (ResolvedState)
│   ├── 5 (PluginState)
│   └── 9 (MatchField, MatchPattern)
├── 3 (IO, Errors)
└── 12 (ExecutionLog)
    ├── 6 (Request, Response) ← needs 3, 4, 5
    │   └── 7 (Plugin protocol) ← needs 6
    │       └── 8 (Mock factory) ← needs 6, 7
    ├── 10 (Manifest builder) ← needs 2, 9
    │   └── 11 (Config builder) ← needs 9, 10
    └── 13 (Cleanup) ← needs all
```
