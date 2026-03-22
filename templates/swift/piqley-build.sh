#!/usr/bin/env sh
#
# piqley-build.sh - Build and package this piqley plugin
#
# Locates the piqley-plugin-sdk (local checkout or clones it) and runs
# the piqley-build tool to produce a .piqleyplugin package.
#
set -e

SDK_REPO="https://github.com/josephquigley/piqley-plugin-sdk.git"

find_sdk() {
    # Check Package.swift for a local path dependency
    if [ -f Package.swift ]; then
        local_path=$(sed -n 's/.*\.package(path: *"\([^"]*\)").*/\1/p' Package.swift | head -1)
        if [ -n "$local_path" ] && [ -d "$local_path" ]; then
            echo "$local_path"
            return
        fi
    fi

    # Check common sibling locations
    script_dir=$(dirname "$0")
    for candidate in "$script_dir/../piqley-plugin-sdk" "../piqley-plugin-sdk" "../../piqley-plugin-sdk"; do
        if [ -d "$candidate/swift/PiqleyBuild" ]; then
            echo "$candidate"
            return
        fi
    done

    # Clone to a temp directory
    echo "SDK not found locally. Cloning..." >&2
    tmp=$(mktemp -d)
    git clone --depth 1 --quiet "$SDK_REPO" "$tmp/piqley-plugin-sdk"
    echo "$tmp/piqley-plugin-sdk"
}

sdk_path=$(find_sdk)
echo "Using SDK at: $sdk_path"
exec swift run --package-path "$sdk_path" piqley-build
