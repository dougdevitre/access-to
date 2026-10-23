#!/usr/bin/env bash
set -euo pipefail

# Renders project listings from repos.json into the hub page about.html (cards,
# counters, share text), the homepage app index.html (doors, plus the embedded
# data app.js reads: projects, journey.json, narration transcripts) and README.md
# (badges, ecosystem diagram, pillars, project directory, impact numbers), so
# nothing can drift from the registry and every page works without JavaScript.
#
# Usage:
#   ./render-hub.sh                 # rewrite about.html, index.html and README.md
#   ./render-hub.sh --check         # exit 1 if any of them is out of date
#
# Generated regions in both files are wrapped in marker comments:
#   <!-- BEGIN GENERATED:<name> -->  ...  <!-- END GENERATED:<name> -->
# Edit repos.json, then re-run this script. Never hand-edit those regions.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib-log.sh"

ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
REPOS_FILE="$ROOT/.github/config/repos.json"
ICONS_FILE="$ROOT/.github/config/icons.json"
INDEX_FILE="$ROOT/about.html"   # the full hub page (cards, stats, sections)
APP_FILE="$ROOT/index.html"     # the homepage app (doors + embedded data)
JOURNEY_FILE="$ROOT/.github/config/journey.json"
README_FILE="$ROOT/README.md"
MODE="${1:-write}"

log_init "render-hub"

for F in "$REPOS_FILE" "$ICONS_FILE" "$INDEX_FILE" "$APP_FILE" "$JOURNEY_FILE" "$README_FILE"; do
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

# How to upload a skill zip in claude.ai (linked from every "Install in Claude").
INSTALL_HELP_URL="https://support.claude.com/en/articles/12512180-use-skills-in-claude"

# --- Block: project cards ---
jq -r --slurpfile icons "$ICONS_FILE" --arg install_help "$INSTALL_HELP_URL" "
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
  | (if \$vis == \"private\" then (if \$st == \"beta\" then \"Private beta\" else \"Coming soon\" end) else \$statuses[\$st] end) as \$label
  | (\"https://github.com/\" + \$owner + \"/\" + .name) as \$repo_url
  | (
      if .live_url then
        \"      <a href=\\\"\" + (.live_url | @html) + \"\\\" class=\\\"pillar-link\\\" target=\\\"_blank\\\" rel=\\\"noopener\\\">\" + ((.cta // \"Open\") | @html) + \" &#8599;</a>\"
      elif .page then
        \"      <a href=\\\"\" + (.page | @html) + \"\\\" class=\\\"pillar-link\\\">Explore projects &#8594;</a>\"
      else
        \"\"
      end
    ) as \$primary
  | (
      if .install_zip and \$vis == \"public\" then
        (if (.install_zip | startswith(\"https://\")) then .install_zip
         else \$repo_url + \"/releases/download/skill-latest/\" + .install_zip end) as \$zip
        | \"      <div class=\\\"install\\\"><a href=\\\"\" + (\$zip | @html) + \"\\\" class=\\\"install-link\\\" aria-label=\\\"Install in Claude: \" + (\$title | @html) + \" skill (downloads a zip file)\\\" aria-describedby=\\\"install-help-\" + .name + \"\\\">\"
          + \"<svg class=\\\"install-icon\\\" viewBox=\\\"0 0 24 24\\\" fill=\\\"none\\\" stroke=\\\"currentColor\\\" stroke-width=\\\"2\\\" stroke-linecap=\\\"round\\\" stroke-linejoin=\\\"round\\\" aria-hidden=\\\"true\\\"><path d=\\\"M12 3v12\\\"/><path d=\\\"m7 10 5 5 5-5\\\"/><path d=\\\"M5 21h14\\\"/></svg> Install in Claude</a>\"
          + \"<p class=\\\"install-help\\\" id=\\\"install-help-\" + .name + \"\\\">Download, don&rsquo;t unzip, then Claude &rarr; Customize &rarr; Skills &rarr; + &rarr; Upload a skill. \"
          + \"<a href=\\\"\" + \$install_help + \"\\\" target=\\\"_blank\\\" rel=\\\"noopener\\\" aria-label=\\\"How to use skills in Claude (opens in a new tab)\\\">How to use skills</a></p></div>\"
      else \"\" end
    ) as \$install
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
      \"      <div class=\\\"tag-row\\\">\" + (if \$vis == \"private\" and \$st == \"beta\" then \"\" else \"<span class=\\\"tag\\\">\" + \$types[\$st] + \"</span>\" end) + \"<span class=\\\"tag\\\">\" + (\$scopes[.scope] // .scope) + \"</span>\" + (if \$st == \"skill\" and \$vis == \"public\" then \"<span class=\\\"tag tag-time\\\">5 min setup</span>\" else \"\" end) + \"</div>\",
      \$primary,
      \$install,
      \$repo,
      \"      <span class=\\\"pillar-status\\\">\" + \$label + \"</span>\",
      (if \$vis == \"private\" and \$st == \"beta\" then \"      <p class=\\\"pillar-note\\\">Invite-only for now.</p>\" else \"\" end),
      \"    </article>\"
    ]
  | map(select(. != \"\"))
  | join(\"\n\")
" "$REPOS_FILE" > "$WORK_DIR/pillars"

# --- Counts used by the stats bar and share text ---
PROJECT_COUNT=$(jq "($PROJECTS_JQ) | length" "$REPOS_FILE")
PILLAR_COUNT=$(jq "($PROJECTS_JQ) | map(.pillar) | unique | length" "$REPOS_FILE")
OPEN_SOURCE_COUNT=$(jq "($PROJECTS_JQ) | map(select((.visibility // \"public\") == \"public\")) | length" "$REPOS_FILE")
COUNTIES=$(jq -r '.repos[] | select(.role == "hub") | .key_stats.counties // 0' "$REPOS_FILE")

if [ "$PROJECT_COUNT" -eq 0 ]; then
  log_error "No listed projects found in repos.json — refusing to render an empty hub"
  exit 1
fi

cat > "$WORK_DIR/stats" <<EOF
    <div class="stat"><div class="stat-number" data-target="$PILLAR_COUNT">$PILLAR_COUNT</div><div class="stat-label">Pillars</div></div>
    <div class="stat"><div class="stat-number" data-target="$PROJECT_COUNT">$PROJECT_COUNT</div><div class="stat-label">Projects</div></div>
    <div class="stat"><div class="stat-number" data-target="$OPEN_SOURCE_COUNT">$OPEN_SOURCE_COUNT</div><div class="stat-label">Open-Source Repos</div></div>
    <div class="stat"><div class="stat-number" data-target="$COUNTIES">$COUNTIES</div><div class="stat-label">MO Counties Covered</div></div>
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
  # Same rule as the site cards: a private beta says so and is invite-only;
  # any other private status is "Coming soon" (tests/card-labels.test.js).
  def private_label: if status_key == "beta" then "Private beta" else "Coming soon" end;
  def private_note: if status_key == "beta" then "private beta, invite-only" else "coming soon" end;
  def badge_label:
    if is_public | not then private_label
    else {"live":"Live","pre-pilot":"Pre-pilot","beta":"Beta","skill":"Active","spec":"In design"}[status_key] end;
  def badge_color:
    if is_public | not then "6B6B6B"
    else {"live":"2E7D32","pre-pilot":"3E4C6B","beta":"8A5A44","skill":"5B7A3A","spec":"6B6B6B"}[status_key] end;
  def shield_text: gsub("-"; "--") | gsub(" "; "_");
  def md_cell: gsub("\\|"; "\\|");
'

# Badges under the banner
cat > "$WORK_DIR/readme_badges" <<EOF
[![Projects](https://img.shields.io/badge/Projects-$PROJECT_COUNT-5B7A3A?style=for-the-badge)](https://dougdevitre.org/about.html#pillars)
[![Pillars](https://img.shields.io/badge/Pillars-$PILLAR_COUNT-2D5A7B?style=for-the-badge)](https://dougdevitre.org/about.html#pillars)
EOF

# Ecosystem diagram: hub -> projects grouped by maturity
jq -r "$README_JQ_DEFS"'
  def node_id: .name | gsub("-"; "_");
  def node: "        " + node_id + "[\"<b>" + .name + "</b><br/>" + title + (if is_public then "" else "<br/><i>" + private_note + "</i>" end) + "\"]";
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
      + ([$items[] | if is_public then "[" + title + "](" + repo_url($owner) + ")" else title + " _(" + private_note + ")_" end] | join(" · "))
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
        + " | ![" + badge_label + "](https://img.shields.io/badge/-" + (badge_label | shield_text) + "-" + badge_color + "?style=flat-square)"
        + (if (is_public | not) and status_key == "beta" then " Invite-only for now." else "" end) + " |")
' "$REPOS_FILE" > "$WORK_DIR/readme_directory"

# Impact at a glance
cat > "$WORK_DIR/readme_impact" <<EOF
| | | | |
|:---:|:---:|:---:|:---:|
| **$PILLAR_COUNT** | **$PROJECT_COUNT** | **$OPEN_SOURCE_COUNT** | **$COUNTIES** |
| Pillars | Projects | Open-Source Repos | MO Counties Covered |
EOF

# --- Homepage app: one door (big touch button) per project ---
# Works without JavaScript: each door is a real link. app.js upgrades a tap into
# the project's detail sheet.
jq -r --slurpfile icons "$ICONS_FILE" "
  ($PROJECTS_JQ) as \$projects
  | .owner as \$owner
  | {live:\"Live\", beta:\"Beta\", skill:\"Ready to use\", \"pre-pilot\":\"Pre-pilot\", spec:\"In design\"} as \$labels
  | \$projects[]
  | (.visibility // \"public\") as \$vis
  | (.title // .name) as \$title
  | (if .live_url then .live_url
     elif .page then .page
     elif \$vis == \"public\" then \"https://github.com/\" + \$owner + \"/\" + .name
     else \"about.html#pillars\" end) as \$href
  | ((\$href | startswith(\"https://\"))) as \$external
  | \"      <li><a class=\\\"door\\\" href=\\\"\" + (\$href | @html) + \"\\\" data-id=\\\"\" + .name + \"\\\" style=\\\"--c:#\" + (.color // \"5A8AAB\") + \"\\\"\"
    + (if \$external then \" target=\\\"_blank\\\" rel=\\\"noopener\\\"\" else \"\" end) + \">\"
    + \"<span class=\\\"door-icon\\\" aria-hidden=\\\"true\\\"><svg viewBox=\\\"0 0 24 24\\\" fill=\\\"none\\\" stroke=\\\"currentColor\\\" stroke-width=\\\"2\\\" stroke-linecap=\\\"round\\\" stroke-linejoin=\\\"round\\\">\" + (\$icons[0][.icon // .pillar] // \"\") + \"</svg></span>\"
    + \"<span class=\\\"door-name\\\">\" + (\$title | @html) + \"</span>\"
    + \"<span class=\\\"door-status\\\">\" + (if \$vis == \"private\" then (if .status == \"beta\" then \"Private beta\" else \"Coming soon\" end) else \$labels[.status // \"skill\"] end) + \"</span>\"
    + \"</a></li>\"
" "$REPOS_FILE" > "$WORK_DIR/doors"

# --- Homepage app: embedded data (projects + journey + narration transcripts) ---
# Embedded rather than fetched so the app works offline and never shows an
# empty state. "</" is escaped so the JSON can't close its <script> element.
CLIPS_JSON="$("$SCRIPT_DIR/narration-clips.sh" "$ROOT/.github/config")"
{
  printf '  <script type="application/json" id="app-data">'
  jq -c --slurpfile icons "$ICONS_FILE" --slurpfile journey "$JOURNEY_FILE" --argjson clips "$CLIPS_JSON" "
    ($PROJECTS_JQ) as \$projects
    | .owner as \$owner
    | (\$projects | map(.name)) as \$listed
    | {live:\"Live\", beta:\"Beta\", skill:\"Ready to use\", \"pre-pilot\":\"Pre-pilot\", spec:\"In design\"} as \$labels
    | {missouri:\"Missouri\", nationwide:\"Nationwide\", global:\"Global\"} as \$scopes
    | {
        projects: [ \$projects[]
          | (.visibility // \"public\") as \$vis
          | (\$journey[0].adoption[.name] // {}) as \$a
          | {
              id: .name,
              title: (.title // .name),
              pillar: .pillar,
              color: (\"#\" + (.color // \"5A8AAB\")),
              icon: (\$icons[0][.icon // .pillar] // \"\"),
              description: .description,
              status: (if \$vis == \"private\" then (if .status == \"beta\" then \"Private beta\" else \"Coming soon\" end) else \$labels[.status // \"skill\"] end),
              scope: (\$scopes[.scope] // .scope),
              private: (\$vis == \"private\"),
              note: (if \$vis != \"private\" then null
                     elif .status == \"beta\" then \"Invite-only for now. The source opens when it is ready for public use.\"
                     else \"The source opens when it is ready for public use.\" end),
              live: (.live_url // null),
              cta: (.cta // \"Open the app\"),
              page: (.page // null),
              repo: (if \$vis == \"public\" then \"https://github.com/\" + \$owner + \"/\" + .name else null end),
              install: (if .install_zip and \$vis == \"public\" then
                          (if (.install_zip | startswith(\"https://\")) then .install_zip
                           else \"https://github.com/\" + \$owner + \"/\" + .name + \"/releases/download/skill-latest/\" + .install_zip end)
                        else null end),
              audience: (.audience // []),
              adopter: (\$a.adopter // null),
              pilot: (\$a.pilot // null),
              connects: [ (.connects_to // [])[] | select(. as \$c | \$listed | index(\$c)) ]
            } ],
        journey: (\$journey[0] | del(._readme, .adoption)),
        clips: (\$clips | map({key: .id, value: .text}) | from_entries)
      }
  " "$REPOS_FILE" | sed 's#</#<\\/#g'
  printf '</script>\n'
} > "$WORK_DIR/app_data"

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
render_file "$APP_FILE"    "doors:doors" "app-data:app_data"
render_file "$README_FILE" "badges:readme_badges" "ecosystem:readme_ecosystem" "pillars:readme_pillars" \
                           "directory:readme_directory" "impact:readme_impact"

STALE=0
for TARGET in "$INDEX_FILE" "$APP_FILE" "$README_FILE"; do
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
  log_success "about.html, index.html and README.md are in sync with repos.json ($PROJECT_COUNT projects, $PILLAR_COUNT pillars)"
  exit 0
fi
log_success "Rendered $PROJECT_COUNT projects across $PILLAR_COUNT pillars"
