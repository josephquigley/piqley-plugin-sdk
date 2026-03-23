#!/usr/bin/env bash
#
# create-plugin.sh - Scaffold a new piqley plugin project
#
# Usage:
#   Local:  ./scripts/create-plugin.sh
#   Remote: curl -sL https://raw.githubusercontent.com/josephquigley/piqley-plugin-sdk/main/scripts/create-plugin.sh | bash
#
set -euo pipefail

SDK_VERSION="0.1.0"
SDK_REPO="https://github.com/josephquigley/piqley-plugin-sdk.git"
RESERVED_NAMES="original skip"

# --- Cleanup ---

TEMP_CLONE=""
cleanup() {
    if [[ -n "$TEMP_CLONE" && -d "$TEMP_CLONE" ]]; then
        rm -rf "$TEMP_CLONE"
    fi
}
trap cleanup EXIT

# --- Find templates ---

find_templates_dir() {
    # Try relative to script location (local mode)
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
    local local_templates="$script_dir/../templates"
    if [[ -d "$local_templates" ]]; then
        echo "$(cd "$local_templates" && pwd)"
        return
    fi

    # Remote mode: clone the SDK repo
    echo "Templates not found locally. Cloning SDK repository..." >&2
    TEMP_CLONE="$(mktemp -d)"
    git clone --depth 1 --quiet "$SDK_REPO" "$TEMP_CLONE/piqley-plugin-sdk"
    echo "$TEMP_CLONE/piqley-plugin-sdk/templates"
}

# --- Name validation (matches CLI sanitizePluginIdentifier) ---

sanitize_name() {
    local raw="$1"
    # Lowercase, replace non-alphanumeric with hyphens, collapse, trim
    echo "$raw" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/-\{2,\}/-/g' | sed 's/^-//;s/-$//'
}

validate_name() {
    local name="$1"
    if [[ -z "$name" ]]; then
        echo "Error: Plugin name must not be empty." >&2
        return 1
    fi
    for reserved in $RESERVED_NAMES; do
        if [[ "$name" == "$reserved" ]]; then
            echo "Error: '$name' is a reserved identifier." >&2
            return 1
        fi
    done
    return 0
}

# --- Prompts ---
# Prompt functions set global RESULT variable instead of echoing,
# so they can be called directly (not in subshells) and still print UI to stdout.

RESULT=""

prompt_language() {
    echo ""
    echo "Select a language:"
    echo "  1) swift"
    echo "  2) python"
    echo "  3) node (TypeScript)"
    echo "  4) go"
    echo ""
    while true; do
        printf "Language [1-4]: "
        read -r choice < /dev/tty
        case "$choice" in
            1|swift)  RESULT="swift"; return ;;
            2|python) RESULT="python"; return ;;
            3|node)   RESULT="node"; return ;;
            4|go)     RESULT="go"; return ;;
            *) echo "Invalid choice. Enter 1-4 or a language name." ;;
        esac
    done
}

prompt_name() {
    while true; do
        printf "Plugin display name (e.g. Ghost CMS Publisher): "
        read -r name < /dev/tty
        if [[ -z "$name" ]]; then
            echo "Plugin name is required."
            continue
        fi
        RESULT="$name"
        return
    done
}

prompt_identifier() {
    local display_name="$1"
    # Synthesize a default identifier from the display name
    local default_id
    default_id="$(sanitize_name "$display_name")"

    while true; do
        printf "Plugin identifier [%s]: " "$default_id"
        read -r raw_id < /dev/tty
        if [[ -z "$raw_id" ]]; then
            raw_id="$default_id"
        fi

        local sanitized
        sanitized="$(sanitize_name "$raw_id")"

        if ! validate_name "$sanitized"; then
            continue
        fi

        if [[ "$sanitized" != "$raw_id" ]]; then
            printf "Sanitized to: %s. Use this? [Y/n] " "$sanitized"
            read -r confirm < /dev/tty
            if [[ "$confirm" =~ ^[Nn] ]]; then
                continue
            fi
        fi

        RESULT="$sanitized"
        return
    done
}

prompt_platforms() {
    # Returns space-separated platform triples in RESULT
    local platforms=""

    printf "Target macOS (arm64)? [Y/n] "
    read -r macos_choice < /dev/tty
    if [[ ! "$macos_choice" =~ ^[Nn] ]]; then
        platforms="macos-arm64"
    fi

    printf "Target Linux? [y/N] "
    read -r linux_choice < /dev/tty
    if [[ "$linux_choice" =~ ^[Yy] ]]; then
        echo ""
        echo "  Linux architectures:"
        echo "    1) amd64"
        echo "    2) arm64"
        echo "    3) both"
        echo ""
        while true; do
            printf "  Architecture [1-3]: "
            read -r arch_choice < /dev/tty
            case "$arch_choice" in
                1|amd64)  platforms="$platforms linux-amd64"; break ;;
                2|arm64)  platforms="$platforms linux-arm64"; break ;;
                3|both)   platforms="$platforms linux-amd64 linux-arm64"; break ;;
                *) echo "  Invalid choice. Enter 1-3." ;;
            esac
        done
    fi

    # Trim leading space
    platforms="$(echo "$platforms" | sed 's/^ //')"

    if [[ -z "$platforms" ]]; then
        echo "Error: At least one platform must be selected." >&2
        prompt_platforms
        return
    fi

    RESULT="$platforms"
}

prompt_destination() {
    local default="$1"
    printf "Destination directory [./%s]: " "$default"
    read -r dest < /dev/tty
    if [[ -z "$dest" ]]; then
        dest="./$default"
    fi
    RESULT="$dest"
}

# --- Scaffold ---

scaffold() {
    local templates_dir="$1"
    local language="$2"
    local name="$3"
    local identifier="$4"
    local dest="$5"

    local template_src="$templates_dir/$language"
    if [[ ! -d "$template_src" ]]; then
        echo "Error: No template found for language '$language' at $template_src" >&2
        exit 1
    fi

    if [[ -e "$dest" ]] && [[ -n "$(ls -A "$dest" 2>/dev/null)" ]]; then
        echo "Error: Destination '$dest' already exists and is not empty." >&2
        exit 1
    fi

    mkdir -p "$dest"

    # Copy template files (including dotfiles)
    cp -R "$template_src/." "$dest/"

    # Rename __PLUGIN_IDENTIFIER__ directories (e.g. Python src package)
    find "$dest" -depth -type d -name '__PLUGIN_IDENTIFIER__' | while read -r dir; do
        local parent
        parent="$(dirname "$dir")"
        mv "$dir" "$parent/$identifier"
    done

    # Derive sanitized package name: "Ghost & 365 Project" -> "ghost-365-project"
    local package_name
    package_name=$(echo "$name" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/-\{2,\}/-/g' | sed 's/^-//;s/-$//')

    # Substitute placeholders in all files
    find "$dest" -type f | while read -r file; do
        if file "$file" | grep -qiE 'text|json'; then
            if [[ "$(uname)" == "Darwin" ]]; then
                sed -i '' -e "s/__PLUGIN_PACKAGE_NAME__/$package_name/g" -e "s/__PLUGIN_NAME__/$name/g" -e "s/__PLUGIN_IDENTIFIER__/$identifier/g" -e "s/__SDK_VERSION__/$SDK_VERSION/g" "$file"
            else
                sed -i "s/__PLUGIN_PACKAGE_NAME__/$package_name/g;s/__PLUGIN_NAME__/$name/g;s/__PLUGIN_IDENTIFIER__/$identifier/g;s/__SDK_VERSION__/$SDK_VERSION/g" "$file"
            fi
        fi
    done
}

rewrite_build_manifest_platforms() {
    local dest="$1"
    local platforms="$2"
    local manifest="$dest/piqley-build-manifest.json"

    if [[ ! -f "$manifest" ]]; then
        return
    fi

    # Extract the bin array value for the template default (macos-arm64)
    local bin_value
    bin_value=$(sed -n 's/.*"macos-arm64": \(\[.*\]\).*/\1/p' "$manifest")

    if [[ -z "$bin_value" ]]; then
        return
    fi

    # Extract non-bin fields from the manifest
    local identifier pluginName schemaVersion pluginVersion
    identifier=$(sed -n 's/.*"identifier": "\(.*\)".*/\1/p' "$manifest")
    pluginName=$(sed -n 's/.*"pluginName": "\(.*\)".*/\1/p' "$manifest")
    schemaVersion=$(sed -n 's/.*"pluginSchemaVersion": "\(.*\)".*/\1/p' "$manifest")
    pluginVersion=$(sed -n 's/.*"pluginVersion": "\(.*\)".*/\1/p' "$manifest")

    # Build the bin block with selected platforms
    local bin_block=""
    local first=true
    for platform in $platforms; do
        if $first; then
            first=false
        else
            bin_block="${bin_block},"
        fi
        bin_block="${bin_block}
    \"${platform}\": ${bin_value}"
    done

    # Write the manifest from scratch
    cat > "$manifest" << MANIFEST
{
  "identifier": "${identifier}",
  "pluginName": "${pluginName}",
  "pluginSchemaVersion": "${schemaVersion}",
  "pluginVersion": "${pluginVersion}",
  "bin": {${bin_block}
  },
  "data": {},
  "dependencies": []
}
MANIFEST
}

print_next_steps() {
    local language="$1"
    local dest="$2"

    echo ""
    echo "Plugin created at: $dest"
    echo ""
    echo "Next steps:"
    case "$language" in
        swift)
            echo "  cd $dest"
            echo "  swift build"
            ;;
        python)
            echo "  cd $dest"
            echo "  python -m venv .venv && source .venv/bin/activate"
            echo "  pip install -e ."
            ;;
        node)
            echo "  cd $dest"
            echo "  npm install"
            echo "  npm run build"
            ;;
        go)
            echo "  cd $dest"
            echo "  go build"
            ;;
    esac
    echo ""
}

# --- Main ---

main() {
    echo "piqley plugin scaffolder"
    echo "========================"

    local templates_dir
    templates_dir="$(find_templates_dir)"

    prompt_language
    local language="$RESULT"

    prompt_name
    local name="$RESULT"

    prompt_identifier "$name"
    local identifier="$RESULT"

    prompt_platforms
    local platforms="$RESULT"

    local dest="./$identifier"

    scaffold "$templates_dir" "$language" "$name" "$identifier" "$dest"
    rewrite_build_manifest_platforms "$dest" "$platforms"
    print_next_steps "$language" "$dest"
}

main
