# Stage File Generation Design

## Summary

Plugins that register standard hooks (e.g., `publish`, `pipeline-finished`) currently produce no stage files during the build process. The CLI requires at least one `stage-*.json` file per plugin, so these plugins fail at discovery time. This design adds automatic stage file generation to the build pipeline by introducing a lightweight `PluginHooks` target and a dedicated `piqley-stage-gen` binary.

## Problem

Three things conspire to prevent stage files from being created:

1. `StandardHook.stageConfig` in PiqleyCore returns an empty `StageConfig` (by design: "managed by the CLI").
2. `HookRegistry.writeStageFiles()` skips hooks with empty stage configs.
3. `piqley-build.sh` never invokes the plugin binary with `--create-stage-files`.

The SDK has a full DSL (`buildStage`, `Binary`, `PreRules`, `PostRules`) for declaring stage configs in Swift, but there is no path for plugin authors using `StandardHook` to use it.

## Design

### 1. HookRegistry API: stage config override closure

Add an overload to `HookRegistry.Registrar.register` that accepts a closure mapping individual hook cases to optional `StageConfig` values:

```swift
let registry = HookRegistry { r in
    r.register(StandardHook.self) { hook in
        switch hook {
        case .publish:
            return buildStage {
                Binary(command: "bin/ghost-cms-publisher", protocol: .json)
            }
        default:
            return nil
        }
    }
}
```

The closure receives each hook case and returns:
- A `StageConfig` for hooks the plugin handles
- `nil` for hooks the plugin does not handle (no stage file written)

When no closure is provided (existing API), behavior falls back to `hook.stageConfig` as today. This preserves backward compatibility for custom hook types that define their own `stageConfig`.

The closure is evaluated eagerly at registration time: during `Registrar.register`, the registrar iterates `H.allCases`, calls the closure for each case, and stores the results. This keeps `writeStageFiles` stateless with no closure invocations at write time.

**Storage mechanism:** `AnyHookBox` gains an optional `stageConfigCache: [String: StageConfig]` dictionary (keyed by `hook.rawValue`), populated eagerly at registration. During `writeStageFiles`, the box checks its cache first, falling back to `hook.stageConfig` if no cache exists.

**Method signatures:**

```swift
// Existing (unchanged)
public func register<H: Hook>(_ type: H.Type)

// New overload
public func register<H: Hook>(_ type: H.Type, stageConfig: @escaping (H) -> StageConfig?)
```

`AnyHookBox.init` gains a corresponding overload:

```swift
init<H: Hook>(_ type: H.Type, stageConfigProvider: ((H) -> StageConfig?)? = nil)
```

When `stageConfigProvider` is non-nil, the init iterates `H.allCases` and populates `stageConfigCache`.

**Changes:** `piqley-plugin-sdk` (`HookRegistry.swift`)

### 2. writeStageFiles logic update

`HookRegistry.writeStageFiles(to:)` is currently `internal`. It must be promoted to `public` so the `piqley-stage-gen` binary (a separate target) can call it.

The method currently iterates all hooks and uses `hook.stageConfig`, skipping empty ones via `config.isEmpty`. The updated logic:

1. For each registered hook, check if the box has a `stageConfigCache` entry for that hook's `rawValue`.
2. If a cached `StageConfig` exists, write it (skip if `isEffectivelyEmpty` to stay consistent with `PluginDiscovery`).
3. If the cache has no entry for this hook, skip (plugin doesn't handle this hook).
4. If no cache exists on the box (no override closure was provided), fall back to `hook.stageConfig` (existing behavior for custom hooks). Use `isEffectivelyEmpty` for consistency on this path too (replacing the current `isEmpty` check).

The existing doc comment ("Used by the SDK's `run()` method when the binary receives `--create-stage-files <dir>`.") must be updated to reflect the new caller.

**Changes:** `piqley-plugin-sdk` (`HookRegistry.swift`)

### 3. Plugin template: three-target layout

The plugin creator script's Swift template currently generates a single executable target. It will generate three targets:

**PluginHooks** (library, `Sources/PluginHooks/`):
- Contains `Hooks.swift` with a public `pluginRegistry` constant
- Depends only on `PiqleyPluginSDK`
- No platform-specific imports; builds on any platform

**Plugin executable** (`Sources/<PluginName>/`):
- Contains `main.swift` calling `Plugin(registry: pluginRegistry).run()`
- Contains `Plugin.swift` with `handle()` and business logic
- Depends on `PluginHooks` (and any platform-specific dependencies)

**piqley-stage-gen** (executable, `Sources/StageGen/`):
- Contains `main.swift` that takes an output directory as a positional argument and calls `pluginRegistry.writeStageFiles(to:)`
- Depends on `PluginHooks` only
- Always builds for the host platform

Template `Package.swift`:

```swift
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
```

**Changes:** `piqley-plugin-sdk` (templates)

### 4. Remove --create-stage-files from PiqleyPlugin.run()

The `--create-stage-files` codepath in `PiqleyPlugin.run()` is replaced by the standalone `piqley-stage-gen` binary. The `run()` method retains only `--piqley-info` handling and the stdin request loop. The call to `registry.writeStageFiles(to:)` from `Plugin.swift` is removed entirely; `writeStageFiles` is only called by the stage-gen binary going forward.

**Changes:** `piqley-plugin-sdk` (`Plugin.swift`)

### 5. Build script: invoke piqley-stage-gen

`piqley-build.sh` gets two new steps between the platform builds and the packager invocation:

1. **Build `piqley-stage-gen` for the host platform:** `$SWIFT build -c release --product piqley-stage-gen`
2. **Run it:** `.build/release/piqley-stage-gen .`

Native `swift build` places the binary at `.build/release/<product>` (no triple subdirectory). This generates `stage-*.json` files in the project root. The packager already copies `stage-*.json` files into the archive.

Since `piqley-stage-gen` depends only on `PluginHooks` (SDK-only), it compiles on any platform regardless of what the plugin's main binary imports. This solves the cross-compilation problem: even if the plugin targets only Linux and the build host is macOS, the stage-gen binary builds and runs natively.

**Changes:** `piqley-plugin-sdk` (`templates/swift/piqley-build.sh`)

## Repos affected

| Repo | What changes |
|------|-------------|
| piqley-plugin-sdk | HookRegistry API, writeStageFiles logic, Plugin.run() simplification, template Package.swift, template sources, piqley-build.sh |
| piqley-core | No changes (StandardHook.stageConfig stays empty; override comes from the registry closure) |
| piqley-cli | No changes (packager and discovery already handle stage-*.json files correctly) |

## Migration for existing plugins

Existing plugins built with the old single-target template will not have `PluginHooks` or `piqley-stage-gen` targets. The updated `piqley-build.sh` would fail trying to build `piqley-stage-gen`.

The build script should detect whether the `piqley-stage-gen` product exists before attempting to build it. If the product does not exist, it skips stage generation and prints a warning directing the plugin author to update their project layout. This keeps old plugins buildable (they just won't get auto-generated stage files, same as today).

The `create-plugin.sh` script generates the new three-target layout for all new plugins going forward.

## Documentation updates

The following documentation must be updated in the affected repos:

- **piqley-plugin-sdk README**: Update the plugin structure section to reflect the three-target layout, and document the `HookRegistry` override closure API with examples.
- **piqley-plugin-sdk CHANGELOG**: Add entry for the new stage file generation feature.
- **Template README** (if one exists in the template): Update to reflect the new project structure.

## What does NOT change

- `StandardHook.stageConfig` in PiqleyCore remains empty. The override mechanism lives in the SDK's `HookRegistry`.
- The packager (`Packager.swift`) continues to copy `stage-*.json` from the project root. No changes needed.
- The CLI's `PluginDiscovery` continues to load stage files as today.
- Custom hook types that implement their own `stageConfig` continue to work via the existing fallback path.
