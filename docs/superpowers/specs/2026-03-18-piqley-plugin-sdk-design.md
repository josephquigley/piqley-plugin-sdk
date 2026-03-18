# PiqleyPluginSDK Design

**Date:** 2026-03-18
**Status:** Approved
**Scope:** PiqleyCore shared library, PiqleyPluginSDK Swift library, prerequisite piqley-cli changes

---

## Overview

The PiqleyPluginSDK is a Swift library that provides a first-class developer experience for building piqley plugins. It wraps the JSON stdio protocol into typed Swift APIs, provides builder patterns for manifests and configs, and offers typed state access with compile-time safety.

The design introduces a shared `PiqleyCore` package containing wire protocol types and validation logic used by both the SDK and piqley-cli. This ensures serialization parity and shared constraint validation across the ecosystem.

**Implementation is phased:**
1. Build PiqleyCore (wire types + validation)
2. Build PiqleyPluginSDK depending on PiqleyCore
3. Refactor piqley-cli to depend on PiqleyCore (separate effort)

---

## Section 1: PiqleyCore — Shared Wire Protocol Package

A standalone Swift package (`github.com/josephquigley/piqley-core`) containing only the types that must be identical on both sides of the plugin protocol. No external dependencies. Swift tools version 6.0.

### Types

**Primitives:**
- `JSONValue` — `Codable`, `Equatable`, `Sendable` enum representing any JSON value (string, number, bool, array, object, null). Includes `ExpressibleBy*Literal` conformances for ergonomic construction.
- `Hook` — enum with cases `preProcess`, `postProcess`, `publish`, `schedule`, `postPublish`. Raw values match the wire format (`"pre-process"`, etc.).
- `ConfigValueType` — enum: `string`, `int`, `float`, `bool`.
- `PluginProtocol` — enum: `json`, `pipe`.
- `SemanticVersion` — `Comparable`, `Codable`, `Sendable` struct with `major`, `minor`, `patch` fields. Parses from strings like `"2.1.0"`. Used for `pluginVersion` and `lastExecutedVersion` tracking.

**Manifest types (wire shape):**
- `PluginManifest` — `name`, `pluginProtocolVersion`, `pluginVersion: SemanticVersion?`, `config: [ConfigEntry]`, `setup: SetupConfig?`, `dependencies: [String]?`, `hooks: [String: HookConfig]`. Note: `pluginVersion` is a new field added to the `manifest.json` schema. It is optional to maintain backward compatibility with existing manifests that lack it. The SDK's builder API requires it, but the CLI's decoder accepts manifests without it.
- `ConfigEntry` — enum with `.value(key:type:value:)` and `.secret(secretKey:type:)` cases. Note: the plugin architecture spec (2026-03-17) describes secrets as a top-level `"secrets"` array, but the implemented CLI code uses `config: [ConfigEntry]` with secrets embedded as `.secret` entries. The code is canonical; the architecture spec is outdated on this point.
- `HookConfig` — `command: String?`, `args: [String]`, `timeout: Int?`, `pluginProtocol: PluginProtocol?`, `successCodes: [Int32]?`, `warningCodes: [Int32]?`, `criticalCodes: [Int32]?`, `batchProxy: BatchProxyConfig?`.
- `SetupConfig` — `command: String`, `args: [String]`.
- `BatchProxyConfig` — `sort: SortConfig?`.
- `SortConfig` — `key: String`, `order: SortOrder`.
- `SortOrder` — enum: `ascending`, `descending`.

**Config types (wire shape):**
- `PluginConfig` — `values: [String: JSONValue]`, `isSetUp: Bool?`, `rules: [Rule]`.
- `Rule` — `match: MatchConfig`, `emit: EmitConfig`.
- `MatchConfig` — `hook: String?`, `field: String`, `pattern: String`.
- `EmitConfig` — `field: String?`, `values: [String]`.

**Payload types:**
- `PluginInputPayload` — `hook: String`, `folderPath: String`, `pluginConfig: [String: JSONValue]`, `secrets: [String: String]`, `executionLogPath: String`, `dataPath: String`, `logPath: String`, `dryRun: Bool`, `state: [String: [String: [String: JSONValue]]]?`, `pluginVersion: SemanticVersion`, `lastExecutedVersion: SemanticVersion?`.
- `PluginOutputLine` — `type: String`, `message: String?`, `filename: String?`, `success: Bool?`, `error: String?`, `state: [String: [String: JSONValue]]?`.

**Validation:**
- `ManifestValidator` — validates manifest constraints and returns descriptive errors:
  - `batchProxy` only valid with pipe protocol
  - Required fields present (`name`, `pluginProtocolVersion`, at least one hook)
  - `pluginVersion` parses as valid semver
  - No unknown hook names (warns, does not error)
- Used by both the SDK (at manifest write time) and the CLI (at manifest load time).

### Package structure

```
Sources/PiqleyCore/
├── JSONValue.swift
├── Hook.swift
├── ConfigValueType.swift
├── PluginProtocol.swift
├── SemanticVersion.swift
├── Manifest/
│   ├── PluginManifest.swift
│   ├── ConfigEntry.swift
│   ├── HookConfig.swift
│   ├── SetupConfig.swift
│   └── BatchProxyConfig.swift
├── Config/
│   ├── PluginConfig.swift
│   └── Rule.swift
├── Payload/
│   ├── PluginInputPayload.swift
│   └── PluginOutputLine.swift
└── Validation/
    └── ManifestValidator.swift
Tests/PiqleyCoreTests/
├── JSONValueTests.swift
├── SemanticVersionTests.swift
├── ManifestCodingTests.swift
├── ConfigCodingTests.swift
├── PayloadCodingTests.swift
└── ManifestValidatorTests.swift
```

---

## Section 2: PiqleyPluginSDK — Plugin Author API

Depends on PiqleyCore. Provides the high-level API plugin authors use. No external dependencies beyond PiqleyCore.

### 2.1 Plugin Protocol & Entry Point

```swift
public protocol PiqleyPlugin {
    func handle(_ request: PluginRequest) async throws -> PluginResponse
}
```

Default `run()` implementation on the protocol:
1. Reads all of stdin.
2. Decodes `PluginInputPayload` → constructs `PluginRequest`.
3. Calls `handle(request)`.
4. Encodes `PluginResponse` → writes final `{"type": "result", ...}` JSON line to stdout.
5. Exits with code 0 on success, 1 on failure.

If `handle()` throws, `run()` catches the error, writes `{"type": "result", "success": false, "error": "<description>"}`, and exits with code 1.

Plugin author usage:
```swift
@main struct MyPlugin: PiqleyPlugin {
    func handle(_ request: PluginRequest) async throws -> PluginResponse {
        // plugin logic
    }
    static func main() async {
        await MyPlugin().run()
    }
}
```

Mono-binary plugins switch on `request.hook`:
```swift
func handle(_ request: PluginRequest) async throws -> PluginResponse {
    switch request.hook {
    case .postProcess: return try await resize(request)
    case .publish:     return try await upload(request)
    default:           return .ok
    }
}
```

### 2.2 PluginRequest

```swift
public struct PluginRequest: Sendable {
    public let hook: Hook
    public let folderPath: String
    public let pluginConfig: [String: JSONValue]
    public let secrets: [String: String]
    public let executionLogPath: String
    public let dataPath: String
    public let logPath: String
    public let dryRun: Bool
    public let state: ResolvedState
    public let pluginVersion: SemanticVersion
    public let lastExecutedVersion: SemanticVersion?

    /// Lists image files in folderPath matching piqley's supported extensions (.jpg, .jpeg, .jxl).
    public func imageFiles() throws -> [URL]

    /// Writes a progress line to stdout immediately.
    public func reportProgress(_ message: String)

    /// Writes an imageResult line to stdout immediately.
    public func reportImageResult(_ filename: String, success: Bool, error: String? = nil)
}
```

`reportProgress` and `reportImageResult` write JSON lines to stdout immediately via an internal `PluginIO` reference. For testing, a mock IO captures output instead.

### 2.3 PluginResponse

```swift
public struct PluginResponse: Sendable {
    public let success: Bool
    public let error: String?
    public let state: [String: PluginState]?  // keyed by image filename

    public init(success: Bool, error: String? = nil, state: [String: PluginState]? = nil)

    /// Convenience for a simple success with no state.
    public static let ok = PluginResponse(success: true)
}
```

### 2.4 Hook Enum

Re-exported from PiqleyCore. Enum with typed cases:

```swift
public enum Hook: String, Codable, Sendable {
    case preProcess = "pre-process"
    case postProcess = "post-process"
    case publish
    case schedule
    case postPublish = "post-publish"
}
```

---

## Section 3: State Access

### 3.1 StateKey Protocol

Any string-backed enum can serve as typed keys for state access:

```swift
public protocol StateKey: RawRepresentable, Sendable where RawValue == String {
    static var namespace: String { get }
}
```

Plugin authors define their own keys:
```swift
enum MyKeys: String, StateKey {
    static let namespace = "my-plugin"
    case keywords
    case caption
    case hashtagCount = "hashtag-count"
}
```

### 3.2 ImageMetadataKey

Curated enum of ~30-40 common EXIF/IPTC/TIFF fields for the `original` namespace:

```swift
public enum ImageMetadataKey: String, StateKey {
    public static let namespace = "original"

    // TIFF
    case make = "TIFF:Make"
    case model = "TIFF:Model"
    case orientation = "TIFF:Orientation"
    case software = "TIFF:Software"

    // EXIF
    case dateTimeOriginal = "EXIF:DateTimeOriginal"
    case exposureTime = "EXIF:ExposureTime"
    case fNumber = "EXIF:FNumber"
    case iso = "EXIF:ISOSpeedRatings"
    case focalLength = "EXIF:FocalLength"
    case lensModel = "EXIF:LensModel"
    case shutterSpeed = "EXIF:ShutterSpeedValue"
    case aperture = "EXIF:ApertureValue"
    case exposureProgram = "EXIF:ExposureProgram"
    case meteringMode = "EXIF:MeteringMode"
    case flash = "EXIF:Flash"
    case whiteBalance = "EXIF:WhiteBalance"
    case exposureCompensation = "EXIF:ExposureBiasValue"
    case bodySerialNumber = "EXIF:BodySerialNumber"
    case lensSerialNumber = "EXIF:LensSerialNumber"

    // IPTC
    case keywords = "IPTC:Keywords"
    case caption = "IPTC:CaptionAbstract"
    case objectName = "IPTC:ObjectName"
    case city = "IPTC:City"
    case country = "IPTC:CountryPrimaryLocationName"
    case provinceState = "IPTC:ProvinceState"
    case sublocation = "IPTC:SubLocation"
    case byline = "IPTC:Byline"
    case copyrightNotice = "IPTC:CopyrightNotice"
    case credit = "IPTC:Credit"
    case source = "IPTC:Source"
    case headline = "IPTC:Headline"
    case specialInstructions = "IPTC:SpecialInstructions"
    case dateCreated = "IPTC:DateCreated"

    // XMP (common)
    case title = "XMP:Title"
    case description = "XMP:Description"
    case creator = "XMP:Creator"
    case rights = "XMP:Rights"
    case rating = "XMP:Rating"
    case label = "XMP:Label"
}
```

String-based access remains available for fields not in the enum.

### 3.3 Reading State — ResolvedState & Namespace

```swift
public struct ResolvedState: Sendable {
    public var imageNames: [String]
    public subscript(image: String) -> ImageState?

    public static let empty: ResolvedState
}

public struct ImageState: Sendable {
    /// Access the "original" namespace.
    public var original: Namespace
    /// Access a dependency plugin's namespace by name.
    public func dependency(_ name: String) -> Namespace
}

public struct Namespace: Sendable {
    // String-keyed access
    public func string(_ key: String) -> String?
    public func int(_ key: String) -> Int?
    public func double(_ key: String) -> Double?
    public func bool(_ key: String) -> Bool?
    public func strings(_ key: String) -> [String]?
    public func raw(_ key: String) -> JSONValue?

    // Typed key access (any StateKey-conforming enum)
    public func string<K: StateKey>(_ key: K) -> String?
    public func int<K: StateKey>(_ key: K) -> Int?
    public func double<K: StateKey>(_ key: K) -> Double?
    public func bool<K: StateKey>(_ key: K) -> Bool?
    public func strings<K: StateKey>(_ key: K) -> [String]?
    public func raw<K: StateKey>(_ key: K) -> JSONValue?
}
```

Usage:
```swift
for image in request.state.imageNames {
    let model = request.state[image]?.original.string(.model)
    let tags = request.state[image]?.dependency("hashtag").strings(HashtagKeys.tags)
}
```

### 3.4 Writing State — PluginState

```swift
public struct PluginState: Sendable {
    public init()

    // String-keyed setters
    public mutating func set(_ key: String, to value: String)
    public mutating func set(_ key: String, to values: [String])
    public mutating func set(_ key: String, to value: Int)
    public mutating func set(_ key: String, to value: Bool)
    public mutating func set(_ key: String, to value: Double)
    public mutating func set(_ key: String, to value: JSONValue)

    // Typed key setters
    public mutating func set<K: StateKey>(_ key: K, to value: String)
    public mutating func set<K: StateKey>(_ key: K, to values: [String])
    public mutating func set<K: StateKey>(_ key: K, to value: Int)
    public mutating func set<K: StateKey>(_ key: K, to value: Bool)
    public mutating func set<K: StateKey>(_ key: K, to value: Double)
    public mutating func set<K: StateKey>(_ key: K, to value: JSONValue)
}
```

Usage:
```swift
var state: [String: PluginState] = [:]
for image in request.state.imageNames {
    var imageState = PluginState()
    imageState.set(MyKeys.keywords, to: ["Sony", "A7R Life"])
    imageState.set(MyKeys.caption, to: "Golden hour")
    state[image] = imageState
}
return PluginResponse(success: true, state: state)
```

---

## Section 4: Manifest Builder API

Result builder DSL for constructing manifests with compile-time safety. Uses typed enums and builder blocks to eliminate magic strings.

```swift
let manifest = PluginManifest {
    Name("my-plugin")
    ProtocolVersion("1")
    PluginVersion("1.0.0")

    ConfigEntries {
        Value("url", type: .string)
        Value("quality", type: .int, default: 80)
        Secret("api-key", type: .string)
    }

    Setup(command: "./bin/setup", args: ["$PIQLEY_SECRET_API_KEY"])

    Dependencies {
        ImageMetadataKey.self   // "original"
        HashtagKeys.self        // "hashtag"
    }

    Hooks {
        Hook(.publish, command: "./bin/publish", protocol: .json)
        Hook(.postProcess, command: "./bin/process", protocol: .json, timeout: 60)
        Hook(.preProcess) // rules-only, no binary
    }
}

try manifest.write(to: pluginDirectory)
```

### Builder types

- `ManifestBuilder` — top-level `@resultBuilder` accepting `Name`, `ProtocolVersion`, `PluginVersion`, `ConfigEntries`, `Setup`, `Dependencies`, `Hooks` components.
- `ConfigBuilder` — `@resultBuilder` accepting `Value` and `Secret` entries.
- `DependencyBuilder` — `@resultBuilder` accepting `StateKey.Type` metatypes (derives namespace string) and raw `String` literals.
- `HookBuilder` — `@resultBuilder` accepting `Hook` entries.

### Validation on write

`write(to:)` runs `ManifestValidator` from PiqleyCore before writing. Throws descriptive errors for:
- `batchProxy` declared with JSON protocol
- Missing required fields (name, protocol version, plugin version)
- Invalid semver in plugin version
- Hook with `batchProxy` but no command

Also provides `encode() -> Data` for cases where the caller wants the bytes without writing to disk.

---

## Section 5: Config Builder API

Result builder DSL for constructing `config.json` files with typed rule construction.

```swift
let config = PluginConfig {
    Values {
        "url" => .string("https://mysite.com")
        "quality" => 85
    }

    Rules {
        Rule(
            match: .field(.original(.model), pattern: .regex(".*a7r.*")),
            emit: .keywords(["Sony", "A7R Life"])
        )
        Rule(
            match: .field(.dependency(HashtagKeys.tags), pattern: .glob("*Cat*")),
            hook: .preProcess,
            emit: .keywords(["Cat Photography", "Feline"])
        )
    }
}

try config.write(to: pluginDirectory)
```

### Typed rule construction

**MatchField** — static factory struct, encodes to the `"namespace:field"` wire format:
```swift
public struct MatchField: Sendable {
    /// Match against core-extracted image metadata.
    public static func original(_ key: ImageMetadataKey) -> MatchField
    /// Match against a dependency's state using a typed key (namespace derived from StateKey.namespace).
    public static func dependency<K: StateKey>(_ key: K) -> MatchField
    /// Match against a dependency's state with raw strings (fallback).
    public static func dependency(_ plugin: String, key: String) -> MatchField
}
```

**MatchPattern** — typed enum, encodes to the `"regex:..."` / `"glob:..."` / bare string wire format:
```swift
public enum MatchPattern: Sendable {
    case exact(String)
    case glob(String)
    case regex(String)
}
```

**EmitConfig convenience factories:**
```swift
public extension EmitConfig {
    /// Emit to the default "keywords" field.
    static func keywords(_ values: [String]) -> EmitConfig
    /// Emit to a named field.
    static func values(field: String, _ values: [String]) -> EmitConfig
}
```

---

## Section 6: Execution Log

Optional helper for plugin deduplication. Uses the `executionLogPath` provided by the CLI.

```swift
public struct ExecutionLog: Sendable {
    /// Opens or creates the log at the given path.
    public init(path: String) throws

    /// Appends an entry to the log.
    public func append(_ entry: ExecutionLogEntry) throws

    /// Returns all entries matching the given filename.
    public func entries(for filename: String) -> [ExecutionLogEntry]

    /// Returns true if the filename has been logged previously.
    public func contains(filename: String) -> Bool
}

public struct ExecutionLogEntry: Codable, Sendable {
    public let filename: String
    public let timestamp: Date
    public let hook: Hook
    public let success: Bool
    public let metadata: [String: JSONValue]?

    public init(filename: String, hook: Hook, success: Bool, metadata: [String: JSONValue]? = nil)
}
```

The log format is JSONL (one JSON object per line), matching the convention established by the piqley-cli design. `timestamp` is set automatically on `append`.

---

## Section 7: IO & Testability

### Internal IO protocol

```swift
internal protocol PluginIO: Sendable {
    func writeLine(_ line: String)
}

internal struct StdoutIO: PluginIO {
    func writeLine(_ line: String) {
        print(line)
        fflush(stdout)
    }
}
```

### Test support

Public mock factory for constructing `PluginRequest` values without real stdin/stdout:

```swift
extension PluginRequest {
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
    ) -> (request: PluginRequest, output: CapturedOutput)
}

public struct CapturedOutput: Sendable {
    public var progressMessages: [String]
    public var imageResults: [(filename: String, success: Bool, error: String?)]
    public var allLines: [String]
}
```

Usage with Swift Testing:
```swift
@Test func publishUploadsImages() async throws {
    let (request, output) = PluginRequest.mock(hook: .publish, dryRun: false)
    let response = try await MyPlugin().handle(request)
    #expect(response.success)
    #expect(output.progressMessages.contains("Uploading photo.jpg..."))
    #expect(output.imageResults.count == 3)
}
```

---

## Section 8: Package Structure

### PiqleyPluginSDK Package.swift

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

### Source file layout

```
swift/PiqleyPluginSDK/
├── Plugin.swift              # PiqleyPlugin protocol, run() entry point
├── Request.swift             # PluginRequest
├── Response.swift            # PluginResponse
├── State/
│   ├── ResolvedState.swift   # ResolvedState, ImageState, Namespace
│   ├── PluginState.swift     # PluginState (write-side)
│   ├── StateKey.swift        # StateKey protocol
│   └── ImageMetadataKey.swift # Curated EXIF/IPTC/TIFF/XMP keys
├── Builders/
│   ├── ManifestBuilder.swift # Result builder for PluginManifest
│   ├── ConfigBuilder.swift   # Result builder for PluginConfig
│   ├── MatchField.swift      # Typed rule match field
│   └── MatchPattern.swift    # Typed rule match pattern
├── ExecutionLog.swift        # JSONL execution log helper
├── IO.swift                  # PluginIO protocol, StdoutIO, CapturedIO
└── Errors.swift              # SDK error types

swift/Tests/
├── PluginTests.swift         # PiqleyPlugin protocol + run() tests
├── RequestTests.swift        # PluginRequest parsing, imageFiles()
├── ResponseTests.swift       # PluginResponse encoding
├── StateTests.swift          # ResolvedState, Namespace, PluginState
├── ManifestBuilderTests.swift # Builder DSL + validation
├── ConfigBuilderTests.swift  # Config builder + rule construction
├── ExecutionLogTests.swift   # JSONL read/write
└── MockTests.swift           # Mock factory tests
```

---

## Section 9: Prerequisite CLI Changes

These changes are required in piqley-cli before the SDK can be fully functional. They can be implemented as part of the Phase 3 PiqleyCore migration or independently.

### 9.1 JSON payload additions

The `PluginInputPayload` gains four new fields:
- `dataPath: String` — writable data directory for the plugin (`~/.local/share/piqley/plugins/<name>/data/`)
- `logPath: String` — writable log directory for the plugin (`~/.local/share/piqley/plugins/<name>/logs/`)
- `pluginVersion: String` — the plugin's version from its manifest
- `lastExecutedVersion: String?` — the version last successfully executed, nil on first run

### 9.2 Directory layout change

Separate config from data/logs following XDG conventions on all platforms:
- Config: `~/.config/piqley/` — manifests, config.json (user-authored, small)
- Data/logs: `~/.local/share/piqley/` — execution logs, plugin data, caches (safe to delete for cleanup)

The CLI guarantees that `dataPath` and `logPath` directories exist and are writable before spawning a plugin subprocess.

### 9.3 Version tracking

The CLI stores the last successfully executed plugin version (from `manifest.pluginVersion`) after each successful pipeline run. Storage location: `~/.local/share/piqley/plugins/<name>/version.json` (in the data directory, not config). Passed to the plugin in the JSON payload as `lastExecutedVersion`.

---

## Section 10: Documentation Strategy

### DocC symbol documentation

Every public type, method, property, and enum case gets `///` documentation comments. These appear in Xcode Quick Help and autocomplete when consuming via `import PiqleyPluginSDK`.

Documentation covers:
- What the symbol does
- Parameter descriptions
- Return value descriptions
- Usage examples in doc comments for key types (`PiqleyPlugin`, `PluginRequest`, builders)
- Notes about wire format mapping where relevant (e.g., `MatchPattern.regex` → `"regex:..."`)

### Developer documentation

A `docs/` directory in the SDK repo with markdown guides:
- **Getting Started** — creating a plugin from scratch with the SDK
- **Manifest & Config Reference** — builder API examples, all options
- **Working with State** — reading dependencies, writing output, custom StateKey enums
- **Testing Plugins** — using the mock factory
- **Execution Log** — deduplication patterns

### DocC catalog (deferred)

A full DocC catalog with tutorials and articles is planned for a future iteration after the API surface stabilizes through real plugin development.

### Pipe protocol note

The SDK targets JSON protocol plugins. Pipe protocol plugins (simple shell/script tools) do not benefit from the SDK beyond manifest generation. This is documented explicitly in the Getting Started guide.

---

## Section 11: What Is NOT in the SDK

- **Pipe protocol runtime support** — pipe plugins are simple shell tools; the SDK's value is in the JSON protocol.
- **batchProxy runtime handling** — batchProxy is a pipe protocol concern.
- **Directory scaffolding** — the CLI manages directory creation.
- **Secrets management** — secrets are injected by the CLI; the SDK just reads them from the request.
- **Image processing utilities** — out of scope; plugins use their own libraries.
- **DocC catalog/tutorials** — deferred to a future iteration.
