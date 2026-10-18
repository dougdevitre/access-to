#!/usr/bin/env bash
set -euo pipefail

# Renders project listings from repos.json into the hub page about.html (cards,
# counters, share text), the homepage app index.html (doors, language switch,
# hreflang links, plus the embedded data app.js reads: projects, journey.json,
# narration transcripts, UI words) and README.md (badges, ecosystem diagram,
# pillars, project directory, impact numbers), so nothing can drift from the
# registry and every page works without JavaScript.
#
# Each other language (.github/config/i18n/<lang>.json + journey.<lang>.json)
# gets <lang>/index.html, generated whole from index.html: the same page and
# app, with its English strings replaced from the i18n page map. Never edit
# <lang>/index.html by hand.
#
# Usage:
#   ./render-hub.sh                 # rewrite about.html, index.html, README.md and <lang>/index.html
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
| **$PILLAR_COUNT** | **$PROJECT_COUNT** | **$OPEN_SOURCE_COUNT** | **$COUNTIES** |
| Pillars | Projects | Open-Source Repos | MO Counties Covered |
EOF

# --- Homepage app, once per language ---
# English is index.html. Every other language with .github/config/i18n/<lang>.json
# and journey.<lang>.json gets <lang>/index.html, built from index.html itself:
# its English strings are swapped for the i18n page map, links are pointed up a
# level, and the doors and embedded data are rendered from that language's words.
I18N_DIR="$ROOT/.github/config/i18n"
[ -f "$I18N_DIR/en.json" ] || { log_error "Required file not found: $I18N_DIR/en.json"; exit 1; }
OTHER_LANGS=()
for F in "$I18N_DIR"/*.json; do
  L="$(basename "$F" .json)"
  [ "$L" = "en" ] && continue
  [ -f "$ROOT/.github/config/journey.$L.json" ] || { log_error "i18n/$L.json has no journey.$L.json"; exit 1; }
  OTHER_LANGS+=("$L")
done
ALL_LANGS=(en ${OTHER_LANGS[@]+"${OTHER_LANGS[@]}"})

CLIPS_JSON="$("$SCRIPT_DIR/narration-clips.sh" "$ROOT/.github/config")"

# journey.json with a language's words laid over it. Structure (ids, finder
# doors, crisis flags, role lenses) always comes from journey.json.
merged_journey() {  # $1 lang -> stdout
  if [ "$1" = "en" ]; then cat "$JOURNEY_FILE"; return; fi
  jq --slurpfile tr "$ROOT/.github/config/journey.$1.json" '
    $tr[0] as $t
    | def by_id($x): map(. as $e | $e + ((($x // []) | map(select(.id == $e.id)))[0] // {}));
      def by_index($x): to_entries | map(.value + (($x // [])[.key] // {}));
    . + {
      catalyst: (.catalyst + ($t.catalyst // {})),
      beacon: (.beacon | by_index($t.beacon)),
      virtues: (.virtues | by_index($t.virtues)),
      gates: ($t.gates // .gates),
      finder: (.finder + ($t.finder // {} | {intro, help_note, crisis_note} | with_entries(select(.value != null)))
               + { roles: (.finder.roles | by_id($t.finder.roles)),
                   needs: (.finder.needs | by_id($t.finder.needs)),
                   places: (.finder.places | by_id($t.finder.places)) }),
      adoption: (.adoption | with_entries(.value += (($t.adoption // {})[.key] // {})))
    }' "$JOURNEY_FILE"
}

# Path from a page in language $1 to the site root: "" for English, "../" otherwise.
root_of() { if [ "$1" = "en" ]; then echo ""; else echo "../"; fi; }

# One door (big touch button) per project. Works without JavaScript: each door
# is a real link. app.js upgrades a tap into the project's detail sheet.
render_doors() {  # $1 lang -> stdout
  jq -r --slurpfile icons "$ICONS_FILE" --slurpfile t "$I18N_DIR/$1.json" --arg root "$(root_of "$1")" "
    ($PROJECTS_JQ) as \$projects
    | .owner as \$owner
    | \$t[0].labels as \$labels
    | \$projects[]
    | (.visibility // \"public\") as \$vis
    | (.title // .name) as \$title
    | (if .live_url then .live_url
       elif .page then \$root + .page
       elif \$vis == \"public\" then \"https://github.com/\" + \$owner + \"/\" + .name
       else \$root + \"about.html#pillars\" end) as \$href
    | ((\$href | startswith(\"https://\"))) as \$external
    | \"      <li><a class=\\\"door\\\" href=\\\"\" + (\$href | @html) + \"\\\" data-id=\\\"\" + .name + \"\\\" style=\\\"--c:#\" + (.color // \"5A8AAB\") + \"\\\"\"
      + (if \$external then \" target=\\\"_blank\\\" rel=\\\"noopener\\\"\" else \"\" end) + \">\"
      + \"<span class=\\\"door-icon\\\" aria-hidden=\\\"true\\\"><svg viewBox=\\\"0 0 24 24\\\" fill=\\\"none\\\" stroke=\\\"currentColor\\\" stroke-width=\\\"2\\\" stroke-linecap=\\\"round\\\" stroke-linejoin=\\\"round\\\">\" + (\$icons[0][.icon // .pillar] // \"\") + \"</svg></span>\"
      + \"<span class=\\\"door-name\\\">\" + (\$title | @html) + \"</span>\"
      + \"<span class=\\\"door-status\\\">\" + ((if \$vis == \"private\" then \$labels.coming_soon else \$labels.status[.status // \"skill\"] end) | @html) + \"</span>\"
      + \"</a></li>\"
  " "$REPOS_FILE"
}

# Embedded data (projects + journey + narration transcripts + UI words).
# Embedded rather than fetched so the app works offline and never shows an
# empty state. "</" is escaped so the JSON can't close its <script> element.
render_app_data() {  # $1 lang -> stdout
  local lang="$1" suffix=""
  [ "$lang" = "en" ] || suffix="-$lang"
  merged_journey "$lang" > "$WORK_DIR/journey.$lang.json"
  printf '  <script type="application/json" id="app-data">'
  jq -c --slurpfile icons "$ICONS_FILE" --slurpfile journey "$WORK_DIR/journey.$lang.json" \
        --slurpfile t "$I18N_DIR/$lang.json" --argjson clips "$CLIPS_JSON" \
        --arg lang "$lang" --arg suffix "$suffix" --arg root "$(root_of "$lang")" "
    ($PROJECTS_JQ) as \$projects
    | .owner as \$owner
    | (\$projects | map(.name)) as \$listed
    | \$t[0].labels as \$labels
    | (\$t[0].projects // {}) as \$copy
    | {
        lang: \$lang,
        root: \$root,
        url: \$t[0].url,
        projects: [ \$projects[]
          | (.visibility // \"public\") as \$vis
          | (\$journey[0].adoption[.name] // {}) as \$a
          | (\$copy[.name] // {}) as \$c
          | {
              id: .name,
              title: (.title // .name),
              pillar: .pillar,
              color: (\"#\" + (.color // \"5A8AAB\")),
              icon: (\$icons[0][.icon // .pillar] // \"\"),
              description: (\$c.description // .description),
              status: (if \$vis == \"private\" then \$labels.coming_soon else \$labels.status[.status // \"skill\"] end),
              stage: (.status // \"skill\"),
              scope: (\$labels.scope[.scope] // .scope),
              region: .scope,
              private: (\$vis == \"private\"),
              live: (.live_url // null),
              cta: (\$c.cta // .cta // \$labels.cta),
              page: (if .page then \$root + .page else null end),
              repo: (if \$vis == \"public\" then \"https://github.com/\" + \$owner + \"/\" + .name else null end),
              audience: (\$c.audience // .audience // []),
              adopter: (\$a.adopter // null),
              pilot: (\$a.pilot // null),
              connects: [ (.connects_to // [])[] | select(. as \$x | \$listed | index(\$x)) ]
            } ],
        journey: (\$journey[0] | del(._readme, .adoption)),
        clips: (\$clips | map(select(.lang == \$lang) | {key: (.id | if \$suffix == \"\" then . else .[:-(\$suffix | length)] end), value: .text}) | from_entries),
        ui: \$t[0].ui
      }
  " "$REPOS_FILE" | sed 's#</#<\\/#g'
  printf '</script>\n'
}

# hreflang alternates: the same list on every language's page.
jq -rn --slurpfile en "$I18N_DIR/en.json" '
  ([$en[0]] + [inputs]) as $all
  | ($all[] | "  <link rel=\"alternate\" hreflang=\"\(.lang)\" href=\"\(.url)\">"),
    "  <link rel=\"alternate\" hreflang=\"x-default\" href=\"\($en[0].url)\">"
' $(for L in ${OTHER_LANGS[@]+"${OTHER_LANGS[@]}"}; do echo "$I18N_DIR/$L.json"; done) < /dev/null > "$WORK_DIR/hreflang"

# Language switch (EN | ES), written for the page in language $1.
render_lang_switch() {  # $1 lang -> stdout
  jq -rn --arg cur "$1" --arg root "$(root_of "$1")" --slurpfile en "$I18N_DIR/en.json" '
    ([$en[0]] + [inputs]) as $all
    | ($all[] | select(.lang == $cur) | .labels.language_nav) as $nav
    | "      <nav class=\"lang-switch\" aria-label=\"\($nav | @html)\">",
      ($all[] | (.lang | ascii_upcase) as $code
        | (if .lang == $cur then "index.html" else "\($root)\(.path)index.html" end) as $href
        | "        <a href=\"\($href)\" lang=\"\(.lang)\" hreflang=\"\(.lang)\" aria-label=\"\($code), \(.name | @html)\""
          + (if .lang == $cur then " aria-current=\"page\"" else "" end) + ">\($code)</a>"),
      "      </nav>"
  ' $(for L in ${OTHER_LANGS[@]+"${OTHER_LANGS[@]}"}; do echo "$I18N_DIR/$L.json"; done) < /dev/null
}

for L in "${ALL_LANGS[@]}"; do
  render_doors "$L" > "$WORK_DIR/doors.$L"
  render_app_data "$L" > "$WORK_DIR/app_data.$L"
  render_lang_switch "$L" > "$WORK_DIR/lang_switch.$L"
done

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
render_file "$APP_FILE"    "hreflang:hreflang" "lang-switch:lang_switch.en" "doors:doors.en" "app-data:app_data.en"
render_file "$README_FILE" "badges:readme_badges" "ecosystem:readme_ecosystem" "pillars:readme_pillars" \
                           "directory:readme_directory" "impact:readme_impact"
TARGETS=("$INDEX_FILE" "$APP_FILE" "$README_FILE")
declare -A RENDERED=(["$INDEX_FILE"]="$WORK_DIR/about.html.rendered" ["$APP_FILE"]="$WORK_DIR/index.html.rendered"
                     ["$README_FILE"]="$WORK_DIR/README.md.rendered")

# --- Other languages: <lang>/index.html from the rendered English homepage ---
for L in ${OTHER_LANGS[@]+"${OTHER_LANGS[@]}"}; do
  T="$I18N_DIR/$L.json"
  OUT="$ROOT/$L/index.html"
  # Empty the generated blocks (they are re-rendered in this language below),
  # then translate the hand-written English and point relative links up a level.
  awk '/<!-- BEGIN GENERATED:/ { print; skip = 1; next } /<!-- END GENERATED:/ { skip = 0 } !skip' \
    "$WORK_DIR/index.html.rendered" > "$WORK_DIR/$L.base"
  jq -Rrs --slurpfile t "$T" '
    $t[0] as $t
    | ($t.page | [.[] | to_entries[]] | from_entries) as $map
    | def tr: $map[.] // .;
    gsub(">(?<pre>\\s*)(?<s>[^<>]*?)(?<post>\\s*)<"; ">\(.pre)\(.s | tr)\(.post)<")
    | gsub("(?<a>\\s(?:content|aria-label|title|alt|placeholder)=\")(?<v>[^\"]*)\""; "\(.a)\(.v | tr)\"")
    | gsub("(?<a>\"description\": \")(?<v>[^\"]*)\""; "\(.a)\(.v | tr)\"")
    | sub("<html lang=\"en\">"; "<html lang=\"\($t.lang)\">")
    | sub("rel=\"canonical\" href=\"[^\"]*\""; "rel=\"canonical\" href=\"\($t.url)\"")
    | sub("property=\"og:url\" content=\"[^\"]*\""; "property=\"og:url\" content=\"\($t.url)\"")
    | gsub("(?<a>(?:href|src)=\")(?<u>(?!https?:|mailto:|#|/|\\.\\./|index\\.html)[^\"]+)\""; "\(.a)../\(.u)\"")
  ' "$WORK_DIR/$L.base" > "$WORK_DIR/$L.translated"
  # Warn about translations that no longer match anything on the English page.
  jq -r --rawfile html "$WORK_DIR/$L.base" '.page | [.[] | keys[]] | .[] | select(. as $k | $html | contains($k) | not)' "$T" \
    | while IFS= read -r K; do log_warn "i18n/$L.json: page string no longer in index.html: $K"; done
  cp "$WORK_DIR/$L.translated" "$WORK_DIR/$L.0"
  for pair in "hreflang:hreflang" "lang-switch:lang_switch.$L" "doors:doors.$L" "app-data:app_data.$L"; do
    splice "${pair%%:*}" "$WORK_DIR/${pair#*:}" "$WORK_DIR/$L.0" "$WORK_DIR/$L.1" "$L/index.html"
    mv "$WORK_DIR/$L.1" "$WORK_DIR/$L.0"
  done
  [ "$MODE" = "--check" ] || mkdir -p "$ROOT/$L"
  TARGETS+=("$OUT")
  RENDERED["$OUT"]="$WORK_DIR/$L.0"
done

STALE=0
for TARGET in "${TARGETS[@]}"; do
  NAME="${TARGET#"$ROOT"/}"
  if diff -q "$TARGET" "${RENDERED[$TARGET]}" >/dev/null 2>&1; then
    [ "$MODE" = "--check" ] || log_info "$NAME already up to date"
    continue
  fi
  if [ "$MODE" = "--check" ]; then
    log_error "$NAME is out of date with repos.json. Run .github/scripts/render-hub.sh and commit the result."
    diff -u "$TARGET" "${RENDERED[$TARGET]}" | head -40 || true
    STALE=1
  else
    cp "${RENDERED[$TARGET]}" "$TARGET"
    log_action "render-hub" "$NAME" "updated"
  fi
done

if [ "$MODE" = "--check" ]; then
  [ "$STALE" -eq 0 ] || exit 1
  log_success "${TARGETS[*]#"$ROOT"/} are in sync with the config ($PROJECT_COUNT projects, $PILLAR_COUNT pillars, languages: ${ALL_LANGS[*]})"
  exit 0
fi
log_success "Rendered $PROJECT_COUNT projects across $PILLAR_COUNT pillars"
