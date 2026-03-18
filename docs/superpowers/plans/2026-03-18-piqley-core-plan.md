# PiqleyCore Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the shared wire protocol types package used by both the PiqleyPluginSDK and piqley-cli.

**Architecture:** PiqleyCore is a standalone Swift package (swift-tools-version 6.0, no external dependencies) containing Codable/Sendable types that define the JSON wire format for the piqley plugin protocol. It includes primitives (JSONValue, Hook, SemanticVersion), manifest/config Codable structs, payload types, and a manifest validator. All types are public and designed for re-export.

**Tech Stack:** Swift 6.0, Swift Package Manager, Swift Testing

**Spec:** `docs/superpowers/specs/2026-03-18-piqley-plugin-sdk-design.md` (Section 1)

**Repo:** `github.com/josephquigley/piqley-core` (created, empty)

**Local path:** `/Users/wash/Developer/tools/piqley/piqley-core/`

---

## File Structure

```
piqley-core/
├── Package.swift
├── Sources/PiqleyCore/
│   ├── JSONValue.swift              # JSON value enum with ExpressibleBy conformances
│   ├── Hook.swift                   # 5-stage hook enum
│   ├── ConfigValueType.swift        # string/int/float/bool enum
│   ├── PluginProtocol.swift         # json/pipe enum
│   ├── SemanticVersion.swift        # Comparable semver type
│   ├── Manifest/
│   │   ├── PluginManifest.swift     # Top-level manifest Codable struct
│   │   ├── ConfigEntry.swift        # Value vs secret config entry enum
│   │   ├── HookConfig.swift         # Per-hook configuration
│   │   ├── SetupConfig.swift        # Optional setup binary config
│   │   └── BatchProxyConfig.swift   # BatchProxy + SortConfig + SortOrder
│   ├── Config/
│   │   ├── PluginConfig.swift       # Mutable config sidecar
│   │   └── Rule.swift               # Rule, MatchConfig, EmitConfig
│   ├── Payload/
│   │   ├── PluginInputPayload.swift # CLI→Plugin stdin JSON
│   │   └── PluginOutputLine.swift   # Plugin→CLI stdout JSON lines
│   └── Validation/
│       └── ManifestValidator.swift   # Constraint validation
└── Tests/PiqleyCoreTests/
    ├── JSONValueTests.swift
    ├── SemanticVersionTests.swift
    ├── ManifestCodingTests.swift
    ├── ConfigCodingTests.swift
    ├── PayloadCodingTests.swift
    └── ManifestValidatorTests.swift
```

---

### Task 1: Package scaffold

**Files:**
- Create: `Package.swift`
- Create: `Sources/PiqleyCore/PiqleyCore.swift` (empty namespace file)
- Create: `Tests/PiqleyCoreTests/PiqleyCoreTests.swift` (placeholder)

- [ ] **Step 1: Initialize git repo and create Package.swift**

```bash
cd /Users/wash/Developer/tools/piqley/piqley-core
git init
git remote add origin https://github.com/josephquigley/piqley-core.git
```

Create `Package.swift`:
```swift
// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "PiqleyCore",
    products: [
        .library(name: "PiqleyCore", targets: ["PiqleyCore"]),
    ],
    targets: [
        .target(name: "PiqleyCore", path: "Sources/PiqleyCore"),
        .testTarget(
            name: "PiqleyCoreTests",
            dependencies: ["PiqleyCore"],
            path: "Tests/PiqleyCoreTests"
        ),
    ]
)
```

- [ ] **Step 2: Create placeholder source and test files**

Create `Sources/PiqleyCore/PiqleyCore.swift`:
```swift
// PiqleyCore — shared wire protocol types for the piqley plugin ecosystem.
```

Create `Tests/PiqleyCoreTests/PiqleyCoreTests.swift`:
```swift
import Testing
@testable import PiqleyCore

@Test func packageCompiles() {
    // Placeholder — replaced as real types are added.
}
```

- [ ] **Step 3: Verify build and test**

Run: `swift build && swift test`
Expected: BUILD SUCCEEDED, all tests pass

- [ ] **Step 4: Create .gitignore and commit**

Create `.gitignore`:
```
.build/
.swiftpm/
*.xcodeproj/
xcuserdata/
DerivedData/
.DS_Store
```

```bash
git add Package.swift Sources/ Tests/ .gitignore
git commit -m "chore: scaffold PiqleyCore package"
```

---

### Task 2: JSONValue

**Files:**
- Create: `Sources/PiqleyCore/JSONValue.swift`
- Create: `Tests/PiqleyCoreTests/JSONValueTests.swift`

- [ ] **Step 1: Write failing tests**

Create `Tests/PiqleyCoreTests/JSONValueTests.swift`:
```swift
import Testing
@testable import PiqleyCore
import Foundation

@Test func decodeString() throws {
    let json = Data(#""hello""#.utf8)
    let value = try JSONDecoder().decode(JSONValue.self, from: json)
    #expect(value == .string("hello"))
}

@Test func decodeNumber() throws {
    let json = Data("42.5".utf8)
    let value = try JSONDecoder().decode(JSONValue.self, from: json)
    #expect(value == .number(42.5))
}

@Test func decodeBool() throws {
    let json = Data("true".utf8)
    let value = try JSONDecoder().decode(JSONValue.self, from: json)
    #expect(value == .bool(true))
}

@Test func decodeNull() throws {
    let json = Data("null".utf8)
    let value = try JSONDecoder().decode(JSONValue.self, from: json)
    #expect(value == .null)
}

@Test func decodeArray() throws {
    let json = Data(#"[1, "two", true]"#.utf8)
    let value = try JSONDecoder().decode(JSONValue.self, from: json)
    #expect(value == .array([.number(1), .string("two"), .bool(true)]))
}

@Test func decodeObject() throws {
    let json = Data(#"{"key": "value"}"#.utf8)
    let value = try JSONDecoder().decode(JSONValue.self, from: json)
    #expect(value == .object(["key": .string("value")]))
}

@Test func encodeRoundTrip() throws {
    let original: JSONValue = .object([
        "name": .string("test"),
        "count": .number(3),
        "active": .bool(true),
        "tags": .array([.string("a"), .string("b")]),
        "meta": .null,
    ])
    let data = try JSONEncoder().encode(original)
    let decoded = try JSONDecoder().decode(JSONValue.self, from: data)
    #expect(decoded == original)
}

@Test func expressibleByStringLiteral() {
    let value: JSONValue = "hello"
    #expect(value == .string("hello"))
}

@Test func expressibleByIntegerLiteral() {
    let value: JSONValue = 42
    #expect(value == .number(42))
}

@Test func expressibleByFloatLiteral() {
    let value: JSONValue = 3.14
    #expect(value == .number(3.14))
}

@Test func expressibleByBooleanLiteral() {
    let value: JSONValue = true
    #expect(value == .bool(true))
}

@Test func expressibleByNilLiteral() {
    let value: JSONValue = nil
    #expect(value == .null)
}

@Test func expressibleByArrayLiteral() {
    let value: JSONValue = ["a", 1, true]
    #expect(value == .array([.string("a"), .number(1), .bool(true)]))
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test 2>&1 | head -20`
Expected: FAIL — `JSONValue` not defined

- [ ] **Step 3: Implement JSONValue**

Create `Sources/PiqleyCore/JSONValue.swift`:
```swift
import Foundation

/// A Codable, Sendable value representing any JSON primitive or structure.
public enum JSONValue: Codable, Equatable, Sendable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case array([JSONValue])
    case object([String: JSONValue])
    case null

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let bool = try? container.decode(Bool.self) {
            self = .bool(bool)
        } else if let number = try? container.decode(Double.self) {
            self = .number(number)
        } else if let string = try? container.decode(String.self) {
            self = .string(string)
        } else if let array = try? container.decode([JSONValue].self) {
            self = .array(array)
        } else if let object = try? container.decode([String: JSONValue].self) {
            self = .object(object)
        } else {
            throw DecodingError.typeMismatch(
                JSONValue.self,
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Unknown JSON type"
                )
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null: try container.encodeNil()
        case let .bool(value): try container.encode(value)
        case let .number(value): try container.encode(value)
        case let .string(value): try container.encode(value)
        case let .array(value): try container.encode(value)
        case let .object(value): try container.encode(value)
        }
    }
}

extension JSONValue: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self = .string(value)
    }
}

extension JSONValue: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int) {
        self = .number(Double(value))
    }
}

extension JSONValue: ExpressibleByFloatLiteral {
    public init(floatLiteral value: Double) {
        self = .number(value)
    }
}

extension JSONValue: ExpressibleByBooleanLiteral {
    public init(booleanLiteral value: Bool) {
        self = .bool(value)
    }
}

extension JSONValue: ExpressibleByNilLiteral {
    public init(nilLiteral: ()) {
        self = .null
    }
}

extension JSONValue: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: JSONValue...) {
        self = .array(elements)
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test`
Expected: All tests pass

- [ ] **Step 5: Commit**

```bash
git add Sources/PiqleyCore/JSONValue.swift Tests/PiqleyCoreTests/JSONValueTests.swift
git commit -m "feat: add JSONValue type with Codable and ExpressibleBy conformances"
```

---

### Task 3: Hook enum

**Files:**
- Create: `Sources/PiqleyCore/Hook.swift`
- Modify: `Tests/PiqleyCoreTests/PiqleyCoreTests.swift` (add hook tests, or create separate file)

- [ ] **Step 1: Write failing tests**

Add to `Tests/PiqleyCoreTests/PiqleyCoreTests.swift` (or create `HookTests.swift`):
```swift
import Testing
@testable import PiqleyCore
import Foundation

@Test func hookRawValues() {
    #expect(Hook.preProcess.rawValue == "pre-process")
    #expect(Hook.postProcess.rawValue == "post-process")
    #expect(Hook.publish.rawValue == "publish")
    #expect(Hook.schedule.rawValue == "schedule")
    #expect(Hook.postPublish.rawValue == "post-publish")
}

@Test func hookDecodeFromJSON() throws {
    let json = Data(#""pre-process""#.utf8)
    let hook = try JSONDecoder().decode(Hook.self, from: json)
    #expect(hook == .preProcess)
}

@Test func hookEncodeToJSON() throws {
    let data = try JSONEncoder().encode(Hook.postPublish)
    let string = String(data: data, encoding: .utf8)
    #expect(string == #""post-publish""#)
}

@Test func hookAllCases() {
    #expect(Hook.allCases.count == 5)
}

@Test func hookCanonicalOrder() {
    let ordered = Hook.canonicalOrder
    #expect(ordered == [.preProcess, .postProcess, .publish, .schedule, .postPublish])
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test 2>&1 | head -20`
Expected: FAIL — `Hook` not defined

- [ ] **Step 3: Implement Hook**

Create `Sources/PiqleyCore/Hook.swift`:
```swift
/// The five canonical pipeline stages a plugin can participate in.
public enum Hook: String, Codable, Sendable, CaseIterable {
    case preProcess = "pre-process"
    case postProcess = "post-process"
    case publish
    case schedule
    case postPublish = "post-publish"

    /// Hooks in canonical pipeline execution order.
    public static let canonicalOrder: [Hook] = [
        .preProcess, .postProcess, .publish, .schedule, .postPublish,
    ]
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test`
Expected: All tests pass

- [ ] **Step 5: Commit**

```bash
git add Sources/PiqleyCore/Hook.swift Tests/
git commit -m "feat: add Hook enum with canonical pipeline stages"
```

---

### Task 4: ConfigValueType and PluginProtocol enums

**Files:**
- Create: `Sources/PiqleyCore/ConfigValueType.swift`
- Create: `Sources/PiqleyCore/PluginProtocol.swift`

These are simple enums with no complex logic. Test them together.

- [ ] **Step 1: Write failing tests**

Create `Tests/PiqleyCoreTests/SimpleEnumTests.swift`:
```swift
import Testing
@testable import PiqleyCore
import Foundation

@Test func configValueTypeRawValues() {
    #expect(ConfigValueType.string.rawValue == "string")
    #expect(ConfigValueType.int.rawValue == "int")
    #expect(ConfigValueType.float.rawValue == "float")
    #expect(ConfigValueType.bool.rawValue == "bool")
}

@Test func configValueTypeDecodes() throws {
    let json = Data(#""int""#.utf8)
    let type = try JSONDecoder().decode(ConfigValueType.self, from: json)
    #expect(type == .int)
}

@Test func pluginProtocolRawValues() {
    #expect(PluginProtocol.json.rawValue == "json")
    #expect(PluginProtocol.pipe.rawValue == "pipe")
}

@Test func pluginProtocolDecodes() throws {
    let json = Data(#""pipe""#.utf8)
    let proto = try JSONDecoder().decode(PluginProtocol.self, from: json)
    #expect(proto == .pipe)
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test 2>&1 | head -20`
Expected: FAIL

- [ ] **Step 3: Implement both enums**

Create `Sources/PiqleyCore/ConfigValueType.swift`:
```swift
/// The type of a config entry value.
public enum ConfigValueType: String, Codable, Sendable {
    case string
    case int
    case float
    case bool
}
```

Create `Sources/PiqleyCore/PluginProtocol.swift`:
```swift
/// Plugin communication protocol.
public enum PluginProtocol: String, Codable, Sendable {
    case json
    case pipe
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test`
Expected: All tests pass

- [ ] **Step 5: Commit**

```bash
git add Sources/PiqleyCore/ConfigValueType.swift Sources/PiqleyCore/PluginProtocol.swift Tests/PiqleyCoreTests/SimpleEnumTests.swift
git commit -m "feat: add ConfigValueType and PluginProtocol enums"
```

---

### Task 5: SemanticVersion

**Files:**
- Create: `Sources/PiqleyCore/SemanticVersion.swift`
- Create: `Tests/PiqleyCoreTests/SemanticVersionTests.swift`

- [ ] **Step 1: Write failing tests**

Create `Tests/PiqleyCoreTests/SemanticVersionTests.swift`:
```swift
import Testing
@testable import PiqleyCore
import Foundation

@Test func parseValidVersion() throws {
    let v = try SemanticVersion("2.1.0")
    #expect(v.major == 2)
    #expect(v.minor == 1)
    #expect(v.patch == 0)
}

@Test func parseVersionWithoutPatch() throws {
    let v = try SemanticVersion("1.0")
    #expect(v.major == 1)
    #expect(v.minor == 0)
    #expect(v.patch == 0)
}

@Test func parseInvalidVersionThrows() {
    #expect(throws: SemanticVersionError.self) {
        try SemanticVersion("not-a-version")
    }
}

@Test func parseEmptyStringThrows() {
    #expect(throws: SemanticVersionError.self) {
        try SemanticVersion("")
    }
}

@Test func comparison() throws {
    let v1 = try SemanticVersion("1.0.0")
    let v2 = try SemanticVersion("2.0.0")
    let v3 = try SemanticVersion("1.1.0")
    let v4 = try SemanticVersion("1.0.1")
    #expect(v1 < v2)
    #expect(v1 < v3)
    #expect(v1 < v4)
    #expect(v3 < v2)
    #expect(v4 < v3)
}

@Test func equality() throws {
    let v1 = try SemanticVersion("1.2.3")
    let v2 = try SemanticVersion("1.2.3")
    #expect(v1 == v2)
}

@Test func codableRoundTrip() throws {
    let original = try SemanticVersion("3.2.1")
    let data = try JSONEncoder().encode(original)
    let string = String(data: data, encoding: .utf8)
    #expect(string == #""3.2.1""#)
    let decoded = try JSONDecoder().decode(SemanticVersion.self, from: data)
    #expect(decoded == original)
}

@Test func initWithComponents() {
    let v = SemanticVersion(1, 2, 3)
    #expect(v.major == 1)
    #expect(v.minor == 2)
    #expect(v.patch == 3)
}

@Test func descriptionFormat() throws {
    let v = try SemanticVersion("1.2.3")
    #expect(v.description == "1.2.3")
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test 2>&1 | head -20`
Expected: FAIL

- [ ] **Step 3: Implement SemanticVersion**

Create `Sources/PiqleyCore/SemanticVersion.swift`:
```swift
import Foundation

/// Error thrown when a string cannot be parsed as a semantic version.
public enum SemanticVersionError: Error, Sendable {
    case invalidFormat(String)
}

/// A semantic version with major, minor, and patch components.
public struct SemanticVersion: Equatable, Comparable, Sendable, CustomStringConvertible {
    public let major: Int
    public let minor: Int
    public let patch: Int

    public init(_ major: Int, _ minor: Int, _ patch: Int) {
        self.major = major
        self.minor = minor
        self.patch = patch
    }

    /// Parse a version string like "1.2.3" or "1.0".
    public init(_ string: String) throws {
        let parts = string.split(separator: ".")
        guard parts.count >= 2, parts.count <= 3 else {
            throw SemanticVersionError.invalidFormat(string)
        }
        guard let major = Int(parts[0]), let minor = Int(parts[1]) else {
            throw SemanticVersionError.invalidFormat(string)
        }
        let patch: Int
        if parts.count == 3 {
            guard let p = Int(parts[2]) else {
                throw SemanticVersionError.invalidFormat(string)
            }
            patch = p
        } else {
            patch = 0
        }
        self.major = major
        self.minor = minor
        self.patch = patch
    }

    public var description: String {
        "\(major).\(minor).\(patch)"
    }

    public static func < (lhs: SemanticVersion, rhs: SemanticVersion) -> Bool {
        if lhs.major != rhs.major { return lhs.major < rhs.major }
        if lhs.minor != rhs.minor { return lhs.minor < rhs.minor }
        return lhs.patch < rhs.patch
    }
}

extension SemanticVersion: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let string = try container.decode(String.self)
        try self.init(string)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(description)
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test`
Expected: All tests pass

- [ ] **Step 5: Commit**

```bash
git add Sources/PiqleyCore/SemanticVersion.swift Tests/PiqleyCoreTests/SemanticVersionTests.swift
git commit -m "feat: add SemanticVersion type with parsing and comparison"
```

---

### Task 6: ConfigEntry

**Files:**
- Create: `Sources/PiqleyCore/Manifest/ConfigEntry.swift`

- [ ] **Step 1: Write failing tests**

Add to `Tests/PiqleyCoreTests/ManifestCodingTests.swift` (create file):
```swift
import Testing
@testable import PiqleyCore
import Foundation

@Test func decodeValueEntry() throws {
    let json = Data(#"{"key": "url", "type": "string", "value": null}"#.utf8)
    let entry = try JSONDecoder().decode(ConfigEntry.self, from: json)
    if case let .value(key, type, value) = entry {
        #expect(key == "url")
        #expect(type == .string)
        #expect(value == .null)
    } else {
        Issue.record("Expected .value case")
    }
}

@Test func decodeValueEntryWithDefault() throws {
    let json = Data(#"{"key": "quality", "type": "int", "value": 80}"#.utf8)
    let entry = try JSONDecoder().decode(ConfigEntry.self, from: json)
    if case let .value(key, type, value) = entry {
        #expect(key == "quality")
        #expect(type == .int)
        #expect(value == .number(80))
    } else {
        Issue.record("Expected .value case")
    }
}

@Test func decodeSecretEntry() throws {
    let json = Data(#"{"secret_key": "api-key", "type": "string"}"#.utf8)
    let entry = try JSONDecoder().decode(ConfigEntry.self, from: json)
    if case let .secret(secretKey, type) = entry {
        #expect(secretKey == "api-key")
        #expect(type == .string)
    } else {
        Issue.record("Expected .secret case")
    }
}

@Test func decodeBothKeysThrows() throws {
    let json = Data(#"{"key": "x", "secret_key": "y", "type": "string", "value": null}"#.utf8)
    #expect(throws: DecodingError.self) {
        try JSONDecoder().decode(ConfigEntry.self, from: json)
    }
}

@Test func decodeNeitherKeyThrows() throws {
    let json = Data(#"{"type": "string"}"#.utf8)
    #expect(throws: DecodingError.self) {
        try JSONDecoder().decode(ConfigEntry.self, from: json)
    }
}

@Test func encodeValueEntry() throws {
    let entry = ConfigEntry.value(key: "url", type: .string, value: .null)
    let data = try JSONEncoder().encode(entry)
    let decoded = try JSONDecoder().decode(ConfigEntry.self, from: data)
    if case let .value(key, type, value) = decoded {
        #expect(key == "url")
        #expect(type == .string)
        #expect(value == .null)
    } else {
        Issue.record("Round-trip failed")
    }
}

@Test func encodeSecretEntry() throws {
    let entry = ConfigEntry.secret(secretKey: "api-key", type: .string)
    let data = try JSONEncoder().encode(entry)
    let decoded = try JSONDecoder().decode(ConfigEntry.self, from: data)
    if case let .secret(secretKey, type) = decoded {
        #expect(secretKey == "api-key")
        #expect(type == .string)
    } else {
        Issue.record("Round-trip failed")
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test 2>&1 | head -20`
Expected: FAIL

- [ ] **Step 3: Implement ConfigEntry**

Create `Sources/PiqleyCore/Manifest/ConfigEntry.swift`:
```swift
import Foundation

/// A single entry in a plugin's config schema.
/// Either a regular value or a secret stored in the system keychain.
public enum ConfigEntry: Codable, Sendable {
    case value(key: String, type: ConfigValueType, value: JSONValue)
    case secret(secretKey: String, type: ConfigValueType)

    private enum CodingKeys: String, CodingKey {
        case key, secretKey = "secret_key", type, value
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(ConfigValueType.self, forKey: .type)
        let hasKey = container.contains(.key)
        let hasSecretKey = container.contains(.secretKey)

        if hasKey && hasSecretKey {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Config entry must have exactly one of 'key' or 'secret_key', not both"
                )
            )
        }

        if let secretKey = try container.decodeIfPresent(String.self, forKey: .secretKey) {
            self = .secret(secretKey: secretKey, type: type)
        } else if let key = try container.decodeIfPresent(String.self, forKey: .key) {
            let value = try container.decode(JSONValue.self, forKey: .value)
            self = .value(key: key, type: type, value: value)
        } else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Config entry must have exactly one of 'key' or 'secret_key'"
                )
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .value(key, type, value):
            try container.encode(key, forKey: .key)
            try container.encode(type, forKey: .type)
            try container.encode(value, forKey: .value)
        case let .secret(secretKey, type):
            try container.encode(secretKey, forKey: .secretKey)
            try container.encode(type, forKey: .type)
        }
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test`
Expected: All tests pass

- [ ] **Step 5: Commit**

```bash
git add Sources/PiqleyCore/Manifest/ConfigEntry.swift Tests/PiqleyCoreTests/ManifestCodingTests.swift
git commit -m "feat: add ConfigEntry type with value and secret cases"
```

---

### Task 7: HookConfig, SetupConfig, BatchProxyConfig

**Files:**
- Create: `Sources/PiqleyCore/Manifest/HookConfig.swift`
- Create: `Sources/PiqleyCore/Manifest/SetupConfig.swift`
- Create: `Sources/PiqleyCore/Manifest/BatchProxyConfig.swift`

- [ ] **Step 1: Write failing tests**

Add to `Tests/PiqleyCoreTests/ManifestCodingTests.swift`:
```swift
@Test func decodeHookConfigFull() throws {
    let json = Data(#"""
    {
        "command": "./bin/publish",
        "args": ["$PIQLEY_FOLDER_PATH"],
        "timeout": 60,
        "protocol": "json",
        "successCodes": [0],
        "warningCodes": [2],
        "criticalCodes": [1]
    }
    """#.utf8)
    let config = try JSONDecoder().decode(HookConfig.self, from: json)
    #expect(config.command == "./bin/publish")
    #expect(config.args == ["$PIQLEY_FOLDER_PATH"])
    #expect(config.timeout == 60)
    #expect(config.pluginProtocol == .json)
    #expect(config.successCodes == [0])
    #expect(config.warningCodes == [2])
    #expect(config.criticalCodes == [1])
    #expect(config.batchProxy == nil)
}

@Test func decodeHookConfigMinimal() throws {
    let json = Data(#"{}"#.utf8)
    let config = try JSONDecoder().decode(HookConfig.self, from: json)
    #expect(config.command == nil)
    #expect(config.args == [])
    #expect(config.timeout == nil)
    #expect(config.pluginProtocol == nil)
}

@Test func decodeSetupConfig() throws {
    let json = Data(#"{"command": "./bin/setup", "args": ["--init"]}"#.utf8)
    let config = try JSONDecoder().decode(SetupConfig.self, from: json)
    #expect(config.command == "./bin/setup")
    #expect(config.args == ["--init"])
}

@Test func decodeSetupConfigNoArgs() throws {
    let json = Data(#"{"command": "./bin/setup"}"#.utf8)
    let config = try JSONDecoder().decode(SetupConfig.self, from: json)
    #expect(config.args == [])
}

@Test func decodeBatchProxyConfig() throws {
    let json = Data(#"{"sort": {"key": "filename", "order": "ascending"}}"#.utf8)
    let config = try JSONDecoder().decode(BatchProxyConfig.self, from: json)
    #expect(config.sort?.key == "filename")
    #expect(config.sort?.order == .ascending)
}

@Test func decodeBatchProxyConfigNoSort() throws {
    let json = Data(#"{}"#.utf8)
    let config = try JSONDecoder().decode(BatchProxyConfig.self, from: json)
    #expect(config.sort == nil)
}

@Test func sortOrderRawValues() {
    #expect(SortOrder.ascending.rawValue == "ascending")
    #expect(SortOrder.descending.rawValue == "descending")
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test 2>&1 | head -20`
Expected: FAIL

- [ ] **Step 3: Implement all three types**

Create `Sources/PiqleyCore/Manifest/HookConfig.swift`:
```swift
import Foundation

/// Configuration for a single hook in a plugin manifest.
public struct HookConfig: Codable, Sendable {
    public let command: String?
    public let args: [String]
    public let timeout: Int?
    public let pluginProtocol: PluginProtocol?
    public let successCodes: [Int32]?
    public let warningCodes: [Int32]?
    public let criticalCodes: [Int32]?
    public let batchProxy: BatchProxyConfig?

    private enum CodingKeys: String, CodingKey {
        case command, args, timeout
        case pluginProtocol = "protocol"
        case successCodes, warningCodes, criticalCodes, batchProxy
    }

    public init(
        command: String? = nil,
        args: [String] = [],
        timeout: Int? = nil,
        pluginProtocol: PluginProtocol? = nil,
        successCodes: [Int32]? = nil,
        warningCodes: [Int32]? = nil,
        criticalCodes: [Int32]? = nil,
        batchProxy: BatchProxyConfig? = nil
    ) {
        self.command = command
        self.args = args
        self.timeout = timeout
        self.pluginProtocol = pluginProtocol
        self.successCodes = successCodes
        self.warningCodes = warningCodes
        self.criticalCodes = criticalCodes
        self.batchProxy = batchProxy
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        command = try container.decodeIfPresent(String.self, forKey: .command)
        args = try container.decodeIfPresent([String].self, forKey: .args) ?? []
        timeout = try container.decodeIfPresent(Int.self, forKey: .timeout)
        pluginProtocol = try container.decodeIfPresent(PluginProtocol.self, forKey: .pluginProtocol)
        successCodes = try container.decodeIfPresent([Int32].self, forKey: .successCodes)
        warningCodes = try container.decodeIfPresent([Int32].self, forKey: .warningCodes)
        criticalCodes = try container.decodeIfPresent([Int32].self, forKey: .criticalCodes)
        batchProxy = try container.decodeIfPresent(BatchProxyConfig.self, forKey: .batchProxy)
    }
}
```

Create `Sources/PiqleyCore/Manifest/SetupConfig.swift`:
```swift
import Foundation

/// Optional setup binary configuration in a plugin manifest.
public struct SetupConfig: Codable, Sendable {
    public let command: String
    public let args: [String]

    public init(command: String, args: [String] = []) {
        self.command = command
        self.args = args
    }

    private enum CodingKeys: String, CodingKey {
        case command, args
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        command = try container.decode(String.self, forKey: .command)
        args = try container.decodeIfPresent([String].self, forKey: .args) ?? []
    }
}
```

Create `Sources/PiqleyCore/Manifest/BatchProxyConfig.swift`:
```swift
import Foundation

/// Sort order for batch proxy image iteration.
public enum SortOrder: String, Codable, Sendable {
    case ascending
    case descending
}

/// Sort configuration for batch proxy mode.
public struct SortConfig: Codable, Sendable {
    public let key: String
    public let order: SortOrder

    public init(key: String, order: SortOrder) {
        self.key = key
        self.order = order
    }
}

/// Batch proxy configuration for single-image tools.
public struct BatchProxyConfig: Codable, Sendable {
    public let sort: SortConfig?

    public init(sort: SortConfig? = nil) {
        self.sort = sort
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test`
Expected: All tests pass

- [ ] **Step 5: Commit**

```bash
git add Sources/PiqleyCore/Manifest/ Tests/PiqleyCoreTests/ManifestCodingTests.swift
git commit -m "feat: add HookConfig, SetupConfig, and BatchProxyConfig types"
```

---

### Task 8: PluginManifest

**Files:**
- Create: `Sources/PiqleyCore/Manifest/PluginManifest.swift`

- [ ] **Step 1: Write failing tests**

Add to `Tests/PiqleyCoreTests/ManifestCodingTests.swift`:
```swift
@Test func decodeFullManifest() throws {
    let json = Data(#"""
    {
        "name": "my-plugin",
        "pluginProtocolVersion": "1",
        "pluginVersion": "2.1.0",
        "config": [
            {"key": "url", "type": "string", "value": null},
            {"secret_key": "api-key", "type": "string"}
        ],
        "setup": {"command": "./bin/setup"},
        "dependencies": ["original", "hashtag"],
        "hooks": {
            "publish": {
                "command": "./bin/publish",
                "protocol": "json"
            },
            "pre-process": {}
        }
    }
    """#.utf8)
    let manifest = try JSONDecoder().decode(PluginManifest.self, from: json)
    #expect(manifest.name == "my-plugin")
    #expect(manifest.pluginProtocolVersion == "1")
    #expect(manifest.pluginVersion == SemanticVersion(2, 1, 0))
    #expect(manifest.config.count == 2)
    #expect(manifest.dependencies == ["original", "hashtag"])
    #expect(manifest.hooks.count == 2)
    #expect(manifest.hooks["publish"]?.command == "./bin/publish")
    #expect(manifest.hooks["pre-process"]?.command == nil)
    #expect(manifest.setup?.command == "./bin/setup")
}

@Test func decodeMinimalManifest() throws {
    let json = Data(#"""
    {
        "name": "simple",
        "pluginProtocolVersion": "1",
        "hooks": {"publish": {"command": "./bin/run"}}
    }
    """#.utf8)
    let manifest = try JSONDecoder().decode(PluginManifest.self, from: json)
    #expect(manifest.name == "simple")
    #expect(manifest.pluginVersion == nil)
    #expect(manifest.config.isEmpty)
    #expect(manifest.dependencies == nil)
    #expect(manifest.setup == nil)
}

@Test func manifestSecretKeys() throws {
    let manifest = PluginManifest(
        name: "test",
        pluginProtocolVersion: "1",
        config: [
            .value(key: "url", type: .string, value: .null),
            .secret(secretKey: "api-key", type: .string),
            .secret(secretKey: "token", type: .string),
        ],
        hooks: ["publish": HookConfig(command: "./run")]
    )
    #expect(manifest.secretKeys == ["api-key", "token"])
}

@Test func manifestValueEntries() throws {
    let manifest = PluginManifest(
        name: "test",
        pluginProtocolVersion: "1",
        config: [
            .value(key: "url", type: .string, value: .null),
            .value(key: "quality", type: .int, value: .number(80)),
            .secret(secretKey: "api-key", type: .string),
        ],
        hooks: ["publish": HookConfig(command: "./run")]
    )
    #expect(manifest.valueEntries.count == 2)
    #expect(manifest.valueEntries[0].key == "url")
    #expect(manifest.valueEntries[1].key == "quality")
}

@Test func manifestUnknownHooks() throws {
    let manifest = PluginManifest(
        name: "test",
        pluginProtocolVersion: "1",
        hooks: [
            "publish": HookConfig(command: "./run"),
            "banana": HookConfig(command: "./banana"),
        ]
    )
    #expect(manifest.unknownHooks() == ["banana"])
}

@Test func manifestEncodeRoundTrip() throws {
    let original = PluginManifest(
        name: "roundtrip",
        pluginProtocolVersion: "1",
        pluginVersion: SemanticVersion(1, 0, 0),
        config: [.value(key: "x", type: .string, value: "default")],
        hooks: ["publish": HookConfig(command: "./run", pluginProtocol: .json)]
    )
    let data = try JSONEncoder().encode(original)
    let decoded = try JSONDecoder().decode(PluginManifest.self, from: data)
    #expect(decoded.name == "roundtrip")
    #expect(decoded.pluginVersion == SemanticVersion(1, 0, 0))
    #expect(decoded.config.count == 1)
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test 2>&1 | head -20`
Expected: FAIL

- [ ] **Step 3: Implement PluginManifest**

Create `Sources/PiqleyCore/Manifest/PluginManifest.swift`:
```swift
import Foundation

/// A plugin's manifest (`manifest.json`), declaring its name, config schema, hooks, and dependencies.
public struct PluginManifest: Codable, Sendable {
    public let name: String
    public let pluginProtocolVersion: String
    public let pluginVersion: SemanticVersion?
    public let config: [ConfigEntry]
    public let setup: SetupConfig?
    public let dependencies: [String]?
    public let hooks: [String: HookConfig]

    public init(
        name: String,
        pluginProtocolVersion: String,
        pluginVersion: SemanticVersion? = nil,
        config: [ConfigEntry] = [],
        setup: SetupConfig? = nil,
        dependencies: [String]? = nil,
        hooks: [String: HookConfig]
    ) {
        self.name = name
        self.pluginProtocolVersion = pluginProtocolVersion
        self.pluginVersion = pluginVersion
        self.config = config
        self.setup = setup
        self.dependencies = dependencies
        self.hooks = hooks
    }

    private enum CodingKeys: String, CodingKey {
        case name, pluginProtocolVersion, pluginVersion, config, setup, dependencies, hooks
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        pluginProtocolVersion = try container.decode(String.self, forKey: .pluginProtocolVersion)
        pluginVersion = try container.decodeIfPresent(SemanticVersion.self, forKey: .pluginVersion)
        config = (try? container.decode([ConfigEntry].self, forKey: .config)) ?? []
        setup = try container.decodeIfPresent(SetupConfig.self, forKey: .setup)
        dependencies = try container.decodeIfPresent([String].self, forKey: .dependencies)
        hooks = try container.decode([String: HookConfig].self, forKey: .hooks)
    }

    /// Returns secret key names from config entries with `secret_key`.
    public var secretKeys: [String] {
        config.compactMap { entry in
            if case let .secret(secretKey, _) = entry { return secretKey }
            return nil
        }
    }

    /// Returns value entries as tuples for easy iteration.
    public var valueEntries: [(key: String, type: ConfigValueType, value: JSONValue)] {
        config.compactMap { entry in
            if case let .value(key, type, value) = entry { return (key, type, value) }
            return nil
        }
    }

    /// Returns hook names in this manifest that are not canonical.
    public func unknownHooks() -> [String] {
        hooks.keys.filter { !Hook.canonicalOrder.map(\.rawValue).contains($0) }
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test`
Expected: All tests pass

- [ ] **Step 5: Commit**

```bash
git add Sources/PiqleyCore/Manifest/PluginManifest.swift Tests/PiqleyCoreTests/ManifestCodingTests.swift
git commit -m "feat: add PluginManifest type with config, hooks, and dependencies"
```

---

### Task 9: Rule, PluginConfig

**Files:**
- Create: `Sources/PiqleyCore/Config/Rule.swift`
- Create: `Sources/PiqleyCore/Config/PluginConfig.swift`
- Create: `Tests/PiqleyCoreTests/ConfigCodingTests.swift`

- [ ] **Step 1: Write failing tests**

Create `Tests/PiqleyCoreTests/ConfigCodingTests.swift`:
```swift
import Testing
@testable import PiqleyCore
import Foundation

@Test func decodeRule() throws {
    let json = Data(#"""
    {
        "match": {
            "hook": "post-process",
            "field": "original:TIFF:Model",
            "pattern": "regex:.*a7r.*"
        },
        "emit": {
            "field": "keywords",
            "values": ["Sony", "A7R Life"]
        }
    }
    """#.utf8)
    let rule = try JSONDecoder().decode(Rule.self, from: json)
    #expect(rule.match.hook == "post-process")
    #expect(rule.match.field == "original:TIFF:Model")
    #expect(rule.match.pattern == "regex:.*a7r.*")
    #expect(rule.emit.field == "keywords")
    #expect(rule.emit.values == ["Sony", "A7R Life"])
}

@Test func decodeRuleMinimal() throws {
    let json = Data(#"""
    {
        "match": {"field": "original:EXIF:LensModel", "pattern": "RF 24-70mm"},
        "emit": {"values": ["Canon RF"]}
    }
    """#.utf8)
    let rule = try JSONDecoder().decode(Rule.self, from: json)
    #expect(rule.match.hook == nil)
    #expect(rule.emit.field == nil)
}

@Test func decodePluginConfigWithRules() throws {
    let json = Data(#"""
    {
        "values": {"url": "https://example.com"},
        "isSetUp": true,
        "rules": [
            {
                "match": {"field": "original:TIFF:Model", "pattern": "Canon"},
                "emit": {"values": ["Canon"]}
            }
        ]
    }
    """#.utf8)
    let config = try JSONDecoder().decode(PluginConfig.self, from: json)
    #expect(config.values["url"] == .string("https://example.com"))
    #expect(config.isSetUp == true)
    #expect(config.rules.count == 1)
}

@Test func decodePluginConfigEmpty() throws {
    let json = Data(#"{}"#.utf8)
    let config = try JSONDecoder().decode(PluginConfig.self, from: json)
    #expect(config.values.isEmpty)
    #expect(config.isSetUp == nil)
    #expect(config.rules.isEmpty)
}

@Test func decodePluginConfigNoRules() throws {
    let json = Data(#"{"values": {"quality": 85}}"#.utf8)
    let config = try JSONDecoder().decode(PluginConfig.self, from: json)
    #expect(config.rules.isEmpty)
}

@Test func pluginConfigEncodeRoundTrip() throws {
    var original = PluginConfig()
    original.values = ["key": .string("val")]
    original.isSetUp = true
    original.rules = [
        Rule(
            match: MatchConfig(hook: "pre-process", field: "original:TIFF:Model", pattern: "Canon"),
            emit: EmitConfig(field: "keywords", values: ["Canon"])
        ),
    ]
    let data = try JSONEncoder().encode(original)
    let decoded = try JSONDecoder().decode(PluginConfig.self, from: data)
    #expect(decoded.values["key"] == .string("val"))
    #expect(decoded.isSetUp == true)
    #expect(decoded.rules.count == 1)
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test 2>&1 | head -20`
Expected: FAIL

- [ ] **Step 3: Implement Rule and PluginConfig**

Create `Sources/PiqleyCore/Config/Rule.swift`:
```swift
import Foundation

/// A declarative metadata matching rule.
public struct Rule: Codable, Sendable {
    public let match: MatchConfig
    public let emit: EmitConfig

    public init(match: MatchConfig, emit: EmitConfig) {
        self.match = match
        self.emit = emit
    }
}

/// Specifies which metadata field and pattern to match against.
public struct MatchConfig: Codable, Sendable {
    /// Pipeline stage to evaluate at. Defaults to "pre-process" when nil.
    public let hook: String?
    /// Namespaced field: "original:TIFF:Model" or "plugin-name:field".
    public let field: String
    /// Pattern with optional prefix: "regex:...", "glob:...", or bare string for exact match.
    public let pattern: String

    public init(hook: String? = nil, field: String, pattern: String) {
        self.hook = hook
        self.field = field
        self.pattern = pattern
    }
}

/// Specifies what values to emit when a rule matches.
public struct EmitConfig: Codable, Sendable {
    /// Field name to write to. Defaults to "keywords" when nil.
    public let field: String?
    /// Values to emit.
    public let values: [String]

    public init(field: String? = nil, values: [String]) {
        self.field = field
        self.values = values
    }
}
```

Create `Sources/PiqleyCore/Config/PluginConfig.swift`:
```swift
import Foundation

/// Per-plugin mutable configuration sidecar (`config.json`).
public struct PluginConfig: Codable, Sendable {
    public var values: [String: JSONValue]
    public var isSetUp: Bool?
    public var rules: [Rule]

    private enum CodingKeys: String, CodingKey {
        case values, isSetUp, rules
    }

    public init(values: [String: JSONValue] = [:], isSetUp: Bool? = nil, rules: [Rule] = []) {
        self.values = values
        self.isSetUp = isSetUp
        self.rules = rules
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        values = (try? container.decodeIfPresent([String: JSONValue].self, forKey: .values)) ?? [:]
        isSetUp = try container.decodeIfPresent(Bool.self, forKey: .isSetUp)
        rules = (try? container.decodeIfPresent([Rule].self, forKey: .rules)) ?? []
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test`
Expected: All tests pass

- [ ] **Step 5: Commit**

```bash
git add Sources/PiqleyCore/Config/ Tests/PiqleyCoreTests/ConfigCodingTests.swift
git commit -m "feat: add Rule, PluginConfig types for declarative metadata rules"
```

---

### Task 10: Payload types

**Files:**
- Create: `Sources/PiqleyCore/Payload/PluginInputPayload.swift`
- Create: `Sources/PiqleyCore/Payload/PluginOutputLine.swift`
- Create: `Tests/PiqleyCoreTests/PayloadCodingTests.swift`

- [ ] **Step 1: Write failing tests**

Create `Tests/PiqleyCoreTests/PayloadCodingTests.swift`:
```swift
import Testing
@testable import PiqleyCore
import Foundation

@Test func encodeInputPayload() throws {
    let payload = PluginInputPayload(
        hook: "publish",
        folderPath: "/tmp/piqley-abc123/",
        pluginConfig: ["url": .string("https://example.com")],
        secrets: ["api-key": "secret123"],
        executionLogPath: "/path/to/log.jsonl",
        dataPath: "/path/to/data",
        logPath: "/path/to/logs",
        dryRun: false,
        state: nil,
        pluginVersion: SemanticVersion(1, 0, 0),
        lastExecutedVersion: nil
    )
    let data = try JSONEncoder().encode(payload)
    let obj = try JSONDecoder().decode(PluginInputPayload.self, from: data)
    #expect(obj.hook == "publish")
    #expect(obj.folderPath == "/tmp/piqley-abc123/")
    #expect(obj.pluginConfig["url"] == .string("https://example.com"))
    #expect(obj.secrets["api-key"] == "secret123")
    #expect(obj.dataPath == "/path/to/data")
    #expect(obj.logPath == "/path/to/logs")
    #expect(obj.dryRun == false)
    #expect(obj.state == nil)
    #expect(obj.pluginVersion == SemanticVersion(1, 0, 0))
    #expect(obj.lastExecutedVersion == nil)
}

@Test func encodeInputPayloadWithState() throws {
    let state: [String: [String: [String: JSONValue]]] = [
        "IMG_001.jpg": [
            "original": ["TIFF:Model": .string("Canon EOS R5")],
        ],
    ]
    let payload = PluginInputPayload(
        hook: "post-process",
        folderPath: "/tmp/test/",
        pluginConfig: [:],
        secrets: [:],
        executionLogPath: "/log.jsonl",
        dataPath: "/data",
        logPath: "/logs",
        dryRun: true,
        state: state,
        pluginVersion: SemanticVersion(2, 0, 0),
        lastExecutedVersion: SemanticVersion(1, 5, 0)
    )
    let data = try JSONEncoder().encode(payload)
    let obj = try JSONDecoder().decode(PluginInputPayload.self, from: data)
    #expect(obj.state?["IMG_001.jpg"]?["original"]?["TIFF:Model"] == .string("Canon EOS R5"))
    #expect(obj.lastExecutedVersion == SemanticVersion(1, 5, 0))
}

@Test func decodeOutputLineResult() throws {
    let json = Data(#"""
    {"type": "result", "success": true, "state": {"IMG_001.jpg": {"keywords": ["Sony"]}}}
    """#.utf8)
    let line = try JSONDecoder().decode(PluginOutputLine.self, from: json)
    #expect(line.type == "result")
    #expect(line.success == true)
    #expect(line.state?["IMG_001.jpg"]?["keywords"] == .array([.string("Sony")]))
}

@Test func decodeOutputLineProgress() throws {
    let json = Data(#"{"type": "progress", "message": "Uploading..."}"#.utf8)
    let line = try JSONDecoder().decode(PluginOutputLine.self, from: json)
    #expect(line.type == "progress")
    #expect(line.message == "Uploading...")
}

@Test func decodeOutputLineImageResult() throws {
    let json = Data(#"{"type": "imageResult", "filename": "photo.jpg", "success": true}"#.utf8)
    let line = try JSONDecoder().decode(PluginOutputLine.self, from: json)
    #expect(line.type == "imageResult")
    #expect(line.filename == "photo.jpg")
    #expect(line.success == true)
    #expect(line.error == nil)
}

@Test func decodeOutputLineImageResultWithError() throws {
    let json = Data(#"{"type": "imageResult", "filename": "fail.jpg", "success": false, "error": "Upload failed"}"#.utf8)
    let line = try JSONDecoder().decode(PluginOutputLine.self, from: json)
    #expect(line.success == false)
    #expect(line.error == "Upload failed")
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test 2>&1 | head -20`
Expected: FAIL

- [ ] **Step 3: Implement payload types**

Create `Sources/PiqleyCore/Payload/PluginInputPayload.swift`:
```swift
import Foundation

/// The JSON payload piqley sends to a plugin on stdin.
public struct PluginInputPayload: Codable, Sendable {
    public let hook: String
    public let folderPath: String
    public let pluginConfig: [String: JSONValue]
    public let secrets: [String: String]
    public let executionLogPath: String
    public let dataPath: String
    public let logPath: String
    public let dryRun: Bool
    public let state: [String: [String: [String: JSONValue]]]?
    public let pluginVersion: SemanticVersion
    public let lastExecutedVersion: SemanticVersion?

    public init(
        hook: String,
        folderPath: String,
        pluginConfig: [String: JSONValue],
        secrets: [String: String],
        executionLogPath: String,
        dataPath: String,
        logPath: String,
        dryRun: Bool,
        state: [String: [String: [String: JSONValue]]]?,
        pluginVersion: SemanticVersion,
        lastExecutedVersion: SemanticVersion?
    ) {
        self.hook = hook
        self.folderPath = folderPath
        self.pluginConfig = pluginConfig
        self.secrets = secrets
        self.executionLogPath = executionLogPath
        self.dataPath = dataPath
        self.logPath = logPath
        self.dryRun = dryRun
        self.state = state
        self.pluginVersion = pluginVersion
        self.lastExecutedVersion = lastExecutedVersion
    }
}
```

Create `Sources/PiqleyCore/Payload/PluginOutputLine.swift`:
```swift
import Foundation

/// A single JSON line written by a plugin to stdout.
public struct PluginOutputLine: Codable, Sendable {
    public let type: String
    public let message: String?
    public let filename: String?
    public let success: Bool?
    public let error: String?
    public let state: [String: [String: JSONValue]]?

    public init(
        type: String,
        message: String? = nil,
        filename: String? = nil,
        success: Bool? = nil,
        error: String? = nil,
        state: [String: [String: JSONValue]]? = nil
    ) {
        self.type = type
        self.message = message
        self.filename = filename
        self.success = success
        self.error = error
        self.state = state
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test`
Expected: All tests pass

- [ ] **Step 5: Commit**

```bash
git add Sources/PiqleyCore/Payload/ Tests/PiqleyCoreTests/PayloadCodingTests.swift
git commit -m "feat: add PluginInputPayload and PluginOutputLine types"
```

---

### Task 11: ManifestValidator

**Files:**
- Create: `Sources/PiqleyCore/Validation/ManifestValidator.swift`
- Create: `Tests/PiqleyCoreTests/ManifestValidatorTests.swift`

- [ ] **Step 1: Write failing tests**

Create `Tests/PiqleyCoreTests/ManifestValidatorTests.swift`:
```swift
import Testing
@testable import PiqleyCore
import Foundation

@Test func validManifestPasses() throws {
    let manifest = PluginManifest(
        name: "valid",
        pluginProtocolVersion: "1",
        pluginVersion: SemanticVersion(1, 0, 0),
        hooks: ["publish": HookConfig(command: "./run", pluginProtocol: .json)]
    )
    let errors = ManifestValidator.validate(manifest)
    #expect(errors.isEmpty)
}

@Test func rulesOnlyHookPasses() throws {
    let manifest = PluginManifest(
        name: "rules-only",
        pluginProtocolVersion: "1",
        pluginVersion: SemanticVersion(1, 0, 0),
        hooks: ["pre-process": HookConfig()]
    )
    let errors = ManifestValidator.validate(manifest)
    #expect(errors.isEmpty)
}

@Test func batchProxyWithJsonProtocolFails() throws {
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
    let errors = ManifestValidator.validate(manifest)
    #expect(errors.count == 1)
    #expect(errors[0].contains("batchProxy"))
}

@Test func batchProxyWithNoCommandFails() throws {
    let manifest = PluginManifest(
        name: "bad",
        pluginProtocolVersion: "1",
        pluginVersion: SemanticVersion(1, 0, 0),
        hooks: ["publish": HookConfig(
            pluginProtocol: .pipe,
            batchProxy: BatchProxyConfig()
        )]
    )
    let errors = ManifestValidator.validate(manifest)
    #expect(errors.count == 1)
    #expect(errors[0].contains("command"))
}

@Test func batchProxyWithPipeProtocolPasses() throws {
    let manifest = PluginManifest(
        name: "good",
        pluginProtocolVersion: "1",
        pluginVersion: SemanticVersion(1, 0, 0),
        hooks: ["publish": HookConfig(
            command: "./run",
            pluginProtocol: .pipe,
            batchProxy: BatchProxyConfig()
        )]
    )
    let errors = ManifestValidator.validate(manifest)
    #expect(errors.isEmpty)
}

@Test func emptyNameFails() throws {
    let manifest = PluginManifest(
        name: "",
        pluginProtocolVersion: "1",
        pluginVersion: SemanticVersion(1, 0, 0),
        hooks: ["publish": HookConfig(command: "./run")]
    )
    let errors = ManifestValidator.validate(manifest)
    #expect(errors.contains { $0.contains("name") })
}

@Test func emptyProtocolVersionFails() throws {
    let manifest = PluginManifest(
        name: "test",
        pluginProtocolVersion: "",
        pluginVersion: SemanticVersion(1, 0, 0),
        hooks: ["publish": HookConfig(command: "./run")]
    )
    let errors = ManifestValidator.validate(manifest)
    #expect(errors.contains { $0.contains("pluginProtocolVersion") })
}

@Test func noHooksFails() throws {
    let manifest = PluginManifest(
        name: "test",
        pluginProtocolVersion: "1",
        pluginVersion: SemanticVersion(1, 0, 0),
        hooks: [:]
    )
    let errors = ManifestValidator.validate(manifest)
    #expect(errors.contains { $0.contains("hook") })
}

@Test func unknownHooksProducesWarnings() throws {
    let manifest = PluginManifest(
        name: "test",
        pluginProtocolVersion: "1",
        pluginVersion: SemanticVersion(1, 0, 0),
        hooks: [
            "publish": HookConfig(command: "./run"),
            "banana": HookConfig(command: "./banana"),
        ]
    )
    let warnings = ManifestValidator.warnings(manifest)
    #expect(warnings.contains { $0.contains("banana") })
    // Unknown hooks are warnings, not errors
    let errors = ManifestValidator.validate(manifest)
    #expect(errors.isEmpty)
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test 2>&1 | head -20`
Expected: FAIL

- [ ] **Step 3: Implement ManifestValidator**

Create `Sources/PiqleyCore/Validation/ManifestValidator.swift`:
```swift
import Foundation

/// Validates plugin manifests for constraint violations.
public enum ManifestValidator {
    /// Returns an array of error messages. Empty array means valid.
    public static func validate(_ manifest: PluginManifest) -> [String] {
        var errors: [String] = []

        if manifest.name.isEmpty {
            errors.append("Manifest 'name' must not be empty")
        }

        if manifest.pluginProtocolVersion.isEmpty {
            errors.append("Manifest 'pluginProtocolVersion' must not be empty")
        }

        if manifest.hooks.isEmpty {
            errors.append("Manifest must declare at least one hook")
        }

        for (hookName, hookConfig) in manifest.hooks {
            if let batchProxy = hookConfig.batchProxy {
                let proto = hookConfig.pluginProtocol ?? .json
                if proto == .json {
                    errors.append(
                        "Hook '\(hookName)': batchProxy is only valid with pipe protocol, not json"
                    )
                }
                if hookConfig.command == nil {
                    errors.append(
                        "Hook '\(hookName)': batchProxy requires a command"
                    )
                }
                _ = batchProxy // silence unused warning
            }
        }

        return errors
    }

    /// Returns an array of warning messages (non-blocking issues).
    public static func warnings(_ manifest: PluginManifest) -> [String] {
        var warnings: [String] = []

        let unknown = manifest.unknownHooks()
        for hookName in unknown {
            warnings.append("Unknown hook '\(hookName)' — not one of the canonical pipeline stages")
        }

        return warnings
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test`
Expected: All tests pass

- [ ] **Step 5: Commit**

```bash
git add Sources/PiqleyCore/Validation/ManifestValidator.swift Tests/PiqleyCoreTests/ManifestValidatorTests.swift
git commit -m "feat: add ManifestValidator with constraint checking"
```

---

### Task 12: Cleanup and final verification

- [ ] **Step 1: Remove placeholder test**

Remove the placeholder `packageCompiles` test from `Tests/PiqleyCoreTests/PiqleyCoreTests.swift` (or delete the file if it only contains the placeholder). Also remove the placeholder `Sources/PiqleyCore/PiqleyCore.swift` if it's empty.

- [ ] **Step 2: Run full test suite**

Run: `swift test`
Expected: All tests pass (should be ~40+ tests across 6 test files)

- [ ] **Step 3: Run build in release mode**

Run: `swift build -c release`
Expected: BUILD SUCCEEDED with no warnings

- [ ] **Step 4: Commit and tag**

```bash
git add -A
git commit -m "chore: remove scaffold placeholders, verify full build"
git tag 0.1.0
```

Do NOT push yet — push happens after implementation review.

---

## Execution Order

Tasks 1 is the scaffold — must be first.

Tasks 2-5 are independent (JSONValue, Hook, ConfigValueType/PluginProtocol, SemanticVersion) — can run in parallel.

Task 6 (ConfigEntry) depends on Tasks 2 and 4 (JSONValue, ConfigValueType).

Task 7 (HookConfig/SetupConfig/BatchProxyConfig) depends on Task 4 (PluginProtocol).

Task 8 (PluginManifest) depends on Tasks 5, 6, 7.

Task 9 (Rule/PluginConfig) depends on Task 2 (JSONValue).

Task 10 (Payload) depends on Tasks 2, 5 (JSONValue, SemanticVersion).

Task 11 (ManifestValidator) depends on Task 8 (PluginManifest).

Task 12 depends on all.

```
1 (scaffold)
├── 2 (JSONValue)
├── 3 (Hook)
├── 4 (ConfigValueType, PluginProtocol)
└── 5 (SemanticVersion)
    ├── 6 (ConfigEntry) ← needs 2, 4
    ├── 7 (HookConfig etc) ← needs 4
    ├── 9 (Rule, PluginConfig) ← needs 2
    └── 10 (Payload) ← needs 2, 5
        └── 8 (PluginManifest) ← needs 5, 6, 7
            └── 11 (ManifestValidator) ← needs 8
                └── 12 (Cleanup)
```
