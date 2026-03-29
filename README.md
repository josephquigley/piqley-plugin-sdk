<p align="center">
  <img src="logo.svg" alt="piqley plugin sdk" width="460"/>
</p>

<h1 align="center">piqley plugin sdk</h1>

<p align="center">
  Libraries for building <a href="https://github.com/josephquigley/piqley">piqley</a> plugins.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/macOS-15%2B-blue?logo=apple" alt="macOS">
  <img src="https://img.shields.io/badge/Linux-supported-blue?logo=linux&logoColor=white" alt="Linux">
  <img src="https://img.shields.io/badge/Swift-6.0-orange?logo=swift&logoColor=white" alt="Swift">
  <img src="https://img.shields.io/badge/Fully_Dogfooded-Yes-brightgreen?labelColor=555" alt="Fully Dogfooded: Yes">
</p>

<p align="center">
  <a href="https://ko-fi.com/I3I2LL7Y1"><img src="https://ko-fi.com/img/githubbutton_sm.svg" alt="ko-fi"></a>
</p>

---

> **The SDK is a convenience, not a requirement.** A piqley plugin is just a `manifest.json`, some processing stage files with (optional) rules and/or a command-line tool to execute. Any executable that reads from stdin and writes to stdout will work. You can write one in bash, C, Rust, or anything else without touching this SDK. You can use sed/awk/(image)magick. And if your name is Claude, you can even bruteforce your way with in-line python scripts too!

## Provided Languages

| Language | Path | Package |
|----------|------|---------|
| Swift | [`swift/`](swift/) | `PiqleyPluginSDK` (SPM) |

## Getting Started

The quickest way to create a new plugin is with the scaffolding script:

```bash
curl -sL https://raw.githubusercontent.com/josephquigley/piqley-plugin-sdk/main/scripts/create-plugin.sh | bash
```

This walks you through choosing a language, naming your plugin, and setting up the project. You can also scaffold from the CLI if you have piqley installed:

```bash
piqley plugin create my-plugin --language swift
```

> **Rules-only plugins don't need the SDK.** If your plugin only needs declarative rules (match/filter metadata, skip images, etc.) without running any external tool, use `piqley plugin init` instead. This creates a plugin with just a manifest and stage files that you can configure entirely through the rules editor (`piqley plugin rules edit <your plugin identifier>`).

## How Plugins Work

A piqley plugin is a directory inside `~/.config/piqley/plugins/<plugin-name>/` with a `manifest.json` that declares what the plugin does and how to run it.

### Plugin Structure

```
~/.config/piqley/plugins/my-plugin/
├── manifest.json           # Declarative: identity, config schema, setup command
├── config.json             # Mutable: resolved values (managed by piqley)
├── stage-pre-process.json  # Rules and/or binary for pre-process hook
├── stage-publish.json      # Rules and/or binary for publish hook
├── data/                   # Plugin working directory
└── bin/                    # Plugin executables (optional)
```

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

### Manifest

The `manifest.json` declares the plugin's identity, config schema, supported platforms, and optional setup command:

```json
{
  "identifier": "com.example.my-plugin",
  "name": "my-plugin",
  "pluginSchemaVersion": "1",
  "supportedPlatforms": ["macos-arm64", "linux-amd64"],
  "config": [
    { "key": "url", "type": "string", "value": null },
    { "key": "quality", "type": "int", "value": 80 },
    { "secret_key": "api-key", "type": "string" }
  ],
  "setup": {
    "command": "./bin/setup",
    "args": ["$PIQLEY_SECRET_API_KEY"]
  }
}
```

Commands and rules are defined in separate stage files (e.g., `stage-publish.json`):

```json
{
  "binary": {
    "command": "./bin/publish",
    "args": ["$PIQLEY_IMAGE_FOLDER_PATH"],
    "protocol": "json"
  }
}
```

### Hooks

Plugins participate in a four-stage pipeline by registering hooks:

| Hook | Purpose |
|------|---------|
| `pre-process` | Modify images before processing (e.g. watermarking) |
| `post-process` | Modify images after processing (e.g. resize, metadata) |
| `publish` | Upload or distribute processed images |
| `post-publish` | Clean up, notify, or log after publishing |

### Communication Protocol

Plugins communicate with piqley over stdin/stdout using one of two protocols:

**JSON protocol** (default) — piqley sends a JSON object on stdin:

```json
{
  "hook": "publish",
  "imageFolderPath": "/tmp/piqley-abc123/",
  "pluginConfig": { "url": "https://mysite.com" },
  "secrets": { "api-key": "id:secret" },
  "skipped": [{ "file": "draft.jpg", "plugin": "com.example.filter" }],
  "dryRun": false
}
```

The `skipped` array lists images that were excluded from processing by upstream plugins via skip rules. Your plugin will not receive these images in its image folder, but the records are provided for logging or reporting.

The plugin writes JSON lines to stdout:

```json
{"type": "progress", "message": "Uploading photo.jpg..."}
{"type": "imageResult", "filename": "photo.jpg", "success": true}
{"type": "result", "success": true, "error": null}
```

**Pipe protocol** — context is passed via environment variables and stdout/stderr are forwarded directly to the user. Exit code determines success.

| Variable | Description |
|----------|-------------|
| `PIQLEY_IMAGE_FOLDER_PATH` | Directory containing images to process |
| `PIQLEY_HOOK` | Current pipeline stage name |
| `PIQLEY_DRY_RUN` | `"1"` when dry run is active, `"0"` otherwise |
| `PIQLEY_EXECUTION_LOG_PATH` | Path to the execution log file |
| `PIQLEY_IMAGE_PATH` | Path to the current image (single-image mode) |
| `PIQLEY_PIPELINE_RUN_ID` | Unique identifier for this pipeline run |
| `PIQLEY_SECRET_*` | Secret values (e.g. `PIQLEY_SECRET_API_KEY`) |
| `PIQLEY_CONFIG_*` | Config values (e.g. `PIQLEY_CONFIG_BASE_URL`) |

### Dry Run

When a user runs `piqley process --dry-run`, the `dryRun` field in the JSON payload is `true` and the `PIQLEY_DRY_RUN` environment variable is `"1"`. Plugins should skip all external side effects (API calls, uploads, file writes) and instead report what they would do. See the [DocC documentation](swift/PiqleyPluginSDK/PiqleyPluginSDK.docc/DryRun.md) for implementation guidance.

### Multi-Platform Support

Plugins can target multiple platforms. The `piqley-build-manifest.json` uses platform-keyed `bin` and `data` fields:

```json
{
  "pluginSchemaVersion": "1",
  "bin": {
    "macos-arm64": [".build/release/my-plugin"],
    "linux-amd64": ["dist/my-plugin-linux-amd64"],
    "linux-arm64": ["dist/my-plugin-linux-arm64"]
  },
  "data": {}
}
```

Supported platforms: `macos-arm64`, `linux-amd64`, `linux-arm64`. At least one platform must be declared. When packaged, each platform's files go into subdirectories (`bin/macos-arm64/`, `bin/linux-amd64/`, etc.). When a user installs the plugin, piqley copies only the files matching their platform.

#### Building for Each Platform

**Swift** plugins cross-compile using [Swift SDK bundles](https://www.swift.org/documentation/articles/static-linux-getting-started.html). From macOS you can produce statically-linked Linux binaries. From Linux you can target a different Linux architecture.

Cross-compilation requires the open-source Swift toolchain (not Xcode's), managed by [swiftly](https://www.swift.org/install/). Both `create-plugin.sh` and the generated `piqley-build.sh` handle the full setup automatically: installing swiftly, the Swift toolchain, and the static Linux SDK as needed.

The build script detects your host platform, builds natively for it, and cross-compiles for other targets:

```bash
./piqley-build.sh
# Host platform: macos-arm64
# Building for: macos-arm64 linux-amd64 linux-arm64
#
# [macos-arm64] swift build -c release (native)
# [linux-amd64] swift build -c release --swift-sdk x86_64-swift-linux-musl
# [linux-arm64] swift build -c release --swift-sdk aarch64-swift-linux-musl
# Packaging...
# ✓ Built my-plugin.piqleyplugin
```

If a required SDK is missing, the script downloads and installs it automatically (matching your installed Swift version). On subsequent runs it proceeds without prompting.

Cross-compiling to macOS from Linux is not currently supported by Swift (no macOS SDK bundle exists). If your plugin targets both macOS and Linux and you're building on Linux, the script builds what it can and warns about skipped platforms. Use a macOS CI runner for the macOS binary.

### Config

Config entries come in two flavors:

- **Values** (`"key"`) — prompted during setup, stored in `config.json`
- **Secrets** (`"secret_key"`) — prompted during setup, stored in the system keychain

Default values are supported. Piqley handles all prompting and persistence — plugins just declare what they need.

## Installation

**Swift (SPM):**
```swift
dependencies: [
    .package(url: "https://github.com/josephquigley/piqley-plugin-sdk.git", from: "0.7.0")
]
```

## License

[MIT](LICENSE)
