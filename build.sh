#!/usr/bin/env bash

set -euo pipefail

BRANCH="${1:-atmos}"
OUTPUT_DIR="downloads"

if ! command -v gh &> /dev/null; then
    echo "ERROR: gh CLI not found. Install from https://cli.github.com/"
    exit 1
fi

if ! gh auth status &> /dev/null; then
    echo "ERROR: Not authenticated. Run: gh auth login"
    exit 1
fi

echo "Triggering build on branch: $BRANCH"

run_output=$(gh workflow run build.yml --ref "$BRANCH" 2>&1)

if [[ "$run_output" =~ "Created workflow_dispatch event" ]]; then
    sleep 3
    RUN_ID=$(gh run list --workflow=build.yml --limit 1 --json databaseId -q '.[0].databaseId')
    echo "Build started: #$RUN_ID"
else
    echo "ERROR: Failed to trigger workflow"
    echo "$run_output"
    exit 1
fi

echo "Waiting for build to complete..."
echo "(Monitor in detail: ./monitor-build.sh $RUN_ID)"
echo

previous_status=""
while true; do
    run_data=$(gh run view "$RUN_ID" --json status,conclusion 2>/dev/null || echo '{}')
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
            ./download-builds.sh "$RUN_ID" "$OUTPUT_DIR" > /dev/null 2>&1

            echo
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo "✓ Build complete!"
            echo
            echo "Binaries available in: $OUTPUT_DIR/"
            for platform in linux_x86_64 win_x86_64 win_arm64 mac_x86_64 mac_arm64; do
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
