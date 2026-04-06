#!/usr/bin/env bash
set -euo pipefail

# Onboards a new repository into the Access To ecosystem.
#
# Usage: ./onboard-repo.sh <repo-name> <pillar> [scope]
#
# This script:
#   1. Verifies the repo exists
#   2. Syncs shared labels
#   3. Adds repo to GitHub Project
#   4. Creates a welcome issue with setup checklist
#   5. Prints next steps for manual config updates

REPO_NAME="${1:?Usage: onboard-repo.sh <repo-name> <pillar> [scope]}"
PILLAR="${2:?Usage: onboard-repo.sh <repo-name> <pillar> [scope]}"
SCOPE="${3:-nationwide}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$SCRIPT_DIR/../config"
LABELS_FILE="$CONFIG_DIR/labels.json"
REPOS_FILE="$CONFIG_DIR/repos.json"

OWNER=$(jq -r '.owner' "$REPOS_FILE")
PROJECT_NUMBER=$(jq -r '.project_number' "$REPOS_FILE")
FULL_REPO="$OWNER/$REPO_NAME"

echo "=== Onboarding $FULL_REPO ==="
echo "  Pillar: $PILLAR"
echo "  Scope:  $SCOPE"
echo ""

# 1. Verify repo exists
echo "Step 1: Verifying repo exists..."
if ! gh repo view "$FULL_REPO" --json name >/dev/null 2>&1; then
  echo "::error::Repository $FULL_REPO not found on GitHub"
  echo ""
  echo "Create it first:"
  echo "  gh repo create $FULL_REPO --public --description 'Access to ${PILLAR^} — Claude Skill for ...'"
  exit 1
fi
echo "  Confirmed: $FULL_REPO exists"

# 2. Sync labels
echo ""
echo "Step 2: Syncing shared labels..."
LABEL_COUNT=$(jq length "$LABELS_FILE")
SYNCED=0
for i in $(seq 0 $((LABEL_COUNT - 1))); do
  NAME=$(jq -r ".[$i].name" "$LABELS_FILE")
  COLOR=$(jq -r ".[$i].color" "$LABELS_FILE")
  DESC=$(jq -r ".[$i].description" "$LABELS_FILE")
  if gh label create "$NAME" --repo "$FULL_REPO" --color "$COLOR" --description "$DESC" --force 2>/dev/null; then
    ((SYNCED++))
  fi
done
echo "  Synced $SYNCED/$LABEL_COUNT labels"

# 3. Add to GitHub Project
echo ""
echo "Step 3: Adding to GitHub Project #$PROJECT_NUMBER..."
REPO_URL="https://github.com/$FULL_REPO"
if gh project item-add "$PROJECT_NUMBER" --owner "$OWNER" --url "$REPO_URL" 2>/dev/null; then
  echo "  Added to project"
else
  echo "  Already in project or could not add (check PROJECT_PAT permissions)"
fi

# 4. Create welcome issue
echo ""
echo "Step 4: Creating onboarding checklist issue..."
ISSUE_BODY=$(cat <<ISSUE_EOF
## Welcome to the Access To Ecosystem

This repo has been onboarded into the Access To admin system. Complete the checklist below to finish setup.

### Automated (already done)
- [x] Shared labels synced ($SYNCED labels)
- [x] Added to GitHub Project #$PROJECT_NUMBER

### Manual setup required
- [ ] Add \`PROJECT_PAT\` repository secret (Settings → Secrets → Actions)
- [ ] Add repo entry to hub's \`.github/config/repos.json\`
- [ ] Create \`SKILL.md\` with Claude Skill content
- [ ] Add \`CONTRIBUTING.md\` (or link to hub's)
- [ ] Add \`CODE_OF_CONDUCT.md\` (or link to hub's)
- [ ] Add \`LICENSE\` (MIT)
- [ ] Create pillar page on hub site (\`${PILLAR}.html\`)
- [ ] Update hub \`README.md\` with new repo
- [ ] Update hub \`sitemap.xml\` if new page added
- [ ] Set up branch protection on \`main\`

### Repo metadata
| Field | Value |
|-------|-------|
| Pillar | $PILLAR |
| Scope | $SCOPE |
| Hub config | \`.github/config/repos.json\` |

### Config entry to add to hub repos.json
\`\`\`json
{
  "name": "$REPO_NAME",
  "pillar": "$PILLAR",
  "description": "",
  "scope": "$SCOPE",
  "role": "pillar",
  "connects_to": []
}
\`\`\`
ISSUE_EOF
)

gh issue create \
  --repo "$FULL_REPO" \
  --title "Onboarding: Complete Access To ecosystem setup" \
  --body "$ISSUE_BODY" \
  --label "type:infra,status:triage" 2>/dev/null && \
  echo "  Created onboarding issue" || \
  echo "  Could not create issue (check permissions)"

# 5. Print next steps
echo ""
echo "=== Onboarding complete ==="
echo ""
echo "Next steps (manual):"
echo "  1. Add the config entry above to .github/config/repos.json in the hub repo"
echo "  2. Add PROJECT_PAT secret to $FULL_REPO"
echo "  3. Create SKILL.md in $FULL_REPO"
echo "  4. Run: gh workflow run sync-labels.yml  (to verify label sync)"
echo ""
