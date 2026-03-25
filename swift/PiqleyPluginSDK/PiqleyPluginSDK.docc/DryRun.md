# Dry Run Support

Skip destructive operations when piqley runs in preview mode.

## Overview

When a user passes `--dry-run` to `piqley process`, every plugin in the pipeline receives a dry run signal. Your plugin should check this flag and skip external side effects (API calls, file uploads, database writes) while still reporting what it *would* do.

## Checking the Flag

### JSON Protocol (SDK plugins)

The ``PluginRequest/dryRun`` property is `true` when dry run is active:

```swift
func handle(_ request: PluginRequest) async throws -> PluginResponse {
    if request.dryRun {
        request.reportProgress("[dry-run] Would upload \(filename)")
        return .ok
    }
    // ... normal logic
}
```

### Pipe Protocol (CLI tool plugins)

The `PIQLEY_DRY_RUN` environment variable is set to `"1"` when active, `"0"` otherwise:

```bash
if [ "$PIQLEY_DRY_RUN" = "1" ]; then
    echo "Would process $PIQLEY_IMAGE_PATH"
    exit 0
fi
```

### JSON Wire Format

In the JSON input payload sent to plugins over stdin, the field is `dryRun` (camelCase):

```json
{
    "hook": "publish",
    "imageFolderPath": "/tmp/piqley-abc123/",
    "dryRun": true,
    ...
}
```

## Implementation Guidelines

- Skip all network requests, file uploads, and external API calls.
- Skip cache updates (upload caches, schedule caches) since no real work was done.
- Report what *would* happen using ``PluginRequest/reportProgress(_:)``.
- Still report image results via ``PluginRequest/reportImageResult(_:success:error:)`` so piqley can show a complete preview.
- Return ``PluginResponse/ok`` as the response.

## See Also

- ``PluginRequest/dryRun``
- ``PluginRequest/reportProgress(_:)``
