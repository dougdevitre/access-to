#!/usr/bin/env bash
# narration-clips.sh — Compose the homepage app's spoken scripts from config.
#
# Prints a JSON array of {id, lang, text} to stdout. One source of truth for the
# words: render-hub.sh embeds these as on-screen transcripts, and
# generate-narration.sh speaks exactly the same text, so a transcript can never
# drift from its audio.
#
# English comes first, with plain ids (welcome, access-to-food). Every other
# language with an i18n/<lang>.json and a journey.<lang>.json follows, with ids
# suffixed -<lang> (welcome-es, access-to-food-es), composed from that
# language's words and joining phrases.
#
# Usage: ./narration-clips.sh [config-dir]   (default: .github/config)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${1:-$SCRIPT_DIR/../config}"

REPOS="$CONFIG_DIR/repos.json"
JOURNEY="$CONFIG_DIR/journey.json"
I18N_DIR="$CONFIG_DIR/i18n"

for f in "$REPOS" "$JOURNEY" "$I18N_DIR/en.json"; do
  [ -f "$f" ] || { echo "narration-clips: missing $f" >&2; exit 1; }
done

# Other languages, in a stable order: i18n/<lang>.json with a journey.<lang>.json.
LANG_FILES=()
for f in "$I18N_DIR"/*.json; do
  lang="$(basename "$f" .json)"
  [ "$lang" = "en" ] && continue
  [ -f "$CONFIG_DIR/journey.$lang.json" ] || { echo "narration-clips: $f has no journey.$lang.json" >&2; exit 1; }
  LANG_FILES+=("$f")
done

# One object per language: {lang, i18n, journey}. English has no overrides.
LANGS_JSON=$(
  {
    jq -n --slurpfile i "$I18N_DIR/en.json" '{lang: "en", i18n: $i[0], journey: {}}'
    for f in ${LANG_FILES[@]+"${LANG_FILES[@]}"}; do
      lang="$(basename "$f" .json)"
      jq -n --arg lang "$lang" --slurpfile i "$f" --slurpfile j "$CONFIG_DIR/journey.$lang.json" \
        '{lang: $lang, i18n: $i[0], journey: $j[0]}'
    done
  } | jq -s .
)

jq -n \
  --slurpfile repos "$REPOS" \
  --slurpfile journey "$JOURNEY" \
  --argjson langs "$LANGS_JSON" '
  ($repos[0].repos) as $all
  | ($all | map({key: .name, value: (.title // .name)}) | from_entries) as $titles
  | [ $langs[]
      | .lang as $lang
      | (if $lang == "en" then "" else "-" + $lang end) as $suffix
      | .i18n.narration as $say
      | ($journey[0]) as $en
      | .journey as $tr
      | (.i18n.projects // {}) as $copy
      # "a", "a and b", "a, b and c" (the joining word is the language'\''s own)
      | def joined: if length <= 1 then (.[0] // "")
                    elif length == 2 then "\(.[0]) \($say.and) \(.[1])"
                    else "\(.[:-1] | join(", ")) \($say.and) \(.[-1])" end;
        def fill($k; $v): split("{" + $k + "}") | join($v);
        ($en.catalyst + ($tr.catalyst // {})) as $c
      | ($tr.gates // $en.gates) as $gates
      | (($tr.finder.intro) // $en.finder.intro) as $intro
      | (
          [ { id: "welcome", text: "\($c.welcome) \($c.blend)" },
            { id: "distribute", text: $c.distribute },
            { id: "finder", text: $intro },
            { id: "gates", text: "\($say.gates_intro) \($gates | join(" ")) \($say.gates_outro)" } ]
          + [ $all[]
              | select(.role != "hub" and (.listed // true))
              | . as $r
              | (($tr.adoption // {})[$r.name] // $en.adoption[$r.name] // null) as $a
              | ([$r.connects_to // [] | .[] | $titles[.] // empty] | joined) as $with
              | { id: $r.name,
                  text: ([ "\($r.title // $r.name).",
                           "\(($copy[$r.name].description) // $r.description).",
                           (if $a then ($say.built_for | fill("adopter"; $a.adopter)), ($say.first_step | fill("pilot"; $a.pilot)) else empty end),
                           (if $with != "" then ($say.alongside | fill("with"; $with)) else empty end),
                           (if ($r.visibility // "public") == "private" then $say.coming_soon else empty end)
                         ] | join(" ")) } ]
        )[]
      | { id: (.id + $suffix), lang: $lang, text } ]
'
