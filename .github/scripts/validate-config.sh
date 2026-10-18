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
#   - i18n/<lang>.json + journey.<lang>.json: same keys, ids and counts as the
#     English source, Spanish copy for every listed project, crisis lines kept

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
    ((ERRORS++)) || true
  fi
done

# Validate each repo entry
REPO_COUNT=$(jq '.repos | length' "$REPOS_FILE")
mapfile -t REPO_NAMES < <(jq -r '.repos[].name' "$REPOS_FILE")

VALID_PILLARS=("hub" "housing" "jobs" "health" "business" "services" "education" "safety" "justice" "peace" "civics" "community" "food" "energy" "care" "mobility")
VALID_SCOPES=("missouri" "nationwide" "global")
VALID_ROLES=("hub" "pillar" "tool" "docs")
VALID_STATUSES=("live" "beta" "skill" "pre-pilot" "spec")
VALID_VISIBILITY=("public" "private")

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

  # Optional hub-site fields: status, visibility, live_url, page
  STATUS=$(jq -r ".repos[$i].status // empty" "$REPOS_FILE")
  if [ -n "$STATUS" ]; then
    FOUND=false
    for S in "${VALID_STATUSES[@]}"; do [ "$S" = "$STATUS" ] && FOUND=true; done
    if [ "$FOUND" = false ]; then
      log_error "repos[$i] ($NAME): invalid status '$STATUS' — expected one of: ${VALID_STATUSES[*]}"
      ((ERRORS++)) || true
    fi
  fi

  VISIBILITY=$(jq -r ".repos[$i].visibility // empty" "$REPOS_FILE")
  if [ -n "$VISIBILITY" ]; then
    FOUND=false
    for V in "${VALID_VISIBILITY[@]}"; do [ "$V" = "$VISIBILITY" ] && FOUND=true; done
    if [ "$FOUND" = false ]; then
      log_error "repos[$i] ($NAME): invalid visibility '$VISIBILITY' — expected one of: ${VALID_VISIBILITY[*]}"
      ((ERRORS++)) || true
    fi
  fi

  LIVE_URL=$(jq -r ".repos[$i].live_url // empty" "$REPOS_FILE")
  if [ -n "$LIVE_URL" ] && [[ "$LIVE_URL" != https://* ]]; then
    log_error "repos[$i] ($NAME): live_url must start with https://"
    ((ERRORS++)) || true
  fi

  PAGE=$(jq -r ".repos[$i].page // empty" "$REPOS_FILE")
  if [ -n "$PAGE" ] && [ ! -f "$CONFIG_DIR/../../$PAGE" ]; then
    log_error "repos[$i] ($NAME): page '$PAGE' does not exist at the repo root"
    ((ERRORS++)) || true
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

# At most one role "pillar" repo per pillar: generate-content.sh writes
# <format>-<pillar>.md, so two would overwrite each other. Extra repos in a
# pillar use role "tool" or "docs".
SHARED_PILLARS=$(jq -r '[.repos[] | select(.role == "pillar") | .pillar] | group_by(.) | map(select(length > 1) | .[0]) | .[]' "$REPOS_FILE")
if [ -n "$SHARED_PILLARS" ]; then
  for P in $SHARED_PILLARS; do
    log_error "Pillar '$P' has more than one repo with role 'pillar' — use role 'tool' or 'docs' for the others"
    ((ERRORS++)) || true
  done
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

# --- Homepage languages: i18n/<lang>.json + journey.<lang>.json ---
# English is the source. Every other language must translate the same keys,
# every listed project and every journey item, and keep the crisis lines.
I18N_DIR="$CONFIG_DIR/i18n"
JOURNEY_FILE="$CONFIG_DIR/journey.json"
if [ -d "$I18N_DIR" ]; then
  log_info "Validating homepage languages (i18n/)..."
  EN_FILE="$I18N_DIR/en.json"
  if [ ! -f "$EN_FILE" ] || ! jq empty "$EN_FILE" 2>/dev/null; then
    log_error "i18n/en.json is missing or not valid JSON"
    ((ERRORS++)) || true
  else
    for F in "$I18N_DIR"/*.json; do
      L="$(basename "$F" .json)"
      if ! jq empty "$F" 2>/dev/null; then
        log_error "i18n/$L.json is not valid JSON"; ((ERRORS++)) || true; continue
      fi
      if [ "$(jq -r '.lang' "$F")" != "$L" ]; then
        log_error "i18n/$L.json: \"lang\" must be \"$L\""; ((ERRORS++)) || true
      fi
      for FIELD in name url labels ui narration; do
        if [ "$(jq "has(\"$FIELD\")" "$F")" != "true" ]; then
          log_error "i18n/$L.json missing required field: $FIELD"; ((ERRORS++)) || true
        fi
      done
      [ "$L" = "en" ] && continue

      JF="$CONFIG_DIR/journey.$L.json"
      if [ ! -f "$JF" ] || ! jq empty "$JF" 2>/dev/null; then
        log_error "i18n/$L.json has no valid journey.$L.json"; ((ERRORS++)) || true; continue
      fi
      if [ "$(jq -r '.path' "$F")" != "$L/" ]; then
        log_error "i18n/$L.json: \"path\" must be \"$L/\""; ((ERRORS++)) || true
      fi
      # Same keys as English, and the same {placeholders} in every ui string.
      while IFS= read -r MSG; do
        [ -n "$MSG" ] || continue
        log_error "i18n/$L.json: $MSG"; ((ERRORS++)) || true
      done < <(jq -r --slurpfile en "$EN_FILE" '
        def ph: [scan("\\{\\w+\\}")] | sort;
        . as $t | $en[0] as $e
        | (["ui", "narration", "labels"][] as $k
            | (($e[$k] | keys) - ($t[$k] // {} | keys))[] | "\($k).\(.) is missing"),
          ((($e.labels.status | keys) - ($t.labels.status // {} | keys))[] | "labels.status.\(.) is missing"),
          ((($e.labels.scope | keys) - ($t.labels.scope // {} | keys))[] | "labels.scope.\(.) is missing"),
          ($e.ui | to_entries[] | select(($t.ui[.key] // "" | ph) != (.value | ph)) | "ui.\(.key) must use the placeholders \(.value | ph | join(" "))"),
          (if ($t.page | type) != "object" or ([$t.page[] | type] | all(. == "object") | not)
           then "page must be an object of sections, each mapping English to \("'"$L"'")" else empty end),
          ([$t.page[]? | to_entries[] | select((.value | type) != "string" or .value == "") | .key][] | "page: empty translation for \"\(.)\"")
      ' "$F")
      # Every listed project has copy here; nothing extra.
      while IFS= read -r MSG; do
        [ -n "$MSG" ] || continue
        log_error "i18n/$L.json: $MSG"; ((ERRORS++)) || true
      done < <(jq -r --slurpfile r "$REPOS_FILE" '
        ([$r[0].repos[] | select(.role != "hub" and (.listed // true))]) as $listed
        | (.projects // {}) as $p
        | ($listed[] | .name as $n | . as $repo
            | if ($p[$n] | not) then "projects.\($n) is missing"
              else (["description", "cta"][] | select(($p[$n][.] // "") == "") | "projects.\($n).\(.) is missing"),
                   (if (($p[$n].audience // []) | length) != (($repo.audience // []) | length) then "projects.\($n).audience must have \(($repo.audience // []) | length) entries" else empty end)
              end),
          ((($p | keys) - ($listed | map(.name)))[] | "projects.\(.) is not a listed project")
      ' "$F")
      # journey.<lang>.json: same ids, counts and order as journey.json, every
      # listed project adopted, and the crisis lines kept.
      while IFS= read -r MSG; do
        [ -n "$MSG" ] || continue
        log_error "journey.$L.json: $MSG"; ((ERRORS++)) || true
      done < <(jq -r --slurpfile en "$JOURNEY_FILE" --slurpfile r "$REPOS_FILE" '
        . as $t | $en[0] as $e
        | (if ($t.beacon | map(.letter)) != ($e.beacon | map(.letter)) then "beacon must have the letters \($e.beacon | map(.letter) | join(""))" else empty end),
          (if ($t.virtues | length) != ($e.virtues | length) then "virtues must have \($e.virtues | length) entries" else empty end),
          (if ($t.gates | length) != ($e.gates | length) then "gates must have \($e.gates | length) entries" else empty end),
          (["roles", "needs", "places"][] as $k
            | if ($t.finder[$k] | map(.id)) != ($e.finder[$k] | map(.id)) then "finder.\($k) ids must match journey.json, in order" else empty end),
          (["911", "988"][] as $line | select(($t.finder.crisis_note // "") | contains($line) | not) | "finder.crisis_note must include \($line)"),
          ([$r[0].repos[] | select(.role != "hub" and (.listed // true)) | .name][]
            | select(($t.adoption[.].adopter // "") == "" or ($t.adoption[.].pilot // "") == "") | "adoption.\(.) needs an adopter and a pilot")
      ' "$JF")
      log_action "validate-language" "$L" "checked"
    done
  fi
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
