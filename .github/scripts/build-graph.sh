#!/usr/bin/env bash
set -euo pipefail

# Builds the integrated network graph (graph.json) by joining repos.json and
# content.json into a single denormalized view the site can fetch in one request.
#
# Usage: ./build-graph.sh <config-dir> [output-file]
#
# Output shape:
#   {
#     "generated_from": ["repos.json", "content.json"],
#     "nodes":    [ { pillar, title, color, icon, description, scope, page, repo, connects_to[] } ],
#     "edges":    [ { from, to } ],   # pillar -> pillar, derived from connects_to
#     "journeys": [ { name, persona, narrative, flow[] } ]
#   }
#
# Idempotent: re-running with unchanged config produces byte-identical output.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib-log.sh"

CONFIG_DIR="${1:?Usage: build-graph.sh <config-dir> [output-file]}"
REPOS_FILE="$CONFIG_DIR/repos.json"
CONTENT_FILE="$CONFIG_DIR/content.json"
# Default output: repo root (config dir is .github/config) so the site can fetch('graph.json').
GRAPH_OUT="${2:-$CONFIG_DIR/../../graph.json}"

log_init "build-graph"

for f in "$REPOS_FILE" "$CONTENT_FILE"; do
  if [ ! -f "$f" ]; then
    log_error "Required config not found: $f"
    exit 1
  fi
  if ! jq empty "$f" 2>/dev/null; then
    log_error "Invalid JSON: $f"
    exit 1
  fi
done

log_info "Joining repos.json + content.json into network graph..."

# Build the graph with jq. Edges are pillar->pillar, mapping connects_to repo
# names through a name->pillar lookup so the site can key everything by pillar.
GRAPH=$(jq -n \
  --slurpfile repos "$REPOS_FILE" \
  --slurpfile content "$CONTENT_FILE" '
  ($repos[0]) as $r
  | ($content[0]) as $c
  | ($r.repos | map({ (.name): .pillar }) | add) as $name2pillar
  | {
      generated_from: ["repos.json", "content.json"],
      nodes: [
        $r.repos[]
        | select(.role != "hub")
        | {
            pillar: .pillar,
            title: ((.pillar[0:1] | ascii_upcase) + .pillar[1:]),
            color: .color,
            icon: .icon,
            description: .description,
            scope: .scope,
            page: (.pillar + ".html"),
            repo: .name,
            connects_to: [ (.connects_to // [])[] | $name2pillar[.] | select(. != null) ]
          }
      ],
      edges: [
        $r.repos[]
        | select(.role != "hub")
        | . as $repo
        | ($repo.connects_to // [])[]
        | ($name2pillar[.]) as $to
        | select($to != null)
        | { from: $repo.pillar, to: $to }
      ],
      journeys: ($c.cross_pillar_stories // [])
    }
') || { log_error "jq join failed"; exit 1; }

# Write atomically and report whether anything changed (idempotency signal).
printf '%s\n' "$GRAPH" > "$GRAPH_OUT.tmp"
if [ -f "$GRAPH_OUT" ] && cmp -s "$GRAPH_OUT.tmp" "$GRAPH_OUT"; then
  rm -f "$GRAPH_OUT.tmp"
  log_success "graph.json already up to date ($GRAPH_OUT)"
else
  mv "$GRAPH_OUT.tmp" "$GRAPH_OUT"
  log_action "build-graph" "$GRAPH_OUT" "written"
fi

NODE_COUNT=$(printf '%s' "$GRAPH" | jq '.nodes | length')
EDGE_COUNT=$(printf '%s' "$GRAPH" | jq '.edges | length')
JOURNEY_COUNT=$(printf '%s' "$GRAPH" | jq '.journeys | length')
log_info "Graph: $NODE_COUNT nodes, $EDGE_COUNT edges, $JOURNEY_COUNT journeys"

log_summary
