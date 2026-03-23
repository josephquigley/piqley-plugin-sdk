# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Unreleased

### Fixed

- Cross-compiled builds use separate scratch paths to avoid module cache conflicts with native builds
- Removed `local` keyword from top-level loop in build script
- Deduplicated platform grep matches in build script (paths containing platform names caused duplicates)
- Build script now builds native platform first, then cross-compiles
- Fixed multiline platform output formatting
- SDK download tries multiple artifact versions (0.1.0, 0.0.1) since the version varies across Swift releases
- Build script SDK availability check uses bundle name instead of triple names
- Build script exits before packaging if any platforms were skipped
- Build script platform detection sed pattern replaced with grep for portability
- `create-plugin.sh` cleans up the scaffolded project directory on failure or user interrupt
- `create-plugin.sh` identifier prompt now defaults to reverse TLD format (e.g. `com.example.my-plugin`)
- SDK detection uses bundle name (`static-linux`) instead of architecture triples, preventing duplicate install attempts
- Swift build manifest now uses correct platform-specific output paths (e.g. `.build/x86_64-swift-linux-musl/release/`) instead of duplicating the native path for all platforms

### Changed

- Reverted `pluginSchemaVersion` back to `"1"` across all schemas, templates, tests, and docs (no production consumers)
- Packager and PackagerTests use `PluginFile` and `PluginDirectory` constants from PiqleyCore instead of magic strings
- `BuildManifest.bin` from `[String]` to `[String: [String]]` (platform-keyed dictionary)
- `BuildManifest.data` from `[String]` to `[String: [String]]` (platform-keyed dictionary)
- Packager stages bin/data files into platform subdirectories
- `toPluginManifest()` derives `supportedPlatforms` from bin keys

### Added

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
