#!/usr/bin/env bash

REPO="openaudible/ffmpeg-build"

set -euo pipefail

RUN_ID="${1:-}"
OUTPUT_DIR="${2:-downloads}"

if [[ -z "$RUN_ID" ]]; then
    echo "Usage: $0 <run-id> [output-dir]"
    echo
    echo "Get recent run IDs with:"
    echo "  gh run list --repo "$REPO" --workflow=build.yml --limit 10"
    echo
    echo "Default output directory: downloads/"
    exit 1
fi

if ! command -v gh &> /dev/null; then
    echo "Error: 'gh' CLI not found. Install it from https://cli.github.com/"
    exit 1
fi

echo "Downloading builds from run #$RUN_ID"
echo "Output directory: $OUTPUT_DIR"
echo

status=$(gh run view --repo "$REPO" "$RUN_ID" --json status,conclusion -q '.status')
conclusion=$(gh run view --repo "$REPO" "$RUN_ID" --json status,conclusion -q '.conclusion // "in_progress"')

if [[ "$status" != "completed" ]]; then
    echo "Error: Build is still running (status: $status)"
    echo "Monitor progress with: ./monitor-build.sh $RUN_ID"
    exit 1
fi

if [[ "$conclusion" != "success" ]]; then
    echo "Error: Build failed with conclusion: $conclusion"
    echo "View logs with: gh run view --repo "$REPO" $RUN_ID --log-failed"
    exit 1
fi

rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

artifacts=$(gh api "repos/$REPO/actions/runs/$RUN_ID/artifacts" -q '.artifacts[] | select(.name == "apps") | .name')

if [[ -z "$artifacts" ]]; then
    echo "Error: 'apps' artifact not found. Build may have failed or artifacts expired."
    echo "Available artifacts:"
    gh api "repos/$REPO/actions/runs/$RUN_ID/artifacts" -q '.artifacts[].name'
    exit 1
fi

temp_dir=$(mktemp -d)
trap "rm -rf $temp_dir" EXIT

echo "Downloading 'apps' artifact..."
gh run download --repo "$REPO" "$RUN_ID" --name apps --dir "$temp_dir"

if [[ ! -d "$temp_dir" ]]; then
    echo "Error: Failed to download artifacts"
    exit 1
fi

echo "Extracting binaries..."

platforms=(
    "linux_x86_64"
    "linux_aarch64"
    "win_x86_64"
    "win_arm64"
    "mac"
)

for platform in "${platforms[@]}"; do
    src="$temp_dir/$platform"
    if [[ -d "$src" ]]; then
        mkdir -p "$OUTPUT_DIR/$platform"
        cp "$src"/ff* "$OUTPUT_DIR/$platform/" 2>/dev/null || true

        if [[ -f "$OUTPUT_DIR/$platform/ffmpeg" ]] || [[ -f "$OUTPUT_DIR/$platform/ffmpeg.exe" ]]; then
            echo "  ✓ $platform"
        fi
    fi
done

echo
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✓ Download complete!"
echo
echo "Binaries available in: $OUTPUT_DIR/"
echo

for platform in "${platforms[@]}"; do
    if [[ -d "$OUTPUT_DIR/$platform" ]]; then
        echo "  $platform/"
        ls -lh "$OUTPUT_DIR/$platform" | tail -n +2 | awk '{print "    " $9 " (" $5 ")"}'
    fi
done

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
