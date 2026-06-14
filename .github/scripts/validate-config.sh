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
CONTENT_FILE="$CONFIG_DIR/content.json"

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
    ((ERRORS++)) || true
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
      ((ERRORS++)) || true
    fi
  done

  # Valid pillar
  PILLAR=$(jq -r ".repos[$i].pillar // empty" "$REPOS_FILE")
  if [ -n "$PILLAR" ]; then
    FOUND=false
    for P in "${VALID_PILLARS[@]}"; do [ "$P" = "$PILLAR" ] && FOUND=true; done
    if [ "$FOUND" = false ]; then
      log_error "repos[$i] ($NAME): invalid pillar '$PILLAR' — expected one of: ${VALID_PILLARS[*]}"
      ((ERRORS++)) || true
    fi
  fi

  # Valid scope
  SCOPE=$(jq -r ".repos[$i].scope // empty" "$REPOS_FILE")
  if [ -n "$SCOPE" ]; then
    FOUND=false
    for S in "${VALID_SCOPES[@]}"; do [ "$S" = "$SCOPE" ] && FOUND=true; done
    if [ "$FOUND" = false ]; then
      log_error "repos[$i] ($NAME): invalid scope '$SCOPE' — expected one of: ${VALID_SCOPES[*]}"
      ((ERRORS++)) || true
    fi
  fi

  # Valid role
  ROLE=$(jq -r ".repos[$i].role // empty" "$REPOS_FILE")
  if [ -n "$ROLE" ]; then
    FOUND=false
    for R in "${VALID_ROLES[@]}"; do [ "$R" = "$ROLE" ] && FOUND=true; done
    if [ "$FOUND" = false ]; then
      log_error "repos[$i] ($NAME): invalid role '$ROLE' — expected one of: ${VALID_ROLES[*]}"
      ((ERRORS++)) || true
    fi
  fi

  # Referential integrity: connects_to must reference existing repo names
  mapfile -t CONNECTIONS < <(jq -r ".repos[$i].connects_to // [] | .[]" "$REPOS_FILE")
  for CONN in "${CONNECTIONS[@]}"; do
    FOUND=false
    for RN in "${REPO_NAMES[@]}"; do [ "$RN" = "$CONN" ] && FOUND=true; done
    if [ "$FOUND" = false ]; then
      log_error "repos[$i] ($NAME): connects_to references unknown repo '$CONN'"
      ((ERRORS++)) || true
    fi
    if [ "$CONN" = "$NAME" ]; then
      log_warn "repos[$i] ($NAME): connects_to references itself"
      ((WARNINGS++)) || true
    fi
  done

  log_action "validate-repo" "$NAME" "checked"
done

# Check for duplicate repo names
DUPES=$(jq -r '.repos[].name' "$REPOS_FILE" | sort | uniq -d)
if [ -n "$DUPES" ]; then
  log_error "Duplicate repo names found: $DUPES"
  ((ERRORS++)) || true
fi

# Exactly one hub
HUB_COUNT=$(jq '[.repos[] | select(.role == "hub")] | length' "$REPOS_FILE")
if [ "$HUB_COUNT" -ne 1 ]; then
  log_warn "Expected exactly 1 hub repo, found $HUB_COUNT"
  ((WARNINGS++)) || true
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
    ((ERRORS++)) || true
  fi
  if [ -z "$COLOR" ]; then
    log_error "labels[$i] ($LNAME): missing 'color'"
    ((ERRORS++)) || true
  elif ! echo "$COLOR" | grep -qE '^[0-9a-fA-F]{6}$'; then
    log_error "labels[$i] ($LNAME): invalid color '$COLOR' — must be 6-char hex"
    ((ERRORS++)) || true
  fi
  if [ -z "$DESC" ]; then
    log_warn "labels[$i] ($LNAME): missing 'description'"
    ((WARNINGS++)) || true
  fi
done

# Duplicate label names
LABEL_DUPES=$(jq -r '.[].name' "$LABELS_FILE" | sort | uniq -d)
if [ -n "$LABEL_DUPES" ]; then
  log_error "Duplicate label names: $LABEL_DUPES"
  ((ERRORS++)) || true
fi

# --- Circular dependency detection ---
log_info "Checking for circular dependencies..."

# Cycle detection: find cycles of length 3+ (A→B→C→A).
# Bidirectional pairs (A↔B) are intentional and allowed.
# Runs in a subshell to isolate from set -e.
CYCLE_RESULTS=$(set +e; for START in $(jq -r '.repos[].name' "$REPOS_FILE"); do
  QUEUE="$START|0|$START"
  FOUND=false
  while [ -n "$QUEUE" ]; do
    ITEM="${QUEUE%%$'\n'*}"
    QUEUE="${QUEUE#"$ITEM"}"
    QUEUE="${QUEUE#$'\n'}"
    CURRENT="${ITEM%%|*}"
    REST="${ITEM#*|}"
    DEPTH="${REST%%|*}"
    VISITED="${REST#*|}"
    if [ "$DEPTH" -ge 6 ]; then continue; fi
    NEIGHBORS=$(jq -r --arg name "$CURRENT" '.repos[] | select(.name == $name) | .connects_to // [] | .[]' "$REPOS_FILE" 2>/dev/null)
    for NEIGHBOR in $NEIGHBORS; do
      if [ "$NEIGHBOR" = "$START" ] && [ "$DEPTH" -ge 2 ]; then
        FOUND=true
        break 2
      fi
      case " $VISITED " in *" $NEIGHBOR "*) continue ;; esac
      QUEUE="${QUEUE:+${QUEUE}$'\n'}$NEIGHBOR|$((DEPTH + 1))|$VISITED $NEIGHBOR"
    done
  done
  if [ "$FOUND" = true ]; then echo "$START"; fi
done)

CYCLES_FOUND=0
if [ -n "$CYCLE_RESULTS" ]; then
  while IFS= read -r CYCLE_REPO; do
    log_warn "Circular dependency (3+ hops) detected involving '$CYCLE_REPO'"
    ((WARNINGS++)) || true
    ((CYCLES_FOUND++)) || true
  done <<< "$CYCLE_RESULTS"
fi
if [ "$CYCLES_FOUND" -eq 0 ]; then
  log_info "No circular dependencies found (bidirectional pairs are allowed)"
fi

# --- Cross-file checks ---
log_info "Running cross-file checks..."

# Each pillar in repos.json should have a matching pillar: label
mapfile -t PILLARS < <(jq -r '.repos[].pillar' "$REPOS_FILE" | sort -u)
for P in "${PILLARS[@]}"; do
  if [ "$P" = "hub" ]; then continue; fi
  LABEL_EXISTS=$(jq --arg p "pillar:$P" '[.[] | select(.name == $p)] | length' "$LABELS_FILE")
  if [ "$LABEL_EXISTS" -eq 0 ]; then
    log_error "Pillar '$P' in repos.json has no matching 'pillar:$P' label"
    ((ERRORS++)) || true
  fi
done

# --- Graph integrity (repos.json <-> content.json) ---
# Treats the pillar dimension as the shared key across the config files and
# enforces the links that are otherwise implicit (color drift, stat drift,
# story flows referencing real pillars and real connections).
if [ ! -f "$CONTENT_FILE" ]; then
  log_warn "content.json not found at $CONTENT_FILE — skipping graph-integrity checks"
  ((WARNINGS++)) || true
elif ! jq empty "$CONTENT_FILE" 2>/dev/null; then
  log_error "content.json is not valid JSON"
  ((ERRORS++)) || true
else
  log_info "Running graph-integrity checks..."

  # Non-hub pillars are the network's nodes.
  mapfile -t NONHUB_PILLARS < <(jq -r '.repos[] | select(.role != "hub") | .pillar' "$REPOS_FILE")
  PILLAR_COUNT_DERIVED=$(jq '[.repos[] | select(.role != "hub") | .pillar] | unique | length' "$REPOS_FILE")
  PROJECT_COUNT_DERIVED=$(jq '[.repos[] | select(.role != "hub")] | length' "$REPOS_FILE")

  # 1. stats must match what repos.json actually contains (prevents hand-edit drift).
  STAT_PILLARS=$(jq -r '.brand.stats.pillars // empty' "$CONTENT_FILE")
  STAT_PROJECTS=$(jq -r '.brand.stats.projects // empty' "$CONTENT_FILE")
  if [ -n "$STAT_PILLARS" ] && [ "$STAT_PILLARS" != "$PILLAR_COUNT_DERIVED" ]; then
    log_error "content.json brand.stats.pillars=$STAT_PILLARS but repos.json has $PILLAR_COUNT_DERIVED pillars"
    ((ERRORS++)) || true
  fi
  if [ -n "$STAT_PROJECTS" ] && [ "$STAT_PROJECTS" != "$PROJECT_COUNT_DERIVED" ]; then
    log_error "content.json brand.stats.projects=$STAT_PROJECTS but repos.json has $PROJECT_COUNT_DERIVED non-hub repos"
    ((ERRORS++)) || true
  fi

  # 2. Every pillar must have a color in content.json that matches repos.json.
  for i in $(seq 0 $((REPO_COUNT - 1))); do
    ROLE=$(jq -r ".repos[$i].role // empty" "$REPOS_FILE")
    [ "$ROLE" = "hub" ] && continue
    PILLAR=$(jq -r ".repos[$i].pillar // empty" "$REPOS_FILE")
    REPO_COLOR=$(jq -r ".repos[$i].color // empty" "$REPOS_FILE")
    CONTENT_COLOR=$(jq -r --arg p "$PILLAR" '.brand.colors[$p] // empty' "$CONTENT_FILE")
    if [ -z "$CONTENT_COLOR" ]; then
      log_error "Pillar '$PILLAR' has no color in content.json brand.colors"
      ((ERRORS++)) || true
    elif [ -n "$REPO_COLOR" ] && [ "${REPO_COLOR,,}" != "${CONTENT_COLOR,,}" ]; then
      log_error "Pillar '$PILLAR' color drift: repos.json=$REPO_COLOR vs content.json=$CONTENT_COLOR"
      ((ERRORS++)) || true
    fi
  done

  # 3. Cross-pillar story flows must reference real pillars, and each hop should
  #    correspond to a connects_to edge (either direction). Build the pillar edge set.
  EDGE_SET=$(jq -r '
    (.repos | map({ (.name): .pillar }) | add) as $m
    | .repos[] | select(.role != "hub") | .pillar as $from
    | (.connects_to // [])[] | "\($from)>\($m[.])"
  ' "$REPOS_FILE")

  STORY_COUNT=$(jq '.cross_pillar_stories | length' "$CONTENT_FILE")
  for s in $(seq 0 $((STORY_COUNT - 1))); do
    SNAME=$(jq -r ".cross_pillar_stories[$s].name" "$CONTENT_FILE")
    mapfile -t FLOW < <(jq -r ".cross_pillar_stories[$s].flow[]" "$CONTENT_FILE")
    for step in "${FLOW[@]}"; do
      FOUND=false
      for P in "${NONHUB_PILLARS[@]}"; do [ "$P" = "$step" ] && FOUND=true; done
      if [ "$FOUND" = false ]; then
        log_error "Story '$SNAME': flow references unknown pillar '$step'"
        ((ERRORS++)) || true
      fi
    done
    # Check each consecutive hop maps to a real connection (bidirectional ok).
    for ((j = 0; j < ${#FLOW[@]} - 1; j++)); do
      A="${FLOW[$j]}"; B="${FLOW[$((j + 1))]}"
      if ! grep -qx "$A>$B" <<< "$EDGE_SET" && ! grep -qx "$B>$A" <<< "$EDGE_SET"; then
        log_warn "Story '$SNAME': hop '$A -> $B' is not a connects_to edge in repos.json"
        ((WARNINGS++)) || true
      fi
    done
  done
fi

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
