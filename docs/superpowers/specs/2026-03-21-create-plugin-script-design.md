# Create Plugin Script Design

## Summary

A standalone bash script (`scripts/create-plugin.sh`) that scaffolds new piqley plugin projects in any supported language. Works autonomously via `curl | bash` (clones the SDK repo) or locally (uses existing skeleton files). Shares the same skeleton templates in `Skeletons/` that the CLI's `piqley plugin create` command uses.

## Script Flow

### Two modes of operation

**Local mode** (script exists on disk):
1. Detect `Skeletons/` relative to the script's location
2. Use it directly

**Remote mode** (curl pipe bash):
1. No local `Skeletons/` directory found
2. Clone the SDK repo to a temp directory
3. Use `Skeletons/` from the clone
4. Clean up the temp clone on exit (trap)

### Interactive prompts (in order)

1. **Language**: menu selection from `swift`, `python`, `node`, `go`
2. **Plugin name**: free text, sanitized to match CLI rules
3. **Destination directory**: path, defaults to `./<plugin-name>`

### After prompts

1. Validate destination doesn't exist or is empty
2. Copy the skeleton for the chosen language
3. Replace `__PLUGIN_NAME__` and `__SDK_VERSION__` via `sed` in all files
4. Print success message with language-specific next steps

## Name Validation

Matches the CLI's `sanitizePluginIdentifier`:
- Lowercase the input
- Strip characters that aren't alphanumeric, `.`, `-`, or `_`
- Reject empty result
- Reject reserved names: `original`, `skip`
- Show sanitized name if it differs from input, ask for confirmation

## SDK Version

Hardcoded at the top of the script: `SDK_VERSION="0.1.0"`. Updated manually on each release.

## Skeleton Templates

All skeletons live in `Skeletons/<language>/` and use two placeholder variables:
- `__PLUGIN_NAME__` - the sanitized plugin name
- `__SDK_VERSION__` - the hardcoded SDK version

### Swift (existing)

Already exists in `Skeletons/swift/`:
- `Package.swift` - SPM manifest
- `Sources/main.swift` - plugin entry point
- `piqley-build-manifest.json` - build config
- `.gitignore`

### Python (new)

`Skeletons/python/`:
- `pyproject.toml` - project config with `piqley-plugin-sdk>=__SDK_VERSION__` dependency
- `src/__PLUGIN_NAME__/main.py` - stub plugin (read JSON stdin, write result stdout)
- `.gitignore`

Note: the `__PLUGIN_NAME__` directory under `src/` needs to be renamed during scaffolding since it's a directory name, not file content.

### Node (new)

`Skeletons/node/`:
- `package.json` - npm config with `@piqley/plugin-sdk` dependency
- `src/index.ts` - stub plugin in TypeScript
- `tsconfig.json` - TypeScript config
- `.gitignore`

### Go (new)

`Skeletons/go/`:
- `go.mod` - module config with SDK dependency
- `main.go` - stub plugin
- `.gitignore`

## Next Steps Output

Language-specific instructions printed after scaffolding:

- Swift: `cd <dir> && swift build`
- Python: `cd <dir> && pip install -e .`
- Node: `cd <dir> && npm install`
- Go: `cd <dir> && go build`

## Curl Usage

```bash
curl -sL https://raw.githubusercontent.com/josephquigley/piqley-plugin-sdk/main/scripts/create-plugin.sh | bash
```

## Shared Contract with CLI

The `Skeletons/` directory is the single source of truth. Both the CLI's `SkeletonFetcher` (Swift) and this bash script consume the same template files with the same `__PLUGIN_NAME__` / `__SDK_VERSION__` placeholders. The substitution logic is duplicated (Swift in CLI, sed in script) but trivial.
