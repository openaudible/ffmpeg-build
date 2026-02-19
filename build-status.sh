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

run_data=$(gh run view --repo "$REPO" "$RUN_ID" --json status,conclusion,displayTitle,url,jobs,createdAt,updatedAt 2>/dev/null)

if [[ -z "$run_data" ]]; then
    echo "ERROR: Run #$RUN_ID not found"
    exit 1
fi

status=$(echo "$run_data" | jq -r '.status')
conclusion=$(echo "$run_data" | jq -r '.conclusion // "in_progress"')
title=$(echo "$run_data" | jq -r '.displayTitle')
url=$(echo "$run_data" | jq -r '.url')
created_at=$(echo "$run_data" | jq -r '.createdAt')
updated_at=$(echo "$run_data" | jq -r '.updatedAt')

current_utc=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
current_epoch=$(date -u '+%s')

time_ago() {
    local timestamp="$1"
    local past_epoch=$(date -d "$timestamp" '+%s' 2>/dev/null || date -j -f '%Y-%m-%dT%H:%M:%SZ' "$timestamp" '+%s' 2>/dev/null)
    local diff=$((current_epoch - past_epoch))

    local days=$((diff / 86400))
    local hours=$(((diff % 86400) / 3600))
    local minutes=$(((diff % 3600) / 60))

    local parts=()
    [[ $days -gt 0 ]] && parts+=("${days} day$([[ $days -ne 1 ]] && echo s)")
    [[ $hours -gt 0 ]] && parts+=("${hours} hour$([[ $hours -ne 1 ]] && echo s)")
    [[ $minutes -gt 0 ]] && parts+=("${minutes} minute$([[ $minutes -ne 1 ]] && echo s)")

    [[ ${#parts[@]} -eq 0 ]] && echo "just now" || echo "${parts[*]} ago" | sed 's/ /\ /g'
}

if [[ "$status" != "completed" ]]; then
    echo "RUNNING: Build #$RUN_ID in progress"
    echo "CURRENT UTC: $current_utc"
    echo "STARTED: $created_at ($(time_ago "$created_at"))"
    exit 2
fi

if [[ "$conclusion" == "success" ]]; then
    output_dir="downloads"

    artifact_exists=$(echo "$run_data" | jq -r '.jobs[] | select(.name == "release") | .conclusion')

    if [[ "$artifact_exists" == "success" ]]; then
        echo "SUCCESS: Build #$RUN_ID completed"
        echo "CURRENT UTC: $current_utc"
        echo "STARTED: $created_at ($(time_ago "$created_at"))"
        echo "FINISHED: $updated_at ($(time_ago "$updated_at"))"
        echo "PATH: $output_dir/"
        echo "DOWNLOAD: ./download-builds.sh $RUN_ID"
    else
        echo "SUCCESS: Build #$RUN_ID completed (artifacts not available)"
        echo "CURRENT UTC: $current_utc"
        echo "STARTED: $created_at ($(time_ago "$created_at"))"
        echo "FINISHED: $updated_at ($(time_ago "$updated_at"))"
        echo "URL: $url"
    fi
    exit 0
else
    failed_jobs=$(echo "$run_data" | jq -r '.jobs[] | select(.conclusion == "failure") | .name' | tr '\n' ', ' | sed 's/,$//')

    echo "FAILED: Build #$RUN_ID failed"
    echo "CURRENT UTC: $current_utc"
    echo "STARTED: $created_at ($(time_ago "$created_at"))"
    echo "FINISHED: $updated_at ($(time_ago "$updated_at"))"
    echo "JOBS: $failed_jobs"
    echo "URL: $url"
    echo "LOGS: gh run view --repo "$REPO" $RUN_ID --log-failed"
    exit 1
fi
