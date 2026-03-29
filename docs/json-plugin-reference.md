# JSON Plugin Reference

This document contains the full JSON specifications for piqley plugin files. If you are building a plugin without the Swift SDK (e.g., in bash, Rust, Go, or any other language), this is the authoritative reference for the file formats piqley expects.

For an overview of how plugins work and the Swift DSL, see the [README](../README.md).

## manifest.json

The manifest declares the plugin's identity, config schema, supported platforms, and optional setup command:

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

### Config entries

Config entries come in two flavors:

- **Values** use the `"key"` field. They are prompted during setup and stored in `config.json`.
- **Secrets** use the `"secret_key"` field. They are prompted during setup and stored in the system keychain.

Default values are supported via the `"value"` field. Piqley handles all prompting and persistence.

## Stage files

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

Stage files are named `stage-<hook>.json`, where `<hook>` is one of: `pre-process`, `post-process`, `publish`, `post-publish`.

## Communication Protocol

Plugins communicate with piqley over stdin/stdout using one of two protocols.

### JSON protocol (default)

piqley sends a JSON object on stdin:

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

### Pipe protocol

Context is passed via environment variables and stdout/stderr are forwarded directly to the user. Exit code determines success. See the [README](../README.md#communication-protocol) for the environment variable table.

## fields.json

Declares the fields a plugin works with. Place this file alongside `manifest.json` in your plugin directory:

```json
[
  { "name": "start_date", "type": "string", "description": "Starting date input", "readOnly": false },
  { "name": "locale", "type": "string", "description": "Locale for date parsing", "readOnly": false },
  { "name": "day_diff", "type": "int", "description": "Computed days difference", "readOnly": true },
  { "name": "month_diff", "type": "int", "description": "Computed months difference", "readOnly": true }
]
```

Each entry has:
- `name`: the bare field name
- `type` (optional): type hint ("string", "csv", "bool", "int", "duration")
- `description` (optional): human-readable description
- `readOnly`: if `true`, the field is visible in match conditions but cannot be targeted by emit or write actions in the rules editor. Use this for computed output fields.

The file is placed alongside `manifest.json` in the plugin directory. If no fields are declared, the file can be omitted.

## piqley-build-manifest.json

The build manifest uses platform-keyed `bin` and `data` fields to declare where built artifacts live:

```json
{
  "pluginSchemaVersion": "1",
  "bin": {
    "macos-arm64": [".build/arm64-apple-macosx/release/my-plugin"],
    "linux-amd64": [".build-linux-amd64/x86_64-swift-linux-musl/release/my-plugin"],
    "linux-arm64": [".build-linux-arm64/aarch64-swift-linux-musl/release/my-plugin"]
  },
  "data": {}
}
```

Supported platforms: `macos-arm64`, `linux-amd64`, `linux-arm64`. At least one platform must be declared. When packaged, each platform's files go into subdirectories (`bin/macos-arm64/`, `bin/linux-amd64/`, etc.). When a user installs the plugin, piqley copies only the files matching their platform.
