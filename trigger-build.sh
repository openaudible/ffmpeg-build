#!/usr/bin/env bash

set -euo pipefail

WORKFLOW_FILE="build.yml"
BRANCH="${1:-atmos}"

echo "Triggering GitHub Actions workflow..."
echo "  Workflow: $WORKFLOW_FILE"
echo "  Branch: $BRANCH"
echo

if ! command -v gh &> /dev/null; then
    echo "Error: 'gh' CLI not found. Install it from https://cli.github.com/"
    exit 1
fi

if ! gh auth status &> /dev/null; then
    echo "Error: Not authenticated with GitHub. Run 'gh auth login'"
    exit 1
fi

run_id=$(gh workflow run "$WORKFLOW_FILE" --ref "$BRANCH" --json databaseId -q '.databaseId' 2>&1)

if [[ "$run_id" =~ ^[0-9]+$ ]]; then
    echo "✓ Workflow triggered successfully"
    echo "  Run ID: $run_id"
    echo "  View at: $(gh run view $run_id --web --print-url 2>/dev/null || echo 'Run gh run view $run_id --web')"
    echo
    echo "Monitor progress with: ./monitor-build.sh $run_id"
else
    gh workflow run "$WORKFLOW_FILE" --ref "$BRANCH"
    echo "✓ Workflow triggered"
    echo
    echo "Find the run ID with: gh run list --workflow=$WORKFLOW_FILE --limit 5"
    echo "Then monitor with: ./monitor-build.sh <run-id>"
fi
