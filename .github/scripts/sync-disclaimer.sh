#!/usr/bin/env bash
# sync-disclaimer.sh — Stamp the shared Access To disclaimer into one repo checkout.
#
# The wording lives only in .github/disclaimer/ in this hub repo. This script
# writes it into a child repo in three places:
#   1. DISCLAIMER.md            the full text (whole file is managed)
#   2. README.md                a short notice right under the title
#   3. SKILL.md (root, skill/)  a notice the skill shows once per conversation
# Blocks 2 and 3 sit between BEGIN/END DISCLAIMER markers; nothing outside the
# markers is touched, so a repo's own topic-specific disclaimers stay intact.
#
# Idempotent: re-running with unchanged wording changes nothing. To update the
# wording everywhere, edit .github/disclaimer/*, then re-run for each repo.
#
# Usage:
#   ./sync-disclaimer.sh [--check] <repo-name> <repo-dir>
#     --check   change nothing; exit 1 if the checkout is out of date
#   <repo-name> must exist in .github/config/repos.json (the hub is allowed).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib-log.sh"

TEMPLATES="$SCRIPT_DIR/../disclaimer"
REPOS_FILE="$SCRIPT_DIR/../config/repos.json"
BEGIN_MARK='<!-- BEGIN DISCLAIMER: synced from dougdevitre/access-to, edit it there -->'
END_MARK='<!-- END DISCLAIMER -->'

CHECK=false
if [ "${1:-}" = "--check" ]; then CHECK=true; shift; fi
REPO="${1:?Usage: sync-disclaimer.sh [--check] <repo-name> <repo-dir>}"
DIR="${2:?Usage: sync-disclaimer.sh [--check] <repo-name> <repo-dir>}"

log_init "sync-disclaimer"

[ -d "$DIR" ] || { log_error "Not a directory: $DIR"; exit 1; }
for t in DISCLAIMER.md readme-notice.md skill-notice.md; do
  [ -f "$TEMPLATES/$t" ] || { log_error "Missing template: $TEMPLATES/$t"; exit 1; }
done

TITLE=$(jq -r --arg n "$REPO" '.repos[] | select(.name == $n) | if .role == "hub" then "Access To" else (.title // .name) end' "$REPOS_FILE")
if [ -z "$TITLE" ]; then
  log_error "Repo '$REPO' is not in repos.json"
  exit 1
fi

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

# render <template> — substitute the project title.
render() {
  local t="$TEMPLATES/$1"
  awk -v title="$TITLE" '{ gsub(/\{\{TITLE\}\}/, title); print }' "$t"
}

# block <template> — the template wrapped in markers.
block() {
  printf '%s\n' "$BEGIN_MARK"
  render "$1"
  printf '%s\n' "$END_MARK"
}

# upsert <file> <template> <insert-after-line> — replace the marked block, or
# insert it after the given line (0 = top of file) with blank lines around it.
upsert() {
  local file="$1" tmpl="$2" after="$3" blk="$WORK/block"
  block "$tmpl" > "$blk"
  if grep -qF "$BEGIN_MARK" "$file"; then
    awk -v blk="$blk" -v begin="$BEGIN_MARK" -v end="$END_MARK" '
      BEGIN { while ((getline l < blk) > 0) b = b l "\n" }
      index($0, begin) == 1 { printf "%s", b; skip = 1; next }
      skip && index($0, end) == 1 { skip = 0; next }
      !skip { print }
    ' "$file"
  else
    awk -v blk="$blk" -v after="$after" '
      BEGIN { while ((getline l < blk) > 0) b = b l "\n" }
      function put() { if (after > 0) print ""; printf "%s", b; pending = 1 }
      after == 0 && NR == 1 { put() }
      {
        if (pending) { if ($0 != "") print ""; pending = 0 }
        print
      }
      NR == after { put() }
      END { }
    ' "$file"
  fi
}

CHANGED=0
# apply <target> <new-content-file> — write (or, in --check, compare).
apply() {
  local target="$1" new="$2" rel="${1#"$DIR"/}"
  if [ -f "$target" ] && cmp -s "$target" "$new"; then
    log_action "unchanged" "$REPO/$rel" "ok"
    return
  fi
  CHANGED=$((CHANGED + 1))
  if $CHECK; then
    log_warn "$REPO/$rel is out of date"
  else
    cp "$new" "$target"
    log_action "write" "$REPO/$rel" "ok"
  fi
}

# 1. DISCLAIMER.md — whole file managed.
{
  render DISCLAIMER.md
  printf '\n<!-- Synced from dougdevitre/access-to (.github/disclaimer). Edit it there, not here. -->\n'
} > "$WORK/DISCLAIMER.md"
apply "$DIR/DISCLAIMER.md" "$WORK/DISCLAIMER.md"

# 2. README.md — under the title. A centered <div>/<p> header block is kept
#    whole: the notice goes after it closes.
if [ -f "$DIR/README.md" ]; then
  if head -1 "$DIR/README.md" | grep -qE '^<(div|p)[ >]'; then
    AFTER=$(grep -nE '^</(div|p)>' "$DIR/README.md" | head -1 | cut -d: -f1)
  else
    AFTER=$(grep -nE '^# ' "$DIR/README.md" | head -1 | cut -d: -f1)
  fi
  upsert "$DIR/README.md" readme-notice.md "${AFTER:-0}" > "$WORK/README.md"
  apply "$DIR/README.md" "$WORK/README.md"
else
  log_warn "$REPO has no README.md; skipping the README notice"
fi

# 3. SKILL.md at the root or in skill/ — right after the YAML frontmatter.
for SKILL in "$DIR/SKILL.md" "$DIR/skill/SKILL.md"; do
  [ -f "$SKILL" ] && [ ! -L "$SKILL" ] || continue
  AFTER=0
  if [ "$(head -1 "$SKILL")" = "---" ]; then
    AFTER=$(awk 'NR > 1 && $0 == "---" { print NR; exit }' "$SKILL")
  fi
  upsert "$SKILL" skill-notice.md "${AFTER:-0}" > "$WORK/SKILL.md"
  apply "$SKILL" "$WORK/SKILL.md"
done

log_summary
if $CHECK && [ "$CHANGED" -gt 0 ]; then
  log_error "$REPO: $CHANGED file(s) differ from the shared disclaimer. Run sync-disclaimer.sh $REPO <dir>."
  exit 1
fi
