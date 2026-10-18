#!/usr/bin/env bash
# narration-clips.sh — Compose the homepage app's spoken scripts from config.
#
# Prints a JSON array of {id, text} to stdout. One source of truth for the words:
# render-hub.sh embeds these as on-screen transcripts, and generate-narration.sh
# speaks exactly the same text, so a transcript can never drift from its audio.
#
# Usage: ./narration-clips.sh [config-dir]   (default: .github/config)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${1:-$SCRIPT_DIR/../config}"

REPOS="$CONFIG_DIR/repos.json"
JOURNEY="$CONFIG_DIR/journey.json"
NARRATION="$CONFIG_DIR/narration.json"

for f in "$REPOS" "$JOURNEY" "$NARRATION"; do
  [ -f "$f" ] || { echo "narration-clips: missing $f" >&2; exit 1; }
done

jq -n \
  --slurpfile repos "$REPOS" \
  --slurpfile journey "$JOURNEY" \
  --slurpfile narration "$NARRATION" '
  ($repos[0].repos) as $all
  | ($journey[0]) as $j
  | ($all | map({key: .name, value: (.title // .name)}) | from_entries) as $titles
  # "a", "a and b", "a, b and c"
  | def joined: if length <= 1 then (.[0] // "")
                elif length == 2 then "\(.[0]) and \(.[1])"
                else "\(.[:-1] | join(", ")) and \(.[-1])" end;
  [
    { id: "welcome", text: "\($j.catalyst.welcome) \($j.catalyst.blend)" },
    { id: "distribute", text: $j.catalyst.distribute },
    { id: "finder", text: $j.finder.intro },
    { id: "gates",
      text: "\($narration[0].gates_intro) \($j.gates | join(" ")) If it fails one, pause and revise." }
  ]
  + [ $all[]
      | select(.role != "hub" and (.listed // true))
      | . as $r
      | ($j.adoption[$r.name] // null) as $a
      | ([$r.connects_to // [] | .[] | $titles[.] // empty] | joined) as $with
      | { id: $r.name,
          text: ([ "\($r.title // $r.name).",
                   "\($r.description).",
                   (if $a then "It is built for \($a.adopter). A good first step is \($a.pilot)." else empty end),
                   (if $with != "" then "It works alongside \($with)." else empty end),
                   (if ($r.visibility // "public") == "private" then "It is coming soon." else empty end)
                 ] | join(" ")) } ]
'
