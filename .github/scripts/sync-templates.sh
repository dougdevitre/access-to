#!/usr/bin/env bash
set -euo pipefail

# Syncs shared issue templates from the hub repo to all child repos.
#
# Usage: ./sync-templates.sh <repos-file> <templates-dir> [--all]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib-log.sh"

REPOS_FILE="${1:?Usage: sync-templates.sh <repos-file> <templates-dir> [--all]}"
TEMPLATES_DIR="${2:?Usage: sync-templates.sh <repos-file> <templates-dir> [--all]}"
SYNC_ALL="${3:-}"

if [ ! -f "$REPOS_FILE" ] || [ ! -d "$TEMPLATES_DIR" ]; then
  log_error "Config file or templates directory not found"
  exit 1
fi

log_init "sync-templates"

OWNER=$(jq -r '.owner' "$REPOS_FILE")
mapfile -t REPOS < <(jq -r '.repos[] | if type == "object" then .name else . end' "$REPOS_FILE")

# Skip the hub repo
HUB_REPO=$(jq -r '.repos[] | if type == "object" then select(.role == "hub") | .name else empty end' "$REPOS_FILE")

SYNCED=0
FAILED=0

for REPO in "${REPOS[@]}"; do
  if [ "$REPO" = "$HUB_REPO" ]; then
    log_info "Skipping hub repo: $REPO"
    continue
  fi

  FULL="$OWNER/$REPO"
  log_info "--- $REPO ---"

  for TEMPLATE in "$TEMPLATES_DIR"/*.md; do
    FILENAME=$(basename "$TEMPLATE")

    # Filter templates unless --all
    if [ "$SYNC_ALL" != "--all" ]; then
      case "$FILENAME" in
        cross_repo.md|bug_report.md) ;;
        *) continue ;;
      esac
    fi

    CONTENT=$(cat "$TEMPLATE")
    CONTENT_B64=$(printf '%s' "$CONTENT" | base64 -w 0)
    TARGET_PATH=".github/ISSUE_TEMPLATE/$FILENAME"

    # Try to get existing file SHA for update
    EXISTING_SHA=""
    if EXISTING=$(gh api "repos/$FULL/contents/$TARGET_PATH" 2>&1); then
      EXISTING_SHA=$(printf '%s' "$EXISTING" | jq -r '.sha // empty' 2>/dev/null || echo "")
    fi

    # Build API call
    API_ARGS=(
      "repos/$FULL/contents/$TARGET_PATH"
      --method PUT
      --field "message=Sync issue template: $FILENAME"
      --field "content=$CONTENT_B64"
    )

    if [ -n "$EXISTING_SHA" ]; then
      API_ARGS+=(--field "sha=$EXISTING_SHA")
    fi

    if OUTPUT=$(gh api "${API_ARGS[@]}" 2>&1); then
      # Verify the response contains our content SHA
      RESPONSE_SHA=$(printf '%s' "$OUTPUT" | jq -r '.content.sha // empty' 2>/dev/null || echo "")
      if [ -n "$RESPONSE_SHA" ]; then
        log_action "sync-template" "$REPO/$FILENAME" "success"
        ((SYNCED++)) || true
      else
        log_action "sync-template" "$REPO/$FILENAME" "unverified" "API returned OK but no content SHA"
        ((SYNCED++)) || true
      fi
    else
      # Parse the actual error
      ERROR_STATUS=$(printf '%s' "$OUTPUT" | grep -oP 'HTTP \K[0-9]+' | head -1 || echo "unknown")
      case "$ERROR_STATUS" in
        404)
          log_action "sync-template" "$REPO/$FILENAME" "failed" "repo or path not found"
          ;;
        403)
          log_action "sync-template" "$REPO/$FILENAME" "failed" "permission denied — check PROJECT_PAT scope"
          ;;
        409)
          log_action "sync-template" "$REPO/$FILENAME" "failed" "conflict — file may have been modified concurrently"
          ;;
        422)
          log_action "sync-template" "$REPO/$FILENAME" "failed" "validation error — check content encoding"
          ;;
        *)
          log_action "sync-template" "$REPO/$FILENAME" "failed" "HTTP $ERROR_STATUS"
          ;;
      esac
      ((FAILED++)) || true
    fi
  done
done

# Write job summary
if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
  {
    echo "## Template Sync Results"
    echo ""
    echo "| Metric | Count |"
    echo "|--------|-------|"
    echo "| Synced | $SYNCED |"
    echo "| Failed | $FAILED |"
  } >> "$GITHUB_STEP_SUMMARY"
fi

log_summary

if [ "$FAILED" -gt 0 ]; then
  log_error "$FAILED template(s) failed to sync"
  exit 1
fi
