#!/usr/bin/env bash
# crisis-conformance.sh — Read-only scan of every repo's SKILL.md for the
# crisis and scope rules each Access To skill must carry.
#
# The 2026-10-23 launch QA found launch blockers that structural CI cannot
# see: a skill with no 911/988 in a danger scenario, Missouri-only numbers
# handed to people in other states, no language rule, a missing disclaimer.
# This scan makes those checks automatic. For each repo in repos.json (the
# hub excepted) it fetches SKILL.md (root, skill/SKILL.md, or the copy inside
# a root *.skill package) through `gh api` and checks:
#
#   1. Disclaimer. The shared notice block (BEGIN/END DISCLAIMER markers) is
#      present.
#   2. Crisis numbers. Each required number ("911", "988") appears in the
#      skill's own text, outside the disclaimer block, since the notice
#      itself always carries both: "notice only" means the skill relies on
#      the stamped notice alone.
#   3. Location check. At least one of the configured phrases ("what state",
#      "outside Missouri", "Missouri only", ...) appears outside the
#      disclaimer block, so Missouri content is not handed to everyone.
#   4. Language rule. At least one of the configured phrases ("language the
#      person writes in", "respond in Spanish", "en español", ...) appears
#      outside the disclaimer block.
#   5. Labelled Missouri numbers. Every phone number with a Missouri area code
#      (314, 573, 636, 660, 816) sits on a line that also names Missouri
#      ("Missouri", "MO", "St. Louis"), so a reader elsewhere knows it is
#      local.
#
# All phrases, numbers, area codes and labels live in
# .github/config/crisis-conformance.json; matching is case-insensitive and
# literal. This is a scan, not a judgement: it reports what the text
# contains, as a table, and never changes a child repo. A repo with no
# SKILL.md anywhere (an app, a spec) is reported as "n/a" and is not a
# finding. A repo the token cannot read is skipped with a warning.
#
# Usage:
#   ./crisis-conformance.sh [--report <file>] [repos-file]
#     --report   also write a markdown report (table + findings per repo)
#     repos-file defaults to .github/config/repos.json
#
# Output: a table through lib-log (one JSON row per repo with LOG_FORMAT=json),
# plus the markdown report on GITHUB_STEP_SUMMARY when set. The report opens
# with  <!-- crisis-conformance findings=N errors=N skipped=N -->  for
# workflows.
#
# Exit codes: 0 clean (skips and n/a allowed), 1 any finding, or any repo that
# should have been readable could not be read.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib-log.sh"

REPORT=""
if [ "${1:-}" = "--report" ]; then REPORT="${2:?--report needs a file}"; shift 2; fi
REPOS_FILE="${1:-$SCRIPT_DIR/../config/repos.json}"
CONFIG="${CRISIS_CONFORMANCE_CONFIG:-$SCRIPT_DIR/../config/crisis-conformance.json}"

log_init "crisis-conformance"

[ -f "$REPOS_FILE" ] || { log_error "Repos config not found: $REPOS_FILE"; exit 1; }
[ -f "$CONFIG" ] || { log_error "Config not found: $CONFIG"; exit 1; }
for tool in gh jq unzip tar; do
  command -v "$tool" >/dev/null || { log_error "Required tool not found: $tool"; exit 1; }
done

OWNER=$(jq -r '.owner' "$REPOS_FILE")
mapfile -t REPOS < <(jq -r '.repos[] | select(type == "object" and .role != "hub") | .name' "$REPOS_FILE")
log_info "Scanning ${#REPOS[@]} repos under $OWNER (read-only)"

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
RESULTS="$WORK/results.jsonl"
: > "$RESULTS"

# The config must be valid and carry every list the scan reads, each a
# non-empty list of strings: a typo here would otherwise pass every repo.
if ! jq -e '
    (.disclaimer_markers.begin | type == "string" and length > 0)
    and (.disclaimer_markers.end | type == "string" and length > 0)
    and all(.required_numbers, .location_phrases, .language_phrases, .missouri_area_codes, .missouri_labels;
            type == "array" and length > 0 and all(.[]; type == "string" and length > 0))
    and all(.missouri_area_codes[]; test("^[0-9]{3}$"))
    and ((.required_numbers_outside_notice // true) | type == "boolean")
  ' "$CONFIG" >/dev/null 2>&1; then
  log_error "Invalid config: $CONFIG (needs disclaimer_markers.begin/end, and non-empty string lists required_numbers, location_phrases, language_phrases, missouri_area_codes (3 digits each), missouri_labels)"
  exit 1
fi

BEGIN_MARK=$(jq -r '.disclaimer_markers.begin' "$CONFIG")
END_MARK=$(jq -r '.disclaimer_markers.end' "$CONFIG")
OUTSIDE=$(jq -r 'if has("required_numbers_outside_notice") then .required_numbers_outside_notice else true end' "$CONFIG")
jq -r '.required_numbers[]' "$CONFIG" > "$WORK/numbers"
jq -r '.location_phrases[]' "$CONFIG" > "$WORK/location"
jq -r '.language_phrases[]' "$CONFIG" > "$WORK/language"
AREA_RE="($(jq -r '.missouri_area_codes | join("|")' "$CONFIG"))"
jq -r '.missouri_labels[]' "$CONFIG" > "$WORK/labels"

FINDINGS=0
ERRORS=0
SKIPPED=0

# --- fetch layer: the only place that talks to GitHub ------------------------

api() { gh api "$1"; }
raw_blob() { gh api "repos/$OWNER/$1/git/blobs/$2" -H 'Accept: application/vnd.github.raw'; }

# fetch_entry <repo> <tree-json-file> <name> <dest> — copy one blob to dest.
fetch_entry() {
  local repo="$1" tree="$2" name="$3" dest="$4" sha
  sha=$(jq -r --arg n "$name" '.tree[] | select(.path == $n and .type == "blob") | .sha' "$tree")
  [ -n "$sha" ] || return 1
  mkdir -p "$(dirname "$dest")"
  raw_blob "$repo" "$sha" > "$dest"
}

list_package() { unzip -Z1 "$1" 2>/dev/null || tar -tzf "$1" 2>/dev/null || tar -tf "$1" 2>/dev/null; }
extract_package_entry() {
  if unzip -Z1 "$1" >/dev/null 2>&1; then unzip -p "$1" "$2"; else tar -xzOf "$1" "$2" 2>/dev/null || tar -xOf "$1" "$2"; fi
}
package_skill_md() {
  list_package "$1" | grep -E '^(\./)?([^/]+/)?SKILL\.md$' | awk -F/ '{ print NF "\t" $0 }' | sort -n | head -1 | cut -f2-
}

# find_skill_md <repo> <tree-file> <dest> — SKILL.md from the root, skill/, or
# a root *.skill package. Prints where it came from; returns 1 when none.
find_skill_md() {
  local repo="$1" tree="$2" dest="$3" sha sub pkg entry
  if fetch_entry "$repo" "$tree" SKILL.md "$dest"; then echo "SKILL.md"; return; fi
  sha=$(jq -r '.tree[] | select(.path == "skill" and .type == "tree") | .sha' "$tree")
  if [ -n "$sha" ]; then
    sub="$WORK/$repo/skill-tree.json"
    api "repos/$OWNER/$repo/git/trees/$sha" > "$sub"
    if fetch_entry "$repo" "$sub" SKILL.md "$dest"; then echo "skill/SKILL.md"; return; fi
  fi
  while IFS= read -r pkg; do
    [ -n "$pkg" ] || continue
    fetch_entry "$repo" "$tree" "$pkg" "$WORK/$repo/pkg/$pkg" || continue
    entry=$(package_skill_md "$WORK/$repo/pkg/$pkg" || true)
    [ -n "$entry" ] || continue
    if extract_package_entry "$WORK/$repo/pkg/$pkg" "$entry" > "$dest"; then echo "$pkg:${entry#./}"; return; fi
  done < <(jq -r '.tree[] | select(.type == "blob" and (.path | endswith(".skill"))) | .path' "$tree")
  return 1
}

# --- the scan ----------------------------------------------------------------

# has_phrase <file> <phrase-list-file> — true when any phrase (case-insensitive,
# literal) occurs; prints the first matching phrase and line.
has_phrase() {
  local p n
  while IFS= read -r p; do
    [ -n "$p" ] || continue
    n=$(grep -inF -- "$p" "$1" | head -1 | cut -d: -f1 || true)
    if [ -n "$n" ]; then printf '%s\t%s\n' "$p" "$n"; return 0; fi
  done < "$2"
  return 1
}

# scan <repo> <SKILL.md> — prints the repo's result JSON.
scan() {
  local repo="$1" f="$2" body="$WORK/$1/outside.md" disclaimer n num status="ok"
  local numbers="{}" loc lang unlabelled="[]" hit
  if grep -qF -- "$BEGIN_MARK" "$f" && grep -qF -- "$END_MARK" "$f"; then disclaimer="present"; else disclaimer="missing"; fi
  # The text outside the disclaimer block, with the block's lines blanked
  # (not dropped) so line numbers still match SKILL.md. Every content check
  # below reads this, so the stamped notice can never satisfy a rule.
  awk -v b="$BEGIN_MARK" -v e="$END_MARK" 'index($0, b) == 1 { skip = 1; print ""; next } skip { if (index($0, e) == 1) skip = 0; print ""; next } { print }' "$f" > "$body"
  while IFS= read -r num; do
    [ -n "$num" ] || continue
    if grep -qF -- "$num" "$body"; then n="yes"
    elif grep -qF -- "$num" "$f"; then n="notice only"
    else n="no"; fi
    numbers=$(jq -c --arg k "$num" --arg v "$n" '. + {($k): $v}' <<<"$numbers")
  done < "$WORK/numbers"
  if hit=$(has_phrase "$body" "$WORK/location"); then loc=$(jq -nc --arg p "$(cut -f1 <<<"$hit")" --argjson l "$(cut -f2 <<<"$hit")" '{status: "yes", phrase: $p, line: $l}'); else loc='{"status": "no"}'; fi
  if hit=$(has_phrase "$body" "$WORK/language"); then lang=$(jq -nc --arg p "$(cut -f1 <<<"$hit")" --argjson l "$(cut -f2 <<<"$hit")" '{status: "yes", phrase: $p, line: $l}'); else lang='{"status": "no"}'; fi
  # Missouri-area-code numbers whose line carries no Missouri label.
  while IFS=: read -r n line; do
    [ -n "$n" ] || continue
    if ! label_on_line "$line"; then
      unlabelled=$(jq -c --argjson l "$n" --arg t "$(grep -oE "(^|[^0-9])\(?$AREA_RE\)?[-. ]?[0-9]{3}[-. ]?[0-9]{4}" <<<"$line" | sed -E 's/^[^0-9(]//' | head -1)" '. + [{line: $l, number: $t}]' <<<"$unlabelled")
    fi
  done < <(grep -nE "(^|[^0-9])\(?$AREA_RE\)?[-. ]?[0-9]{3}[-. ]?[0-9]{4}([^0-9]|$)" "$body" || true)

  if [ "$OUTSIDE" != "true" ]; then
    # Counting the notice is enough: "notice only" is not a finding.
    numbers=$(jq -c 'with_entries(if .value == "notice only" then .value = "yes" else . end)' <<<"$numbers")
  fi
  if [ "$disclaimer" != "present" ] || jq -e 'any(.[]; . != "yes")' <<<"$numbers" >/dev/null \
     || [ "$(jq -r .status <<<"$loc")" != "yes" ] || [ "$(jq -r .status <<<"$lang")" != "yes" ] \
     || [ "$(jq 'length' <<<"$unlabelled")" -gt 0 ]; then
    status="findings"
  fi
  jq -nc --arg s "$status" --arg d "$disclaimer" --argjson n "$numbers" --argjson loc "$loc" --argjson lang "$lang" --argjson u "$unlabelled" \
    '{status: $s, disclaimer: $d, numbers: $n, location_check: $loc, language_rule: $lang, unlabelled_missouri_numbers: $u}'
}

# label_on_line <line> — true when the line names Missouri (whole word).
label_on_line() {
  local w
  while IFS= read -r w; do
    [ -n "$w" ] || continue
    grep -qE "(^|[^A-Za-z])$(sed 's/[.[\*^$]/\\&/g' <<<"$w")([^A-Za-z]|$)" <<<"$1" && return 0
  done < "$WORK/labels"
  return 1
}

# --- main loop ---------------------------------------------------------------

for REPO in "${REPOS[@]}"; do
  mkdir -p "$WORK/$REPO"
  TREE="$WORK/$REPO/tree.json"
  if ! META=$(api "repos/$OWNER/$REPO" 2>"$WORK/err"); then
    if grep -q 'HTTP 404' "$WORK/err"; then
      log_warn "$REPO: not readable with this token (private?); skipped"
      SKIPPED=$((SKIPPED + 1))
      jq -nc --arg r "$REPO" '{repo: $r, status: "skipped", note: "not readable with this token"}' >> "$RESULTS"
    else
      log_error "$REPO: could not read repo: $(cat "$WORK/err")"
      ERRORS=$((ERRORS + 1))
      jq -nc --arg r "$REPO" '{repo: $r, status: "error"}' >> "$RESULTS"
    fi
    continue
  fi
  BRANCH=$(jq -r '.default_branch' <<<"$META")
  if ! api "repos/$OWNER/$REPO/git/trees/$BRANCH" > "$TREE" 2>"$WORK/err"; then
    log_error "$REPO: could not read the $BRANCH tree: $(cat "$WORK/err")"
    ERRORS=$((ERRORS + 1))
    jq -nc --arg r "$REPO" '{repo: $r, status: "error"}' >> "$RESULTS"
    continue
  fi
  if ! SOURCE=$(find_skill_md "$REPO" "$TREE" "$WORK/$REPO/SKILL.md"); then
    log_action "scan" "$REPO" "n/a" "no SKILL.md"
    jq -nc --arg r "$REPO" '{repo: $r, status: "n/a", source: ""}' >> "$RESULTS"
    continue
  fi
  R=$(scan "$REPO" "$WORK/$REPO/SKILL.md")
  S=$(jq -r '.status' <<<"$R")
  log_action "scan" "$REPO/$SOURCE" "$S" "$(jq -r '"disclaimer \(.disclaimer), " + ([.numbers | to_entries[] | "\(.key) \(.value)"] | join(", ")) + ", location \(.location_check.status), language \(.language_rule.status), unlabelled MO numbers \(.unlabelled_missouri_numbers | length)"' <<<"$R")"
  [ "$S" = "ok" ] || FINDINGS=$((FINDINGS + 1))
  jq -nc --arg r "$REPO" --arg src "$SOURCE" --argjson x "$R" '{repo: $r, source: $src} + $x' >> "$RESULTS"
done

# --- output ------------------------------------------------------------------

if [ "$LOG_FORMAT" = "json" ]; then
  while IFS= read -r row; do
    _log_json "info" "result $(jq -r '.repo' <<<"$row")" "$(jq -c '.' <<<"$row" | sed 's/^{//; s/}$//')"
  done < "$RESULTS"
else
  log_info "$(printf '%-22s %-9s %-10s %-12s %-12s %-9s %-9s %s' REPO STATUS DISCLAIMER 911 988 LOCATION LANGUAGE 'UNLABELLED MO')"
  while IFS= read -r row; do
    log_info "$(printf '%-22s %-9s %-10s %-12s %-12s %-9s %-9s %s' \
      "$(jq -r '.repo' <<<"$row")" "$(jq -r '.status' <<<"$row")" "$(jq -r '.disclaimer // "-"' <<<"$row")" \
      "$(jq -r '.numbers["911"] // "-"' <<<"$row")" "$(jq -r '.numbers["988"] // "-"' <<<"$row")" \
      "$(jq -r '.location_check.status // "-"' <<<"$row")" "$(jq -r '.language_rule.status // "-"' <<<"$row")" \
      "$(jq -r 'if .unlabelled_missouri_numbers then (.unlabelled_missouri_numbers | length | tostring) else "-" end' <<<"$row")")"
  done < "$RESULTS"
fi

render_report() {
  local cols
  cols=$(jq -r '.required_numbers | map("| " + .) | join(" ")' "$CONFIG")
  echo "<!-- crisis-conformance findings=$FINDINGS errors=$ERRORS skipped=$SKIPPED -->"
  echo "## Crisis conformance"
  echo ""
  echo "_Scanned $(date -u '+%Y-%m-%d %H:%M UTC') across ${#REPOS[@]} repos (read-only). Phrases: \`.github/config/crisis-conformance.json\`._"
  echo ""
  echo "| Repo | SKILL.md | Disclaimer $cols | Location check | Language rule | Unlabelled MO numbers |"
  echo "|------|----------|------------|$(jq -r '.required_numbers | map("-----|") | join("")' "$CONFIG")----------------|---------------|-----------------------|"
  jq -r --slurpfile cfg "$CONFIG" '
    if .status == "skipped" then "| \(.repo) | skipped (\(.note)) |" + ($cfg[0].required_numbers | map(" — |") | join("")) + " — | — | — | — |"
    elif .status == "error" then "| \(.repo) | error |" + ($cfg[0].required_numbers | map(" — |") | join("")) + " — | — | — | — |"
    elif .status == "n/a" then "| \(.repo) | none (n/a) |" + ($cfg[0].required_numbers | map(" — |") | join("")) + " — | — | — | — |"
    else "| \(.repo) | `\(.source)` | \(.disclaimer) |" + ([$cfg[0].required_numbers[] as $n | " \(.numbers[$n]) |"] | join("")) + " \(.location_check.status)\(if .location_check.phrase then " (\"\(.location_check.phrase)\", line \(.location_check.line))" else "" end) | \(.language_rule.status)\(if .language_rule.phrase then " (\"\(.language_rule.phrase)\", line \(.language_rule.line))" else "" end) | \(.unlabelled_missouri_numbers | length) |"
    end' "$RESULTS"
  echo ""
  if [ "$FINDINGS" -gt 0 ]; then
    echo "### Findings"
    echo ""
    echo "What the text contains, not a judgement of it. Each item names the rule and where to look; the fix is a PR in the child repo (never edit between the disclaimer markers there)."
    echo ""
    jq -r --slurpfile cfg "$CONFIG" '
      select(.status == "findings") |
      "**\(.repo)** (`\(.source)`)\n",
      (select(.disclaimer == "missing") | "- No shared disclaimer block (BEGIN/END DISCLAIMER markers). Stamp it: `sync-disclaimer.sh \(.repo) <checkout>`."),
      (.numbers | to_entries[] | select(.value == "no") | "- \"\(.key)\" does not appear anywhere in SKILL.md."),
      (.numbers | to_entries[] | select(.value == "notice only") | "- \"\(.key)\" appears only inside the disclaimer notice: the skill'"'"'s own crisis handling never gives it."),
      (select(.location_check.status == "no") | "- No location check: none of the configured phrases (e.g. \"what state\", \"outside Missouri\", \"Missouri only\") appear, so Missouri content may go to everyone."),
      (select(.language_rule.status == "no") | "- No language rule: none of the configured phrases (e.g. \"language the person writes in\", \"respond in Spanish\", \"en español\") appear."),
      (.unlabelled_missouri_numbers[] | "- Line \(.line): `\(.number)` has a Missouri area code but the line does not say \($cfg[0].missouri_labels | join(", "))."),
      ""
    ' "$RESULTS"
  fi
  if [ "$SKIPPED" -gt 0 ]; then
    echo "### Not checked"
    echo ""
    jq -r 'select(.status == "skipped") | "- \(.repo): \(.note)"' "$RESULTS"
    echo ""
    echo "Private repos need a read-only token in the \`ECOSYSTEM_READ_TOKEN\` secret (see the workflow header)."
    echo ""
  fi
  if [ "$ERRORS" -gt 0 ]; then
    echo "### Errors"
    echo ""
    jq -r 'select(.status == "error") | "- \(.repo): could not be read (see the run log)"' "$RESULTS"
    echo ""
  fi
}

render_report > "$WORK/report.md"
[ -n "$REPORT" ] && cp "$WORK/report.md" "$REPORT"
[ -n "${GITHUB_STEP_SUMMARY:-}" ] && cat "$WORK/report.md" >> "$GITHUB_STEP_SUMMARY"

log_info "findings=$FINDINGS errors=$ERRORS skipped=$SKIPPED"
log_summary

if [ "$FINDINGS" -gt 0 ] || [ "$ERRORS" -gt 0 ]; then
  [ "$FINDINGS" -gt 0 ] && log_error "$FINDINGS repo(s) with crisis-conformance findings; see the table above"
  exit 1
fi
