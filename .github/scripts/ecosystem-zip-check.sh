#!/usr/bin/env bash
# ecosystem-zip-check.sh — Read-only completeness check of every published
# install zip (the `install_zip` asset on each repo's skill-latest release).
#
# ecosystem-drift.sh asks whether a zip is *current* (its release commit vs.
# the sources). This asks whether what is *inside* the zip is complete, which
# no date comparison can tell: the 2026-10-23 launch QA found SKILL.md files
# that routed to reference files the zip did not carry. For each repo in
# repos.json with `install_zip`, it downloads the asset through the REST API,
# unzips it into a fresh temp dir and checks:
#
#   1. Layout. The zip holds one top-level folder with SKILL.md in it (what
#      claude.ai expects), and that folder is named after the skill.
#   2. References. Every relative path SKILL.md points at exists in the zip:
#      markdown link targets, backticked paths (`references/x.md`, `docs/`,
#      `templates/*.md`) and bare paths in table cells (routing tables). A
#      path resolves when it exists as written or under any folder of the zip
#      (routing tables are often written relative to references/), and a glob
#      when it matches at least one entry. A line that says the paths on it
#      are deliberately not shipped (phrases in .github/config/zip-check.json)
#      is exempt, as is a whole section whose heading says so; the count of
#      exempt lines is reported, never hidden.
#   3. Disclaimer. The zip's SKILL.md, DISCLAIMER.md and README.md (when
#      present) pass `sync-disclaimer.sh --check`: the shared notice is there,
#      between the BEGIN/END DISCLAIMER markers, with the current wording.
#   4. Frontmatter. The zip's SKILL.md passes check-skill-frontmatter.py (the
#      claude.ai upload rules: name and description present and within
#      limits, folder name equal to the skill name).
#
# Everything remote goes through `gh api` (release by tag, asset download),
# and nothing is ever written to any repo. A repo the token cannot read is
# skipped with a warning. A repo without `install_zip` is not checked.
#
# Usage:
#   ./ecosystem-zip-check.sh [--report <file>] [repos-file]
#     --report   also write a markdown report (table + findings per repo)
#     repos-file defaults to .github/config/repos.json
#
# Output: a table through lib-log (one JSON row per repo with LOG_FORMAT=json),
# plus the markdown report on GITHUB_STEP_SUMMARY when set. The report opens
# with  <!-- ecosystem-zip-check findings=N errors=N skipped=N -->  for
# workflows (ecosystem-drift.yml folds it into the drift issue).
#
# Exit codes: 0 clean (skips allowed), 1 any finding (bad layout, a missing
# reference, a drifted or missing disclaimer, invalid frontmatter, a missing
# release or asset) or any repo that should have been readable could not be.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib-log.sh"

REPORT=""
if [ "${1:-}" = "--report" ]; then REPORT="${2:?--report needs a file}"; shift 2; fi
REPOS_FILE="${1:-$SCRIPT_DIR/../config/repos.json}"
CONFIG="${ZIP_CHECK_CONFIG:-$SCRIPT_DIR/../config/zip-check.json}"
FRONTMATTER="$SCRIPT_DIR/check-skill-frontmatter.py"

log_init "ecosystem-zip-check"

[ -f "$REPOS_FILE" ] || { log_error "Repos config not found: $REPOS_FILE"; exit 1; }
[ -f "$CONFIG" ] || { log_error "Config not found: $CONFIG"; exit 1; }
[ -f "$FRONTMATTER" ] || { log_error "Frontmatter checker not found: $FRONTMATTER"; exit 1; }
for tool in gh jq unzip python3; do
  command -v "$tool" >/dev/null || { log_error "Required tool not found: $tool"; exit 1; }
done
python3 -I -c 'import yaml' 2>/dev/null || { log_error "python3 needs PyYAML for the frontmatter check (pip install pyyaml)"; exit 1; }

OWNER=$(jq -r '.owner' "$REPOS_FILE")
mapfile -t REPOS < <(jq -r '.repos[] | select(type == "object" and .install_zip) | .name' "$REPOS_FILE")
log_info "Checking ${#REPOS[@]} install zip(s) under $OWNER (read-only)"

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
RESULTS="$WORK/results.jsonl"
: > "$RESULTS"
jq -r '.not_shipped_phrases[]' "$CONFIG" > "$WORK/phrases"
EXT_RE="($(jq -r '.path_extensions | join("|")' "$CONFIG"))"

FINDINGS=0
ERRORS=0
SKIPPED=0

# --- fetch layer: the only place that talks to GitHub ------------------------

api() { gh api "$1"; }
# download_asset <repo> <asset-id> <dest> — the asset's bytes.
download_asset() { gh api "repos/$OWNER/$1/releases/assets/$2" -H 'Accept: application/octet-stream' > "$3"; }

# --- reference extraction ----------------------------------------------------

# extract_refs <SKILL.md> — one "kind<TAB>path<TAB>line" per relative path
# SKILL.md references, plus "exempt<TAB><TAB>line" for every line skipped
# because it (or its section heading) says the paths are not shipped.
extract_refs() {
  awk -v phrases="$WORK/phrases" -v ext="$EXT_RE" '
    BEGIN {
      while ((getline p < phrases) > 0) if (p != "") phr[++np] = tolower(p)
      path_re = "^[A-Za-z0-9_.-]+(/[A-Za-z0-9_.*-]+)*/?$"
      file_re = "(/|[.]" ext "$)"
      skip_url = "^(https?:|mailto:|tel:|[a-z]+://|/|#|$)"
      domain_re = "^[A-Za-z0-9-]+[.](gov|com|org|net|edu|io|bz|us)(/|$)"
    }
    function says_not_shipped(s,   i) {
      s = tolower(s)
      for (i = 1; i <= np; i++) if (index(s, phr[i])) return 1
      return 0
    }
    function emit(kind, p) {
      sub(/[#?].*$/, "", p); sub(/ ".*"$/, "", p)
      if (p == "" || p ~ skip_url || p ~ domain_re || p ~ /^[0-9.]+$/ || p ~ /\.\./ || p ~ /[{}<>]/) return
      if (p !~ path_re || p !~ file_re) return
      print kind "\t" p "\t" NR
    }
    {
      line = $0
      if (match(line, /^#+ /)) {
        level = RLENGTH - 1
        if (exempt_level && level <= exempt_level) exempt_level = 0
        if (!exempt_level && says_not_shipped(line)) exempt_level = level
      }
      if (exempt_level || says_not_shipped(line)) { if (line ~ /[^ \t]/) print "exempt\t\t" NR; next }
      # markdown links: [text](path)
      s = line
      while (match(s, /\]\([^)]*\)/)) {
        t = substr(s, RSTART + 2, RLENGTH - 3); s = substr(s, RSTART + RLENGTH)
        emit("link", t)
      }
      # backticked paths
      s = line
      while (match(s, /`[^` ]+`/)) {
        t = substr(s, RSTART + 1, RLENGTH - 2); s = substr(s, RSTART + RLENGTH)
        emit("code", t)
      }
      # bare paths in table cells (routing tables)
      if (line ~ /^\|/) {
        s = line; gsub(/`/, "", s)
        n = split(s, cells, "|")
        for (i = 1; i <= n; i++) {
          m = split(cells[i], toks, /[ (),]+/)
          for (j = 1; j <= m; j++) if (toks[j] ~ ("^[A-Za-z0-9_.-]+(/[A-Za-z0-9_.*-]+)*[.]" ext "$")) emit("table", toks[j])
        }
      }
    }
  ' "$1"
}

# resolve <dir> <path> — true when path exists in dir as written, under any
# folder of dir, or (for a glob) matches at least one entry.
resolve() {
  local dir="$1" p="${2%/}" hit
  [ -n "$p" ] || return 0
  [ -e "$dir/$p" ] && return 0
  if [[ "$p" == *'*'* ]]; then
    hit=$(find "$dir" -path "$dir/$p" -print -quit 2>/dev/null; find "$dir" -path "$dir/*/$p" -print -quit 2>/dev/null)
  else
    hit=$(find "$dir" -path "$dir/*/$p" -print -quit 2>/dev/null)
  fi
  [ -n "$hit" ]
}

# --- checks ------------------------------------------------------------------

# check_zip <repo> <zip-file> <asset> — prints the repo's result JSON. Writes
# only under $WORK/<repo>/.
check_zip() {
  local repo="$1" zipf="$2" asset="$3" dir="$WORK/$1/unzipped" top skill folders
  local layout="ok" layout_note="" refs_checked=0 refs_exempt=0 missing="[]" disc disc_files fm fm_errs rc out status
  mkdir -p "$dir"
  if ! unzip -q -o "$zipf" -d "$dir" 2>"$WORK/$repo/unzip.err"; then
    jq -nc --arg a "$asset" --arg e "$(head -c 300 "$WORK/$repo/unzip.err")" \
      '{status: "findings", asset: $a, layout: "not a zip", layout_note: $e, references: {checked: 0, exempt: 0, missing: []}, disclaimer: "unchecked", drifted_files: [], frontmatter: "unchecked", frontmatter_errors: []}'
    return
  fi
  folders=$(find "$dir" -mindepth 1 -maxdepth 1 -printf '%f\n' | sort)
  if [ "$(wc -l <<<"$folders")" -ne 1 ] || [ ! -d "$dir/$folders" ]; then
    layout="bad"; layout_note="expected one top-level folder, found: $(tr '\n' ' ' <<<"$folders")"
    top=""
  else
    top="$folders"
  fi
  skill="$dir/$top/SKILL.md"
  if [ ! -f "$skill" ]; then
    skill=$(find "$dir" -name SKILL.md -print -quit)
    layout="bad"; layout_note="${layout_note:+$layout_note; }SKILL.md is not at <folder>/SKILL.md${skill:+ (found $(realpath --relative-to="$dir" "$skill"))}"
  fi
  if [ -z "$skill" ]; then
    jq -nc --arg a "$asset" --arg n "$layout_note" \
      '{status: "findings", asset: $a, layout: "bad", layout_note: $n, references: {checked: 0, exempt: 0, missing: []}, disclaimer: "missing", drifted_files: ["SKILL.md"], frontmatter: "invalid", frontmatter_errors: ["no SKILL.md in the zip"]}'
    return
  fi
  local root; root=$(dirname "$skill")

  # 2. references
  while IFS=$'\t' read -r kind p line; do
    [ -n "$kind" ] || continue
    if [ "$kind" = "exempt" ]; then refs_exempt=$((refs_exempt + 1)); continue; fi
    refs_checked=$((refs_checked + 1))
    resolve "$root" "$p" || missing=$(jq -c --arg p "$p" --arg k "$kind" --argjson l "$line" '. + [{path: $p, kind: $k, line: $l}]' <<<"$missing")
  done < <(extract_refs "$skill" | sort -u | sort -s -t$'\t' -k3,3n)
  missing=$(jq -c 'unique_by(.path)' <<<"$missing")

  # 3. disclaimer, on a copy of the files sync-disclaimer.sh manages
  local chk="$WORK/$repo/checkout"; mkdir -p "$chk"
  cp "$skill" "$chk/SKILL.md"
  [ -f "$root/DISCLAIMER.md" ] && cp "$root/DISCLAIMER.md" "$chk/DISCLAIMER.md"
  [ -f "$root/README.md" ] && cp "$root/README.md" "$chk/README.md"
  if [ ! -f "$chk/DISCLAIMER.md" ]; then
    disc="missing"; disc_files='["DISCLAIMER.md"]'
  else
    rc=0
    out=$(LOG_FORMAT=text "$SCRIPT_DIR/sync-disclaimer.sh" --check "$repo" "$chk" 2>&1) || rc=$?
    if [ "$rc" -eq 0 ]; then
      disc="in sync"; disc_files="[]"
    else
      disc="drifted"
      disc_files=$(grep -oE "\] sync-disclaimer: $repo/[^ ]+ is out of date" <<<"$out" \
        | sed -E "s/.*: $repo\/([^ ]+) is out of date/\1/" | sort -u | jq -Rsc 'split("\n") | map(select(. != ""))')
      [ "$disc_files" != "[]" ] || sub_error "$repo: sync-disclaimer.sh --check failed without naming a file: $out"
    fi
  fi

  # 4. frontmatter (and folder name = skill name)
  rc=0
  out=$(python3 -I "$FRONTMATTER" "$skill" "$top" 2>&1) || rc=$?
  if [ "$rc" -eq 0 ]; then
    fm="ok"; fm_errs="[]"
  else
    fm="invalid"
    fm_errs=$(sed -E "s#^$skill: ##" <<<"$out" | jq -Rsc 'split("\n") | map(select(. != ""))')
  fi

  status="ok"
  if [ "$layout" != "ok" ] || [ "$(jq 'length' <<<"$missing")" -gt 0 ] || [ "$disc" != "in sync" ] || [ "$fm" != "ok" ]; then
    status="findings"
  fi
  jq -nc --arg s "$status" --arg a "$asset" --arg lay "$layout" --arg ln "$layout_note" \
    --argjson rc "$refs_checked" --argjson re "$refs_exempt" --argjson m "$missing" \
    --arg d "$disc" --argjson df "$disc_files" --arg fm "$fm" --argjson fe "$fm_errs" \
    '{status: $s, asset: $a, layout: $lay, layout_note: $ln, references: {checked: $rc, exempt: $re, missing: $m}, disclaimer: $d, drifted_files: $df, frontmatter: $fm, frontmatter_errors: $fe}'
}

# check_zip runs via $(...), so its warnings go to stderr and a tally file
# (see ecosystem-drift.sh for the same arrangement).
TALLY="$WORK/tally"
: > "$TALLY"
sub_error() { log_error "$1" >&2; echo error >> "$TALLY"; }
fold_tally() {
  local e
  e=$(grep -c '^error$' "$TALLY" || true)
  ERRORS=$((ERRORS + e))
  _LOG_ERROR_COUNT=$((_LOG_ERROR_COUNT + e))
  : > "$TALLY"
}

# --- main loop ---------------------------------------------------------------

for REPO in "${REPOS[@]}"; do
  mkdir -p "$WORK/$REPO"
  ZIP=$(jq -r --arg r "$REPO" '.repos[] | select(type == "object" and .name == $r) | .install_zip' "$REPOS_FILE")
  PREFIX="https://github.com/$OWNER/$REPO/releases/download/skill-latest/"
  if [[ "$ZIP" == https://* ]]; then
    if [[ "$ZIP" != "$PREFIX"* ]]; then
      log_action "zip" "$REPO" "external" "$ZIP is outside the skill-latest release; not checked"
      jq -nc --arg r "$REPO" --arg a "$ZIP" '{repo: $r, status: "external", asset: $a}' >> "$RESULTS"
      continue
    fi
    ASSET="${ZIP#"$PREFIX"}"
  else
    ASSET="$ZIP"
  fi

  if ! REL=$(api "repos/$OWNER/$REPO/releases/tags/skill-latest" 2>"$WORK/err"); then
    if grep -q 'HTTP 404' "$WORK/err"; then
      # Either the repo is private to this token or it has no skill-latest release.
      if api "repos/$OWNER/$REPO" >/dev/null 2>&1; then
        log_action "zip" "$REPO/$ASSET" "missing release"
        FINDINGS=$((FINDINGS + 1))
        jq -nc --arg r "$REPO" --arg a "$ASSET" '{repo: $r, status: "missing release", asset: $a}' >> "$RESULTS"
      else
        log_warn "$REPO: not readable with this token (private?); skipped"
        SKIPPED=$((SKIPPED + 1))
        jq -nc --arg r "$REPO" --arg a "$ASSET" '{repo: $r, status: "skipped", asset: $a, note: "not readable with this token"}' >> "$RESULTS"
      fi
    else
      log_error "$REPO: could not read the skill-latest release: $(cat "$WORK/err")"
      ERRORS=$((ERRORS + 1))
      jq -nc --arg r "$REPO" --arg a "$ASSET" '{repo: $r, status: "error", asset: $a}' >> "$RESULTS"
    fi
    continue
  fi
  ASSET_ID=$(jq -r --arg a "$ASSET" '.assets[]? | select(.name == $a) | .id' <<<"$REL")
  if [ -z "$ASSET_ID" ]; then
    log_action "zip" "$REPO/$ASSET" "missing asset"
    FINDINGS=$((FINDINGS + 1))
    jq -nc --arg r "$REPO" --arg a "$ASSET" '{repo: $r, status: "missing asset", asset: $a}' >> "$RESULTS"
    continue
  fi
  if ! download_asset "$REPO" "$ASSET_ID" "$WORK/$REPO/$ASSET" 2>"$WORK/err"; then
    log_error "$REPO: could not download $ASSET: $(cat "$WORK/err")"
    ERRORS=$((ERRORS + 1))
    jq -nc --arg r "$REPO" --arg a "$ASSET" '{repo: $r, status: "error", asset: $a}' >> "$RESULTS"
    continue
  fi

  R=$(check_zip "$REPO" "$WORK/$REPO/$ASSET" "$ASSET")
  S=$(jq -r '.status' <<<"$R")
  log_action "zip" "$REPO/$ASSET" "$S" "$(jq -r '"layout \(.layout), references \(.references.checked) checked / \(.references.missing | length) missing / \(.references.exempt) exempt lines, disclaimer \(.disclaimer), frontmatter \(.frontmatter)"' <<<"$R")"
  [ "$S" = "ok" ] || FINDINGS=$((FINDINGS + 1))
  jq -nc --arg r "$REPO" --argjson x "$R" '{repo: $r} + $x' >> "$RESULTS"
done

# --- output ------------------------------------------------------------------

fold_tally

if [ "$LOG_FORMAT" = "json" ]; then
  while IFS= read -r row; do
    _log_json "info" "result $(jq -r '.repo' <<<"$row")" "$(jq -c '.' <<<"$row" | sed 's/^{//; s/}$//')"
  done < "$RESULTS"
else
  log_info "$(printf '%-22s %-16s %-7s %-12s %-10s %s' REPO STATUS LAYOUT REFERENCES DISCLAIMER FRONTMATTER)"
  while IFS= read -r row; do
    log_info "$(printf '%-22s %-16s %-7s %-12s %-10s %s' \
      "$(jq -r '.repo' <<<"$row")" \
      "$(jq -r '.status' <<<"$row")" \
      "$(jq -r '.layout // "-"' <<<"$row")" \
      "$(jq -r 'if .references then "\(.references.missing | length) missing" else "-" end' <<<"$row")" \
      "$(jq -r '.disclaimer // "-"' <<<"$row")" \
      "$(jq -r '.frontmatter // "-"' <<<"$row")")"
  done < "$RESULTS"
fi

render_report() {
  echo "<!-- ecosystem-zip-check findings=$FINDINGS errors=$ERRORS skipped=$SKIPPED -->"
  echo "## Install zip completeness"
  echo ""
  echo "_Checked $(date -u '+%Y-%m-%d %H:%M UTC') across ${#REPOS[@]} published zips (read-only)._"
  echo ""
  echo "| Repo | Zip | Layout | References | Disclaimer | Frontmatter |"
  echo "|------|-----|--------|------------|------------|-------------|"
  jq -r '"| \(.repo) | `\(.asset)` \(if .status == "ok" then "ok" elif .status == "findings" then "findings" else .status end) | \(.layout // "—") | \(if .references then "\(.references.checked) checked, \(.references.missing | length) missing" + (if .references.exempt > 0 then ", \(.references.exempt) exempt line(s)" else "" end) else "—" end) | \(.disclaimer // "—")\(if (.drifted_files // []) | length > 0 then " (" + (.drifted_files | join(", ")) + ")" else "" end) | \(.frontmatter // "—") |"' "$RESULTS"
  echo ""
  if [ "$FINDINGS" -gt 0 ]; then
    echo "### Findings"
    echo ""
    jq -r --arg owner "$OWNER" '
      select(.status != "ok" and .status != "skipped" and .status != "error" and .status != "external") |
      "**\(.repo)** (`\(.asset)`)\n",
      (if .status == "missing release" then "- No `skill-latest` release. Publish one:\n  ```bash\n  gh workflow run skill-package.yml -R \($owner)/\(.repo) --ref main\n  ```"
       elif .status == "missing asset" then "- The `skill-latest` release has no `\(.asset)` asset. Republish:\n  ```bash\n  gh workflow run skill-package.yml -R \($owner)/\(.repo) --ref main\n  ```"
       else empty end),
      (select(.layout and .layout != "ok") | "- Layout: \(.layout_note). claude.ai expects `<skill-name>/SKILL.md` as the only top-level folder."),
      (.references.missing[]? | "- `\(.path)` (SKILL.md line \(.line), \(.kind)) is not in the zip. Ship it, fix the path, or say on that line that it is not part of the installed skill."),
      (select(.disclaimer == "missing") | "- The zip has no DISCLAIMER.md, which the notice in SKILL.md points to. Add it to the packaging step."),
      (select(.disclaimer == "drifted") | "- Disclaimer drifted in \(.drifted_files | join(", ")). Re-stamp with `sync-disclaimer.sh \(.repo) <checkout>` and republish."),
      (.frontmatter_errors[]? | "- Frontmatter: \(.)"),
      ""
    ' "$RESULTS"
    echo "After fixing the source, republish the zip: \`gh workflow run skill-package.yml -R $OWNER/<repo> --ref main\`, then re-run this check."
    echo ""
  fi
  if [ "$SKIPPED" -gt 0 ]; then
    echo "### Not checked"
    echo ""
    jq -r 'select(.status == "skipped") | "- \(.repo): \(.note)"' "$RESULTS"
    echo ""
  fi
  if [ "$ERRORS" -gt 0 ]; then
    echo "### Errors"
    echo ""
    jq -r 'select(.status == "error") | "- \(.repo): could not be read or downloaded (see the run log)"' "$RESULTS"
    echo ""
  fi
}

render_report > "$WORK/report.md"
[ -n "$REPORT" ] && cp "$WORK/report.md" "$REPORT"
[ -n "${GITHUB_STEP_SUMMARY:-}" ] && cat "$WORK/report.md" >> "$GITHUB_STEP_SUMMARY"

log_info "findings=$FINDINGS errors=$ERRORS skipped=$SKIPPED"
log_summary

if [ "$FINDINGS" -gt 0 ] || [ "$ERRORS" -gt 0 ]; then
  [ "$FINDINGS" -gt 0 ] && log_error "$FINDINGS zip finding(s); see the table above"
  exit 1
fi
