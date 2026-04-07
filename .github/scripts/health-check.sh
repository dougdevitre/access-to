#!/usr/bin/env bash
set -euo pipefail

# Generates a health dashboard across all Access To repositories.
#
# Usage: ./health-check.sh <repos-file>
#
# Outputs a markdown summary to GITHUB_STEP_SUMMARY (or stdout if not in CI).

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib-log.sh"

REPOS_FILE="${1:?Usage: health-check.sh <repos-file>}"
OUTPUT="${GITHUB_STEP_SUMMARY:-/dev/stdout}"

if [ ! -f "$REPOS_FILE" ]; then
  log_error "Repos config not found: $REPOS_FILE"
  exit 1
fi

log_init "health-check"

OWNER=$(jq -r '.owner' "$REPOS_FILE")
mapfile -t REPOS < <(jq -r '.repos[] | if type == "object" then .name else . end' "$REPOS_FILE")

log_info "Checking ${#REPOS[@]} repos under $OWNER"

# Fetch all repo data once and cache it
declare -A REPO_CACHE
FETCH_ERRORS=0

for REPO in "${REPOS[@]}"; do
  FULL="$OWNER/$REPO"
  if DATA=$(gh repo view "$FULL" --json openIssues,pushedAt 2>&1); then
    REPO_CACHE["$REPO"]="$DATA"
    log_action "fetch-repo" "$REPO" "success"
  else
    REPO_CACHE["$REPO"]="{}"
    log_action "fetch-repo" "$REPO" "failed" "$DATA"
    ((FETCH_ERRORS++)) || true
  fi
done

# Calculate stale threshold
THIRTY_DAYS_AGO=$(date -u -d '30 days ago' '+%Y-%m-%d' 2>/dev/null || date -u -v-30d '+%Y-%m-%d' 2>/dev/null || echo "")

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
  STALE_REPOS=()

  for REPO in "${REPOS[@]}"; do
    FULL="$OWNER/$REPO"
    DATA="${REPO_CACHE[$REPO]}"
    PILLAR=$(jq -r --arg name "$REPO" '.repos[] | select(.name == $name) | .pillar // "—"' "$REPOS_FILE")

    ISSUES=$(echo "$DATA" | jq -r '.openIssues // 0' 2>/dev/null || echo "?")
    PUSHED_RAW=$(echo "$DATA" | jq -r '.pushedAt // ""' 2>/dev/null || echo "")

    # Validate date format before using
    PUSHED_SHORT="—"
    if [[ "$PUSHED_RAW" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2} ]]; then
      PUSHED_SHORT="${PUSHED_RAW:0:10}"
      # Check staleness using the same cached data
      if [ -n "$THIRTY_DAYS_AGO" ] && [[ "$PUSHED_SHORT" < "$THIRTY_DAYS_AGO" ]]; then
        STALE_REPOS+=("$REPO|$PUSHED_SHORT")
      fi
    fi

    # Count open PRs
    PR_COUNT=$(gh pr list --repo "$FULL" --state open --json number 2>/dev/null | jq length 2>/dev/null || echo "?")

    echo "| [$(escape_md "$REPO")](https://github.com/$FULL) | $ISSUES | $PR_COUNT | $PUSHED_SHORT | $PILLAR |"

    if [[ "$ISSUES" =~ ^[0-9]+$ ]]; then ((TOTAL_ISSUES += ISSUES)) || true; fi
    if [[ "$PR_COUNT" =~ ^[0-9]+$ ]]; then ((TOTAL_PRS += PR_COUNT)) || true; fi
  done

  echo "| **Total** | **$TOTAL_ISSUES** | **$TOTAL_PRS** | | |"
  echo ""

  # --- Stale repos ---
  echo "### Repos with No Activity (30+ days)"
  echo ""
  if [ ${#STALE_REPOS[@]} -gt 0 ]; then
    for ENTRY in "${STALE_REPOS[@]}"; do
      REPO="${ENTRY%%|*}"
      PUSHED="${ENTRY##*|}"
      echo "- **$(escape_md "$REPO")** — last push: $PUSHED"
      log_action "stale-check" "$REPO" "stale" "last push $PUSHED"
    done
  else
    echo "_All repos have recent activity._"
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
      # Escape issue titles before writing to summary
      echo "$CROSS_ISSUES" | jq -r --arg repo "$REPO" '.[] | "- **\($repo)#\(.number)**: \(.title | gsub("[*_\\[\\]`\\\\|]"; "\\\\\\(.)"))"'
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

  echo ""

  # --- Ecosystem metrics ---
  echo "### Ecosystem Metrics"
  echo ""
  REPO_COUNT=${#REPOS[@]}
  PILLAR_COUNT=$(jq '[.repos[].pillar] | unique | length' "$REPOS_FILE")
  CONNECTION_COUNT=$(jq '[.repos[].connects_to // [] | .[]] | length' "$REPOS_FILE")
  echo "| Metric | Value |"
  echo "|--------|-------|"
  echo "| Total repos | $REPO_COUNT |"
  echo "| Pillars | $PILLAR_COUNT |"
  echo "| Cross-connections | $CONNECTION_COUNT |"
  echo "| Total open issues | $TOTAL_ISSUES |"
  echo "| Total open PRs | $TOTAL_PRS |"
  echo "| Stale repos (30d) | ${#STALE_REPOS[@]} |"
  echo "| Cross-repo issues | $CROSS_COUNT |"
  echo "| API fetch errors | $FETCH_ERRORS |"

} >> "$OUTPUT"

log_summary

if [ "$FETCH_ERRORS" -gt 0 ]; then
  log_warn "$FETCH_ERRORS repo(s) could not be fetched"
fi
