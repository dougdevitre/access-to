#!/usr/bin/env bash
# generate-narration.sh — Speak the homepage app's scripts in Doug's ElevenLabs voice.
#
# Reads the clips from narration-clips.sh and the voice settings from
# .github/config/narration.json, writes audio/<id>.mp3 and audio/manifest.json.
# Idempotent: a clip is regenerated only when its text, voice, model or settings
# change (tracked by a sha256 in the manifest), so re-running costs nothing.
# Clips that no longer exist are removed.
#
# Usage:
#   ELEVENLABS_API_KEY=... ./generate-narration.sh        # generate what changed
#   ./generate-narration.sh --dry-run                     # list changes + characters, no key needed
#
# The API key is read from the environment only and never printed or passed on
# the command line.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib-log.sh"

ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
NARRATION="$ROOT/.github/config/narration.json"
OUT_DIR="$ROOT/audio"
MANIFEST="$OUT_DIR/manifest.json"
DRY_RUN=false
[ "${1:-}" = "--dry-run" ] && DRY_RUN=true

log_init "generate-narration"

if ! $DRY_RUN && [ -z "${ELEVENLABS_API_KEY:-}" ]; then
  log_error "ELEVENLABS_API_KEY is not set (add it as a repository secret, or use --dry-run)"
  exit 1
fi

VOICE_ID=$(jq -r '.voice_id' "$NARRATION")
MODEL_ID=$(jq -r '.model_id' "$NARRATION")
FORMAT=$(jq -r '.output_format' "$NARRATION")
SETTINGS=$(jq -c '.voice_settings' "$NARRATION")

if ! [[ "$VOICE_ID" =~ ^[A-Za-z0-9]{20}$ ]]; then
  log_error "narration.json voice_id is not a 20-character ElevenLabs id"
  exit 1
fi

CLIPS=$("$SCRIPT_DIR/narration-clips.sh" "$ROOT/.github/config")
mkdir -p "$OUT_DIR"
[ -f "$MANIFEST" ] || echo '{"clips":{}}' > "$MANIFEST"

clip_sha() {
  printf '%s|%s|%s|%s|%s' "$1" "$VOICE_ID" "$MODEL_ID" "$SETTINGS" "$FORMAT" | sha256sum | cut -c1-16
}

synthesize() {  # $1 text, $2 output path
  local body tmp code
  body=$(jq -n --arg text "$1" --arg model "$MODEL_ID" --argjson vs "$SETTINGS" \
    '{text: $text, model_id: $model, voice_settings: $vs}')
  tmp=$(mktemp)
  code=$(curl -sS -o "$tmp" -w '%{http_code}' --max-time 120 \
    -X POST "https://api.elevenlabs.io/v1/text-to-speech/${VOICE_ID}?output_format=${FORMAT}" \
    -H @<(printf 'xi-api-key: %s\n' "$ELEVENLABS_API_KEY") \
    -H 'Content-Type: application/json' -H 'Accept: audio/mpeg' \
    --data-binary "$body") || { rm -f "$tmp"; echo "curl failed"; return 1; }
  if [ "$code" != "200" ]; then
    echo "HTTP $code: $(head -c 300 "$tmp" | tr -d '\n')"; rm -f "$tmp"; return 1
  fi
  # An MP3 starts with an ID3 tag or an MPEG frame sync; anything else is an error page.
  local magic
  magic=$(head -c 3 "$tmp" | od -An -tx1 | tr -d ' \n')
  if [ "$(stat -c%s "$tmp")" -lt 2000 ] || ! [[ "$magic" == 494433* || "$magic" == ff[ef]* ]]; then
    echo "response is not audio"; rm -f "$tmp"; return 1
  fi
  mv "$tmp" "$2"
}

TOTAL_CHARS=0
FAILED=0
IDS=$(echo "$CLIPS" | jq -r '.[].id')

for id in $IDS; do
  text=$(echo "$CLIPS" | jq -r --arg id "$id" '.[] | select(.id == $id) | .text')
  sha=$(clip_sha "$text")
  file="audio/$id.mp3"
  current=$(jq -r --arg id "$id" '.clips[$id].sha // ""' "$MANIFEST")
  if [ "$current" = "$sha" ] && [ -s "$ROOT/$file" ]; then
    log_action "narration" "$id" "skipped" "unchanged"
    continue
  fi
  TOTAL_CHARS=$(( TOTAL_CHARS + ${#text} ))
  if $DRY_RUN; then
    log_action "narration" "$id" "would-generate" "${#text} characters"
    continue
  fi
  if err=$(synthesize "$text" "$ROOT/$file"); then
    jq --arg id "$id" --arg file "$file" --arg sha "$sha" --argjson chars "${#text}" \
      '.clips[$id] = {file: $file, sha: $sha, chars: $chars}' "$MANIFEST" > "$MANIFEST.tmp" && mv "$MANIFEST.tmp" "$MANIFEST"
    log_action "narration" "$id" "generated" "${#text} characters"
  else
    FAILED=$(( FAILED + 1 ))
    log_error "narration $id failed: $err"
  fi
done

# Remove clips that no longer exist in the scripts.
for stale in $(jq -r '.clips | keys[]' "$MANIFEST"); do
  if ! grep -qx "$stale" <<< "$IDS"; then
    if $DRY_RUN; then
      log_action "narration" "$stale" "would-remove" "no longer in the scripts"
    else
      rm -f "$OUT_DIR/$stale.mp3"
      jq --arg id "$stale" 'del(.clips[$id])' "$MANIFEST" > "$MANIFEST.tmp" && mv "$MANIFEST.tmp" "$MANIFEST"
      log_action "narration" "$stale" "removed" "no longer in the scripts"
    fi
  fi
done

if ! $DRY_RUN; then
  jq --arg v "$VOICE_ID" --arg m "$MODEL_ID" '.voice_id = $v | .model_id = $m' "$MANIFEST" > "$MANIFEST.tmp" && mv "$MANIFEST.tmp" "$MANIFEST"
fi

log_info "Characters to synthesize this run: $TOTAL_CHARS"
log_summary
[ "$FAILED" -eq 0 ] || exit 1
