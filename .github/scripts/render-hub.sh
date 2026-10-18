#!/usr/bin/env bash
set -euo pipefail

# Renders project listings from repos.json into the hub's index.html (cards,
# counters, share text) and README.md (badges, ecosystem diagram, pillars,
# project directory, impact numbers), so neither can drift from the registry
# and the site works without JavaScript.
#
# Usage:
#   ./render-hub.sh                 # rewrite index.html and README.md in place
#   ./render-hub.sh --check         # exit 1 if either is out of date
#
# Generated regions in both files are wrapped in marker comments:
#   <!-- BEGIN GENERATED:<name> -->  ...  <!-- END GENERATED:<name> -->
# Edit repos.json, then re-run this script. Never hand-edit those regions.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib-log.sh"

ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
REPOS_FILE="$ROOT/.github/config/repos.json"
ICONS_FILE="$ROOT/.github/config/icons.json"
INDEX_FILE="$ROOT/index.html"
README_FILE="$ROOT/README.md"
MODE="${1:-write}"

log_init "render-hub"

for F in "$REPOS_FILE" "$ICONS_FILE" "$INDEX_FILE" "$README_FILE"; do
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

# --- README.md blocks (same registry, same ordering as the site) ---
README_JQ_DEFS='
  def status_key: .status // "skill";
  def is_public: (.visibility // "public") == "public";
  def title: .title // ("Access to " + (.pillar[:1] | ascii_upcase) + .pillar[1:]);
  def pillar_name: (.pillar[:1] | ascii_upcase) + .pillar[1:];
  def repo_url($owner): "https://github.com/" + $owner + "/" + .name;
  def badge_label:
    if is_public | not then "Coming soon"
    else {"live":"Live","pre-pilot":"Pre-pilot","beta":"Beta","skill":"Active","spec":"In design"}[status_key] end;
  def badge_color:
    if is_public | not then "6B6B6B"
    else {"live":"2E7D32","pre-pilot":"3E4C6B","beta":"8A5A44","skill":"5B7A3A","spec":"6B6B6B"}[status_key] end;
  def shield_text: gsub("-"; "--") | gsub(" "; "_");
  def md_cell: gsub("\\|"; "\\|");
'

# Badges under the banner
cat > "$WORK_DIR/readme_badges" <<EOF
[![Projects](https://img.shields.io/badge/Projects-$PROJECT_COUNT-5B7A3A?style=for-the-badge)](https://dougdevitre.org/#pillars)
[![Pillars](https://img.shields.io/badge/Pillars-$PILLAR_COUNT-2D5A7B?style=for-the-badge)](https://dougdevitre.org/#pillars)
EOF

# Ecosystem diagram: hub -> projects grouped by maturity
jq -r "$README_JQ_DEFS"'
  def node_id: .name | gsub("-"; "_");
  def node: "        " + node_id + "[\"<b>" + .name + "</b><br/>" + title + (if is_public then "" else "<br/><i>coming soon</i>" end) + "\"]";
  def group($id; $label; $items):
    if ($items | length) == 0 then empty
    else ("    subgraph " + $id + " [\"" + $label + "\"]"), "        direction TB", ($items[] | node), "    end", ("    HUB --> " + $id)
    end;
  ('"$PROJECTS_JQ"') as $p
  | "```mermaid",
    "flowchart LR",
    "    HUB[\"<b>access-to</b><br/>Central Hub & Landing Site<br/><i>dougdevitre.org</i>\"]",
    group("LIVE"; "Live and piloting"; [$p[] | select(status_key == "live" or status_key == "pre-pilot")]),
    group("BETA"; "In beta"; [$p[] | select(status_key == "beta")]),
    group("SKILLS"; "Claude Skills"; [$p[] | select(status_key == "skill")]),
    group("DESIGN"; "In design"; [$p[] | select(status_key == "spec")]),
    "",
    "    style HUB fill:#2D5A7B,stroke:#1A1A1A,color:#fff,stroke-width:3px",
    ($p[] | "    style " + node_id + " fill:#" + (.color // "5A8AAB") + ",stroke:#1A1A1A,color:#fff"),
    "```"
' "$REPOS_FILE" > "$WORK_DIR/readme_ecosystem"

# Pillars: one row per pillar, its projects linked when public
jq -r "$README_JQ_DEFS"'
  .owner as $owner
  | ('"$PROJECTS_JQ"') as $p
  | "| Pillar | Projects |",
    "|:-------|:---------|",
    ( [$p[] | .pillar] | reduce .[] as $x ([]; if index($x) then . else . + [$x] end) | .[] ) as $pillar
    | [$p[] | select(.pillar == $pillar)] as $items
    | "| **" + ($items[0] | pillar_name) + "** | "
      + ([$items[] | if is_public then "[" + title + "](" + repo_url($owner) + ")" else title + " _(coming soon)_" end] | join(" · "))
      + " |"
' "$REPOS_FILE" > "$WORK_DIR/readme_pillars"

# Project directory table
jq -r "$README_JQ_DEFS"'
  .owner as $owner
  | {missouri:"Missouri", nationwide:"Nationwide", global:"Global"} as $scopes
  | ('"$PROJECTS_JQ"') as $p
  | "| Project | Pillar | Scope | What it does | Status |",
    "|:--------|:-------|:------|:-------------|:-------|",
    ($p[]
      | ((if is_public then "[" + .name + "](" + repo_url($owner) + ")" else .name end)
         + (if .live_url then " · [live ↗](" + .live_url + ")" else "" end)) as $proj
      | "| " + $proj + " | " + pillar_name + " | " + ($scopes[.scope] // .scope) + " | " + (.description | md_cell)
        + " | ![" + badge_label + "](https://img.shields.io/badge/-" + (badge_label | shield_text) + "-" + badge_color + "?style=flat-square) |")
' "$REPOS_FILE" > "$WORK_DIR/readme_directory"

# Impact at a glance
cat > "$WORK_DIR/readme_impact" <<EOF
| | | | |
|:---:|:---:|:---:|:---:|
| **$PILLAR_COUNT** | **$PROJECT_COUNT** | **$MODULES+** | **$COUNTIES** |
| Pillars | Projects | Modules | MO Counties Served |
EOF

# --- Splice each block between its markers ---
splice() {
  local name="$1" block="$2" src="$3" out="$4" label="$5"
  local begin="<!-- BEGIN GENERATED:$name -->" end="<!-- END GENERATED:$name -->"
  if [ "$(grep -cF "$begin" "$src")" -ne 1 ] || [ "$(grep -cF "$end" "$src")" -ne 1 ]; then
    log_error "$label must contain exactly one '$begin' and one '$end' marker"
    exit 1
  fi
  awk -v begin="$begin" -v end="$end" -v blockfile="$block" '
    index($0, begin) { print; while ((getline line < blockfile) > 0) print line; skipping = 1; next }
    index($0, end)   { skipping = 0 }
    !skipping        { print }
  ' "$src" > "$out"
}

# render_file <target> <name:block>...  -> writes $WORK_DIR/<basename>.rendered
render_file() {
  local target="$1"; shift
  local label; label="$(basename "$target")"
  local cur="$WORK_DIR/$label.0" next="$WORK_DIR/$label.1"
  cp "$target" "$cur"
  for pair in "$@"; do
    splice "${pair%%:*}" "$WORK_DIR/${pair#*:}" "$cur" "$next" "$label"
    mv "$next" "$cur"
  done
  mv "$cur" "$WORK_DIR/$label.rendered"
}

render_file "$INDEX_FILE"  "pillars:pillars" "stats:stats" "share:share"
render_file "$README_FILE" "badges:readme_badges" "ecosystem:readme_ecosystem" "pillars:readme_pillars" \
                           "directory:readme_directory" "impact:readme_impact"

STALE=0
for TARGET in "$INDEX_FILE" "$README_FILE"; do
  NAME="$(basename "$TARGET")"
  if diff -q "$TARGET" "$WORK_DIR/$NAME.rendered" >/dev/null; then
    [ "$MODE" = "--check" ] || log_info "$NAME already up to date"
    continue
  fi
  if [ "$MODE" = "--check" ]; then
    log_error "$NAME is out of date with repos.json. Run .github/scripts/render-hub.sh and commit the result."
    diff -u "$TARGET" "$WORK_DIR/$NAME.rendered" | head -40 || true
    STALE=1
  else
    cp "$WORK_DIR/$NAME.rendered" "$TARGET"
    log_action "render-hub" "$NAME" "updated"
  fi
done

if [ "$MODE" = "--check" ]; then
  [ "$STALE" -eq 0 ] || exit 1
  log_success "index.html and README.md are in sync with repos.json ($PROJECT_COUNT projects, $PILLAR_COUNT pillars)"
  exit 0
fi
log_success "Rendered $PROJECT_COUNT projects across $PILLAR_COUNT pillars"
