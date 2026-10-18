#!/usr/bin/env bash
set -euo pipefail

# Renders the hub landing page's project cards, counters, and share-text
# counts from repos.json into index.html, so the page works without
# JavaScript and search engines / link previews see every project.
#
# Usage:
#   ./render-hub.sh                 # rewrite index.html in place
#   ./render-hub.sh --check         # exit 1 if index.html is out of date
#
# Generated regions in index.html are wrapped in marker comments:
#   <!-- BEGIN GENERATED:<name> -->  ...  <!-- END GENERATED:<name> -->
# Edit repos.json, then re-run this script. Never hand-edit those regions.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib-log.sh"

ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
REPOS_FILE="$ROOT/.github/config/repos.json"
ICONS_FILE="$ROOT/.github/config/icons.json"
INDEX_FILE="$ROOT/index.html"
MODE="${1:-write}"

log_init "render-hub"

for F in "$REPOS_FILE" "$ICONS_FILE" "$INDEX_FILE"; do
  if [ ! -f "$F" ]; then
    log_error "Required file not found: $F"
    exit 1
  fi
done

WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

# Projects shown on the hub: everything except the hub itself and
# anything explicitly unlisted. Ordered by maturity, then registry order.
PROJECTS_JQ='
  [ .repos | to_entries[]
    | select(.value.role != "hub" and (.value.listed // true))
    | .value + {order: .key} ]
  | sort_by(
      ({"live":0,"pre-pilot":1,"beta":2,"skill":3,"spec":4}[.status // "skill"] // 5),
      .order)
'

# --- Block: project cards ---
jq -r --slurpfile icons "$ICONS_FILE" "
  ($PROJECTS_JQ) as \$projects
  | .owner as \$owner
  | {missouri:\"Missouri\", nationwide:\"Nationwide\", global:\"Global\"} as \$scopes
  | {live:\"Live app\", beta:\"In beta\", skill:\"Claude Skill\", \"pre-pilot\":\"Pre-pilot\", spec:\"Spec\"} as \$types
  | {live:\"Live\", beta:\"Beta\", skill:\"Active\", \"pre-pilot\":\"Pre-pilot\", spec:\"In design\"} as \$statuses
  | \$projects[]
  | (.status // \"skill\") as \$st
  | (.visibility // \"public\") as \$vis
  | (.title // (\"Access to \" + (.pillar[:1] | ascii_upcase) + .pillar[1:])) as \$title
  | (\$icons[0][.icon // .pillar] // \"\") as \$svg
  | (\"https://github.com/\" + \$owner + \"/\" + .name) as \$repo_url
  | (
      if .live_url then
        \"      <a href=\\\"\" + (.live_url | @html) + \"\\\" class=\\\"pillar-link\\\" target=\\\"_blank\\\" rel=\\\"noopener\\\">\" + ((.cta // \"Open\") | @html) + \" &#8599;</a>\"
      elif .page then
        \"      <a href=\\\"\" + (.page | @html) + \"\\\" class=\\\"pillar-link\\\">Explore projects &#8594;</a>\"
      elif \$vis == \"public\" then
        \"\"
      else
        \"      <span class=\\\"pillar-link pillar-link-pending\\\">Coming soon</span>\"
      end
    ) as \$primary
  | (
      if \$vis == \"public\" then
        \"      <ul class=\\\"repo-list\\\"><li><a href=\\\"\" + \$repo_url + \"\\\" target=\\\"_blank\\\" rel=\\\"noopener\\\" aria-label=\\\"\" + .name + \" on GitHub (opens in a new tab)\\\"><svg class=\\\"repo-icon\\\" viewBox=\\\"0 0 16 16\\\" fill=\\\"currentColor\\\" aria-hidden=\\\"true\\\"><path d=\\\"M8 0C3.58 0 0 3.58 0 8c0 3.54 2.29 6.53 5.47 7.59.4.07.55-.17.55-.38 0-.19-.01-.82-.01-1.49-2.01.37-2.53-.49-2.69-.94-.09-.23-.48-.94-.82-1.13-.28-.15-.68-.52-.01-.53.63-.01 1.08.58 1.23.82.72 1.21 1.87.87 2.33.66.07-.52.28-.87.51-1.07-1.78-.2-3.64-.89-3.64-3.95 0-.87.31-1.59.82-2.15-.08-.2-.36-1.02.08-2.12 0 0 .67-.21 2.2.82.64-.18 1.32-.27 2-.27.68 0 1.36.09 2 .27 1.53-1.04 2.2-.82 2.2-.82.44 1.1.16 1.92.08 2.12.51.56.82 1.27.82 2.15 0 3.07-1.87 3.75-3.65 3.95.29.25.54.73.54 1.48 0 1.07-.01 1.93-.01 2.2 0 .21.15.46.55.38A8.013 8.013 0 0016 8c0-4.42-3.58-8-8-8z\\\"/></svg> \" + .name + \" <span class=\\\"repo-arrow\\\" aria-hidden=\\\"true\\\">&#8599;</span></a></li></ul>\"
      else
        \"      <ul class=\\\"repo-list\\\"><li><span class=\\\"repo-private\\\">\" + .name + \" &middot; source opening soon</span></li></ul>\"
      end
    ) as \$repo
  | [
      \"    <article class=\\\"pillar-card\\\" data-pillar=\\\"\" + .pillar + \"\\\" data-status=\\\"\" + \$st + \"\\\" style=\\\"--pillar-color:#\" + (.color // \"5A8AAB\") + \"\\\">\",
      \"      <div class=\\\"pillar-icon\\\" aria-hidden=\\\"true\\\"><svg width=\\\"22\\\" height=\\\"22\\\" viewBox=\\\"0 0 24 24\\\" fill=\\\"none\\\" stroke=\\\"currentColor\\\" stroke-width=\\\"2\\\" stroke-linecap=\\\"round\\\" stroke-linejoin=\\\"round\\\">\" + \$svg + \"</svg></div>\",
      \"      <h2>\" + (\$title | @html) + \"</h2>\",
      \"      <p class=\\\"pillar-desc\\\">\" + (.description | @html) + \"</p>\",
      \"      <div class=\\\"tag-row\\\"><span class=\\\"tag\\\">\" + \$types[\$st] + \"</span><span class=\\\"tag\\\">\" + (\$scopes[.scope] // .scope) + \"</span>\" + (if \$st == \"skill\" and \$vis == \"public\" then \"<span class=\\\"tag tag-time\\\">5 min setup</span>\" else \"\" end) + \"</div>\",
      \$primary,
      \$repo,
      \"      <span class=\\\"pillar-status\\\">\" + (if \$vis == \"private\" then \"In development\" else \$statuses[\$st] end) + \"</span>\",
      \"    </article>\"
    ]
  | map(select(. != \"\"))
  | join(\"\n\")
" "$REPOS_FILE" > "$WORK_DIR/pillars"

# --- Counts used by the stats bar and share text ---
PROJECT_COUNT=$(jq "($PROJECTS_JQ) | length" "$REPOS_FILE")
PILLAR_COUNT=$(jq "($PROJECTS_JQ) | map(.pillar) | unique | length" "$REPOS_FILE")
MODULES=$(jq -r '.repos[] | select(.role == "hub") | .key_stats.modules // 0' "$REPOS_FILE")
COUNTIES=$(jq -r '.repos[] | select(.role == "hub") | .key_stats.counties // 0' "$REPOS_FILE")

if [ "$PROJECT_COUNT" -eq 0 ]; then
  log_error "No listed projects found in repos.json — refusing to render an empty hub"
  exit 1
fi

cat > "$WORK_DIR/stats" <<EOF
    <div class="stat"><div class="stat-number" data-target="$PILLAR_COUNT">$PILLAR_COUNT</div><div class="stat-label">Pillars</div></div>
    <div class="stat"><div class="stat-number" data-target="$PROJECT_COUNT">$PROJECT_COUNT</div><div class="stat-label">Projects</div></div>
    <div class="stat"><div class="stat-number" data-target="$MODULES" data-suffix="+">$MODULES+</div><div class="stat-label">Modules</div></div>
    <div class="stat"><div class="stat-number" data-target="$COUNTIES">$COUNTIES</div><div class="stat-label">MO Counties Served</div></div>
EOF

SHARE="$PROJECT_COUNT open-source projects across $PILLAR_COUNT pillars — closing the access gaps that matter most."
cat > "$WORK_DIR/share" <<EOF
  <meta property="og:description" content="$SHARE">
  <meta name="twitter:description" content="$SHARE">
EOF

# --- Splice each block between its markers ---
splice() {
  local name="$1" block="$2" src="$3" out="$4"
  local begin="<!-- BEGIN GENERATED:$name -->" end="<!-- END GENERATED:$name -->"
  if [ "$(grep -cF "$begin" "$src")" -ne 1 ] || [ "$(grep -cF "$end" "$src")" -ne 1 ]; then
    log_error "index.html must contain exactly one '$begin' and one '$end' marker"
    exit 1
  fi
  awk -v begin="$begin" -v end="$end" -v blockfile="$block" '
    index($0, begin) { print; while ((getline line < blockfile) > 0) print line; skipping = 1; next }
    index($0, end)   { skipping = 0 }
    !skipping        { print }
  ' "$src" > "$out"
}

cp "$INDEX_FILE" "$WORK_DIR/step0"
splice "pillars" "$WORK_DIR/pillars" "$WORK_DIR/step0" "$WORK_DIR/step1"
splice "stats"   "$WORK_DIR/stats"   "$WORK_DIR/step1" "$WORK_DIR/step2"
splice "share"   "$WORK_DIR/share"   "$WORK_DIR/step2" "$WORK_DIR/rendered"

if [ "$MODE" = "--check" ]; then
  if ! diff -q "$INDEX_FILE" "$WORK_DIR/rendered" >/dev/null; then
    log_error "index.html is out of date with repos.json. Run .github/scripts/render-hub.sh and commit the result."
    diff -u "$INDEX_FILE" "$WORK_DIR/rendered" | head -40 || true
    exit 1
  fi
  log_success "index.html is in sync with repos.json ($PROJECT_COUNT projects, $PILLAR_COUNT pillars)"
  exit 0
fi

if diff -q "$INDEX_FILE" "$WORK_DIR/rendered" >/dev/null; then
  log_info "index.html already up to date"
else
  cp "$WORK_DIR/rendered" "$INDEX_FILE"
  log_action "render-hub" "index.html" "updated"
fi
log_success "Rendered $PROJECT_COUNT projects across $PILLAR_COUNT pillars"
