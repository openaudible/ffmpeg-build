#!/usr/bin/env bash

set -euo pipefail

DAYS=30
DRY_RUN=true
DELETE_RUNS=false
REPOS=()
ALL_REPOS=false
OWNER=""

show_usage() {
    cat <<EOF
Usage: $0 [options]

Frees GitHub Actions storage by deleting workflow artifacts older than N days.
Artifacts are what consume the Actions storage quota; the quota is billed per
account, so cleaning a single repo may not be enough.

Options:
  --days N        Age threshold in days (default: 30)
  --repo R        Repo to clean (owner/name), repeatable
                  (default: the repo in the current directory)
  --all-repos     Clean every repo owned by the authenticated user
  --owner O       Owner to enumerate with --all-repos (default: authenticated user)
  --runs          Also delete the workflow runs themselves (removes logs)
  --execute       Actually delete. Without this the script only reports.
  -h, --help      Show this help

Examples:
  $0                              # dry run, this repo, 30 days
  $0 --all-repos                  # dry run across every repo you own
  $0 --all-repos --execute        # delete artifacts >30 days old everywhere
  $0 --days 7 --runs --execute    # also purge run logs older than 7 days
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --days) DAYS="$2"; shift 2 ;;
        --repo) REPOS+=("$2"); shift 2 ;;
        --all-repos) ALL_REPOS=true; shift ;;
        --owner) OWNER="$2"; shift 2 ;;
        --runs) DELETE_RUNS=true; shift ;;
        --execute) DRY_RUN=false; shift ;;
        -h|--help) show_usage; exit 0 ;;
        *) echo "ERROR: unknown option: $1" >&2; show_usage >&2; exit 1 ;;
    esac
done

for tool in gh jq; do
    if ! command -v "$tool" &> /dev/null; then
        echo "ERROR: $tool not found" >&2
        exit 1
    fi
done

if ! gh auth status &> /dev/null; then
    echo "ERROR: not logged in. Run: gh auth login" >&2
    exit 1
fi

CUTOFF=$(date -u -d "${DAYS} days ago" +%Y-%m-%dT%H:%M:%SZ)

if [[ "$ALL_REPOS" == true ]]; then
    [[ -z "$OWNER" ]] && OWNER=$(gh api user --jq .login)
    mapfile -t REPOS < <(gh repo list "$OWNER" --limit 1000 --json nameWithOwner -q '.[].nameWithOwner')
elif [[ ${#REPOS[@]} -eq 0 ]]; then
    REPOS=("$(gh repo view --json nameWithOwner -q .nameWithOwner)")
fi

human() {
    numfmt --to=iec-i --suffix=B --format='%.1f' "$1" 2>/dev/null || echo "${1}B"
}

echo "Cutoff:  artifacts created before $CUTOFF (${DAYS} days)"
echo "Repos:   ${#REPOS[@]}"
echo "Mode:    $([[ "$DRY_RUN" == true ]] && echo 'DRY RUN (nothing deleted; pass --execute to delete)' || echo 'DELETE')"
echo

total_bytes=0
total_count=0
total_runs=0

for repo in "${REPOS[@]}"; do
    artifacts=$(gh api --paginate "repos/$repo/actions/artifacts?per_page=100" \
        --jq '.artifacts[]' 2>/dev/null | jq -s \
        --arg cutoff "$CUTOFF" \
        '[.[] | select(.expired == false and .created_at < $cutoff)]')

    count=$(jq 'length' <<<"$artifacts")
    [[ "$count" -eq 0 ]] && continue

    bytes=$(jq '[.[].size_in_bytes] | add' <<<"$artifacts")
    echo "$repo: $count artifact(s), $(human "$bytes")"

    while IFS=$'\t' read -r id name size created; do
        printf '  %-40.40s %10s  %s' "$name" "$(human "$size")" "${created%T*}"
        if [[ "$DRY_RUN" == true ]]; then
            printf '  [would delete]\n'
        elif gh api -X DELETE "repos/$repo/actions/artifacts/$id" --silent 2>/dev/null; then
            printf '  [deleted]\n'
        else
            printf '  [FAILED]\n'
        fi
    done < <(jq -r '.[] | [.id, .name, .size_in_bytes, .created_at] | @tsv' <<<"$artifacts")

    total_bytes=$((total_bytes + bytes))
    total_count=$((total_count + count))
done

if [[ "$DELETE_RUNS" == true ]]; then
    echo
    for repo in "${REPOS[@]}"; do
        mapfile -t run_ids < <(gh api --paginate \
            "repos/$repo/actions/runs?per_page=100&created=<${CUTOFF%T*}" \
            --jq '.workflow_runs[] | select(.status == "completed") | .id' 2>/dev/null)
        [[ ${#run_ids[@]} -eq 0 ]] && continue

        echo "$repo: ${#run_ids[@]} completed run(s) older than ${DAYS} days"
        for id in "${run_ids[@]}"; do
            if [[ "$DRY_RUN" == true ]]; then
                echo "  run $id [would delete]"
            elif gh api -X DELETE "repos/$repo/actions/runs/$id" --silent 2>/dev/null; then
                echo "  run $id [deleted]"
            else
                echo "  run $id [FAILED]"
            fi
        done
        total_runs=$((total_runs + ${#run_ids[@]}))
    done
fi

echo
if [[ "$DRY_RUN" == true ]]; then
    echo "Would free $(human "$total_bytes") from $total_count artifact(s)$([[ "$DELETE_RUNS" == true ]] && echo " and $total_runs run(s)")."
    echo "Re-run with --execute to delete."
else
    echo "Freed $(human "$total_bytes") from $total_count artifact(s)$([[ "$DELETE_RUNS" == true ]] && echo " and $total_runs run(s)")."
    echo "Note: GitHub's storage usage report updates on a delay (can take hours)."
fi
