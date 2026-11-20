#!/usr/bin/env bash
# Runs the 2x2 test: ADHD-STE {off,on} x Concise {off,on}, N replicates each.
# Measures the rules file of this repo (../ADHD-STE.md), not the installed copy.
# Usage: scripts/run-matrix.sh [N] [outdir]
#   N       replicates per cell (default: 3)
#   outdir  output directory (default: runs/<UTC timestamp>, a new directory
#           for each experiment). The script does not start when outdir holds
#           run files, a manifest or a failed/ directory of an earlier run.
#
# Output in outdir:
#   meta.json      the parameters of the experiment
#   manifest.json  one record per run of this experiment: file, cell, exit
#                  status, ok, reason. summarize.py and ste-lint.py read only
#                  the files that the manifest marks ok.
#   adhd-<off|on>_concise-<off|on>_rep<i>.json   the runs that passed
#   failed/        output and stderr of the runs that failed or were stopped
#
# Environment:
#   MODEL            model for the paid runs (default: claude-fable-5-2)
#   RULES            rules file to test (default: ADHD-STE.md of this checkout)
#   CELLS            cells to run, as adhd:concise (default: "off:off off:on on:off on:on")
#   EFFORT           optional effort level, passed as --effort (default: CLI default)
#   JOBS             parallel runs (default: 3)
#   AUTH_MODE        auto | isolated | project (default: auto), see below
#   SKIP_SELF_CHECK  set to 1 to skip the two cheap calls that check each condition
#   CHECK_MODEL      model for the self-check (default: claude-haiku-5-5)
#   CHECK_ONLY       set to 1 to stop after the self-check (two cheap calls, no paid run,
#                    nothing written to outdir)
#
# Isolation. Claude Code keys its macOS Keychain login to the config directory,
# so a fresh CLAUDE_CONFIG_DIR is "Not logged in" unless the environment holds a
# credential. Every mode runs from an empty temp directory under ~/.cache/adhd-ste with MCP servers,
# skills, auto memory and session files off. No mode writes into the real config
# directory.
#   isolated  Needs CLAUDE_CODE_OAUTH_TOKEN (from `claude setup-token`) or
#             ANTHROPIC_API_KEY. Uses a temp CLAUDE_CONFIG_DIR that holds only
#             CLAUDE.md (with or without `@ADHD-STE.md`) and the rules file.
#             Nothing of the operator's config loads. auto picks this mode when
#             one of the two variables is set.
#   project   Keychain login. Reads the real config dir for auth only: user
#             settings, hooks, plugins and the user CLAUDE.md are excluded with
#             --setting-sources project. The rules load as the CLAUDE.md of the
#             temp working directory (inlined, no import). Writes nothing to
#             ~/.claude. auto picks this mode when no credential variable is set.
set -euo pipefail

N="${1:-3}"
OUT="${2:-runs/$(date -u +%Y%m%dT%H%M%SZ)-$$}"
MODEL="${MODEL:-claude-fable-5-2}"
EFFORT="${EFFORT:-}"
JOBS="${JOBS:-3}"
AUTH_MODE="${AUTH_MODE:-auto}"
CHECK_MODEL="${CHECK_MODEL:-claude-haiku-5-5}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RULES="${RULES:-$SCRIPT_DIR/../ADHD-STE.md}"
PROMPT_FILE="$SCRIPT_DIR/prompt.txt"
CHECK_PROMPT='Your loaded instructions name one exact phrase that the reader says to turn the output style off for the session. Reply with only that phrase. Do not use tools. If no loaded instruction names such a phrase, reply NONE.'
CHECK_PHRASE='normal mode'

die() { echo "run-matrix: $*" >&2; exit 1; }

command -v claude >/dev/null || die "claude CLI not found"
command -v jq >/dev/null || die "jq not found"
[ -f "$RULES" ] || die "$RULES not found"
[ -f "$PROMPT_FILE" ] || die "$PROMPT_FILE not found"
case "$N" in ''|*[!0-9]*|0) die "N must be a positive integer, got '$N'";; esac
case "$JOBS" in ''|*[!0-9]*|0) die "JOBS must be a positive integer, got '$JOBS'";; esac

if [ "$AUTH_MODE" = auto ]; then
  if [ -n "${CLAUDE_CODE_OAUTH_TOKEN:-}${ANTHROPIC_API_KEY:-}" ]; then AUTH_MODE=isolated; else AUTH_MODE=project; fi
fi
case "$AUTH_MODE" in
  isolated)
    [ -n "${CLAUDE_CODE_OAUTH_TOKEN:-}${ANTHROPIC_API_KEY:-}" ] ||
      die "AUTH_MODE=isolated needs CLAUDE_CODE_OAUTH_TOKEN (run: claude setup-token) or ANTHROPIC_API_KEY" ;;
  project) ;;
  *) die "unknown AUTH_MODE '$AUTH_MODE' (auto, isolated, project)" ;;
esac

# An output directory belongs to one experiment. Files of an earlier run must
# not mix with this one: the reports count every run file that they find.
case "$OUT" in /*) ;; *) OUT="$PWD/$OUT" ;; esac
OUT="${OUT%/}"
# The lock comes before the check of the contents, so two runs cannot both pass
# the check and then write the same files. mkdir is atomic. CHECK_ONLY writes
# nothing, so it takes no lock.
LOCKED=0
MADE_OUT=0  # 1 when this run made $OUT; a directory of the operator stays
unlock() {
  if [ "$LOCKED" = 1 ]; then rmdir "$OUT/.lock" 2>/dev/null || :; fi
  # rmdir removes only an empty directory: a run that stopped before any output.
  if [ "$MADE_OUT" = 1 ]; then rmdir "$OUT" 2>/dev/null || :; fi
  return 0
}
trap unlock EXIT
if [ "${CHECK_ONLY:-0}" != 1 ]; then
  [ ! -e "$OUT" ] || [ -d "$OUT" ] || die "$OUT exists and is not a directory"
  if [ ! -e "$OUT" ]; then mkdir -p "$OUT"; MADE_OUT=1; fi
  mkdir "$OUT/.lock" 2>/dev/null ||
    die "$OUT is in use by another run (lock $OUT/.lock). If no run is active, remove that directory."
  LOCKED=1
fi
if [ -e "$OUT" ]; then
  [ -d "$OUT" ] || die "$OUT exists and is not a directory"
  used=""
  for f in "$OUT/manifest.json" "$OUT/meta.json" "$OUT/failed" "$OUT"/adhd-*_concise-*_rep*.json; do
    if [ -e "$f" ]; then used="$f"; break; fi
  done
  [ -z "$used" ] ||
    die "$OUT holds output of an earlier run ($(basename "$used")). Use a new directory, or omit outdir: the default is runs/<UTC timestamp>."
fi
# The work dir is not under /tmp: Claude Code 2.1.328 did not load a CLAUDE.md
# from a working directory there, so the "on" cells ran without the rules.
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/adhd-ste"
mkdir -p "$CACHE"
WORK="$(mktemp -d "$CACHE/matrix.XXXXXX")"

# The real config dir. project mode names it in claudeMdExcludes; nothing writes there.
REAL_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
ACTIVE=()       # pids of the runs in flight
ACTIVE_F=()     # their output files, names relative to $OUT
ACTIVE_CELL=()  # their "<adhd> <concise> <rep>"
STARTED=0       # 1 after the manifest exists
COMPLETE=false  # true after every run of the experiment has a record

# record_run <name> <adhd> <concise> <rep> <exit status> <reason>; an empty reason means ok.
# A run that is not ok moves to failed/, with its stderr file.
record_run() {
  local name="$1" file="$1" ok=true
  if [ -n "$6" ]; then
    ok=false; file="failed/$name"
    mkdir -p "$OUT/failed"
    [ ! -e "$OUT/$name" ] || mv -f "$OUT/$name" "$OUT/failed/$name"
    [ ! -e "$OUT/$name.err" ] || mv -f "$OUT/$name.err" "$OUT/failed/$name.err"
  elif [ ! -s "$OUT/$name.err" ]; then
    rm -f "$OUT/$name.err"
  fi
  jq -cn --arg file "$file" --arg adhd "$2" --arg concise "$3" --argjson rep "$4" --argjson status "$5" \
    --argjson ok "$ok" --arg reason "$6" \
    '{file:$file, cell:("adhd-"+$adhd+"_concise-"+$concise), adhd:$adhd, concise:$concise, rep:$rep,
      exit_status:$status, ok:$ok, reason:(if $reason == "" then null else $reason end)}' >> "$WORK/runs.jsonl"
}

# The manifest lists exactly the runs of this experiment. The script writes it
# again after each batch, so a stopped experiment keeps a correct one.
write_manifest() {
  jq -s --argjson complete "$COMPLETE" --argjson n "$N" \
    '{manifest_version:1, complete:$complete, runs_per_cell:$n, runs:.}' "$WORK/runs.jsonl" > "$OUT/manifest.json.tmp" &&
    mv -f "$OUT/manifest.json.tmp" "$OUT/manifest.json"
}

cleanup() {
  local code=$? k
  trap - EXIT INT TERM
  set +eu
  # Stop the runs that are still alive, then record them as failed.
  if [ "${#ACTIVE[@]}" -gt 0 ]; then
    kill "${ACTIVE[@]}" 2>/dev/null
    wait "${ACTIVE[@]}" 2>/dev/null
    if [ "$STARTED" = 1 ]; then
      for k in "${!ACTIVE_F[@]}"; do
        # shellcheck disable=SC2086
        record_run "${ACTIVE_F[$k]}" ${ACTIVE_CELL[$k]} "$code" "interrupted: the script stopped before the run ended"
      done
      write_manifest
    fi
  fi
  rm -rf "$WORK"
  unlock
  exit "$code"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

# One empty working directory and, in isolated mode, one config dir per condition.
mkdir -p "$WORK/wd-off" "$WORK/wd-on" "$WORK/rules"
# One snapshot of the rules and the prompt. Every run and both hashes in
# meta.json use the snapshot, so an edit during the run cannot split them.
SNAP="$WORK/rules/ADHD-STE.md"
cp "$RULES" "$SNAP"
cp "$PROMPT_FILE" "$WORK/prompt.txt"
PROMPT="$(cat "$WORK/prompt.txt")"
case "$AUTH_MODE" in
  isolated)
    mkdir -p "$WORK/cfg-off" "$WORK/cfg-on"
    : > "$WORK/cfg-off/CLAUDE.md"
    printf '@ADHD-STE.md\n' > "$WORK/cfg-on/CLAUDE.md"
    cp "$SNAP" "$WORK/cfg-on/ADHD-STE.md"
    ;;
  project)
    cp "$SNAP" "$WORK/wd-on/CLAUDE.md"
    ;;
esac

# Variables of a parent Claude Code session must not reach the runs.
CLEAN_ENV=(env -u CLAUDECODE -u CLAUDE_CODE_CHILD_SESSION -u CLAUDE_CODE_SESSION_ID
  -u CLAUDE_CODE_ENTRYPOINT -u CLAUDE_CODE_MESSAGING_TOKEN -u CLAUDE_CODE_MESSAGING_SOCKET
  -u CLAUDE_CODE_CHILD_NOTES_DIR -u CLAUDE_CODE_SESSION_ATTENDED -u CLAUDE_CODE_EXECPATH
  -u CLAUDE_PID -u CLAUDE_EFFORT -u CLAUDE_PLUGIN_DATA CLAUDE_CODE_DISABLE_AUTO_MEMORY=1)

# run_one <adhd> <concise> <model> <prompt> <outfile>; stderr goes to <outfile>.err
# Call it in a subshell or with `&`: it execs claude, so the job is the claude
# process itself and cleanup can stop it.
run_one() {
  local adhd="$1" concise="$2" model="$3" prompt="$4" f="$5"
  local style=default; [ "$concise" = on ] && style=Concise
  local settings args=(--model "$model" --output-format json --strict-mcp-config
    --disable-slash-commands --no-session-persistence)
  local envv=("${CLEAN_ENV[@]}")
  case "$AUTH_MODE" in
    isolated)
      settings="$(jq -cn --arg s "$style" '{outputStyle:$s}')"
      envv+=("CLAUDE_CONFIG_DIR=$WORK/cfg-$adhd") ;;
    project)
      settings="$(jq -cn --arg s "$style" --arg d "$REAL_DIR" \
        '{outputStyle:$s, claudeMdExcludes:[$d+"/CLAUDE.md", $d+"/rules/**"]}')"
      args+=(--setting-sources project) ;;
  esac
  [ -z "$EFFORT" ] || args+=(--effort "$EFFORT")
  cd "$WORK/wd-$adhd"
  exec "${envv[@]}" claude -p "$prompt" "${args[@]}" --settings "$settings" < /dev/null > "$f" 2> "$f.err"
}

# check_run <outfile> <exit status>; prints the reason when the run failed
check_run() {
  local f="$1" status="$2" why=""
  if [ "$status" != 0 ]; then why="exit status $status"
  elif [ ! -s "$f" ]; then why="empty output"
  elif ! jq -e 'type == "object"' "$f" >/dev/null 2>&1; then why="invalid JSON"
  elif [ "$(jq -r '.is_error // false' "$f")" != false ]; then why="is_error"
  elif [ "$(jq -r '.result | type' "$f")" != string ]; then why="no result field"
  elif [ -z "$(jq -r '.result' "$f" | tr -d '[:space:]')" ]; then why="empty result"
  fi
  [ -z "$why" ] && return 0
  if [ "$why" = "empty result" ]; then echo "$why"; return 1; fi
  local detail; detail="$(jq -r '.result // empty' "$f" 2>/dev/null | head -c 200)"
  [ -n "$detail" ] || detail="$(head -c 200 "$f.err" 2>/dev/null | tr '\n' ' ')"
  echo "$why${detail:+: $detail}"
  return 1
}

sha() { if command -v shasum >/dev/null; then shasum -a 256 "$1"; else sha256sum "$1"; fi | cut -d' ' -f1; }

echo "model $MODEL, auth mode $AUTH_MODE, $N runs per cell, $JOBS parallel"

# Self-check: the "on" condition must know the phrase and the "off" condition must not.
if [ "${SKIP_SELF_CHECK:-0}" != 1 ]; then
  for adhd in off on; do
    f="$WORK/check-$adhd.json"; status=0
    # A background job and `wait`, so that INT and TERM stop the call at once.
    run_one "$adhd" off "$CHECK_MODEL" "$CHECK_PROMPT" "$f" &
    ACTIVE=("$!"); wait "$!" || status=$?; ACTIVE=()
    why="$(check_run "$f" "$status")" || die "self-check adhd-$adhd failed: $why"
    answer="$(jq -r '.result' "$f")"
    if printf '%s' "$answer" | grep -qi "$CHECK_PHRASE"; then knows=on; else knows=off; fi
    [ "$knows" = "$adhd" ] ||
      die "self-check adhd-$adhd: the rules file is $knows in this condition (answer: $(printf '%s' "$answer" | head -c 200)). No paid run started."
    echo "self-check adhd-$adhd ok: $(printf '%s' "$answer" | head -c 60)"
  done
fi
if [ "${CHECK_ONLY:-0}" = 1 ]; then echo "CHECK_ONLY=1: no paid run started"; exit 0; fi

mkdir -p "$OUT"
jq -n --arg model "$MODEL" --arg effort "$EFFORT" --arg version "$(claude --version 2>&1 | head -1)" \
  --arg date "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --argjson n "$N" --argjson jobs "$JOBS" \
  --arg auth_mode "$AUTH_MODE" --arg rules_sha256 "$(sha "$SNAP")" --arg prompt_sha256 "$(sha "$WORK/prompt.txt")" \
  --arg check_model "$([ "${SKIP_SELF_CHECK:-0}" = 1 ] && echo skipped || echo "$CHECK_MODEL")" \
  '{model:$model, effort:(if $effort == "" then null else $effort end), claude_version:$version,
    date:$date, n:$n, jobs:$jobs, auth_mode:$auth_mode, self_check_model:$check_model,
    rules_file:"ADHD-STE.md", rules_sha256:$rules_sha256, prompt_sha256:$prompt_sha256}' > "$OUT/meta.json"
: > "$WORK/runs.jsonl"
write_manifest
STARTED=1
echo "output directory: $OUT/"

FAILED=()
run_cell() {
  local adhd="$1" concise="$2" i name k status why
  for i in $(seq 1 "$N"); do
    name="adhd-${adhd}_concise-${concise}_rep${i}.json"
    echo "running $name"
    run_one "$adhd" "$concise" "$MODEL" "$PROMPT" "$OUT/$name" &
    ACTIVE+=("$!"); ACTIVE_F+=("$name"); ACTIVE_CELL+=("$adhd $concise $i")
    # Bash 3.2 has no `wait -n`, so the runs go in batches of $JOBS.
    if [ "${#ACTIVE[@]}" -ge "$JOBS" ] || [ "$i" -eq "$N" ]; then
      for k in "${!ACTIVE[@]}"; do
        status=0; wait "${ACTIVE[$k]}" || status=$?
        why="$(check_run "$OUT/${ACTIVE_F[$k]}" "$status")" || FAILED+=("${ACTIVE_F[$k]}: $why")
        # shellcheck disable=SC2086
        record_run "${ACTIVE_F[$k]}" ${ACTIVE_CELL[$k]} "$status" "$why"
        # A run with a record leaves the lists, so cleanup does not record it again.
        unset "ACTIVE[$k]" "ACTIVE_F[$k]" "ACTIVE_CELL[$k]"
      done
      ACTIVE=(); ACTIVE_F=(); ACTIVE_CELL=()
      write_manifest
    fi
  done
}

CELLS="${CELLS:-off:off off:on on:off on:on}"
NCELLS=0
for cell in $CELLS; do
  case "$cell" in off:off|off:on|on:off|on:on) ;; *) die "CELLS: bad cell '$cell' (use adhd:concise, for example on:off)";; esac
  run_cell "${cell%%:*}" "${cell##*:}"; NCELLS=$((NCELLS + 1))
done
COMPLETE=true
write_manifest

total=$((NCELLS * N))
if [ "${#FAILED[@]}" -gt 0 ]; then
  echo "FAILED: ${#FAILED[@]} of $total runs. Output and stderr of each one are in $OUT/failed/; the reports skip them." >&2
  printf '  %s\n' "${FAILED[@]}" >&2
  echo "next: python3 $SCRIPT_DIR/summarize.py $OUT" >&2
  exit 1
fi
echo "done: $total runs in $OUT/"
echo "next: python3 $SCRIPT_DIR/summarize.py $OUT"
