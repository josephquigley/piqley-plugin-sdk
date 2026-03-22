#!/usr/bin/env sh
# Build the plugin in release mode and package it for installation.
set -e
swift build -c release
swift run piqley-build
