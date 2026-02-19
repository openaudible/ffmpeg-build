#!/usr/bin/env bash

set -euo pipefail

echo "Cleaning build artifacts..."

directories_to_clean=(
    "artifacts"
    "builds"
    "bin"
    "downloads"
    "build_win_x86_64"
    "build_win_arm64"
    "build_linux_x86_64"
    "build_macos_x86_64"
    "build_macos_arm64"
)

for dir in "${directories_to_clean[@]}"; do
    if [[ -d "$dir" ]]; then
        echo "  Removing $dir/"
        rm -rf "$dir"
    fi
done

temp_builds=$(find . -maxdepth 1 -type d -name "build.????????" 2>/dev/null || true)
if [[ -n "$temp_builds" ]]; then
    echo "  Removing temporary build directories..."
    echo "$temp_builds" | xargs rm -rf
fi

# Remove fixed-name local build directories (debug builds, incremental builds, etc.)
local_builds=$(find . -maxdepth 1 -type d \( -name "build-debug-*" -o -name "build-linux-*" \) 2>/dev/null || true)
if [[ -n "$local_builds" ]]; then
    echo "  Removing local build directories..."
    echo "$local_builds" | xargs rm -rf
fi

echo "✓ Clean complete"

