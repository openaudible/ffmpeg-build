#!/usr/bin/env bash

REPO="openaudible/ffmpeg-build"

set -euo pipefail

RUN_ID="${1:-}"
REFRESH_INTERVAL=10

if [[ -z "$RUN_ID" ]]; then
    echo "Usage: $0 <run-id>"
    echo
    echo "Get recent run IDs with:"
    echo "  gh run list --repo "$REPO" --workflow=build.yml --limit 10"
    exit 1
fi

if ! command -v gh &> /dev/null; then
    echo "Error: 'gh' CLI not found. Install it from https://cli.github.com/"
    exit 1
fi

echo "Monitoring GitHub Actions run #$RUN_ID"
echo "Press Ctrl+C to stop monitoring"
echo

previous_status=""

while true; do
    run_data=$(gh run view --repo "$REPO" "$RUN_ID" --json status,conclusion,displayTitle,createdAt,url,jobs)

    status=$(echo "$run_data" | jq -r '.status')
    conclusion=$(echo "$run_data" | jq -r '.conclusion // "in_progress"')
    title=$(echo "$run_data" | jq -r '.displayTitle')
    url=$(echo "$run_data" | jq -r '.url')

    if [[ "$status" != "$previous_status" ]]; then
        clear
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "  Workflow: $title"
        echo "  Run ID: $RUN_ID"
        echo "  URL: $url"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo

        echo "$run_data" | jq -r '.jobs[] | "[\(.status | ascii_upcase)] \(.name)"'
        echo

        previous_status="$status"
    fi

    if [[ "$status" == "completed" ]]; then
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        if [[ "$conclusion" == "success" ]]; then
            echo "✓ Build completed successfully!"
            echo
            echo "Download artifacts with:"
            echo "  ./download-builds.sh $RUN_ID"
        elif [[ "$conclusion" == "failure" ]]; then
            echo "✗ Build failed"
            echo
            echo "View logs with:"
            echo "  gh run view --repo "$REPO" $RUN_ID --log-failed"
        else
            echo "Build completed with status: $conclusion"
        fi
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        break
    fi

    sleep $REFRESH_INTERVAL
done
