# __PLUGIN_NAME__

A [piqley](https://github.com/josephquigley/piqley-cli) plugin built with the [PiqleyPluginSDK](https://github.com/josephquigley/piqley-plugin-sdk).

## Prerequisites

- macOS 15+
- Swift 6.0+ toolchain (Xcode 16+ or standalone)

## Build

```bash
swift build -c release
```

The binary is produced at `.build/release/__PLUGIN_NAME__`.

## Install

Copy the release binary and a `manifest.json` into piqley's plugin directory:

```bash
mkdir -p ~/.config/piqley/plugins/__PLUGIN_NAME__/bin
cp .build/release/__PLUGIN_NAME__ ~/.config/piqley/plugins/__PLUGIN_NAME__/bin/
```

Then create `~/.config/piqley/plugins/__PLUGIN_NAME__/manifest.json` with your plugin's identity and config schema. See the [SDK README](https://github.com/josephquigley/piqley-plugin-sdk) for the manifest format.

Add stage files (e.g. `stage-publish.json`) to configure which hooks run your binary.

## Develop

```bash
# Build in debug mode
swift build

# Run tests
swift test
```

## Plugin Structure

- `Sources/Plugin.swift` - main entry point, routes hooks to handler functions
- `Package.swift` - Swift package manifest
- `piqley-build-manifest.json` - tells `piqley-build` what to package

## Hooks

Edit `Sources/Plugin.swift` to implement logic for the hooks your plugin needs. Remove hooks you don't use from your workflow configuration.

| Hook | When it runs |
|------|-------------|
| `pipeline-start` | Before any processing begins |
| `pre-process` | Before image processing |
| `post-process` | After image processing |
| `publish` | Upload or distribute images |
| `post-publish` | Cleanup, notify, or log |
| `pipeline-finished` | After the pipeline completes (cleanup) |

## Protocol

This plugin uses the JSON protocol. Piqley sends a JSON payload on stdin containing the image folder path, plugin config, secrets, and pipeline state. The plugin writes JSON lines to stdout to report progress and results.

See the [SDK README](https://github.com/josephquigley/piqley-plugin-sdk) for the full protocol reference.
