#!/usr/bin/env bash
set -euo pipefail

# Syncs shared issue templates from the hub repo to all child repos.
#
# Usage: ./sync-templates.sh <repos-file> <templates-dir>
#
# Only syncs templates that have a "shared: true" marker in their frontmatter,
# or all templates if --all is passed.

REPOS_FILE="${1:?Usage: sync-templates.sh <repos-file> <templates-dir> [--all]}"
TEMPLATES_DIR="${2:?Usage: sync-templates.sh <repos-file> <templates-dir> [--all]}"
SYNC_ALL="${3:-}"

if [ ! -f "$REPOS_FILE" ] || [ ! -d "$TEMPLATES_DIR" ]; then
  echo "::error::Config file or templates directory not found"
  exit 1
fi

OWNER=$(jq -r '.owner' "$REPOS_FILE")
mapfile -t REPOS < <(jq -r '.repos[] | if type == "object" then .name else . end' "$REPOS_FILE")

# Skip the hub repo — it already has the templates
HUB_REPO=$(jq -r '.repos[] | if type == "object" then select(.role == "hub") | .name else empty end' "$REPOS_FILE")

SYNCED=0
FAILED=0

for REPO in "${REPOS[@]}"; do
  if [ "$REPO" = "$HUB_REPO" ]; then
    echo "Skipping hub repo: $REPO"
    continue
  fi

  FULL="$OWNER/$REPO"
  echo ""
  echo "--- $REPO ---"

  for TEMPLATE in "$TEMPLATES_DIR"/*.md; do
    FILENAME=$(basename "$TEMPLATE")

    # Check if template should be synced
    if [ "$SYNC_ALL" != "--all" ]; then
      # Only sync cross_repo and bug_report templates by default
      case "$FILENAME" in
        cross_repo.md|bug_report.md) ;;
        *) continue ;;
      esac
    fi

    CONTENT=$(cat "$TEMPLATE")
    TARGET_PATH=".github/ISSUE_TEMPLATE/$FILENAME"

    if gh api "repos/$FULL/contents/$TARGET_PATH" \
      --method PUT \
      --field message="Sync issue template: $FILENAME" \
      --field content="$(echo "$CONTENT" | base64 -w 0)" \
      --field sha="$(gh api "repos/$FULL/contents/$TARGET_PATH" --jq '.sha' 2>/dev/null || echo "")" \
      >/dev/null 2>&1; then
      echo "  Synced $FILENAME"
      ((SYNCED++))
    else
      # File might not exist yet — try without sha
      if gh api "repos/$FULL/contents/$TARGET_PATH" \
        --method PUT \
        --field message="Sync issue template: $FILENAME" \
        --field content="$(echo "$CONTENT" | base64 -w 0)" \
        >/dev/null 2>&1; then
        echo "  Created $FILENAME"
        ((SYNCED++))
      else
        echo "::warning::Failed to sync $FILENAME to $REPO"
        ((FAILED++))
      fi
    fi
  done
done

echo ""
echo "Template sync complete: $SYNCED synced, $FAILED failed"
