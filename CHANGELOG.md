# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Unreleased

### Added

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
