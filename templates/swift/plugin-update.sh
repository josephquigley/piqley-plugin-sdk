#!/usr/bin/env bash
# Update piqley plugin tooling to the latest SDK version.
#
# Updates:
#   - piqley-build.sh (build script)
#   - plugin-update.sh (this script)
#   - Package.swift SDK dependency version
#   - .piqley-sdk-version stamp
#
# Does NOT touch:
#   - Source code (Sources/)
#   - Stage configs (stage-*.json)
#   - config.json
#   - piqley-build-manifest.json
set -euo pipefail

SDK_REPO="https://github.com/josephquigley/piqley-plugin-sdk.git"
SDK_REPO_SLUG="josephquigley/piqley-plugin-sdk"
VERSION_FILE=".piqley-sdk-version"

current_version() {
    if [[ -f "$VERSION_FILE" ]]; then
        cat "$VERSION_FILE"
    else
        echo "unknown"
    fi
}

latest_version() {
    local tag
    tag=$(git ls-remote --tags --sort=-v:refname "${SDK_REPO}" 2>/dev/null \
        | head -1 | sed 's/.*refs\/tags\///') || true
    if [[ -z "$tag" ]]; then
        echo "Error: Could not fetch latest version from GitHub." >&2
        exit 1
    fi
    echo "$tag"
}

# --- Main ---

current="$(current_version)"
echo "Current SDK version: $current"

latest="$(latest_version)"
echo "Latest SDK version:  $latest"

if [[ "$current" == "$latest" ]]; then
    echo ""
    echo "Already up to date."
    exit 0
fi

echo ""
printf "Update from %s to %s? [Y/n] " "$current" "$latest"
read -r choice < /dev/tty
if [[ "$choice" =~ ^[Nn] ]]; then
    echo "Aborted."
    exit 0
fi

echo ""
echo "Updating..."

RAW_BASE="https://raw.githubusercontent.com/${SDK_REPO_SLUG}/${latest}"

# Detect language from templates
if [[ -f "Package.swift" ]]; then
    language="swift"
else
    echo "Error: Could not detect project language. Only Swift is currently supported." >&2
    exit 1
fi

# Update piqley-build.sh
echo "  Updating piqley-build.sh..."
curl -sfL "${RAW_BASE}/templates/${language}/piqley-build.sh" -o piqley-build.sh
chmod +x piqley-build.sh

# Update plugin-update.sh (this script)
echo "  Updating plugin-update.sh..."
curl -sfL "${RAW_BASE}/templates/${language}/plugin-update.sh" -o plugin-update.sh
chmod +x plugin-update.sh

# Update Package.swift SDK version
if [[ -f "Package.swift" ]]; then
    echo "  Updating Package.swift SDK dependency..."
    if [[ "$(uname)" == "Darwin" ]]; then
        sed -i '' "s|.upToNextMajor(from: \"[^\"]*\")|.upToNextMajor(from: \"${latest}\")|g" Package.swift
    else
        sed -i "s|.upToNextMajor(from: \"[^\"]*\")|.upToNextMajor(from: \"${latest}\")|g" Package.swift
    fi
fi

# Stamp new version
echo "$latest" > "$VERSION_FILE"

echo ""
echo "Updated to SDK version $latest."
echo "Run './piqley-build.sh' to rebuild with the new tooling."
