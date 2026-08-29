#!/usr/bin/env bash
# Runs the 2x2 test: ADHD-STE {off,on} x Concise {off,on}, N replicates each.
# Swaps ~/.claude/CLAUDE.md between cells and restores it on exit.
# Usage: scripts/run-matrix.sh [N] [outdir]
set -euo pipefail

N="${1:-3}"
OUT="${2:-runs}"
CLAUDE_MD="$HOME/.claude/CLAUDE.md"
RULES="$HOME/.claude/ADHD-STE.md"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROMPT="$(cat "$SCRIPT_DIR/prompt.txt")"

command -v claude >/dev/null || { echo "claude CLI not found" >&2; exit 1; }
command -v jq >/dev/null || { echo "jq not found" >&2; exit 1; }
[ -f "$RULES" ] || { echo "$RULES not found; install the config first" >&2; exit 1; }

mkdir -p "$OUT"
BACKUP="$(mktemp)"
if [ -f "$CLAUDE_MD" ]; then cp "$CLAUDE_MD" "$BACKUP"; else : > "$BACKUP"; fi
trap 'cp "$BACKUP" "$CLAUDE_MD"; rm -f "$BACKUP"; echo "restored $CLAUDE_MD"' EXIT

# CLAUDE.md variants: with and without the import line.
WITH="$(mktemp)"; WITHOUT="$(mktemp)"
grep -v '^@ADHD-STE.md$' "$BACKUP" > "$WITHOUT" || true
{ cat "$WITHOUT"; printf '\n@ADHD-STE.md\n'; } > "$WITH"

run_cell() {
  local adhd="$1" concise="$2"
  if [ "$adhd" = on ]; then cp "$WITH" "$CLAUDE_MD"; else cp "$WITHOUT" "$CLAUDE_MD"; fi
  local style; if [ "$concise" = on ]; then style=Concise; else style=default; fi
  for i in $(seq 1 "$N"); do
    local f="$OUT/adhd-${adhd}_concise-${concise}_rep${i}.json"
    echo "running $f"
    claude -p "$PROMPT" --settings "{\"outputStyle\":\"$style\"}" --output-format json < /dev/null > "$f" 2>/dev/null &
  done
  wait
}

# Cells that share a CLAUDE.md state run back to back so the file is swapped only twice.
run_cell off off
run_cell off on
run_cell on off
run_cell on on

echo "done: $(ls "$OUT"/*.json | wc -l | tr -d ' ') runs in $OUT/"
echo "next: python3 $SCRIPT_DIR/summarize.py $OUT"
