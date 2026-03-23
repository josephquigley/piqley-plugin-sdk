#!/usr/bin/env bash
# Build the plugin for all platforms declared in piqley-build-manifest.json,
# then package it into a .piqleyplugin archive.
#
# Works on both macOS and Linux. Uses swiftly to manage the open-source
# Swift toolchain (required for cross-compilation). Builds natively for
# the host platform and cross-compiles for other targets.
set -euo pipefail

MANIFEST="piqley-build-manifest.json"
SWIFTLY_BIN="${HOME}/.swiftly/bin"

if [[ ! -f "$MANIFEST" ]]; then
    echo "Error: $MANIFEST not found in $(pwd)" >&2
    exit 1
fi

# --- Swiftly setup ---

ensure_swiftly() {
    if [[ -x "${SWIFTLY_BIN}/swiftly" ]]; then
        return
    fi

    echo "swiftly is not installed. It manages open-source Swift toolchains"
    echo "required for cross-compilation."
    printf "Install swiftly now? [Y/n] "
    read -r choice < /dev/tty
    if [[ "$choice" =~ ^[Nn] ]]; then
        echo "Aborting. Install swiftly from https://www.swift.org/install/" >&2
        exit 1
    fi

    echo "Installing swiftly..."
    local os
    os="$(uname -s)"
    case "$os" in
        Darwin)
            local pkg="/tmp/swiftly-$$.pkg"
            curl -sL https://download.swift.org/swiftly/darwin/swiftly.pkg -o "$pkg"
            installer -pkg "$pkg" -target CurrentUserHomeDirectory
            rm -f "$pkg"
            "${SWIFTLY_BIN}/swiftly" init --assume-yes
            ;;
        Linux)
            local arch tarball
            arch="$(uname -m)"
            tarball="/tmp/swiftly-$$.tar.gz"
            curl -sL "https://download.swift.org/swiftly/linux/swiftly-${arch}.tar.gz" -o "$tarball"
            tar xzf "$tarball" -C /tmp
            rm -f "$tarball"
            /tmp/swiftly init --assume-yes
            rm -f /tmp/swiftly
            ;;
        *)
            echo "Error: Unsupported OS for swiftly: $os" >&2
            exit 1
            ;;
    esac
    echo ""
}

# Use swiftly's Swift for all builds.
ensure_swift_toolchain() {
    if ! "${SWIFTLY_BIN}/swift" --version &>/dev/null; then
        echo "No Swift toolchain installed via swiftly. Installing latest..."
        "${SWIFTLY_BIN}/swiftly" install latest --use
    fi
}

# --- Platform detection ---

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

sdk_for_platform() {
    local target="$1"
    case "$target" in
        linux-amd64) echo "x86_64-swift-linux-musl" ;;
        linux-arm64) echo "aarch64-swift-linux-musl" ;;
        *)           echo "" ;;
    esac
}

# --- Static Linux SDK ---

ensure_static_linux_sdk() {
    if "${SWIFTLY_BIN}/swift" sdk list 2>/dev/null | grep -q "static-linux"; then
        return
    fi

    echo "Static Linux SDK not installed (required for cross-compilation)."
    printf "Install it now? [Y/n] "
    read -r choice < /dev/tty
    if [[ "$choice" =~ ^[Nn] ]]; then
        echo "Aborting. Install manually from:" >&2
        echo "  https://www.swift.org/documentation/articles/static-linux-getting-started.html" >&2
        exit 1
    fi

    local swift_version
    swift_version=$("${SWIFTLY_BIN}/swift" --version 2>/dev/null | sed -n 's/.*Swift version \([0-9]*\.[0-9]*\.[0-9]*\).*/\1/p')
    if [[ -z "$swift_version" ]]; then
        echo "Error: Could not detect Swift version." >&2
        exit 1
    fi

    # Try known SDK artifact versions (newer first).
    local base="https://download.swift.org/swift-${swift_version}-release/static-sdk/swift-${swift_version}-RELEASE/swift-${swift_version}-RELEASE_static-linux"
    local tmpfile
    tmpfile="$(mktemp /tmp/swift-static-sdk.XXXXXX.tar.gz)"

    local installed=false
    for sdk_ver in 0.1.0 0.0.1; do
        local url="${base}-${sdk_ver}.artifactbundle.tar.gz"
        echo "Trying SDK artifact version ${sdk_ver}..."
        if curl -fL --progress-bar -o "$tmpfile" "$url" 2>/dev/null; then
            echo "Installing..."
            "${SWIFTLY_BIN}/swift" sdk install "$tmpfile"
            installed=true
            break
        fi
    done

    rm -f "$tmpfile"

    if ! $installed; then
        echo "Error: Could not find a static Linux SDK for Swift ${swift_version}." >&2
        echo "Install manually from:" >&2
        echo "  https://www.swift.org/documentation/articles/static-linux-getting-started.html" >&2
        exit 1
    fi
    echo ""
}

# --- Main ---

ensure_swiftly
ensure_swift_toolchain

SWIFT="${SWIFTLY_BIN}/swift"
HOST_PLATFORM="$(detect_host_platform)"

# Extract declared platform keys from the bin section.
platforms=$(grep -oE '(macos-arm64|linux-amd64|linux-arm64)' "$MANIFEST" | sort -u | tr '\n' ' ' | sed 's/ $//')

if [[ -z "$platforms" ]]; then
    echo "Error: No platforms found in $MANIFEST bin section." >&2
    exit 1
fi

# Check if any Linux cross-compilation is needed.
needs_linux_sdk=false
for platform in $platforms; do
    if [[ "$platform" != "$HOST_PLATFORM" ]]; then
        case "$platform" in
            linux-amd64|linux-arm64) needs_linux_sdk=true ;;
        esac
    fi
done

if $needs_linux_sdk; then
    ensure_static_linux_sdk
fi

has_linux_sdk=false
if "${SWIFT}" sdk list 2>/dev/null | grep -q "static-linux"; then
    has_linux_sdk=true
fi

echo "Host platform: $HOST_PLATFORM"
echo "Building for: $platforms"
echo ""

# Build function for a single platform.
build_platform() {
    local platform="$1"
    if [[ "$platform" == "$HOST_PLATFORM" ]]; then
        echo "[$platform] $SWIFT build -c release (native)"
        "$SWIFT" build -c release
        return
    fi

    local sdk
    sdk="$(sdk_for_platform "$platform")"
    if [[ -z "$sdk" ]]; then
        echo "[$platform] Cannot cross-compile to this platform from $HOST_PLATFORM. Skipping." >&2
        skipped+=("$platform")
        return
    fi

    if ! $has_linux_sdk; then
        echo "[$platform] Static Linux SDK not installed. Skipping." >&2
        skipped+=("$platform")
        return
    fi

    scratch=".build-${platform}"
    echo "[$platform] $SWIFT build -c release --swift-sdk $sdk --scratch-path $scratch"
    "$SWIFT" build -c release --swift-sdk "$sdk" --scratch-path "$scratch"
}

# Build host platform first, then cross-compile the rest.
skipped=()
for platform in $platforms; do
    if [[ "$platform" == "$HOST_PLATFORM" ]]; then
        build_platform "$platform"
    fi
done
for platform in $platforms; do
    if [[ "$platform" != "$HOST_PLATFORM" ]]; then
        build_platform "$platform"
    fi
done

if [[ ${#skipped[@]} -gt 0 ]]; then
    echo ""
    echo "Skipped platforms: ${skipped[*]}"
    echo "Build binaries for these platforms on a native machine or in CI,"
    echo "then run '$SWIFT run piqley-build' to package."
    exit 1
fi

echo ""
echo "Packaging..."
"$SWIFT" run piqley-build
