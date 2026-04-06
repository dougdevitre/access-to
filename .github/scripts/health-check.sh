#!/usr/bin/env bash
set -euo pipefail

# Generates a health dashboard across all Access To repositories.
#
# Usage: ./health-check.sh <repos-file>
#
# Outputs a markdown summary to GITHUB_STEP_SUMMARY (or stdout if not in CI).

REPOS_FILE="${1:?Usage: health-check.sh <repos-file>}"
OUTPUT="${GITHUB_STEP_SUMMARY:-/dev/stdout}"

if [ ! -f "$REPOS_FILE" ]; then
  echo "::error::Repos config not found: $REPOS_FILE"
  exit 1
fi

OWNER=$(jq -r '.owner' "$REPOS_FILE")
mapfile -t REPOS < <(jq -r '.repos[].name' "$REPOS_FILE")

{
  echo "## Access To Ecosystem Health Dashboard"
  echo ""
  echo "_Generated on $(date -u '+%Y-%m-%d %H:%M UTC')_"
  echo ""

  # --- Open issues table ---
  echo "### Open Issues by Repo"
  echo ""
  echo "| Repo | Open Issues | Open PRs | Last Push | Pillar |"
  echo "|------|------------|----------|-----------|--------|"

  TOTAL_ISSUES=0
  TOTAL_PRS=0

  for REPO in "${REPOS[@]}"; do
    FULL="$OWNER/$REPO"
    PILLAR=$(jq -r --arg name "$REPO" '.repos[] | select(.name == $name) | .pillar // "—"' "$REPOS_FILE")

    # Fetch repo data
    REPO_DATA=$(gh repo view "$FULL" --json openIssues,pullRequests,pushedAt 2>/dev/null || echo '{}')
    ISSUES=$(echo "$REPO_DATA" | jq -r '.openIssues // 0' 2>/dev/null || echo "?")
    PUSHED=$(echo "$REPO_DATA" | jq -r '.pushedAt // "unknown"' 2>/dev/null || echo "?")

    # Count open PRs
    PR_COUNT=$(gh pr list --repo "$FULL" --state open --json number 2>/dev/null | jq length 2>/dev/null || echo "?")

    # Format date
    if [ "$PUSHED" != "unknown" ] && [ "$PUSHED" != "?" ]; then
      PUSHED_SHORT=$(echo "$PUSHED" | cut -c1-10)
    else
      PUSHED_SHORT="—"
    fi

    echo "| [$REPO](https://github.com/$FULL) | $ISSUES | $PR_COUNT | $PUSHED_SHORT | $PILLAR |"

    if [[ "$ISSUES" =~ ^[0-9]+$ ]]; then ((TOTAL_ISSUES += ISSUES)) || true; fi
    if [[ "$PR_COUNT" =~ ^[0-9]+$ ]]; then ((TOTAL_PRS += PR_COUNT)) || true; fi
  done

  echo "| **Total** | **$TOTAL_ISSUES** | **$TOTAL_PRS** | | |"
  echo ""

  # --- Stale repos (no push in 30+ days) ---
  echo "### Repos with No Activity (30+ days)"
  echo ""
  STALE_COUNT=0
  THIRTY_DAYS_AGO=$(date -u -d '30 days ago' '+%Y-%m-%d' 2>/dev/null || date -u -v-30d '+%Y-%m-%d' 2>/dev/null || echo "")

  if [ -n "$THIRTY_DAYS_AGO" ]; then
    for REPO in "${REPOS[@]}"; do
      FULL="$OWNER/$REPO"
      PUSHED=$(gh repo view "$FULL" --json pushedAt --jq '.pushedAt' 2>/dev/null | cut -c1-10 || echo "")
      if [ -n "$PUSHED" ] && [[ "$PUSHED" < "$THIRTY_DAYS_AGO" ]]; then
        echo "- **$REPO** — last push: $PUSHED"
        ((STALE_COUNT++))
      fi
    done
    if [ "$STALE_COUNT" -eq 0 ]; then
      echo "_All repos have recent activity._"
    fi
  else
    echo "_Could not determine date threshold._"
  fi

  echo ""

  # --- Cross-repo issues ---
  echo "### Cross-Repo Issues"
  echo ""
  CROSS_COUNT=0
  for REPO in "${REPOS[@]}"; do
    FULL="$OWNER/$REPO"
    CROSS_ISSUES=$(gh issue list --repo "$FULL" --label "cross-repo" --state open --json number,title 2>/dev/null || echo '[]')
    COUNT=$(echo "$CROSS_ISSUES" | jq length 2>/dev/null || echo 0)
    if [ "$COUNT" -gt 0 ]; then
      echo "$CROSS_ISSUES" | jq -r --arg repo "$REPO" '.[] | "- **\($repo)#\(.number)**: \(.title)"'
      ((CROSS_COUNT += COUNT))
    fi
  done
  if [ "$CROSS_COUNT" -eq 0 ]; then
    echo "_No open cross-repo issues._"
  fi

  echo ""

  # --- Connection map ---
  echo "### Pillar Connections"
  echo ""
  echo '```mermaid'
  echo 'graph LR'
  for REPO in "${REPOS[@]}"; do
    CONNECTIONS=$(jq -r --arg name "$REPO" '.repos[] | select(.name == $name) | .connects_to // [] | .[]' "$REPOS_FILE" 2>/dev/null)
    if [ -n "$CONNECTIONS" ]; then
      while IFS= read -r TARGET; do
        echo "  $REPO --> $TARGET"
      done <<< "$CONNECTIONS"
    fi
  done
  echo '```'

} >> "$OUTPUT"

echo "Health check complete."
