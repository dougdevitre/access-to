#!/usr/bin/env bash
set -euo pipefail

# Validates Access To configuration files for structural correctness
# and referential integrity.
#
# Usage: ./validate-config.sh <config-dir>
#
# Checks:
#   - repos.json: required fields, valid pillars, connects_to references exist
#   - labels.json: required fields, valid hex colors, no duplicate names
#   - Cross-file: pillar labels exist for each pillar in repos.json

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib-log.sh"

CONFIG_DIR="${1:?Usage: validate-config.sh <config-dir>}"
REPOS_FILE="$CONFIG_DIR/repos.json"
LABELS_FILE="$CONFIG_DIR/labels.json"

log_init "validate-config"
ERRORS=0
WARNINGS=0

# --- repos.json ---
log_info "Validating repos.json..."

if [ ! -f "$REPOS_FILE" ]; then
  log_error "repos.json not found at $REPOS_FILE"
  exit 1
fi

# Valid JSON check
if ! jq empty "$REPOS_FILE" 2>/dev/null; then
  log_error "repos.json is not valid JSON"
  exit 1
fi

# Required top-level fields
for FIELD in owner project_number repos; do
  if [ "$(jq "has(\"$FIELD\")" "$REPOS_FILE")" != "true" ]; then
    log_error "repos.json missing required field: $FIELD"
    ((ERRORS++))
  fi
done

# Validate each repo entry
REPO_COUNT=$(jq '.repos | length' "$REPOS_FILE")
mapfile -t REPO_NAMES < <(jq -r '.repos[].name' "$REPOS_FILE")

VALID_PILLARS=("hub" "housing" "jobs" "health" "business" "services" "education" "safety")
VALID_SCOPES=("missouri" "nationwide" "global")
VALID_ROLES=("hub" "pillar" "tool" "docs")

for i in $(seq 0 $((REPO_COUNT - 1))); do
  NAME=$(jq -r ".repos[$i].name" "$REPOS_FILE")

  # Required fields
  for FIELD in name pillar description scope role; do
    VAL=$(jq -r ".repos[$i].$FIELD // empty" "$REPOS_FILE")
    if [ -z "$VAL" ]; then
      log_error "repos[$i] ($NAME): missing required field '$FIELD'"
      ((ERRORS++))
    fi
  done

  # Valid pillar
  PILLAR=$(jq -r ".repos[$i].pillar // empty" "$REPOS_FILE")
  if [ -n "$PILLAR" ]; then
    FOUND=false
    for P in "${VALID_PILLARS[@]}"; do [ "$P" = "$PILLAR" ] && FOUND=true; done
    if [ "$FOUND" = false ]; then
      log_error "repos[$i] ($NAME): invalid pillar '$PILLAR' — expected one of: ${VALID_PILLARS[*]}"
      ((ERRORS++))
    fi
  fi

  # Valid scope
  SCOPE=$(jq -r ".repos[$i].scope // empty" "$REPOS_FILE")
  if [ -n "$SCOPE" ]; then
    FOUND=false
    for S in "${VALID_SCOPES[@]}"; do [ "$S" = "$SCOPE" ] && FOUND=true; done
    if [ "$FOUND" = false ]; then
      log_error "repos[$i] ($NAME): invalid scope '$SCOPE' — expected one of: ${VALID_SCOPES[*]}"
      ((ERRORS++))
    fi
  fi

  # Valid role
  ROLE=$(jq -r ".repos[$i].role // empty" "$REPOS_FILE")
  if [ -n "$ROLE" ]; then
    FOUND=false
    for R in "${VALID_ROLES[@]}"; do [ "$R" = "$ROLE" ] && FOUND=true; done
    if [ "$FOUND" = false ]; then
      log_error "repos[$i] ($NAME): invalid role '$ROLE' — expected one of: ${VALID_ROLES[*]}"
      ((ERRORS++))
    fi
  fi

  # Referential integrity: connects_to must reference existing repo names
  mapfile -t CONNECTIONS < <(jq -r ".repos[$i].connects_to // [] | .[]" "$REPOS_FILE")
  for CONN in "${CONNECTIONS[@]}"; do
    FOUND=false
    for RN in "${REPO_NAMES[@]}"; do [ "$RN" = "$CONN" ] && FOUND=true; done
    if [ "$FOUND" = false ]; then
      log_error "repos[$i] ($NAME): connects_to references unknown repo '$CONN'"
      ((ERRORS++))
    fi
    if [ "$CONN" = "$NAME" ]; then
      log_warn "repos[$i] ($NAME): connects_to references itself"
      ((WARNINGS++))
    fi
  done

  log_action "validate-repo" "$NAME" "checked"
done

# Check for duplicate repo names
DUPES=$(jq -r '.repos[].name' "$REPOS_FILE" | sort | uniq -d)
if [ -n "$DUPES" ]; then
  log_error "Duplicate repo names found: $DUPES"
  ((ERRORS++))
fi

# Exactly one hub
HUB_COUNT=$(jq '[.repos[] | select(.role == "hub")] | length' "$REPOS_FILE")
if [ "$HUB_COUNT" -ne 1 ]; then
  log_warn "Expected exactly 1 hub repo, found $HUB_COUNT"
  ((WARNINGS++))
fi

# --- labels.json ---
log_info "Validating labels.json..."

if [ ! -f "$LABELS_FILE" ]; then
  log_error "labels.json not found at $LABELS_FILE"
  exit 1
fi

if ! jq empty "$LABELS_FILE" 2>/dev/null; then
  log_error "labels.json is not valid JSON"
  exit 1
fi

LABEL_COUNT=$(jq length "$LABELS_FILE")

for i in $(seq 0 $((LABEL_COUNT - 1))); do
  LNAME=$(jq -r ".[$i].name // empty" "$LABELS_FILE")
  COLOR=$(jq -r ".[$i].color // empty" "$LABELS_FILE")
  DESC=$(jq -r ".[$i].description // empty" "$LABELS_FILE")

  if [ -z "$LNAME" ]; then
    log_error "labels[$i]: missing 'name'"
    ((ERRORS++))
  fi
  if [ -z "$COLOR" ]; then
    log_error "labels[$i] ($LNAME): missing 'color'"
    ((ERRORS++))
  elif ! echo "$COLOR" | grep -qE '^[0-9a-fA-F]{6}$'; then
    log_error "labels[$i] ($LNAME): invalid color '$COLOR' — must be 6-char hex"
    ((ERRORS++))
  fi
  if [ -z "$DESC" ]; then
    log_warn "labels[$i] ($LNAME): missing 'description'"
    ((WARNINGS++))
  fi
done

# Duplicate label names
LABEL_DUPES=$(jq -r '.[].name' "$LABELS_FILE" | sort | uniq -d)
if [ -n "$LABEL_DUPES" ]; then
  log_error "Duplicate label names: $LABEL_DUPES"
  ((ERRORS++))
fi

# --- Cross-file checks ---
log_info "Running cross-file checks..."

# Each pillar in repos.json should have a matching pillar: label
mapfile -t PILLARS < <(jq -r '.repos[].pillar' "$REPOS_FILE" | sort -u)
for P in "${PILLARS[@]}"; do
  if [ "$P" = "hub" ]; then continue; fi
  LABEL_EXISTS=$(jq --arg p "pillar:$P" '[.[] | select(.name == $p)] | length' "$LABELS_FILE")
  if [ "$LABEL_EXISTS" -eq 0 ]; then
    log_warn "Pillar '$P' in repos.json has no matching 'pillar:$P' label"
    ((WARNINGS++))
  fi
done

# --- Summary ---
log_summary

if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
  {
    echo "## Config Validation Results"
    echo ""
    echo "| Check | Result |"
    echo "|-------|--------|"
    echo "| repos.json | $REPO_COUNT repos validated |"
    echo "| labels.json | $LABEL_COUNT labels validated |"
    echo "| Errors | $ERRORS |"
    echo "| Warnings | $WARNINGS |"
  } >> "$GITHUB_STEP_SUMMARY"
fi

if [ "$ERRORS" -gt 0 ]; then
  log_error "Validation failed with $ERRORS error(s)"
  exit 1
fi

log_success "All checks passed ($WARNINGS warning(s))"
