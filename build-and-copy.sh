#!/usr/bin/env bash

set -euo pipefail

REPO="openaudible/ffmpeg-build"
WORKFLOW_FILE="build.yml"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OA_DIR="${OA_DIR:-$SCRIPT_DIR/../oa}"
COPY_SCRIPT="$OA_DIR/app/copy_ffmpegs.sh"
RUN_APPEAR_TIMEOUT=90

RUN_ID=""
PUSH=true

show_usage() {
    cat <<EOF
Usage: $0 [options]

Builds the current HEAD in GitHub Actions, waits for it, downloads the
binaries and copies them into OpenAudible ($OA_DIR/app/bin).

Steps:
  1. push the current branch if it is ahead of origin (push triggers CI)
  2. reuse the CI run for HEAD's commit, or start one via workflow_dispatch
  3. wait for the run to finish
  4. ./download-builds.sh <run-id>
  5. $COPY_SCRIPT

Options:
  --run-id ID   Skip building; download and copy an existing run
  --no-push     Do not push; fail if HEAD is not on origin
  -h, --help    Show this help

Environment:
  OA_DIR        OpenAudible checkout (default: ../oa)
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --run-id) RUN_ID="$2"; shift 2 ;;
        --no-push) PUSH=false; shift ;;
        -h|--help) show_usage; exit 0 ;;
        *) echo "ERROR: unknown option: $1" >&2; show_usage >&2; exit 1 ;;
    esac
done

for tool in gh jq git; do
    if ! command -v "$tool" &> /dev/null; then
        echo "ERROR: $tool not found" >&2
        exit 1
    fi
done

if ! gh auth status &> /dev/null; then
    echo "ERROR: not logged in. Run: gh auth login" >&2
    exit 1
fi

if [[ ! -x "$COPY_SCRIPT" ]]; then
    echo "ERROR: $COPY_SCRIPT not found or not executable (set OA_DIR)" >&2
    exit 1
fi

cd "$SCRIPT_DIR"

run_for_commit() {
    gh run list --repo "$REPO" --workflow "$WORKFLOW_FILE" --commit "$1" --limit 20 \
        --json databaseId,status,conclusion \
        -q '[.[] | select(.status != "completed" or .conclusion == "success")][0].databaseId // empty'
}

wait_for_run_for_commit() {
    local sha="$1" waited=0 id=""
    while [[ -z "$id" && $waited -lt $RUN_APPEAR_TIMEOUT ]]; do
        sleep 5
        waited=$((waited + 5))
        id=$(run_for_commit "$sha")
    done
    echo "$id"
}

if [[ -z "$RUN_ID" ]]; then
    BRANCH=$(git rev-parse --abbrev-ref HEAD)
    SHA=$(git rev-parse HEAD)

    if [[ -n "$(git status --porcelain --untracked-files=no)" ]]; then
        echo "WARNING: uncommitted changes are NOT included in the CI build"
        git status --short --untracked-files=no
        echo
    fi

    git fetch -q origin "$BRANCH" 2>/dev/null || true
    REMOTE_SHA=$(git rev-parse -q --verify "origin/$BRANCH" || true)

    if [[ -n "$REMOTE_SHA" ]] && ! git merge-base --is-ancestor "$REMOTE_SHA" HEAD; then
        echo "ERROR: origin/$BRANCH has commits not in your local branch. Pull first:" >&2
        git log --oneline "HEAD..origin/$BRANCH" >&2
        exit 1
    fi

    if ! git merge-base --is-ancestor origin/main HEAD 2>/dev/null; then
        echo "NOTE: origin/main has commits not in $BRANCH (they will NOT be in this build):"
        git log --oneline "HEAD..origin/main"
        echo
    fi

    echo "Branch: $BRANCH"
    echo "Commit: $(git log --oneline -1)"
    echo

    if [[ "$REMOTE_SHA" != "$SHA" ]]; then
        if [[ "$PUSH" != true ]]; then
            echo "ERROR: HEAD is not pushed to origin/$BRANCH (drop --no-push to push it)" >&2
            exit 1
        fi
        echo "Pushing $BRANCH (this triggers the CI build)..."
        git push -u origin "$BRANCH"
        echo "Waiting for the push-triggered run to appear..."
        RUN_ID=$(wait_for_run_for_commit "$SHA")
    else
        RUN_ID=$(run_for_commit "$SHA")
        [[ -n "$RUN_ID" ]] && echo "Reusing existing run #$RUN_ID for $SHA"
    fi

    if [[ -z "$RUN_ID" ]]; then
        echo "No run found for $SHA; starting one via workflow_dispatch..."
        gh workflow run --repo "$REPO" "$WORKFLOW_FILE" --ref "$BRANCH"
        RUN_ID=$(wait_for_run_for_commit "$SHA")
    fi

    if [[ -z "$RUN_ID" ]]; then
        echo "ERROR: could not find a CI run for $SHA" >&2
        echo "Check: gh run list --repo $REPO --workflow $WORKFLOW_FILE --limit 5" >&2
        exit 1
    fi
fi

echo
echo "Run #$RUN_ID: $(gh run view --repo "$REPO" "$RUN_ID" --json url -q .url)"
echo

if ! gh run watch --repo "$REPO" "$RUN_ID" --exit-status --interval 30; then
    echo
    echo "ERROR: build #$RUN_ID failed. Logs:" >&2
    echo "  gh run view --repo $REPO $RUN_ID --log-failed" >&2
    exit 1
fi

echo
./download-builds.sh "$RUN_ID"

echo
"$COPY_SCRIPT"

LINUX_BIN="$OA_DIR/app/bin/linux_x86_64/ffmpeg"
if [[ "$(uname -s)-$(uname -m)" == "Linux-x86_64" && -x "$LINUX_BIN" ]]; then
    echo
    echo "Installed linux_x86_64 binary:"
    "$LINUX_BIN" -hide_banner -version | head -1
    "$LINUX_BIN" -hide_banner -version | tr ' ' '\n' | grep OACOMPAT || true
fi
