#!/usr/bin/env bash
# ecosystem-drift.sh — Read-only drift check across every repo in repos.json.
#
# Two kinds of silent rot that no child repo's own CI can see:
#
#   1. Disclaimer drift. The shared disclaimer is stamped into each repo by
#      sync-disclaimer.sh. This fetches the repo's DISCLAIMER.md, README.md,
#      SKILL.md and skill/SKILL.md at its default branch into a temp dir and
#      runs `sync-disclaimer.sh --check` on them:
#        in sync | drifted (files named) | missing (no DISCLAIMER.md)
#   2. Stale skill packages. For each *.skill file (zip or tarball) at the repo
#      root, it lists the package, maps its entries to repo paths (dropping a
#      single top-level folder the repo doesn't have), and compares the
#      package's last commit date with the newest commit touching any of those
#      top-level paths:
#        fresh | stale (both dates) | n/a (none of its paths are in the repo,
#        so the package is the source) | unreadable
#
# Everything remote goes through `gh api` (repo, git trees, git blobs,
# commits), and nothing is ever written to any repo. A repo the token cannot
# read (a private repo without a suitable token) is skipped with a warning.
#
# Usage:
#   ./ecosystem-drift.sh [--report <file>] [repos-file]
#     --report   also write a markdown report (table + fix command per finding)
#     repos-file defaults to .github/config/repos.json
#
# Output: a table through lib-log (one JSON row per repo with LOG_FORMAT=json),
# plus the markdown report on GITHUB_STEP_SUMMARY when set. The report opens
# with  <!-- ecosystem-drift findings=N errors=N skipped=N -->  for workflows.
#
# Exit codes: 0 clean (skips allowed), 1 any repo drifted, missing or stale,
# or any repo that should have been readable could not be read.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib-log.sh"

REPORT=""
if [ "${1:-}" = "--report" ]; then REPORT="${2:?--report needs a file}"; shift 2; fi
REPOS_FILE="${1:-$SCRIPT_DIR/../config/repos.json}"

log_init "ecosystem-drift"

[ -f "$REPOS_FILE" ] || { log_error "Repos config not found: $REPOS_FILE"; exit 1; }
for tool in gh jq unzip tar; do
  command -v "$tool" >/dev/null || { log_error "Required tool not found: $tool"; exit 1; }
done

OWNER=$(jq -r '.owner' "$REPOS_FILE")
mapfile -t REPOS < <(jq -r '.repos[] | if type == "object" then .name else . end' "$REPOS_FILE")
log_info "Checking ${#REPOS[@]} repos under $OWNER (read-only)"

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
RESULTS="$WORK/results.jsonl"
: > "$RESULTS"

FINDINGS=0
ERRORS=0
SKIPPED=0

# --- fetch layer: the only place that talks to GitHub ------------------------

# api <endpoint> — JSON from the GitHub REST API.
api() { gh api "$1"; }
# raw_blob <repo> <sha> — raw bytes of a git blob (for a symlink: its target).
raw_blob() { gh api "repos/$OWNER/$1/git/blobs/$2" -H 'Accept: application/vnd.github.raw'; }
# last_commit <repo> <branch> <path> — committer date of the newest commit touching path.
last_commit() {
  api "repos/$OWNER/$1/commits?sha=$2&path=$3&per_page=1" | jq -r '.[0].commit.committer.date // ""'
}

# fetch_entry <repo> <tree-json-file> <name> <dest> — copy one tree entry
# (file or symlink) to dest. Returns 1 when the entry doesn't exist.
fetch_entry() {
  local repo="$1" tree="$2" name="$3" dest="$4" entry mode sha
  entry=$(jq -c --arg n "$name" '.tree[] | select(.path == $n and .type == "blob")' "$tree")
  [ -n "$entry" ] || return 1
  mode=$(jq -r '.mode' <<<"$entry")
  sha=$(jq -r '.sha' <<<"$entry")
  mkdir -p "$(dirname "$dest")"
  if [ "$mode" = "120000" ]; then
    ln -s "$(raw_blob "$repo" "$sha")" "$dest"
  else
    raw_blob "$repo" "$sha" > "$dest"
  fi
}

# list_package <file> — one entry path per line, for a zip or a (gzipped) tarball.
list_package() {
  unzip -Z1 "$1" 2>/dev/null || tar -tzf "$1" 2>/dev/null || tar -tf "$1" 2>/dev/null
}

# --- checks ------------------------------------------------------------------

# check_disclaimer <repo> <dir> <tree-file> — prints {disclaimer, drifted_files}.
check_disclaimer() {
  local repo="$1" dir="$2" tree="$3" out rc files
  if ! jq -e '.tree[] | select(.path == "DISCLAIMER.md")' "$tree" >/dev/null; then
    jq -nc '{disclaimer: "missing", drifted_files: ["DISCLAIMER.md"]}'
    return
  fi
  rc=0
  out=$(LOG_FORMAT=text "$SCRIPT_DIR/sync-disclaimer.sh" --check "$repo" "$dir" 2>&1) || rc=$?
  if [ "$rc" -eq 0 ]; then
    jq -nc '{disclaimer: "in sync", drifted_files: []}'
    return
  fi
  files=$(grep -oE "\] sync-disclaimer: $repo/[^ ]+ is out of date" <<<"$out" \
    | sed -E "s/.*: $repo\/([^ ]+) is out of date/\1/" | sort -u | jq -Rsc 'split("\n") | map(select(. != ""))')
  if [ "$files" = "[]" ]; then
    log_error "$repo: sync-disclaimer.sh --check failed without naming a file: $out"
    ERRORS=$((ERRORS + 1))
  fi
  jq -nc --argjson f "$files" '{disclaimer: "drifted", drifted_files: $f}'
}

# check_package <repo> <branch> <tree-file> <name> — prints one package result.
check_package() {
  local repo="$1" branch="$2" tree="$3" name="$4"
  local pkg="$WORK/$1/pkg/$4"
  local entries comps prefix p d pkg_date content_date="" newest="" status
  fetch_entry "$repo" "$tree" "$name" "$pkg"
  if ! entries=$(list_package "$pkg") || [ -z "$entries" ]; then
    log_warn "$repo/$name is neither a zip nor a tarball; cannot list its contents"
    jq -nc --arg f "$name" '{file: $f, status: "unreadable"}'
    return
  fi
  entries=$(sed -E 's#^\./##' <<<"$entries" | grep -v '^$' || true)
  # Drop one top-level folder that wraps everything, unless the repo has it too.
  prefix=$(awk -F/ '{print $1}' <<<"$entries" | sort -u)
  if [ "$(wc -l <<<"$prefix")" -eq 1 ] && grep -q / <<<"$entries" \
     && ! jq -e --arg n "$prefix" '.tree[] | select(.path == $n)' "$tree" >/dev/null; then
    entries=$(sed -E "s#^$prefix/##" <<<"$entries" | grep -v '^$' || true)
  fi
  # Top-level paths the package carries that also exist in the repo.
  mapfile -t comps < <(awk -F/ '{print $1}' <<<"$entries" | sort -u \
    | while read -r c; do
        [ "$c" != "$name" ] && jq -e --arg n "$c" '.tree[] | select(.path == $n)' "$tree" >/dev/null && echo "$c"
      done || true)
  pkg_date=$(last_commit "$repo" "$branch" "$name")
  for p in "${comps[@]}"; do
    d=$(last_commit "$repo" "$branch" "$p")
    if [ -n "$d" ] && [[ "$d" > "$content_date" ]]; then content_date="$d"; newest="$p"; fi
  done
  if [ "${#comps[@]}" -eq 0 ] || [ -z "$content_date" ]; then
    status="n/a"
  elif [[ "$content_date" > "$pkg_date" ]]; then
    status="stale"
  else
    status="fresh"
  fi
  jq -nc --arg f "$name" --arg s "$status" --arg pd "$pkg_date" --arg cd "$content_date" --arg np "$newest" \
    --argjson paths "$(printf '%s\n' "${comps[@]}" | jq -Rsc 'split("\n") | map(select(. != ""))')" \
    '{file: $f, status: $s, package_date: $pd, content_date: $cd, newest_path: $np, paths: $paths}'
}

# has_build_script <repo> <tree-file> — true when scripts/build-skill.sh exists.
has_build_script() {
  local sha
  sha=$(jq -r '.tree[] | select(.path == "scripts" and .type == "tree") | .sha' "$2")
  [ -n "$sha" ] && api "repos/$OWNER/$1/git/trees/$sha" | jq -e '.tree[] | select(.path == "build-skill.sh")' >/dev/null
}

# --- main loop ---------------------------------------------------------------

for REPO in "${REPOS[@]}"; do
  DIR="$WORK/$REPO/checkout"
  TREE="$WORK/$REPO/tree.json"
  mkdir -p "$DIR"

  if ! META=$(api "repos/$OWNER/$REPO" 2>"$WORK/err"); then
    if grep -q 'HTTP 404' "$WORK/err"; then
      log_warn "$REPO: not readable with this token (private?); skipped"
      SKIPPED=$((SKIPPED + 1))
      jq -nc --arg r "$REPO" '{repo: $r, disclaimer: "skipped", drifted_files: [], packages: [], note: "not readable with this token"}' >> "$RESULTS"
    else
      log_error "$REPO: could not read repo: $(cat "$WORK/err")"
      ERRORS=$((ERRORS + 1))
      jq -nc --arg r "$REPO" '{repo: $r, disclaimer: "error", drifted_files: [], packages: []}' >> "$RESULTS"
    fi
    continue
  fi
  BRANCH=$(jq -r '.default_branch' <<<"$META")

  if ! api "repos/$OWNER/$REPO/git/trees/$BRANCH" > "$TREE" 2>"$WORK/err"; then
    log_error "$REPO: could not read the $BRANCH tree: $(cat "$WORK/err")"
    ERRORS=$((ERRORS + 1))
    jq -nc --arg r "$REPO" '{repo: $r, disclaimer: "error", drifted_files: [], packages: []}' >> "$RESULTS"
    continue
  fi

  for f in DISCLAIMER.md README.md SKILL.md; do
    fetch_entry "$REPO" "$TREE" "$f" "$DIR/$f" || true
  done
  SKILL_SHA=$(jq -r '.tree[] | select(.path == "skill" and .type == "tree") | .sha' "$TREE")
  if [ -n "$SKILL_SHA" ]; then
    api "repos/$OWNER/$REPO/git/trees/$SKILL_SHA" > "$WORK/$REPO/skill-tree.json"
    fetch_entry "$REPO" "$WORK/$REPO/skill-tree.json" SKILL.md "$DIR/skill/SKILL.md" || true
  fi

  DISC=$(check_disclaimer "$REPO" "$DIR" "$TREE")
  STATUS=$(jq -r '.disclaimer' <<<"$DISC")
  log_action "disclaimer" "$REPO" "$STATUS" "$(jq -r '.drifted_files | join(", ")' <<<"$DISC")"
  [ "$STATUS" = "in sync" ] || FINDINGS=$((FINDINGS + 1))

  PKGS="[]"
  BUILD=false
  mapfile -t SKILLS < <(jq -r '.tree[] | select(.type == "blob" and (.path | endswith(".skill"))) | .path' "$TREE")
  for S in "${SKILLS[@]}"; do
    P=$(check_package "$REPO" "$BRANCH" "$TREE" "$S")
    PKGS=$(jq -c --argjson p "$P" '. + [$p]' <<<"$PKGS")
    PS=$(jq -r '.status' <<<"$P")
    log_action "package" "$REPO/$S" "$PS" "$(jq -r 'select(.package_date) | "package \(.package_date), sources \(.content_date) (\(.newest_path))"' <<<"$P")"
    if [ "$PS" = "stale" ]; then
      FINDINGS=$((FINDINGS + 1))
      has_build_script "$REPO" "$TREE" && BUILD=true
    fi
  done

  jq -nc --arg r "$REPO" --argjson d "$DISC" --argjson p "$PKGS" --argjson b "$BUILD" \
    '{repo: $r} + $d + {packages: $p, build_script: $b}' >> "$RESULTS"
done

# --- output ------------------------------------------------------------------

short() { printf '%s' "${1:0:10}"; }

# Table: one row per repo.
if [ "$LOG_FORMAT" = "json" ]; then
  while IFS= read -r row; do
    _log_json "info" "result $(jq -r '.repo' <<<"$row")" "$(jq -c '.' <<<"$row" | sed 's/^{//; s/}$//')"
  done < "$RESULTS"
else
  log_info "$(printf '%-22s %-10s %s' REPO DISCLAIMER PACKAGES)"
  while IFS= read -r row; do
    log_info "$(printf '%-22s %-10s %s' \
      "$(jq -r '.repo' <<<"$row")" \
      "$(jq -r '.disclaimer' <<<"$row")" \
      "$(jq -r '[.packages[] | "\(.file): \(.status)" + (if .status == "stale" then " (package \(.package_date[0:10]) < sources \(.content_date[0:10]))" else "" end)] | join("; ") | if . == "" then "-" else . end' <<<"$row")")"
  done < "$RESULTS"
fi

# Markdown report: summary table plus the fix for each finding.
render_report() {
  echo "<!-- ecosystem-drift findings=$FINDINGS errors=$ERRORS skipped=$SKIPPED -->"
  echo "## Ecosystem drift"
  echo ""
  echo "_Checked $(date -u '+%Y-%m-%d %H:%M UTC') across ${#REPOS[@]} repos (read-only)._"
  echo ""
  echo "| Repo | Disclaimer | Skill packages |"
  echo "|------|------------|----------------|"
  jq -r '"| \(.repo) | \(.disclaimer)\(if (.drifted_files | length) > 0 and .disclaimer == "drifted" then " (" + (.drifted_files | join(", ")) + ")" else "" end) | \([.packages[] | "`\(.file)` \(.status)" + (if .package_date and .status != "n/a" and .status != "unreadable" then " (package \(.package_date[0:10]), sources \(.content_date[0:10]))" else "" end)] | join("<br>") | if . == "" then "—" else . end) |"' "$RESULTS"
  echo ""
  if [ "$FINDINGS" -gt 0 ]; then
    echo "### How to fix"
    echo ""
    jq -r --arg owner "$OWNER" '
      select(.disclaimer == "drifted" or .disclaimer == "missing" or any(.packages[]; .status == "stale")) |
      . as $root |
      "**\(.repo)**\n",
      (if .disclaimer == "drifted" or .disclaimer == "missing" then
        "- Disclaimer \(.disclaimer) (\(.drifted_files | join(", "))). From the hub checkout:\n  ```bash\n  gh repo clone \($owner)/\(.repo) ../\(.repo)\n  .github/scripts/sync-disclaimer.sh \(.repo) ../\(.repo)\n  ```\n  Then open a PR in \(.repo)."
       else empty end),
      (.packages[] | select(.status == "stale") |
        "- `\(.file)` is stale: last packaged \(.package_date[0:10]), but `\(.newest_path)` changed \(.content_date[0:10]). Rebuild it from the current sources" +
        (if $root.build_script then " (`./scripts/build-skill.sh \(.file)` in \($root.repo))" else "" end) +
        " and open a PR in \($root.repo)."),
      ""
    ' "$RESULTS"
  fi
  if [ "$SKIPPED" -gt 0 ]; then
    echo "### Not checked"
    echo ""
    jq -r 'select(.disclaimer == "skipped") | "- \(.repo): \(.note)"' "$RESULTS"
    echo ""
    echo "Private repos need a read-only token in the \`ECOSYSTEM_READ_TOKEN\` secret (see the workflow header)."
    echo ""
  fi
  if [ "$ERRORS" -gt 0 ]; then
    echo "### Errors"
    echo ""
    jq -r 'select(.disclaimer == "error") | "- \(.repo): could not be read (see the run log)"' "$RESULTS"
    echo ""
  fi
}

render_report > "$WORK/report.md"
[ -n "$REPORT" ] && cp "$WORK/report.md" "$REPORT"
[ -n "${GITHUB_STEP_SUMMARY:-}" ] && cat "$WORK/report.md" >> "$GITHUB_STEP_SUMMARY"

log_info "findings=$FINDINGS errors=$ERRORS skipped=$SKIPPED"
log_summary

if [ "$FINDINGS" -gt 0 ] || [ "$ERRORS" -gt 0 ]; then
  [ "$FINDINGS" -gt 0 ] && log_error "$FINDINGS drift finding(s); see the table above for the fix"
  exit 1
fi
