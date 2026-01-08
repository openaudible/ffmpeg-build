#!/usr/bin/env bash

REPO="openaudible/ffmpeg-build"

set -euo pipefail

RUN_ID="${1:-}"
WAIT="${2:-false}"

if [[ -z "$RUN_ID" ]]; then
    recent_run=$(gh run list --repo "$REPO" --workflow=build.yml --limit 1 --json databaseId -q '.[0].databaseId' 2>/dev/null)
    if [[ -n "$recent_run" ]]; then
        RUN_ID="$recent_run"
    else
        echo "ERROR: No run ID provided and no recent runs found"
        exit 1
    fi
fi

if ! command -v gh &> /dev/null; then
    echo "ERROR: gh CLI not found"
    exit 1
fi

if [[ "$WAIT" == "true" ]] || [[ "$WAIT" == "--wait" ]]; then
    while true; do
        status=$(gh run view --repo "$REPO" "$RUN_ID" --json status -q '.status')
        if [[ "$status" == "completed" ]]; then
            break
        fi
        sleep 10
    done
fi

run_data=$(gh run view --repo "$REPO" "$RUN_ID" --json status,conclusion,displayTitle,url,jobs,createdAt 2>/dev/null)

if [[ -z "$run_data" ]]; then
    echo "ERROR: Run #$RUN_ID not found"
    exit 1
fi

status=$(echo "$run_data" | jq -r '.status')
conclusion=$(echo "$run_data" | jq -r '.conclusion // "in_progress"')
title=$(echo "$run_data" | jq -r '.displayTitle')
url=$(echo "$run_data" | jq -r '.url')

if [[ "$status" != "completed" ]]; then
    echo "RUNNING: Build #$RUN_ID in progress"
    exit 2
fi

if [[ "$conclusion" == "success" ]]; then
    output_dir="downloads"

    artifact_exists=$(echo "$run_data" | jq -r '.jobs[] | select(.name == "release") | .conclusion')

    if [[ "$artifact_exists" == "success" ]]; then
        echo "SUCCESS: Build #$RUN_ID completed"
        echo "PATH: $output_dir/"
        echo "DOWNLOAD: ./download-builds.sh $RUN_ID"
    else
        echo "SUCCESS: Build #$RUN_ID completed (artifacts not available)"
        echo "URL: $url"
    fi
    exit 0
else
    failed_jobs=$(echo "$run_data" | jq -r '.jobs[] | select(.conclusion == "failure") | .name' | tr '\n' ', ' | sed 's/,$//')

    echo "FAILED: Build #$RUN_ID failed"
    echo "JOBS: $failed_jobs"
    echo "URL: $url"
    echo "LOGS: gh run view --repo "$REPO" $RUN_ID --log-failed"
    exit 1
fi
