#!/usr/bin/env bash

set -euo pipefail

REPO="openaudible/ffmpeg-build"
ACTION="${1:-}"

if ! command -v gh &> /dev/null; then
    echo "ERROR: gh CLI not found. Install from https://cli.github.com/"
    exit 1
fi

show_usage() {
    cat <<EOF
Usage: $0 [command]

Commands:
  cancel-running    Cancel all running/queued workflows
  delete-old [days] Delete completed runs older than N days (default: 30)
  delete-all        Delete all completed workflow runs
  list              List recent workflow runs
  cancel <run-id>   Cancel specific workflow run
  delete <run-id>   Delete specific workflow run

Examples:
  $0 list                    # Show recent runs
  $0 cancel-running          # Cancel all in-progress runs
  $0 delete-old 7            # Delete runs older than 7 days
  $0 cancel 12345678         # Cancel specific run
  $0 delete 12345678         # Delete specific run
EOF
}

list_runs() {
    echo "Recent workflow runs:"
    echo
    gh run list --repo "$REPO" --workflow=build.yml --limit 20 \
        --json databaseId,status,conclusion,displayTitle,createdAt,updatedAt \
        --jq '.[] | "\(.databaseId)\t\(.status)\t\(.conclusion // "n/a")\t\(.displayTitle)\t\(.createdAt)"' | \
        column -t -s $'\t' -N "ID,STATUS,CONCLUSION,TITLE,CREATED"
}

cancel_running() {
    echo "Finding running/queued workflows..."

    run_ids=$(gh run list --repo "$REPO" --workflow=build.yml --limit 50 \
        --json databaseId,status --jq '.[] | select(.status == "in_progress" or .status == "queued") | .databaseId')

    if [[ -z "$run_ids" ]]; then
        echo "No running or queued workflows found"
        return 0
    fi

    count=$(echo "$run_ids" | wc -l)
    echo "Found $count running/queued workflow(s)"
    echo

    for run_id in $run_ids; do
        echo "Canceling run #$run_id..."
        gh run cancel "$run_id" --repo "$REPO" 2>&1 || echo "  Failed to cancel"
    done

    echo
    echo "✓ Canceled $count workflow(s)"
}

delete_old() {
    days="${1:-30}"
    cutoff_date=$(date -d "$days days ago" -Iseconds 2>/dev/null || date -v-${days}d -Iseconds 2>/dev/null)

    echo "Finding completed runs older than $days days (before $cutoff_date)..."

    run_ids=$(gh run list --repo "$REPO" --workflow=build.yml --limit 100 \
        --json databaseId,status,createdAt \
        --jq --arg cutoff "$cutoff_date" \
        '.[] | select(.status == "completed" and .createdAt < $cutoff) | .databaseId')

    if [[ -z "$run_ids" ]]; then
        echo "No old completed runs found"
        return 0
    fi

    count=$(echo "$run_ids" | wc -l)
    echo "Found $count old completed run(s)"
    echo

    for run_id in $run_ids; do
        echo "Deleting run #$run_id..."
        gh run delete "$run_id" --repo "$REPO" 2>&1 || echo "  Failed to delete"
    done

    echo
    echo "✓ Deleted $count old run(s)"
}

delete_all_completed() {
    echo "Finding all completed runs..."

    run_ids=$(gh run list --repo "$REPO" --workflow=build.yml --limit 100 \
        --json databaseId,status --jq '.[] | select(.status == "completed") | .databaseId')

    if [[ -z "$run_ids" ]]; then
        echo "No completed runs found"
        return 0
    fi

    count=$(echo "$run_ids" | wc -l)
    echo "Found $count completed run(s)"
    echo
    read -p "Delete all $count runs? (y/N) " -n 1 -r
    echo

    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Canceled"
        return 0
    fi

    for run_id in $run_ids; do
        echo "Deleting run #$run_id..."
        gh run delete "$run_id" --repo "$REPO" 2>&1 || echo "  Failed to delete"
    done

    echo
    echo "✓ Deleted $count run(s)"
}

case "$ACTION" in
    list|"")
        list_runs
        ;;
    cancel-running)
        cancel_running
        ;;
    delete-old)
        delete_old "${2:-30}"
        ;;
    delete-all)
        delete_all_completed
        ;;
    cancel)
        if [[ -z "${2:-}" ]]; then
            echo "ERROR: Run ID required"
            echo "Usage: $0 cancel <run-id>"
            exit 1
        fi
        echo "Canceling run #$2..."
        gh run cancel "$2" --repo "$REPO"
        echo "✓ Canceled"
        ;;
    delete)
        if [[ -z "${2:-}" ]]; then
            echo "ERROR: Run ID required"
            echo "Usage: $0 delete <run-id>"
            exit 1
        fi
        echo "Deleting run #$2..."
        gh run delete "$2" --repo "$REPO"
        echo "✓ Deleted"
        ;;
    -h|--help|help)
        show_usage
        ;;
    *)
        echo "ERROR: Unknown command: $ACTION"
        echo
        show_usage
        exit 1
        ;;
esac
