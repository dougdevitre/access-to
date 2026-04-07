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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib-log.sh"

REPO_NAME="${1:?Usage: onboard-repo.sh <repo-name> <pillar> [scope]}"
PILLAR="${2:?Usage: onboard-repo.sh <repo-name> <pillar> [scope]}"
SCOPE="${3:-nationwide}"

CONFIG_DIR="$SCRIPT_DIR/../config"

# Validate pillar
VALID_PILLARS=("hub" "housing" "jobs" "health" "business" "services" "education" "safety")
PILLAR_VALID=false
for P in "${VALID_PILLARS[@]}"; do [ "$P" = "$PILLAR" ] && PILLAR_VALID=true; done
if [ "$PILLAR_VALID" = false ]; then
  log_error "Invalid pillar '$PILLAR'. Must be one of: ${VALID_PILLARS[*]}"
  exit 1
fi

# Validate scope
VALID_SCOPES=("missouri" "nationwide" "global")
SCOPE_VALID=false
for S in "${VALID_SCOPES[@]}"; do [ "$S" = "$SCOPE" ] && SCOPE_VALID=true; done
if [ "$SCOPE_VALID" = false ]; then
  log_error "Invalid scope '$SCOPE'. Must be one of: ${VALID_SCOPES[*]}"
  exit 1
fi

# Validate repo name format
if ! echo "$REPO_NAME" | grep -qE '^[a-z0-9-]+$'; then
  log_error "Invalid repo name '$REPO_NAME'. Must be lowercase with hyphens only."
  exit 1
fi

LABELS_FILE="$CONFIG_DIR/labels.json"
REPOS_FILE="$CONFIG_DIR/repos.json"

OWNER=$(jq -r '.owner' "$REPOS_FILE")
PROJECT_NUMBER=$(jq -r '.project_number' "$REPOS_FILE")
FULL_REPO="$OWNER/$REPO_NAME"

log_init "onboard-repo"
log_info "Onboarding $FULL_REPO (pillar: $PILLAR, scope: $SCOPE)"

# 1. Verify repo exists
log_info "Step 1: Verifying repo exists..."
if ! gh repo view "$FULL_REPO" --json name >/dev/null 2>&1; then
  log_error "Repository $FULL_REPO not found on GitHub"
  log_info "Create it first: gh repo create $FULL_REPO --public --description 'Access to ${PILLAR^}'"
  exit 1
fi
log_action "verify-repo" "$FULL_REPO" "exists"

# 2. Sync labels
log_info "Step 2: Syncing shared labels..."
LABEL_COUNT=$(jq length "$LABELS_FILE")
SYNCED=0
for i in $(seq 0 $((LABEL_COUNT - 1))); do
  NAME=$(jq -r ".[$i].name" "$LABELS_FILE")
  COLOR=$(jq -r ".[$i].color" "$LABELS_FILE")
  DESC=$(jq -r ".[$i].description" "$LABELS_FILE")
  if gh label create "$NAME" --repo "$FULL_REPO" --color "$COLOR" --description "$DESC" --force 2>/dev/null; then
    ((SYNCED++)) || true
  fi
done
log_action "sync-labels" "$FULL_REPO" "success" "$SYNCED/$LABEL_COUNT synced"

# 3. Add to GitHub Project
log_info "Step 3: Adding to GitHub Project #$PROJECT_NUMBER..."
REPO_URL="https://github.com/$FULL_REPO"
if gh project item-add "$PROJECT_NUMBER" --owner "$OWNER" --url "$REPO_URL" 2>/dev/null; then
  log_action "add-to-project" "$FULL_REPO" "added"
else
  log_action "add-to-project" "$FULL_REPO" "skipped" "already in project or permission denied"
fi

# 4. Create welcome issue
log_info "Step 4: Creating onboarding checklist issue..."
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

if gh issue create \
  --repo "$FULL_REPO" \
  --title "Onboarding: Complete Access To ecosystem setup" \
  --body "$ISSUE_BODY" \
  --label "type:infra,status:triage" 2>/dev/null; then
  log_action "create-issue" "$FULL_REPO" "success"
else
  log_action "create-issue" "$FULL_REPO" "failed" "check permissions"
fi

# 5. Print next steps
log_summary
log_info "Next steps (manual):"
log_info "  1. Add the config entry above to .github/config/repos.json in the hub repo"
log_info "  2. Add PROJECT_PAT secret to $FULL_REPO"
log_info "  3. Create SKILL.md in $FULL_REPO"
log_info "  4. Run: gh workflow run sync-labels.yml  (to verify label sync)"
