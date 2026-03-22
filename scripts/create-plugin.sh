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

    local dest="./$identifier"

    scaffold "$templates_dir" "$language" "$name" "$identifier" "$dest"
    print_next_steps "$language" "$dest"
}

main
