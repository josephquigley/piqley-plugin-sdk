<p align="center">
  <img src="logo.svg" alt="piqley plugin sdk" width="460"/>
</p>

<h1 align="center">piqley plugin sdk</h1>

<p align="center">
  Libraries for building <a href="https://github.com/josephquigley/piqley">piqley</a> plugins in multiple languages.
</p>

[![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/I3I2LL7Y1)
---

> **The SDK is a convenience, not a requirement.** A piqley plugin is just a `manifest.json`, some processing stage files with (optional) rules and/or a command-line tool to execute. Any executable that reads from stdin and writes to stdout will work. You can write one in bash, C, Rust, or anything else without touching this SDK. You can use sed/awk/(image)magick. And if your name is Claude, you can even bruteforce your way with in-line python scripts too!

## Provided Languages

| Language | Path | Package |
|----------|------|---------|
| Swift | [`swift/`](swift/) | `PiqleyPluginSDK` (SPM) |
| Python | [`python/`](python/) | `piqley-plugin-sdk` (pip) |
| TypeScript / Node.js | [`node/`](node/) | `@piqley/plugin-sdk` (npm) |
| Go | [`go/`](go/) | `github.com/josephquigley/piqley-plugin-sdk/go` |

## How Plugins Work

A piqley plugin is a directory inside `~/.config/piqley/plugins/<plugin-name>/` with a `manifest.json` that declares what the plugin does and how to run it.

### Plugin Structure

```
~/.config/piqley/plugins/my-plugin/
├── manifest.json    # Declarative: config schema, hooks, setup command
├── config.json      # Mutable: resolved values (managed by piqley)
├── data/            # Plugin working directory
└── bin/             # Plugin executables (optional)
```

### Manifest

The `manifest.json` declares the plugin's name, config schema, hooks, and optional setup command:

```json
{
  "name": "my-plugin",
  "pluginProtocolVersion": "1",
  "config": [
    { "key": "url", "type": "string", "value": null },
    { "key": "quality", "type": "int", "value": 80 },
    { "secret_key": "api-key", "type": "string" }
  ],
  "setup": {
    "command": "./bin/setup",
    "args": ["$PIQLEY_SECRET_API_KEY"]
  },
  "hooks": {
    "publish": {
      "command": "./bin/publish",
      "args": ["$PIQLEY_IMAGE_FOLDER_PATH"],
      "protocol": "json"
    }
  }
}
```

### Hooks

Plugins participate in a five-stage pipeline by registering hooks:

| Hook | Purpose |
|------|---------|
| `pre-process` | Modify images before processing (e.g. watermarking) |
| `post-process` | Modify images after processing (e.g. resize, metadata) |
| `publish` | Upload or distribute processed images |
| `schedule` | Schedule or queue posts |
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
  "dryRun": false
}
```

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
