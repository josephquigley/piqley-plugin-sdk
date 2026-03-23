#!/usr/bin/env bash
# Build the plugin for all platforms declared in piqley-build-manifest.json,
# then package it into a .piqleyplugin archive.
#
# Works on both macOS and Linux. Cross-compiles where Swift SDK bundles
# are available. Builds natively for the host platform.
set -euo pipefail

MANIFEST="piqley-build-manifest.json"
STATIC_SDK_URL="https://download.swift.org/swift-6.0.3-release/static-sdk/swift-6.0.3-RELEASE/swift-6.0.3-RELEASE_static-linux-0.0.1.artifactbundle.tar.gz"

if [[ ! -f "$MANIFEST" ]]; then
    echo "Error: $MANIFEST not found in $(pwd)" >&2
    exit 1
fi

# Detect the host platform triple.
detect_host_platform() {
    local os arch
    os="$(uname -s)"
    arch="$(uname -m)"

    case "$os" in
        Darwin)
            case "$arch" in
                arm64) echo "macos-arm64" ;;
                *)     echo "macos-$arch" ;;
            esac
            ;;
        Linux)
            case "$arch" in
                x86_64)  echo "linux-amd64" ;;
                aarch64) echo "linux-arm64" ;;
                *)       echo "linux-$arch" ;;
            esac
            ;;
        *)
            echo "unknown" ;;
    esac
}

HOST_PLATFORM="$(detect_host_platform)"

# Map a target platform to its Swift SDK name (for cross-compilation).
# Returns empty string if the target is the host (native build).
sdk_for_platform() {
    local target="$1"
    case "$target" in
        linux-amd64) echo "x86_64-swift-linux-musl" ;;
        linux-arm64) echo "aarch64-swift-linux-musl" ;;
        *)           echo "" ;;
    esac
}

# Extract declared platform keys from the bin section.
platforms=$(sed -n '/"bin"/,/^  }/{ s/.*"\(macos-arm64\|linux-amd64\|linux-arm64\)".*/\1/p; }' "$MANIFEST")

if [[ -z "$platforms" ]]; then
    echo "Error: No platforms found in $MANIFEST bin section." >&2
    exit 1
fi

# Check for needed SDKs and offer to install them.
missing_sdks=()
for platform in $platforms; do
    if [[ "$platform" == "$HOST_PLATFORM" ]]; then
        continue
    fi

    sdk="$(sdk_for_platform "$platform")"
    if [[ -z "$sdk" ]]; then
        continue
    fi

    if ! swift sdk list 2>/dev/null | grep -q "$sdk"; then
        missing_sdks+=("$sdk")
    fi
done

if [[ ${#missing_sdks[@]} -gt 0 ]]; then
    # Deduplicate (both linux targets share the same SDK bundle)
    unique_missing=($(printf '%s\n' "${missing_sdks[@]}" | sort -u))

    echo "Required Swift SDK(s) not installed: ${unique_missing[*]}"
    printf "Install the static Linux SDK now? [Y/n] "
    read -r choice < /dev/tty
    if [[ "$choice" =~ ^[Nn] ]]; then
        echo "Aborting. Install manually:" >&2
        echo "  swift sdk install $STATIC_SDK_URL" >&2
        exit 1
    fi
    echo "Installing static Linux SDK (this may take a few minutes)..."
    swift sdk install "$STATIC_SDK_URL"
    echo ""
fi

echo "Host platform: $HOST_PLATFORM"
echo "Building for: $platforms"
echo ""

skipped=()
for platform in $platforms; do
    if [[ "$platform" == "$HOST_PLATFORM" ]]; then
        echo "[$platform] swift build -c release (native)"
        swift build -c release
        continue
    fi

    sdk="$(sdk_for_platform "$platform")"
    if [[ -z "$sdk" ]]; then
        echo "[$platform] Cannot cross-compile to this platform from $HOST_PLATFORM. Skipping." >&2
        skipped+=("$platform")
        continue
    fi

    if ! swift sdk list 2>/dev/null | grep -q "$sdk"; then
        echo "[$platform] SDK '$sdk' not available. Skipping." >&2
        skipped+=("$platform")
        continue
    fi

    echo "[$platform] swift build -c release --swift-sdk $sdk"
    swift build -c release --swift-sdk "$sdk"
done

if [[ ${#skipped[@]} -gt 0 ]]; then
    echo ""
    echo "Warning: Skipped platforms: ${skipped[*]}"
    echo "Build binaries for these platforms on a native machine or in CI."
fi

echo ""
echo "Packaging..."
swift run piqley-build
