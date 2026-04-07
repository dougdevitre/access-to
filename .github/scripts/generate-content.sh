#!/usr/bin/env bash
set -euo pipefail

# Generates content from repos.json + content.json using templates.
#
# Usage: ./generate-content.sh <config-dir> <content-dir>
#
# Reads config, applies templates, and writes generated content.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib-log.sh"

CONFIG_DIR="${1:?Usage: generate-content.sh <config-dir> <content-dir>}"
CONTENT_DIR="${2:?Usage: generate-content.sh <config-dir> <content-dir>}"

REPOS_FILE="$CONFIG_DIR/repos.json"
CONTENT_FILE="$CONFIG_DIR/content.json"
TEMPLATES_DIR="$CONTENT_DIR/templates"
OUTPUT_DIR="$CONTENT_DIR/generated"

for F in "$REPOS_FILE" "$CONTENT_FILE"; do
  if [ ! -f "$F" ]; then
    log_error "Config not found: $F"
    exit 1
  fi
done

if [ ! -d "$TEMPLATES_DIR" ]; then
  log_error "Templates directory not found: $TEMPLATES_DIR"
  exit 1
fi

log_init "generate-content"
mkdir -p "$OUTPUT_DIR"

# Load brand data
BRAND_NAME=$(jq -r '.brand.name' "$CONTENT_FILE")
BRAND_MISSION=$(jq -r '.brand.mission' "$CONTENT_FILE")
BRAND_URL=$(jq -r '.brand.url' "$CONTENT_FILE")
BRAND_EMAIL=$(jq -r '.brand.email' "$CONTENT_FILE")
BRAND_ACCENT=$(jq -r '.brand.colors.accent' "$CONTENT_FILE")
FOUNDER=$(jq -r '.brand.founder' "$CONTENT_FILE")
FONT_HEADING=$(jq -r '.brand.fonts.heading' "$CONTENT_FILE")
FONT_BODY=$(jq -r '.brand.fonts.body' "$CONTENT_FILE")
BRAND_STATS_PILLARS=$(jq -r '.brand.stats.pillars' "$CONTENT_FILE")
BRAND_STATS_PROJECTS=$(jq -r '.brand.stats.projects' "$CONTENT_FILE")
BRAND_STATS_MODULES=$(jq -r '.brand.stats.modules' "$CONTENT_FILE")
BRAND_STATS_COUNTIES=$(jq -r '.brand.stats.counties' "$CONTENT_FILE")
SOCIAL_PROOF=$(jq -r '.brand.social_proof | join(", ")' "$CONTENT_FILE")
OWNER=$(jq -r '.owner' "$REPOS_FILE")
DATE=$(date -u '+%Y-%m-%d')

GENERATED=0
REPO_COUNT=$(jq '.repos | length' "$REPOS_FILE")

# Get format metadata
FORMAT_KEYS=$(jq -r '.formats | keys[]' "$CONTENT_FILE")

for i in $(seq 0 $((REPO_COUNT - 1))); do
  ROLE=$(jq -r ".repos[$i].role" "$REPOS_FILE")
  # Skip hub — content is for pillar repos
  if [ "$ROLE" = "hub" ]; then continue; fi

  # Load repo data
  REPO_NAME=$(jq -r ".repos[$i].name" "$REPOS_FILE")
  PILLAR=$(jq -r ".repos[$i].pillar" "$REPOS_FILE")
  PILLAR_NAME=$(echo "$PILLAR" | sed 's/./\U&/' )
  PILLAR_LOWER="$PILLAR"
  DESCRIPTION=$(jq -r ".repos[$i].description" "$REPOS_FILE")
  DESCRIPTION_LOWER=$(echo "$DESCRIPTION" | sed 's/./\l&/')
  SCOPE=$(jq -r ".repos[$i].scope" "$REPOS_FILE")
  COLOR=$(jq -r ".repos[$i].color" "$REPOS_FILE")
  ICON=$(jq -r ".repos[$i].icon" "$REPOS_FILE")
  TAGLINE=$(jq -r ".repos[$i].tagline" "$REPOS_FILE")
  CTA=$(jq -r ".repos[$i].cta" "$REPOS_FILE")

  # Audience
  AUDIENCE_LIST=$(jq -r ".repos[$i].audience | join(\", \")" "$REPOS_FILE")
  AUDIENCE_FIRST=$(jq -r ".repos[$i].audience[0]" "$REPOS_FILE")
  AUDIENCE_LIST_PROSE=$(jq -r ".repos[$i].audience | join(\", \") | sub(\"(?<a>.*), \"; \"\(.a), and \")" "$REPOS_FILE" 2>/dev/null || echo "$AUDIENCE_LIST")
  AUDIENCE_BULLETS=$(jq -r ".repos[$i].audience[] | \"- \" + ." "$REPOS_FILE")
  AUDIENCE_HASHTAGS=$(jq -r ".repos[$i].audience | map(gsub(\" \"; \"\")) | map(\"#\" + .) | join(\" \")" "$REPOS_FILE")

  # Use cases
  USE_CASES_NUMBERED=$(jq -r ".repos[$i].use_cases | to_entries | map(\"\(.key + 1). \(.value)\") | join(\"\n\")" "$REPOS_FILE")
  USE_CASES_BULLETS=$(jq -r ".repos[$i].use_cases[] | \"- \" + ." "$REPOS_FILE")
  USE_CASES_PROSE=$(jq -r ".repos[$i].use_cases | join(\". \")" "$REPOS_FILE")
  USE_CASE_FIRST_SHORT=$(jq -r ".repos[$i].use_cases[0]" "$REPOS_FILE")
  USE_CASES_DISCUSSION=""
  while IFS= read -r UC; do
    USE_CASES_DISCUSSION+="### $UC"$'\n'"- How it works in practice"$'\n'"- Who benefits most"$'\n'"- Real-world example"$'\n\n'
  done < <(jq -r ".repos[$i].use_cases[]" "$REPOS_FILE")

  # Key stats
  KEY_STATS_TABLE=$(jq -r ".repos[$i].key_stats | to_entries | map(\"| \(.key) | \(.value) |\") | join(\"\n\")" "$REPOS_FILE")
  KEY_STATS_BULLETS=$(jq -r ".repos[$i].key_stats | to_entries | map(\"- **\(.key):** \(.value)\") | join(\"\n\")" "$REPOS_FILE")

  # Connections
  CONNECTIONS_RAW=$(jq -r ".repos[$i].connects_to // [] | .[]" "$REPOS_FILE")
  CONNECTIONS_LIST=""
  CONNECTIONS_PROSE=""
  CONNECTIONS_BULLETS=""
  CONNECTIONS_FIRST=""
  while IFS= read -r CONN; do
    [ -z "$CONN" ] && continue
    CONN_PILLAR=$(jq -r --arg name "$CONN" '.repos[] | select(.name == $name) | .pillar' "$REPOS_FILE")
    CONN_NAME=$(echo "$CONN_PILLAR" | sed 's/./\U&/')
    CONNECTIONS_LIST+="- $CONN_NAME ($CONN)"$'\n'
    CONNECTIONS_BULLETS+="- $CONN_NAME"$'\n'
    if [ -z "$CONNECTIONS_FIRST" ]; then
      CONNECTIONS_FIRST="$CONN_NAME"
    fi
    if [ -n "$CONNECTIONS_PROSE" ]; then
      CONNECTIONS_PROSE+=", $CONN_NAME"
    else
      CONNECTIONS_PROSE="$CONN_NAME"
    fi
  done <<< "$CONNECTIONS_RAW"

  # Cross-pillar story (find first story involving this pillar)
  STORY_NAME=$(jq -r --arg p "$PILLAR" '.cross_pillar_stories[] | select(.flow | index($p)) | .name' "$CONTENT_FILE" | head -1)
  STORY_NARRATIVE=$(jq -r --arg p "$PILLAR" '.cross_pillar_stories[] | select(.flow | index($p)) | .narrative' "$CONTENT_FILE" | head -1)
  STORY_PERSONA=$(jq -r --arg p "$PILLAR" '.cross_pillar_stories[] | select(.flow | index($p)) | .persona' "$CONTENT_FILE" | head -1)
  STORY_FLOW=$(jq -r --arg p "$PILLAR" '.cross_pillar_stories[] | select(.flow | index($p)) | .flow | join(" → ")' "$CONTENT_FILE" | head -1)
  STORY_FLOW_ARROWS=$(jq -r --arg p "$PILLAR" '.cross_pillar_stories[] | select(.flow | index($p)) | .flow | map(. | sub("^."; (.[0:1] | ascii_upcase) + .[1:])) | join(" → ")' "$CONTENT_FILE" 2>/dev/null | head -1 || echo "$STORY_FLOW")

  PILLAR_HASHTAG=$(echo "$PILLAR_NAME" | sed 's/ //g')

  log_info "Generating content for $PILLAR_NAME ($REPO_NAME)"

  # Process each template
  for TEMPLATE in "$TEMPLATES_DIR"/*.md; do
    TNAME=$(basename "$TEMPLATE" .md)
    FORMAT_AUDIENCE=$(jq -r --arg k "$TNAME" '.formats[$k].audience // "general"' "$CONTENT_FILE" 2>/dev/null || echo "general")

    OUTPUT_FILE="$OUTPUT_DIR/${TNAME}-${PILLAR}.md"

    # Apply template substitutions
    sed \
      -e "s|{{PILLAR_NAME}}|$PILLAR_NAME|g" \
      -e "s|{{PILLAR_LOWER}}|$PILLAR_LOWER|g" \
      -e "s|{{PILLAR_HASHTAG}}|$PILLAR_HASHTAG|g" \
      -e "s|{{REPO_NAME}}|$REPO_NAME|g" \
      -e "s|{{DESCRIPTION}}|$DESCRIPTION|g" \
      -e "s|{{DESCRIPTION_LOWER}}|$DESCRIPTION_LOWER|g" \
      -e "s|{{TAGLINE}}|$TAGLINE|g" \
      -e "s|{{CTA}}|$CTA|g" \
      -e "s|{{SCOPE}}|$SCOPE|g" \
      -e "s|{{COLOR}}|$COLOR|g" \
      -e "s|{{ICON}}|$ICON|g" \
      -e "s|{{AUDIENCE_LIST}}|$AUDIENCE_LIST|g" \
      -e "s|{{AUDIENCE_FIRST}}|$AUDIENCE_FIRST|g" \
      -e "s|{{AUDIENCE_LIST_PROSE}}|$AUDIENCE_LIST_PROSE|g" \
      -e "s|{{USE_CASE_FIRST_SHORT}}|$USE_CASE_FIRST_SHORT|g" \
      -e "s|{{CONNECTIONS_FIRST}}|$CONNECTIONS_FIRST|g" \
      -e "s|{{CONNECTIONS_PROSE}}|$CONNECTIONS_PROSE|g" \
      -e "s|{{STORY_NAME}}|${STORY_NAME:-N/A}|g" \
      -e "s|{{STORY_NARRATIVE}}|${STORY_NARRATIVE:-N/A}|g" \
      -e "s|{{STORY_PERSONA}}|${STORY_PERSONA:-N/A}|g" \
      -e "s|{{STORY_FLOW}}|${STORY_FLOW:-N/A}|g" \
      -e "s|{{STORY_FLOW_ARROWS}}|${STORY_FLOW_ARROWS:-N/A}|g" \
      -e "s|{{BRAND_NAME}}|$BRAND_NAME|g" \
      -e "s|{{BRAND_MISSION}}|$BRAND_MISSION|g" \
      -e "s|{{BRAND_URL}}|$BRAND_URL|g" \
      -e "s|{{BRAND_EMAIL}}|$BRAND_EMAIL|g" \
      -e "s|{{BRAND_ACCENT}}|$BRAND_ACCENT|g" \
      -e "s|{{BRAND_STATS_PILLARS}}|$BRAND_STATS_PILLARS|g" \
      -e "s|{{BRAND_STATS_PROJECTS}}|$BRAND_STATS_PROJECTS|g" \
      -e "s|{{BRAND_STATS_MODULES}}|$BRAND_STATS_MODULES|g" \
      -e "s|{{BRAND_STATS_COUNTIES}}|$BRAND_STATS_COUNTIES|g" \
      -e "s|{{SOCIAL_PROOF}}|$SOCIAL_PROOF|g" \
      -e "s|{{FOUNDER}}|$FOUNDER|g" \
      -e "s|{{OWNER}}|$OWNER|g" \
      -e "s|{{FONT_HEADING}}|$FONT_HEADING|g" \
      -e "s|{{FONT_BODY}}|$FONT_BODY|g" \
      -e "s|{{FORMAT_AUDIENCE}}|$FORMAT_AUDIENCE|g" \
      -e "s|{{DATE}}|$DATE|g" \
      "$TEMPLATE" > "$OUTPUT_FILE"

    # Replace multi-line placeholders (sed can't do these)
    python3 -c "
import sys
with open('$OUTPUT_FILE', 'r') as f:
    content = f.read()
replacements = {
    '{{USE_CASES_NUMBERED}}': '''$USE_CASES_NUMBERED''',
    '{{USE_CASES_BULLETS}}': '''$USE_CASES_BULLETS''',
    '{{USE_CASES_PROSE}}': '''$USE_CASES_PROSE''',
    '{{USE_CASES_DISCUSSION}}': '''$USE_CASES_DISCUSSION''',
    '{{KEY_STATS_TABLE}}': '''$KEY_STATS_TABLE''',
    '{{KEY_STATS_BULLETS}}': '''$KEY_STATS_BULLETS''',
    '{{CONNECTIONS_LIST}}': '''$CONNECTIONS_LIST''',
    '{{CONNECTIONS_BULLETS}}': '''$CONNECTIONS_BULLETS''',
    '{{AUDIENCE_BULLETS}}': '''$AUDIENCE_BULLETS''',
    '{{AUDIENCE_HASHTAGS}}': '''$AUDIENCE_HASHTAGS''',
}
for k, v in replacements.items():
    content = content.replace(k, v)
with open('$OUTPUT_FILE', 'w') as f:
    f.write(content)
" 2>/dev/null || true

    log_action "generate" "$TNAME-$PILLAR" "success"
    ((GENERATED++)) || true
  done
done

# Write summary
if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
  {
    echo "## Content Generation Results"
    echo ""
    echo "| Metric | Value |"
    echo "|--------|-------|"
    echo "| Files generated | $GENERATED |"
    echo "| Pillars | $((REPO_COUNT - 1)) |"
    echo "| Templates | $(ls "$TEMPLATES_DIR"/*.md 2>/dev/null | wc -l) |"
    echo "| Output dir | $OUTPUT_DIR |"
  } >> "$GITHUB_STEP_SUMMARY"
fi

log_summary
log_success "Generated $GENERATED content files in $OUTPUT_DIR"
