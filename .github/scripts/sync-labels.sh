#!/usr/bin/env bash
set -euo pipefail

# Syncs a shared label set from a config file to all Access To repositories.
#
# Usage: ./sync-labels.sh <labels-file> <repos-file>

LABELS_FILE="${1:?Usage: sync-labels.sh <labels-file> <repos-file>}"
REPOS_FILE="${2:?Usage: sync-labels.sh <labels-file> <repos-file>}"

if [ ! -f "$LABELS_FILE" ] || [ ! -f "$REPOS_FILE" ]; then
  echo "::error::Config files not found"
  exit 1
fi

OWNER=$(jq -r '.owner' "$REPOS_FILE")
mapfile -t REPOS < <(jq -r '.repos[].name' "$REPOS_FILE")
LABEL_COUNT=$(jq length "$LABELS_FILE")

echo "Syncing $LABEL_COUNT labels to ${#REPOS[@]} repos under $OWNER"

ERRORS=0

for REPO in "${REPOS[@]}"; do
  echo ""
  echo "--- $REPO ---"

  for i in $(seq 0 $((LABEL_COUNT - 1))); do
    NAME=$(jq -r ".[$i].name" "$LABELS_FILE")
    COLOR=$(jq -r ".[$i].color" "$LABELS_FILE")
    DESC=$(jq -r ".[$i].description" "$LABELS_FILE")

    # Try to create; if it exists, update it
    if gh label create "$NAME" \
      --repo "$OWNER/$REPO" \
      --color "$COLOR" \
      --description "$DESC" \
      --force 2>/dev/null; then
      echo "  $NAME"
    else
      echo "::warning::Failed to sync label '$NAME' to $REPO"
      ((ERRORS++))
    fi
  done
done

echo ""
echo "Label sync complete."

if [ "$ERRORS" -gt 0 ]; then
  echo "::warning::$ERRORS label(s) failed to sync"
fi
