#!/usr/bin/env bash
set -euo pipefail

# Universal check script for build binary
# Ensures the build command is the latest compiled version of build.odin

BUILD_SOURCE="build.odin"
BUILD_BINARY="build"

# Function to get modification time of a file
get_mtime() {
    if [[ -f "$1" ]]; then
        stat -f "%m" "$1" 2>/dev/null || echo "0"
    else
        echo "0"
    fi
}

# Get modification times
source_time=$(get_mtime "$BUILD_SOURCE")
binary_time=$(get_mtime "$BUILD_BINARY")

# Check if build is needed
if [[ "$source_time" -gt "$binary_time" ]]; then
    echo "⚠️  build.odin is newer than build binary, rebuilding..."
    odin build build.odin -file
    echo "✅ Build binary updated"
elif [[ ! -f "$BUILD_BINARY" ]]; then
    echo "⚠️  build binary missing, creating..."
    odin build build.odin -file
    echo "✅ Build binary created"
else
    echo "✅ Build binary is up to date"
fi

# Verify the binary works
if ./build -help >/dev/null 2>&1; then
    echo "✅ Build binary is functional"
else
    echo "❌ Build binary is not functional, rebuilding..."
    odin build build.odin -file
    echo "✅ Build binary rebuilt"
fi