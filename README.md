<p align="center">
  <img src="logo.svg" alt="piqley plugin sdk" width="460"/>
</p>

<h1 align="center">piqley plugin sdk</h1>

<p align="center">
  Libraries for building <a href="https://github.com/josephquigley/piqley">piqley</a> plugins in multiple languages.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/macOS-15%2B-blue?logo=apple" alt="macOS">
  <img src="https://img.shields.io/badge/Linux-supported-blue?logo=linux&logoColor=white" alt="Linux">
  <img src="https://img.shields.io/badge/Swift-6.0-orange?logo=swift&logoColor=white" alt="Swift">
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
| Python | [`python/`](python/) | `piqley-plugin-sdk` (pip) |
| TypeScript / Node.js | [`node/`](node/) | `@piqley/plugin-sdk` (npm) |
| Go | [`go/`](go/) | `github.com/josephquigley/piqley-plugin-sdk/go` |

## Getting Started

The quickest way to create a new plugin is with the scaffolding script:

```bash
curl -sL https://raw.githubusercontent.com/josephquigley/piqley-plugin-sdk/main/scripts/create-plugin.sh | bash
```

This walks you through choosing a language, naming your plugin, and setting up the project. You can also scaffold from the CLI if you have piqley installed:

```bash
piqley plugin create my-plugin --language swift
```

> **Rules-only plugins don't need the SDK.** If your plugin only needs declarative rules (match/filter metadata, skip images, etc.) without running any external tool, use `piqley plugin init <identifier>` instead. This creates a plugin with just a manifest and stage files that you can configure entirely through the rules editor (`piqley plugin rules edit <identifier>`).

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

### Manifest

The `manifest.json` declares the plugin's identity, config schema, and optional setup command:

```json
{
  "identifier": "com.example.my-plugin",
  "name": "my-plugin",
  "pluginSchemaVersion": "1",
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

**Pipe protocol** — context is passed via environment variables (`PIQLEY_IMAGE_FOLDER_PATH`, `PIQLEY_HOOK`, `PIQLEY_SECRET_*`, etc.) and stdout/stderr are forwarded directly to the user. Exit code determines success.

### Config

Config entries come in two flavors:

- **Values** (`"key"`) — prompted during setup, stored in `config.json`
- **Secrets** (`"secret_key"`) — prompted during setup, stored in the system keychain

Default values are supported. Piqley handles all prompting and persistence — plugins just declare what they need.

## Installation

**Swift (SPM):**
```swift
dependencies: [
    .package(url: "https://github.com/josephquigley/piqley-plugin-sdk.git", from: "0.1.0")
]
```

**Python:**
```bash
pip install piqley-plugin-sdk
```

**Node.js:**
```bash
npm install @piqley/plugin-sdk
```

**Go:**
```bash
go get github.com/josephquigley/piqley-plugin-sdk/go
```

## License

[MIT](LICENSE)
