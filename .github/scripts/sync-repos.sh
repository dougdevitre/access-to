#!/usr/bin/env bash
set -euo pipefail

# Syncs repositories listed in a config file to a GitHub Project.
#
# Usage: ./sync-repos.sh <config-file> [project_number] [owner]
#
# Arguments override values from the config file.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib-log.sh"

CONFIG_FILE="${1:?Usage: sync-repos.sh <config-file> [project_number] [owner]}"
PROJECT_NUMBER="${2:-$(jq -r '.project_number' "$CONFIG_FILE")}"
OWNER="${3:-$(jq -r '.owner' "$CONFIG_FILE")}"
MAX_RETRIES="${MAX_RETRIES:-3}"
RETRY_DELAY="${RETRY_DELAY:-2}"

if [ ! -f "$CONFIG_FILE" ]; then
  log_error "Config file not found: $CONFIG_FILE"
  exit 1
fi

log_init "sync-repos"

# Read repo list from config
mapfile -t REPOS < <(jq -r '.repos[] | if type == "object" then .name else . end' "$CONFIG_FILE")

if [ ${#REPOS[@]} -eq 0 ]; then
  log_error "No repos found in $CONFIG_FILE"
  exit 1
fi

# Retry wrapper for gh commands
gh_retry() {
  local attempt=1
  local output
  while [ $attempt -le "$MAX_RETRIES" ]; do
    if output=$(gh "$@" 2>&1); then
      echo "$output"
      return 0
    fi
    if [ $attempt -lt "$MAX_RETRIES" ]; then
      local wait=$((RETRY_DELAY ** attempt))
      log_info "Retry $attempt/$MAX_RETRIES in ${wait}s..."
      sleep "$wait"
    fi
    ((attempt++))
  done
  echo "$output"
  return 1
}

# Validate project exists
PROJECT_ID=$(gh_retry project list --owner "$OWNER" --format json | \
  jq -r --arg num "$PROJECT_NUMBER" '.[] | select(.number == ($num | tonumber)) | .id' | \
  head -1)

if [ -z "$PROJECT_ID" ]; then
  log_error "Project $PROJECT_NUMBER not found for owner $OWNER"
  exit 1
fi

log_info "Found project ID: $PROJECT_ID"

ADDED=0
SKIPPED=0
FAILED=0
DETAILS=""

for REPO in "${REPOS[@]}"; do
  REPO_URL="https://github.com/$OWNER/$REPO"

  if OUTPUT=$(gh_retry project item-add "$PROJECT_NUMBER" \
    --owner "$OWNER" \
    --url "$REPO_URL" 2>&1); then
    log_action "sync-repo" "$REPO" "added"
    DETAILS+="| $REPO | Added |"$'\n'
    ((ADDED++))
  else
    if echo "$OUTPUT" | grep -qi "already exists"; then
      log_action "sync-repo" "$REPO" "skipped" "already in project"
      DETAILS+="| $REPO | Skipped |"$'\n'
      ((SKIPPED++))
    else
      log_action "sync-repo" "$REPO" "failed" "$OUTPUT"
      DETAILS+="| $(escape_md "$REPO") | **Failed**: $(escape_md "$OUTPUT") |"$'\n'
      ((FAILED++))
    fi
  fi
done

# Write job summary
if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
  {
    echo "## Repo Sync Results"
    echo ""
    echo "| Metric | Count |"
    echo "|--------|-------|"
    echo "| Added | $ADDED |"
    echo "| Skipped (already in project) | $SKIPPED |"
    echo "| Failed | $FAILED |"
    echo "| **Total** | **${#REPOS[@]}** |"
    echo ""
    echo "<details><summary>Details per repo</summary>"
    echo ""
    echo "| Repo | Status |"
    echo "|------|--------|"
    echo "$DETAILS"
    echo "</details>"
  } >> "$GITHUB_STEP_SUMMARY"
fi

log_summary

if [ "$FAILED" -gt 0 ]; then
  log_error "$FAILED repo(s) failed to sync"
  exit 1
fi
