# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Unreleased

### Removed

- `config.json` sidecar is no longer created or included in `.piqleyplugin` archives
- Python, Node.js/TypeScript, and Go language support (moved to `wip/*-support` branches)

### Fixed

- Swift template uses sanitized package name for target and bin paths instead of dotted identifier
- SDK version resolution uses `git ls-remote --tags` instead of GitHub Releases API (repo uses tags, not releases)
- Cross-compiled builds use separate scratch paths to avoid module cache conflicts with native builds
- Removed `local` keyword from top-level loop in build script
- Deduplicated platform grep matches in build script (paths containing platform names caused duplicates)
- Build script now builds native platform first, then cross-compiles
- Fixed multiline platform output formatting
- Swift bin paths use plugin identifier (the Swift target name) instead of sanitized package name
- Corrected Linux bin paths to `.build-<platform>/release/` (scratch path replaces the triple subdirectory)
- SDK download tries multiple artifact versions (0.1.0, 0.0.1) since the version varies across Swift releases
- Build script SDK availability check uses bundle name instead of triple names
- Build script exits before packaging if any platforms were skipped
- Build script platform detection sed pattern replaced with grep for portability
- `create-plugin.sh` cleans up the scaffolded project directory on failure or user interrupt
- `create-plugin.sh` identifier prompt now defaults to reverse TLD format (e.g. `com.example.my-plugin`)
- SDK detection uses bundle name (`static-linux`) instead of architecture triples, preventing duplicate install attempts
- Build script stage-gen target detection grep pattern now handles SPM's JSON spacing
- Swift build manifest now uses correct platform-specific output paths (e.g. `.build/x86_64-swift-linux-musl/release/`) instead of duplicating the native path for all platforms

### Changed

- All JSON encoding/decoding now uses `JSONEncoder.piqley`/`JSONDecoder.piqley` from PiqleyCore instead of bare initializers
- **BREAKING:** Swift plugin template restructured to three-target layout (PluginHooks library, plugin executable, piqley-stage-gen executable)
- `HookRegistry.writeStageFiles(to:)` promoted from `internal` to `public`
- `writeStageFiles` prefers override cache when available, falls back to `Hook.stageConfig`, uses `isEffectivelyEmpty` instead of `isEmpty`
- Removed `--create-stage-files` codepath from `PiqleyPlugin.run()`
- Minimum PiqleyCore dependency bumped to 0.7.0 (Hook protocol)
- **BREAKING:** `PiqleyPlugin` protocol now requires a `registry: HookRegistry` property
- **BREAKING:** `PluginRequest.hook` is now `any Hook` instead of the old `Hook` enum. Use `request.hook as? StandardHook` for type-casting switch dispatch.
- **BREAKING:** `PluginRequest` init now throws on unrecognized hooks instead of silently falling back to `.preProcess`
- **BREAKING:** `ExecutionLogEntry.hook` is now a `String` instead of the old `Hook` enum
- Plugin template updated to use `HookRegistry` and type-casting switch pattern
- Reverted `pluginSchemaVersion` back to `"1"` across all schemas, templates, tests, and docs (no production consumers)
- Packager and PackagerTests use `PluginFile` and `PluginDirectory` constants from PiqleyCore instead of magic strings
- `BuildManifest.bin` from `[String]` to `[String: [String]]` (platform-keyed dictionary)
- `BuildManifest.data` from `[String]` to `[String: [String]]` (platform-keyed dictionary)
- Packager stages bin/data files into platform subdirectories
- `toPluginManifest()` derives `supportedPlatforms` from bin keys
- **BREAKING:** Renamed `piqley-stage-gen` template target to `piqley-manifest-gen`; directory renamed from `StageGen` to `ManifestGen`
- `piqley-manifest-gen` now generates both stage files and `config-entries.json`
- Build script detects and invokes `piqley-manifest-gen` instead of `piqley-stage-gen`
- Packager loads `config-entries.json` from plugin directory for manifest config instead of `BuildManifest.config`
- `BuildManifest.toPluginManifest()` accepts optional `configOverride` parameter

### Added

- `ConsumedFieldRegistry` DSL for declaring state fields a plugin works with
- `Consumes` component: accepts `StateKey` types (bulk) or individual cases with optional type/description
- `ConsumedFieldRegistry.writeConsumedFields(to:)` writes `consumed-fields.json` for build-time generation
- `BuildManifest.toPluginManifest()` accepts optional `consumedFieldsOverride` parameter
- Packager loads `consumed-fields.json` and injects into manifest during packaging
- `ConfigRegistry` DSL for declaring plugin config values and secrets programmatically
- `Config` typealias (for `Value`) and `Secret` conform to `ConfigComponent` for use in `ConfigRegistry`
- DocC documentation catalog with landing page and dry run article
- Doc comment on `PluginRequest.dryRun` explaining JSON and pipe protocol delivery
- Pipe protocol environment variable reference table in README
- `ConfigRegistry.writeConfigEntries(to:)` writes `config-entries.json` for build-time config generation
- `pluginConfig` export in plugin template Hooks.swift for `ConfigRegistry` declarations
- `HookRegistry.Registrar.register(_:stageConfig:)` overload for declaring stage configs via closure
- `AnyHookBox.stageConfigCache` property for eager evaluation of override closures
- `piqley-stage-gen` executable target in Swift plugin template for build-time stage file generation
- `PluginDirectory.pluginBinary` constant in Hooks.swift template, derived from `__PLUGIN_PACKAGE_NAME__` to avoid magic strings in stage configs
- `piqley-build.sh` auto-detects and invokes `piqley-stage-gen` before packaging
- `create-plugin.sh` renames `__PLUGIN_PACKAGE_NAME__` directories during scaffolding
- `HookRegistry` for resolving hook strings into typed `Hook` protocol values with `register<H: Hook>(_:)` API
- `AnyHookBox` internal type-erased container for hook type registration
- `SDKError.unhandledHook` case for hooks the plugin didn't implement
- `--create-stage-files <dir>` CLI flag on plugin binaries for build-time stage file generation
- `plugin-update.sh` template to update plugin tooling to the latest SDK version
- `-v, --version` flag to build script, reports SDK version from `.piqley-sdk-version`
- `.piqley-sdk-version` stamp file created during scaffolding
- Dynamic SDK version resolution in `create-plugin.sh` (from git tags or GitHub API)
- `-o <path>` option to build script and packager for custom output path
- `--help` flag to build script with usage documentation
- Platform selection prompt in `create-plugin.sh` (macOS/Linux, Linux architecture choice)
- Automatic swiftly and open-source Swift toolchain setup in `piqley-build.sh` and `create-plugin.sh` for cross-compilation
- `./piqley-build.sh clean` to remove all build artifacts
- Multi-platform `piqley-build.sh` template: detects host platform, builds natively, cross-compiles for other targets using Swift SDK bundles, downloads and installs missing SDKs (version-matched)
- `create-plugin.sh` offers to download and install Swift cross-compilation SDKs when targeting platforms other than the host
- Validation that data platform keys are a subset of bin keys in BuildManifest decoder
- `supportedPlatforms` array property in manifest schema for declaring platform compatibility
- Schema version `"2"` support in `pluginSchemaVersion` (manifest schema)
- Build-manifest schema `bin` and `data` updated to platform-keyed object format with `patternProperties`
- Plugin templates (Swift, Go, Node, Python) updated to schema v2 with platform-keyed `bin`
- `pipelineRunId` property on `PluginRequest` for per-run identification
- `pipelineStart` and `pipelineFinished` lifecycle hooks in Swift skeleton
- `scripts/create-plugin.sh` standalone scaffolding script for creating new plugin projects in any language; works via `curl|bash` or locally
- Skeleton templates for Python, Node.js/TypeScript, and Go (Swift already existed)
- Automatic `--piqley-info` probe response in `run()` for binary detection by the CLI
- `not` parameter on `RuleMatch` for negated match conditions
- `RuleEmit.writeBack` case for builder DSL, emitting `action: "writeBack"`
- Extended `imageExtensions` with png, tiff, tif, heic, heif, webp; updated tests
- Skeleton `main.swift` now branches on hook type with dedicated handler methods
- `RuleEmit.skip` case for builder DSL, emitting `action: "skip"` with all other fields nil
- Environment mapping in `hookConfig` schema
- Clone emit cases in `RuleEmit` and `EmitConfig`
- `StageBuilder` with PreRules/Binary/PostRules DSL
- `stage.schema.json` for stage-based architecture
- Stage file inclusion in `.piqleyplugin` archives
- Linux platform support
- `piqley-build-manifest.json` template in Swift skeleton
- Schema conformance tests with JSON Schema validation
- JSON Schema files for manifest, config, build manifest, and plugin I/O
- `MatchField.read()` and `ConfigRule.write` for metadata I/O
- Remove, replace, and removeField emit actions in `RuleEmit`
- Swift plugin skeleton for `piqley plugin create`
- `encode() -> Data` convenience on `PluginManifest`
- `=>` operator and renamed Values/Rules in config builder DSL
- `ExecutionLog` JSONL helper for deduplication
- Config builder DSL with typed rule construction
- Manifest builder DSL with validation
- `MatchField` and `MatchPattern` for typed rule construction
- Mock factory and `CapturedOutput` for testing
- `PiqleyPlugin` protocol with `run()` entry point
- `PluginRequest` and `PluginResponse` with typed accessors
- `PluginState` for typed state writing
- `ResolvedState`, `ImageState`, and `Namespace` for typed state access
- `PluginIO` layer and `SDKError` types
- `StateKey` protocol and `ImageMetadataKey` enum
