#!/usr/bin/env bash
# Build the plugin for all platforms declared in piqley-build-manifest.json,
# then package it into a .piqleyplugin archive.
set -euo pipefail

MANIFEST="piqley-build-manifest.json"
STATIC_SDK_URL="https://download.swift.org/swift-6.0.3-release/static-sdk/swift-6.0.3-RELEASE/swift-6.0.3-RELEASE_static-linux-0.0.1.artifactbundle.tar.gz"

if [[ ! -f "$MANIFEST" ]]; then
    echo "Error: $MANIFEST not found in $(pwd)" >&2
    exit 1
fi

# Extract declared platform keys from the bin section.
platforms=$(sed -n '/"bin"/,/^  }/{ s/.*"\(macos-arm64\|linux-amd64\|linux-arm64\)".*/\1/p; }' "$MANIFEST")

if [[ -z "$platforms" ]]; then
    echo "Error: No platforms found in $MANIFEST bin section." >&2
    exit 1
fi

# Check if any Linux platforms are targeted and ensure the SDK is installed.
needs_linux_sdk=false
for platform in $platforms; do
    case "$platform" in
        linux-amd64|linux-arm64) needs_linux_sdk=true ;;
    esac
done

if $needs_linux_sdk; then
    installed_sdks=$(swift sdk list 2>/dev/null || true)
    missing=false

    for platform in $platforms; do
        case "$platform" in
            linux-amd64)
                if ! echo "$installed_sdks" | grep -q "x86_64-swift-linux-musl"; then missing=true; fi
                ;;
            linux-arm64)
                if ! echo "$installed_sdks" | grep -q "aarch64-swift-linux-musl"; then missing=true; fi
                ;;
        esac
    done

    if $missing; then
        echo "One or more Linux Swift SDKs are not installed."
        printf "Install the static Linux SDK now? [Y/n] "
        read -r choice < /dev/tty
        if [[ "$choice" =~ ^[Nn] ]]; then
            echo "Aborting. Install the SDK manually:" >&2
            echo "  swift sdk install $STATIC_SDK_URL" >&2
            exit 1
        fi
        echo "Installing static Linux SDK (this may take a few minutes)..."
        swift sdk install "$STATIC_SDK_URL"
        echo ""
    fi
fi

echo "Building for: $platforms"
echo ""

for platform in $platforms; do
    case "$platform" in
        macos-arm64)
            echo "[$platform] swift build -c release"
            swift build -c release
            ;;
        linux-amd64)
            echo "[$platform] swift build -c release --swift-sdk x86_64-swift-linux-musl"
            swift build -c release --swift-sdk x86_64-swift-linux-musl
            ;;
        linux-arm64)
            echo "[$platform] swift build -c release --swift-sdk aarch64-swift-linux-musl"
            swift build -c release --swift-sdk aarch64-swift-linux-musl
            ;;
        *)
            echo "Warning: Unknown platform '$platform', skipping." >&2
            ;;
    esac
done

echo ""
echo "Packaging..."
swift run piqley-build
