# Debug Output

Emit extra diagnostic information when piqley runs in debug mode.

## Overview

When a user passes `--debug` to `piqley process`, every plugin in the pipeline receives a debug signal. Your plugin can check this flag and emit additional diagnostic output to help with troubleshooting.

## Checking the Flag

### JSON Protocol (SDK plugins)

The ``PluginRequest/debug`` property is `true` when debug mode is active:

```swift
func handle(_ request: PluginRequest) async throws -> PluginResponse {
    if request.debug {
        request.reportProgress("[debug] Processing \(imageFiles.count) images")
        request.reportProgress("[debug] Config: \(request.pluginConfig)")
    }
    // ... normal logic
}
```

### Pipe Protocol (CLI tool plugins)

The `PIQLEY_DEBUG` environment variable is set to `"1"` when active, `"0"` otherwise:

```bash
if [ "$PIQLEY_DEBUG" = "1" ]; then
    echo "[debug] Image path: $PIQLEY_IMAGE_PATH"
    echo "[debug] Hook: $PIQLEY_HOOK"
fi
```

### JSON Wire Format

In the JSON input payload sent to plugins over stdin, the field is `debug` (camelCase):

```json
{
    "hook": "publish",
    "imageFolderPath": "/tmp/piqley-abc123/",
    "dryRun": false,
    "debug": true,
    ...
}
```

## Implementation Guidelines

- Use ``PluginRequest/reportProgress(_:)`` to emit debug messages.
- Prefix debug messages with `[debug]` for easy filtering.
- Include information useful for troubleshooting: config values, file counts, API request details, timing.
- Debug mode does not change plugin behavior, only verbosity. Unlike dry run, plugins should still perform all normal operations.

## See Also

- ``PluginRequest/debug``
- ``PluginRequest/reportProgress(_:)``
- <doc:DryRun>
