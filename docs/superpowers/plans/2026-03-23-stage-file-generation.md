# Stage File Generation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Enable automatic stage file generation during plugin builds so plugins using StandardHook produce valid stage-*.json files.

**Architecture:** Add a stage config override closure to HookRegistry, split the plugin template into three SPM targets (PluginHooks library, plugin executable, stage-gen executable), and update the build script to invoke the stage-gen binary before packaging.

**Tech Stack:** Swift 6.0, Swift Package Manager, PiqleyCore, PiqleyPluginSDK, bash

**Spec:** `docs/superpowers/specs/2026-03-23-stage-file-generation-design.md`

---

### Task 1: Add stageConfigCache to AnyHookBox

**Files:**
- Modify: `swift/PiqleyPluginSDK/AnyHookBox.swift`
- Test: `swift/Tests/PiqleyPluginSDKTests.swift`

- [ ] **Step 1: Write failing test for AnyHookBox with stage config cache**

In `swift/Tests/PiqleyPluginSDKTests.swift`, add:

```swift
@Test func anyHookBoxCachesStageConfigs() {
    let box = AnyHookBox(StandardHook.self) { hook in
        switch hook {
        case .publish:
            return StageConfig(binary: HookConfig(command: "bin/test"))
        default:
            return nil
        }
    }
    #expect(box.stageConfigCache?["publish"] != nil)
    #expect(box.stageConfigCache?["publish"]?.binary?.command == "bin/test")
    #expect(box.stageConfigCache?["pre-process"] == nil)
}

@Test func anyHookBoxWithoutOverrideHasNilCache() {
    let box = AnyHookBox(StandardHook.self)
    #expect(box.stageConfigCache == nil)
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd /Users/wash/Developer/tools/piqley/piqley-plugin-sdk && swift test --filter "anyHookBox"`
Expected: Compilation error (no stageConfigCache property, no init overload)

- [ ] **Step 3: Implement AnyHookBox changes**

Replace `swift/PiqleyPluginSDK/AnyHookBox.swift` with:

```swift
import PiqleyCore

/// Internal type-erased container for a ``Hook``-conforming type.
struct AnyHookBox: Sendable {
    private let _resolve: @Sendable (String) -> (any Hook)?
    private let _allHooks: @Sendable () -> [any Hook]

    /// Cached stage configs from the override closure, keyed by hook rawValue.
    /// nil when no override closure was provided.
    let stageConfigCache: [String: StageConfig]?

    init<H: Hook>(_ type: H.Type) {
        _resolve = { H(rawValue: $0) }
        _allHooks = { Array(H.allCases) }
        stageConfigCache = nil
    }

    init<H: Hook>(_ type: H.Type, stageConfigProvider: @escaping (H) -> StageConfig?) {
        _resolve = { H(rawValue: $0) }
        _allHooks = { Array(H.allCases) }
        var cache: [String: StageConfig] = [:]
        for hook in H.allCases {
            if let config = stageConfigProvider(hook) {
                cache[hook.rawValue] = config
            }
        }
        stageConfigCache = cache
    }

    func resolve(_ rawValue: String) -> (any Hook)? { _resolve(rawValue) }
    var allHooks: [any Hook] { _allHooks() }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd /Users/wash/Developer/tools/piqley/piqley-plugin-sdk && swift test --filter "anyHookBox"`
Expected: PASS

- [ ] **Step 5: Commit**

Message: `feat: add stageConfigCache to AnyHookBox for override closures`

---

### Task 2: Add register overload to HookRegistry.Registrar

**Files:**
- Modify: `swift/PiqleyPluginSDK/HookRegistry.swift`
- Test: `swift/Tests/PiqleyPluginSDKTests.swift`

- [ ] **Step 1: Write failing test for register with stage config closure**

In `swift/Tests/PiqleyPluginSDKTests.swift`, add:

```swift
@Test func registryWithStageConfigOverride() {
    let registry = HookRegistry { r in
        r.register(StandardHook.self) { hook in
            switch hook {
            case .publish:
                return StageConfig(binary: HookConfig(command: "bin/test-plugin"))
            default:
                return nil
            }
        }
    }
    // Resolve still works
    let hook = registry.resolve("publish")
    #expect(hook != nil)
    #expect(hook?.rawValue == "publish")

    // All hooks still enumerated
    #expect(registry.allHooks.count == StandardHook.allCases.count)
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /Users/wash/Developer/tools/piqley/piqley-plugin-sdk && swift test --filter "registryWithStageConfigOverride"`
Expected: Compilation error (no register overload accepting closure)

- [ ] **Step 3: Add register overload**

In `swift/PiqleyPluginSDK/HookRegistry.swift`, add to the `Registrar` class:

```swift
/// Register a ``Hook``-conforming enum type with a stage config override.
/// The closure is evaluated eagerly for each case. Return a ``StageConfig``
/// for hooks the plugin handles, or `nil` to skip.
public func register<H: Hook>(_ type: H.Type, stageConfig: @escaping (H) -> StageConfig?) {
    boxes.append(AnyHookBox(type, stageConfigProvider: stageConfig))
}
```

Also update the doc comment on HookRegistry to show the new API:

```swift
/// ```swift
/// let registry = HookRegistry { r in
///     r.register(StandardHook.self) { hook in
///         switch hook {
///         case .publish:
///             return buildStage { Binary(command: "bin/my-plugin") }
///         default:
///             return nil
///         }
///     }
/// }
/// ```
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd /Users/wash/Developer/tools/piqley/piqley-plugin-sdk && swift test --filter "registryWithStageConfigOverride"`
Expected: PASS

- [ ] **Step 5: Commit**

Message: `feat: add register overload with stageConfig closure to HookRegistry`

---

### Task 3: Update writeStageFiles to use cache and make public

**Files:**
- Modify: `swift/PiqleyPluginSDK/HookRegistry.swift`
- Test: `swift/Tests/StageBuilderTests.swift`

- [ ] **Step 1: Write failing test for writeStageFiles with override**

In `swift/Tests/StageBuilderTests.swift`, add:

```swift
@Test func writeStageFilesUsesOverrideCache() throws {
    let registry = HookRegistry { r in
        r.register(StandardHook.self) { hook in
            switch hook {
            case .publish:
                return buildStage {
                    Binary(command: "bin/test-plugin", protocol: .json)
                }
            default:
                return nil
            }
        }
    }

    let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tempDir) }

    try registry.writeStageFiles(to: tempDir)

    // Only publish should have a stage file
    let files = try FileManager.default.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
    #expect(files.count == 1)
    #expect(files[0].lastPathComponent == "stage-publish.json")

    let data = try Data(contentsOf: files[0])
    let config = try JSONDecoder().decode(StageConfig.self, from: data)
    #expect(config.binary?.command == "bin/test-plugin")
    #expect(config.binary?.pluginProtocol == .json)
}

@Test func writeStageFilesFallbackProducesNothingForEmptyStageConfig() throws {
    // StandardHook.stageConfig returns empty configs, so no files should be written
    let registry = HookRegistry { r in
        r.register(StandardHook.self)
    }

    let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tempDir) }

    try registry.writeStageFiles(to: tempDir)

    let files = try FileManager.default.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
    #expect(files.isEmpty)
}

@Test func writeStageFilesSkipsEffectivelyEmpty() throws {
    let registry = HookRegistry { r in
        r.register(StandardHook.self) { hook in
            switch hook {
            case .publish:
                return StageConfig(binary: HookConfig(command: ""))
            default:
                return nil
            }
        }
    }

    let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tempDir) }

    try registry.writeStageFiles(to: tempDir)

    let files = try FileManager.default.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
    #expect(files.isEmpty)
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd /Users/wash/Developer/tools/piqley/piqley-plugin-sdk && swift test --filter "writeStageFiles"`
Expected: Compilation error (writeStageFiles is internal)

- [ ] **Step 3: Rewrite writeStageFiles**

Replace the `writeStageFiles` extension in `swift/PiqleyPluginSDK/HookRegistry.swift`:

```swift
/// Writes stage files for registered hooks to the given directory.
///
/// For hooks registered with a stage config override closure, the cached
/// configs are used. For hooks without an override, falls back to
/// ``Hook/stageConfig``. Effectively empty configs are skipped.
extension HookRegistry {
    public func writeStageFiles(to directory: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        for box in boxes {
            if let cache = box.stageConfigCache {
                // Override path: write cached configs
                for (hookName, config) in cache {
                    guard !config.isEffectivelyEmpty else { continue }
                    let filename = "\(PluginFile.stagePrefix)\(hookName)\(PluginFile.stageSuffix)"
                    let data = try encoder.encode(config)
                    try data.write(to: directory.appendingPathComponent(filename), options: .atomic)
                }
            } else {
                // Fallback path: use hook.stageConfig
                for hook in box.allHooks {
                    let config = hook.stageConfig
                    guard !config.isEffectivelyEmpty else { continue }
                    let filename = "\(PluginFile.stagePrefix)\(hook.rawValue)\(PluginFile.stageSuffix)"
                    let data = try encoder.encode(config)
                    try data.write(to: directory.appendingPathComponent(filename), options: .atomic)
                }
            }
        }
    }
}
```

Note: `writeStageFiles` is in an extension in the same file as `HookRegistry`, so it can access `private` members. No access modifier changes needed.

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd /Users/wash/Developer/tools/piqley/piqley-plugin-sdk && swift test --filter "writeStageFiles"`
Expected: PASS

- [ ] **Step 5: Run full test suite**

Run: `cd /Users/wash/Developer/tools/piqley/piqley-plugin-sdk && swift test`
Expected: All tests pass

- [ ] **Step 6: Commit**

Message: `feat: make writeStageFiles public and use stageConfigCache with isEffectivelyEmpty`

---

### Task 4: Remove --create-stage-files from PiqleyPlugin.run()

**Files:**
- Modify: `swift/PiqleyPluginSDK/Plugin.swift`
- Test: `swift/Tests/PluginTests.swift`

- [ ] **Step 1: Remove the --create-stage-files block from Plugin.swift**

In `swift/PiqleyPluginSDK/Plugin.swift`, remove lines 22-41 (the entire `--create-stage-files` if-block):

```swift
// Remove this entire block:
// Handle --create-stage-files <output-dir>
if let flagIndex = CommandLine.arguments.firstIndex(of: "--create-stage-files") {
    ...
    Foundation.exit(0)
}
```

- [ ] **Step 2: Run full test suite**

Run: `cd /Users/wash/Developer/tools/piqley/piqley-plugin-sdk && swift test`
Expected: All tests pass (no existing tests depend on `--create-stage-files` since it exits the process)

- [ ] **Step 3: Commit**

Message: `refactor: remove --create-stage-files codepath from PiqleyPlugin.run()`

---

### Task 5: Restructure Swift template to three-target layout

**Files:**
- Delete: `templates/swift/Sources/Plugin.swift`
- Create: `templates/swift/Sources/PluginHooks/Hooks.swift`
- Create: `templates/swift/Sources/__PLUGIN_PACKAGE_NAME__/main.swift`
- Create: `templates/swift/Sources/__PLUGIN_PACKAGE_NAME__/Plugin.swift`
- Create: `templates/swift/Sources/StageGen/main.swift`
- Modify: `templates/swift/Package.swift`

- [ ] **Step 1: Delete old flat Plugin.swift**

Delete `templates/swift/Sources/Plugin.swift`.

- [ ] **Step 2: Create Sources/PluginHooks/Hooks.swift**

```swift
import PiqleyPluginSDK
import PiqleyCore

public let pluginRegistry = HookRegistry { r in
    r.register(StandardHook.self) { hook in
        switch hook {
        case .pipelineStart:
            return nil
        case .preProcess:
            return nil
        case .postProcess:
            return nil
        case .publish:
            return nil
        case .postPublish:
            return nil
        case .pipelineFinished:
            return nil
        }
    }
}
```

- [ ] **Step 3: Create Sources/__PLUGIN_PACKAGE_NAME__/Plugin.swift**

```swift
import PiqleyPluginSDK
import PiqleyCore
import PluginHooks

struct Plugin: PiqleyPlugin {
    let registry = pluginRegistry

    func handle(_ request: PluginRequest) async throws -> PluginResponse {
        switch request.hook {
        case let h as StandardHook:
            switch h {
            case .pipelineStart:
                return try await pipelineStart(request)
            case .preProcess:
                return try await preProcess(request)
            case .postProcess:
                return try await postProcess(request)
            case .publish:
                return try await publish(request)
            case .postPublish:
                return try await postPublish(request)
            case .pipelineFinished:
                return try await pipelineFinished(request)
            }
        default:
            throw SDKError.unhandledHook(request.hook.rawValue)
        }
    }

    private func pipelineStart(_ request: PluginRequest) async throws -> PluginResponse {
        // TODO: Add pipeline-start logic
        return .ok
    }

    private func preProcess(_ request: PluginRequest) async throws -> PluginResponse {
        // TODO: Add pre-process logic
        return .ok
    }

    private func postProcess(_ request: PluginRequest) async throws -> PluginResponse {
        // TODO: Add post-process logic
        return .ok
    }

    private func publish(_ request: PluginRequest) async throws -> PluginResponse {
        // TODO: Add publish logic
        return .ok
    }

    private func postPublish(_ request: PluginRequest) async throws -> PluginResponse {
        // TODO: Add post-publish logic
        return .ok
    }

    private func pipelineFinished(_ request: PluginRequest) async throws -> PluginResponse {
        // TODO: Add pipeline-finished logic
        return .ok
    }
}
```

- [ ] **Step 4: Create Sources/__PLUGIN_PACKAGE_NAME__/main.swift**

```swift
await Plugin().run()
```

`Plugin` is defined in the same target and sets `let registry = pluginRegistry` in its declaration, so no arguments needed.

- [ ] **Step 5: Create Sources/StageGen/main.swift**

```swift
import Foundation
import PluginHooks

guard CommandLine.arguments.count > 1 else {
    FileHandle.standardError.write(Data("Usage: piqley-stage-gen <output-directory>\n".utf8))
    exit(1)
}

let outputDir = URL(fileURLWithPath: CommandLine.arguments[1])
try pluginRegistry.writeStageFiles(to: outputDir)
```

- [ ] **Step 6: Update template Package.swift**

Replace `templates/swift/Package.swift` with:

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "__PLUGIN_PACKAGE_NAME__",
    platforms: [.macOS(.v15)],
    dependencies: [
        .package(
            url: "https://github.com/josephquigley/piqley-plugin-sdk",
            .upToNextMajor(from: "__SDK_VERSION__")
        ),
    ],
    targets: [
        .target(
            name: "PluginHooks",
            dependencies: [
                .product(name: "PiqleyPluginSDK", package: "piqley-plugin-sdk"),
            ],
            path: "Sources/PluginHooks"
        ),
        .executableTarget(
            name: "__PLUGIN_PACKAGE_NAME__",
            dependencies: ["PluginHooks"],
            path: "Sources/__PLUGIN_PACKAGE_NAME__"
        ),
        .executableTarget(
            name: "piqley-stage-gen",
            dependencies: ["PluginHooks"],
            path: "Sources/StageGen"
        ),
    ]
)
```

- [ ] **Step 7: Commit**

Message: `feat: restructure Swift template to three-target layout for stage generation`

---

### Task 6: Update create-plugin.sh to rename __PLUGIN_PACKAGE_NAME__ directories

**Files:**
- Modify: `scripts/create-plugin.sh`

- [ ] **Step 1: Add directory rename for __PLUGIN_PACKAGE_NAME__**

In `scripts/create-plugin.sh`, after the existing `__PLUGIN_IDENTIFIER__` directory rename block (line 248-252), add:

```bash
# Rename __PLUGIN_PACKAGE_NAME__ directories (e.g. Swift executable target source dir)
find "$dest" -depth -type d -name '__PLUGIN_PACKAGE_NAME__' | while read -r dir; do
    local parent
    parent="$(dirname "$dir")"
    mv "$dir" "$parent/$package_name"
done
```

Important: this block must appear AFTER the `package_name` variable is derived (line 254-256). Move the `package_name` derivation before both directory rename blocks.

- [ ] **Step 2: Commit**

Message: `fix: rename __PLUGIN_PACKAGE_NAME__ directories in create-plugin.sh`

---

### Task 7: Update piqley-build.sh to invoke piqley-stage-gen

**Files:**
- Modify: `templates/swift/piqley-build.sh`

- [ ] **Step 1: Add stage generation steps to build script**

In `templates/swift/piqley-build.sh`, after the platform build loops (after the skipped platforms check, around line 304) and before the "Packaging..." section, add:

```bash
# --- Stage file generation ---

# Check if piqley-stage-gen target exists in this project
if "$SWIFT" package describe --type json 2>/dev/null | grep -q '"name":"piqley-stage-gen"'; then
    echo "Generating stage files..."
    "$SWIFT" build -c release --product piqley-stage-gen
    .build/release/piqley-stage-gen .
    echo ""
else
    echo "Warning: No piqley-stage-gen target found. Stage files will not be auto-generated."
    echo "Update your project layout to the latest SDK template for automatic stage generation."
    echo ""
fi
```

- [ ] **Step 2: Commit**

Message: `feat: invoke piqley-stage-gen in build script for stage file generation`

---

### Task 8: Update documentation

**Files:**
- Modify: `README.md`
- Modify: `CHANGELOG.md`

- [ ] **Step 1: Update README Plugin Structure section**

In `README.md`, update the "Plugin Structure" section to mention stage files are auto-generated during build. Add a brief note about the three-target layout for Swift plugins after the existing structure diagram.

After the existing structure diagram, add:

```markdown
### Swift Plugin Structure

Swift plugins built with the SDK use a three-target layout:

```
Sources/
├── PluginHooks/        # Hook registry + stage configs (SDK-only deps)
│   └── Hooks.swift
├── <plugin-name>/      # Plugin binary (business logic)
│   ├── main.swift
│   └── Plugin.swift
└── StageGen/           # Stage file generator (built at package time)
    └── main.swift
```

The `PluginHooks` target declares which hooks your plugin handles and their stage configurations using the SDK's DSL:

```swift
public let pluginRegistry = HookRegistry { r in
    r.register(StandardHook.self) { hook in
        switch hook {
        case .publish:
            return buildStage {
                Binary(command: "bin/my-plugin", protocol: .json)
            }
        default:
            return nil
        }
    }
}
```

Stage files are generated automatically during `./piqley-build.sh`. The `piqley-stage-gen` binary builds for the host platform and writes `stage-*.json` files before packaging.
```

- [ ] **Step 2: Update CHANGELOG**

In `CHANGELOG.md`, under `## Unreleased`, add to the `### Changed` section:

```markdown
- **BREAKING:** Swift plugin template restructured to three-target layout (PluginHooks, plugin executable, piqley-stage-gen)
- `HookRegistry.writeStageFiles(to:)` promoted from `internal` to `public`
- `writeStageFiles` uses `isEffectivelyEmpty` instead of `isEmpty` for consistency with CLI discovery
- Removed `--create-stage-files` codepath from `PiqleyPlugin.run()`
```

And add to the `### Added` section:

```markdown
- `HookRegistry.Registrar.register(_:stageConfig:)` overload for declaring stage configs via override closure
- `AnyHookBox` stage config cache for eager evaluation of override closures
- `piqley-stage-gen` executable target in Swift plugin template for build-time stage file generation
- `piqley-build.sh` auto-detects and invokes `piqley-stage-gen` before packaging
- `create-plugin.sh` renames `__PLUGIN_PACKAGE_NAME__` directories during scaffolding
```

- [ ] **Step 3: Commit**

Message: `docs: update README and CHANGELOG for stage file generation`

---

### Task 9: Run full test suite and verify

- [ ] **Step 1: Run full SDK test suite**

Run: `cd /Users/wash/Developer/tools/piqley/piqley-plugin-sdk && swift test`
Expected: All tests pass

- [ ] **Step 2: Verify template structure**

Run: `find templates/swift/Sources -type f | sort`
Expected:
```
templates/swift/Sources/PluginHooks/Hooks.swift
templates/swift/Sources/StageGen/main.swift
templates/swift/Sources/__PLUGIN_PACKAGE_NAME__/Plugin.swift
templates/swift/Sources/__PLUGIN_PACKAGE_NAME__/main.swift
```

- [ ] **Step 3: Verify no regressions in existing tests**

Run: `cd /Users/wash/Developer/tools/piqley/piqley-plugin-sdk && swift test 2>&1 | tail -5`
Expected: "Test Suite ... passed" with 0 failures

---

## Parallelization Notes

Tasks 1-3 are sequential (each builds on the previous).
Task 4 is independent of Tasks 1-3 (removes code, no new deps).
Tasks 5-6 are independent of Tasks 1-4 (template changes only).
Task 7 is independent (bash script only).
Task 8 is independent (docs only).
Task 9 depends on all previous tasks.

**Parallel groups:**
- Group A: Tasks 1 → 2 → 3 (HookRegistry + AnyHookBox + writeStageFiles)
- Group B: Task 4 (remove --create-stage-files)
- Group C: Tasks 5 → 6 → 7 (template restructure + create-plugin.sh + build script; Task 7 modifies the template build script created in Task 5)
- Group D: Task 8 (docs)
- Final: Task 9 (verification, after all groups merge)
