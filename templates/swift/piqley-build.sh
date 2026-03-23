#!/usr/bin/env bash
# Build the plugin for all platforms declared in piqley-build-manifest.json,
# then package it into a .piqleyplugin archive.
#
# Works on both macOS and Linux. Cross-compiles where Swift SDK bundles
# are available. Builds natively for the host platform.
set -euo pipefail

MANIFEST="piqley-build-manifest.json"

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

# Build the static Linux SDK download URL for the installed Swift version.
static_linux_sdk_url() {
    local swift_version
    swift_version=$(swift --version 2>/dev/null | sed -n 's/.*Swift version \([0-9]*\.[0-9]*\.[0-9]*\).*/\1/p')
    if [[ -z "$swift_version" ]]; then
        echo ""
        return
    fi
    echo "https://download.swift.org/swift-${swift_version}-release/static-sdk/swift-${swift_version}-RELEASE/swift-${swift_version}-RELEASE_static-linux-0.0.1.artifactbundle.tar.gz"
}

# Install the static Linux SDK by downloading to a temp file first
# (local installs don't require a checksum).
install_static_linux_sdk() {
    local url
    url="$(static_linux_sdk_url)"
    if [[ -z "$url" ]]; then
        echo "Error: Could not detect Swift version for SDK URL." >&2
        echo "Install manually from https://www.swift.org/documentation/articles/static-linux-getting-started.html" >&2
        return 1
    fi

    local tmpfile
    tmpfile="$(mktemp /tmp/swift-static-sdk.XXXXXX.tar.gz)"
    trap "rm -f '$tmpfile'" RETURN

    echo "Downloading: $url"
    if command -v curl &>/dev/null; then
        curl -L --progress-bar -o "$tmpfile" "$url"
    elif command -v wget &>/dev/null; then
        wget -q --show-progress -O "$tmpfile" "$url"
    else
        echo "Error: curl or wget required to download the SDK." >&2
        return 1
    fi

    echo "Installing..."
    swift sdk install "$tmpfile"
}

HOST_PLATFORM="$(detect_host_platform)"

# Map a target platform to its Swift SDK name (for cross-compilation).
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
        echo "Aborting. Install manually from:" >&2
        echo "  https://www.swift.org/documentation/articles/static-linux-getting-started.html" >&2
        exit 1
    fi
    echo ""
    install_static_linux_sdk
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
