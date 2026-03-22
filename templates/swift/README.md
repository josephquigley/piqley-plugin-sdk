# __PLUGIN_NAME__

A [piqley](https://github.com/josephquigley/piqley-cli) plugin built with the [PiqleyPluginSDK](https://github.com/josephquigley/piqley-plugin-sdk).

## Prerequisites

- macOS 15+
- Swift 6.0+ toolchain (Xcode 16+ or standalone)

## Build

```bash
swift build -c release
```

The binary is produced at `.build/release/__PLUGIN_PACKAGE_NAME__`.

## Install

Build a `.piqleyplugin` package and install it:

```bash
./piqley-build.sh
piqley plugin install .build/__PLUGIN_IDENTIFIER__.piqleyplugin
```

Or install manually by copying the release binary and a `manifest.json` into `~/.config/piqley/plugins/__PLUGIN_IDENTIFIER__/`.

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
- `piqley-build.sh` - builds and packages the plugin for installation

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
