#!/usr/bin/env bash
set -euo pipefail

# Syncs a shared label set from a config file to all Access To repositories.
#
# Usage: ./sync-labels.sh <labels-file> <repos-file>

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib-log.sh"

LABELS_FILE="${1:?Usage: sync-labels.sh <labels-file> <repos-file>}"
REPOS_FILE="${2:?Usage: sync-labels.sh <labels-file> <repos-file>}"

if [ ! -f "$LABELS_FILE" ] || [ ! -f "$REPOS_FILE" ]; then
  log_error "Config files not found"
  exit 1
fi

log_init "sync-labels"

OWNER=$(jq -r '.owner' "$REPOS_FILE")
mapfile -t REPOS < <(jq -r '.repos[] | if type == "object" then .name else . end' "$REPOS_FILE")
LABEL_COUNT=$(jq length "$LABELS_FILE")

log_info "Syncing $LABEL_COUNT labels to ${#REPOS[@]} repos under $OWNER"

SYNCED=0
ERRORS=0

for REPO in "${REPOS[@]}"; do
  log_info "--- $REPO ---"

  for i in $(seq 0 $((LABEL_COUNT - 1))); do
    NAME=$(jq -r ".[$i].name" "$LABELS_FILE")
    COLOR=$(jq -r ".[$i].color" "$LABELS_FILE")
    DESC=$(jq -r ".[$i].description" "$LABELS_FILE")

    if gh label create "$NAME" \
      --repo "$OWNER/$REPO" \
      --color "$COLOR" \
      --description "$DESC" \
      --force 2>/dev/null; then
      log_action "sync-label" "$REPO/$NAME" "success"
      ((SYNCED++))
    else
      log_action "sync-label" "$REPO/$NAME" "failed"
      ((ERRORS++))
    fi
  done
done

# Write job summary
if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
  {
    echo "## Label Sync Results"
    echo ""
    echo "| Metric | Count |"
    echo "|--------|-------|"
    echo "| Synced | $SYNCED |"
    echo "| Failed | $ERRORS |"
    echo "| Labels | $LABEL_COUNT |"
    echo "| Repos | ${#REPOS[@]} |"
  } >> "$GITHUB_STEP_SUMMARY"
fi

log_summary

if [ "$ERRORS" -gt 0 ]; then
  log_error "$ERRORS label(s) failed to sync"
  exit 1
fi
