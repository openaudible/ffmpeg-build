#!/usr/bin/env bash

set -euo pipefail

BRANCH="${1:-main}"
OUTPUT_DIR="downloads"
REPO="openaudible/ffmpeg-build"

if ! command -v gh &> /dev/null; then
    echo "ERROR: gh CLI not found. Install from https://cli.github.com/"
    exit 1
fi

if ! gh auth status &> /dev/null; then
    echo "ERROR: Not authenticated. Run: gh auth login"
    exit 1
fi

echo "Triggering build on branch: $BRANCH"

if ! gh workflow run build.yml --repo "$REPO" --ref "$BRANCH" 2>&1; then
    echo "ERROR: Failed to trigger workflow"
    exit 1
fi

echo "Waiting for workflow to start..."
sleep 5

RUN_ID=$(gh run list --repo "$REPO" --workflow=build.yml --branch="$BRANCH" --limit 1 --json databaseId,status -q '.[0] | select(.status != "completed") | .databaseId')

if [[ -z "$RUN_ID" ]]; then
    echo "ERROR: Could not find running workflow"
    echo "Check manually: gh run list --repo "$REPO" --workflow=build.yml --limit 5"
    exit 1
fi

echo "Build started: #$RUN_ID"

echo "Waiting for build to complete..."
echo "(Monitor in detail: ./monitor-build.sh $RUN_ID)"
echo

previous_status=""
while true; do
    run_data=$(gh run view "$RUN_ID" --repo "$REPO" --json status,conclusion 2>/dev/null || echo '{}')
    status=$(echo "$run_data" | jq -r '.status // "unknown"')

    if [[ "$status" != "$previous_status" && "$status" != "queued" ]]; then
        echo "Status: $status"
        previous_status="$status"
    fi

    if [[ "$status" == "completed" ]]; then
        conclusion=$(echo "$run_data" | jq -r '.conclusion')

        if [[ "$conclusion" == "success" ]]; then
            echo
            echo "Downloading binaries..."
            ./download-builds.sh "$RUN_ID" "$OUTPUT_DIR"

            echo
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo "✓ Build complete!"
            echo
            echo "Binaries available in: $OUTPUT_DIR/"
            for platform in linux_x86_64 linux_aarch64 win_x86_64 win_arm64 mac; do
                if [[ -d "$OUTPUT_DIR/$platform" ]]; then
                    echo "  - $platform/"
                fi
            done
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            exit 0
        else
            echo
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo "✗ Build failed"
            echo
            echo "View logs: gh run view $RUN_ID --log-failed"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            exit 1
        fi
    fi

    sleep 10
done
