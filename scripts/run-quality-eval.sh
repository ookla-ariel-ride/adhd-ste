#!/usr/bin/env bash
# Runs the quality eval of ayghri/i-have-adhd (14 cases, blind judge, rubric,
# release gate) on three conditions:
#   baseline    the bare task prompt
#   candidate   this repo's ADHD-STE.md
#   comparator  upstream skills/i-have-adhd/SKILL.md
# The candidate-minus-comparator numbers answer: do the STE rules add anything
# over i-have-adhd alone?
#
# Usage: scripts/run-quality-eval.sh [--plan] [--yes] [--trials N] [--budget USD]
#                                    [--model MODEL] [--judge-model MODEL | --judge-codex] [--cases ID,ID] [--cases-file PATH] [--out DIR]
#   --plan        print the plan and the expected cost; no model calls
#   --yes         spend without the interactive confirmation
#   --trials N    trials per case (default: 3)
#   --budget USD  hard cap of the generation cost per condition (default: 5, max: 25)
#   --model MODEL model for generation and judge (default: claude-fable-5-2)
#   --judge-model MODEL  model for the judge only (default: the same as --model)
#   --judge-codex  use the Codex CLI as the judge, with its default model. It has
#                  no cost cap and reports no cost; it uses your Codex plan.
#   --cases ID,ID  run only these case ids (default: all cases)
#   --cases-file PATH  cases file in the upstream format (default: upstream's
#                  evals/cases.jsonl); evals/heldout-cases.jsonl is a second set
#                  that the rules file never saw
#   --out DIR     output directory (default: runs/quality-eval/<UTC timestamp>,
#                 a new directory for each experiment; runs/ is gitignored)
#
# Environment:
#   UPSTREAM_SHA       upstream commit to use (default: the pin below)
#   UPSTREAM_REPO      upstream git URL
#   CACHE_DIR          where the upstream checkout lives (default: ~/.cache/adhd-ste)
#   PYTHON             Python 3.10 or later; upstream does not run on 3.9
#   COMPARATOR         rules file of the third condition (default: upstream SKILL.md)
#   JUDGE_CALL_BUDGET  hard cap of one judge call in USD (default: 0.50)
#
# Limits of the upstream harness:
#   - It puts the rules file into the prompt inside <response_style> tags. It
#     does not load the file through CLAUDE.md as an install does.
#   - The release gate of `score` compares candidate with baseline only. This
#     script prints the candidate-minus-comparator deltas itself.
#
# Resume. Upstream resumes on (case, trial, condition, runner) only, so old
# responses can pass for new ones after the rules or the model change. This
# script records model, trials, upstream commit and the sha256 of the candidate,
# comparator and cases files in meta.json. It continues in an existing --out DIR
# only when all of these match, and it never writes meta.json a second time.
# After a failure, run the same command again with --out DIR.
#
# Cost. Each generation and judge call gets one attempt (--retries 0), so the
# number of billable calls is at most the number in the plan. The maximum in
# the plan is the sum of the caps that the claude CLI gets (--max-budget-usd).
# The CLI enforces a cap on its own cost estimate and checks it between API
# requests, so one request can pass its cap.
set -euo pipefail

UPSTREAM_SHA="${UPSTREAM_SHA:-1ecea1993b7fce257ffbd686c070948b5e07eda6}"
UPSTREAM_REPO="${UPSTREAM_REPO:-https://github.com/ayghri/i-have-adhd}"
CACHE_DIR="${CACHE_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/adhd-ste}"
JUDGE_CALL_BUDGET="${JUDGE_CALL_BUDGET:-0.50}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$SCRIPT_DIR/.." && pwd)"
RULES="$REPO/ADHD-STE.md"
# Costs per call that this project measured on claude-fable-5-2 in November 2026
# (results/RESULTS.md): the mean of the three conditions, and one judge call.
GEN_COST_PER_ROW=0.152
JUDGE_COST_PER_GROUP=0.131

ONLY=""; PLAN=0; YES=0; TRIALS=3; BUDGET=5; MODEL="${MODEL:-claude-fable-5-2}"; JUDGE_MODEL=""; JUDGE_RUNNER=claude-judge; CASES_FILE=""; OUT=""

die() { echo "run-quality-eval: $*" >&2; exit 1; }

while [ $# -gt 0 ]; do
  case "$1" in
    --plan) PLAN=1 ;;
    --yes) YES=1 ;;
    --trials) TRIALS="${2:?--trials needs a value}"; shift ;;
    --budget) BUDGET="${2:?--budget needs a value}"; shift ;;
    --model) MODEL="${2:?--model needs a value}"; shift ;;
    --judge-model) JUDGE_MODEL="${2:?--judge-model needs a value}"; shift ;;
    --judge-codex) JUDGE_RUNNER=codex; JUDGE_MODEL="codex-cli" ;;
    --cases-file) CASES_FILE="${2:?--cases-file needs a value}"; shift ;;
    --cases) ONLY="${2:?--cases needs a value}"; shift ;;
    --out) OUT="${2:?--out needs a value}"; shift ;;
    -h|--help) sed -n '2,/^set -euo/p' "$0" | sed '$d' | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) die "unknown argument '$1' (see --help)" ;;
  esac
  shift
done
case "$TRIALS" in ''|*[!0-9]*|0) die "--trials must be a positive integer, got '$TRIALS'";; esac
[[ "$BUDGET" =~ ^[0-9]+(\.[0-9]+)?$ ]] || die "--budget must be a number, got '$BUDGET'"
[[ "$UPSTREAM_SHA" =~ ^[0-9a-f]{40}$ ]] || die "UPSTREAM_SHA must be a full 40-character commit SHA"
[ -f "$RULES" ] || die "$RULES not found"
command -v git >/dev/null || die "git not found"
command -v jq >/dev/null || die "jq not found"

# Upstream uses `int | None` annotations, which need Python 3.10.
find_python() {
  local p
  for p in ${PYTHON:+"$PYTHON"} python3 python3.14 python3.13 python3.12 python3.11 python3.10; do
    if command -v "$p" >/dev/null && "$p" -c 'import sys; sys.exit(sys.version_info < (3, 10))' 2>/dev/null; then
      echo "$p"; return 0
    fi
  done
  return 1
}
PY="$(find_python)" || die "Python 3.10 or later not found. Install one (for example: brew install python@3.12) or set PYTHON=/path/to/python3."

# Checkout of upstream at the pinned commit, outside this repo.
UP="$CACHE_DIR/i-have-adhd-$UPSTREAM_SHA"
if [ "$(git -C "$UP" rev-parse HEAD 2>/dev/null || true)" != "$UPSTREAM_SHA" ]; then
  echo "fetching $UPSTREAM_REPO at $UPSTREAM_SHA into $UP" >&2
  rm -rf "$UP"
  mkdir -p "$UP"
  git -C "$UP" init -q
  git -C "$UP" fetch -q --depth 1 "$UPSTREAM_REPO" "$UPSTREAM_SHA"
  git -C "$UP" checkout -q --detach FETCH_HEAD
  [ "$(git -C "$UP" rev-parse HEAD)" = "$UPSTREAM_SHA" ] || die "checkout of $UPSTREAM_SHA failed"
fi
[ -z "$(git -C "$UP" status --porcelain)" ] || die "$UP has local changes; remove the directory and run again"
COMPARATOR="${COMPARATOR:-$UP/skills/i-have-adhd/SKILL.md}"
case "$COMPARATOR" in /*) ;; *) COMPARATOR="$PWD/$COMPARATOR" ;; esac
[ -f "$COMPARATOR" ] || die "$COMPARATOR not found in upstream"
CASES="$UP/evals/cases.jsonl"
if [ -n "$CASES_FILE" ]; then case "$CASES_FILE" in /*) CASES="$CASES_FILE" ;; *) CASES="$PWD/$CASES_FILE" ;; esac; fi
[ -f "$CASES" ] || die "$CASES not found"

sha() { if command -v shasum >/dev/null; then shasum -a 256 "$1"; else sha256sum "$1"; fi | cut -d' ' -f1; }

# The fields that identify the experiment. Responses and scores of one output
# directory are valid for exactly one value of this object.
# A snapshot of the candidate rules. The hash in meta.json and the generation
# both use it, so an edit of ADHD-STE.md during the run cannot split them.
SNAP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/adhd-ste-qe.XXXXXX")"
LOCKED=0
MADE_OUT=0  # 1 when this run made $OUT; a directory of the operator stays
cleanup() {
  local code=$?
  trap - EXIT INT TERM
  set +e
  rm -rf "$SNAP_DIR"
  if [ "$LOCKED" = 1 ]; then rmdir "$OUT/.lock" 2>/dev/null; fi
  # rmdir removes only an empty directory: a run that stopped before any output.
  if [ "$MADE_OUT" = 1 ]; then rmdir "$OUT" 2>/dev/null; fi
  exit "$code"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
if [ -n "$ONLY" ]; then
  # A subset of the upstream cases, in upstream order. Its hash goes in meta.json,
  # so a resume with another subset stops.
  SUBSET="$SNAP_DIR/cases.jsonl"
  jq -c --arg ids "$ONLY" '($ids | split(",")) as $w | select(.id as $i | $w | index($i))' "$CASES" > "$SUBSET"
  for id in $(printf '%s' "$ONLY" | tr ',' ' '); do
    jq -e --arg id "$id" 'select(.id == $id)' "$SUBSET" >/dev/null || die "--cases: no case '$id' in $CASES"
  done
  CASES="$SUBSET"
fi
CANDIDATE="$SNAP_DIR/ADHD-STE.md"
cp "$RULES" "$CANDIDATE"

[ -n "$JUDGE_MODEL" ] || JUDGE_MODEL="$MODEL"
IDENTITY="$(jq -cnS --arg model "$MODEL" --arg judge_model "$JUDGE_MODEL" --argjson trials "$TRIALS" --arg upstream_sha "$UPSTREAM_SHA" \
  --arg candidate_sha256 "$(sha "$CANDIDATE")" --arg comparator_sha256 "$(sha "$COMPARATOR")" \
  --arg cases_sha256 "$(sha "$CASES")" \
  '{model:$model, judge_model:$judge_model, trials:$trials, upstream_sha:$upstream_sha, candidate_sha256:$candidate_sha256,
    comparator_sha256:$comparator_sha256, cases_sha256:$cases_sha256}')"

[ -n "$OUT" ] || OUT="$REPO/runs/quality-eval/$(date -u +%Y%m%dT%H%M%SZ)-$$"
case "$OUT" in /*) ;; *) OUT="$PWD/$OUT" ;; esac
OUT="${OUT%/}"
# The lock comes before the identity check, so two invocations (new or resume)
# cannot both pass the check and then share the files. --plan writes nothing.
if [ "$PLAN" != 1 ]; then
  [ ! -e "$OUT" ] || [ -d "$OUT" ] || die "$OUT exists and is not a directory"
  if [ ! -e "$OUT" ]; then mkdir -p "$OUT"; MADE_OUT=1; fi
  mkdir "$OUT/.lock" 2>/dev/null ||
    die "$OUT is in use by another run (lock $OUT/.lock). If no run is active, remove that directory."
  LOCKED=1
fi
RESUME=0
if [ -e "$OUT" ]; then
  [ -d "$OUT" ] || die "$OUT exists and is not a directory"
  if [ -f "$OUT/meta.json" ]; then
    RECORDED="$(jq -cS '{model, judge_model: (.judge_model // .model), trials, upstream_sha, candidate_sha256, comparator_sha256, cases_sha256}' "$OUT/meta.json")" ||
      die "$OUT/meta.json is not valid JSON. Use a new --out directory."
    if [ "$RECORDED" != "$IDENTITY" ]; then
      echo "run-quality-eval: $OUT holds a different experiment. Fields that differ (recorded -> now):" >&2
      jq -rn --argjson old "$RECORDED" --argjson new "$IDENTITY" \
        '$new | keys[] | select($old[.] != $new[.]) | "  \(.): \($old[.] | tojson) -> \($new[.] | tojson)"' >&2
      die "no resume: the old responses and scores do not belong to this experiment. Use a new --out directory, or omit --out. No model call made."
    fi
    RESUME=1
  elif [ -n "$(ls -A "$OUT" | grep -v '^\.lock$')" ]; then
    die "$OUT is not empty and has no meta.json, so its contents cannot be matched to this experiment. Use a new --out directory, or omit --out. No model call made."
  fi
fi

run_evals() { "$PY" "$UP/scripts/run_evals.py" "$@"; }

run_evals validate --cases "$CASES" >&2
ROWS="$(run_evals plan --cases "$CASES" --trials "$TRIALS" --include-comparator | wc -l | tr -d ' ')"
[ "$ROWS" -gt 0 ] && [ $((ROWS % 3)) -eq 0 ] || die "unexpected plan from upstream: $ROWS rows"
GROUPS_N=$((ROWS / 3))
calc() { awk "BEGIN { printf \"%.2f\", $1 }"; }
# A judge group here holds three responses, upstream's recorded cost is for two.
if [ "$JUDGE_RUNNER" = codex ]; then JUDGE_EXPECTED=0; else JUDGE_EXPECTED="$(calc "$GROUPS_N * $JUDGE_COST_PER_GROUP")"; fi
EXPECTED="$(calc "$ROWS * $GEN_COST_PER_ROW + $JUDGE_EXPECTED")"
MAXIMUM="$(calc "3 * $BUDGET + $GROUPS_N * $JUDGE_CALL_BUDGET")"

cat <<EOF
Plan
  upstream     $UPSTREAM_REPO @ $UPSTREAM_SHA
  checkout     $UP
  model        $MODEL (generation), $JUDGE_MODEL (judge), $(claude --version 2>/dev/null | head -1 || echo "claude CLI not found")
  conditions   baseline   = bare task prompt
               candidate  = $RULES
               comparator = $COMPARATOR
  calls        $ROWS generation ($((GROUPS_N / TRIALS)) cases x $TRIALS trials x 3 conditions) + $GROUPS_N judge
  budget       \$$BUDGET per condition for generation, \$$JUDGE_CALL_BUDGET per judge call
  attempts     one per call (--retries 0 for generation and judge): a failed call does not repeat
  output       $OUT/ (responses.jsonl, scores.jsonl, score.json, measure.json, meta.json)
               $([ "$RESUME" = 1 ] && echo "resume: meta.json there matches this experiment; finished calls do not repeat" || echo "new directory")
Cost
  expected     about \$$EXPECTED (from this project's measured cost per call on claude-fable-5-2; another model changes it. A Codex judge adds no Claude cost)
  maximum      \$$MAXIMUM for this invocation = 3 conditions x \$$BUDGET generation cap + $GROUPS_N judge calls x \$$JUDGE_CALL_BUDGET cap
               How it is computed: every permitted attempt at its cap. One attempt per call, so at most
               $ROWS generation calls (each capped at what is left of its condition's \$$BUDGET) and
               $GROUPS_N judge calls. Cost of a failed call counts inside the same caps.
               Limit: the claude CLI enforces each cap (--max-budget-usd) on its own cost estimate and
               checks it between API requests, so one request can pass its cap. A later
               invocation (resume) has its own maximum.
Steps
  1. run_evals.py run --condition baseline
  2. run_evals.py run --condition candidate --condition-skill ADHD-STE.md
  3. run_evals.py run --condition comparator --condition-skill SKILL.md
  4. judge.py --conditions baseline candidate comparator (blind, one call per case and trial)
  5. run_evals.py score (release gate: candidate against baseline)
  6. run_evals.py measure (tokens, cost, length)
EOF

if [ "$PLAN" = 1 ]; then
  echo "plan only: no model call made"
  exit 0
fi

command -v claude >/dev/null || die "claude CLI not found"
if [ "$YES" != 1 ]; then
  [ -t 0 ] || die "refusing to spend without --yes (stdin is not a terminal)"
  printf 'Spend up to $%s in this invocation (3 x $%s generation caps + %s x $%s judge caps, one attempt per call)? Type yes to continue: ' \
    "$MAXIMUM" "$BUDGET" "$GROUPS_N" "$JUDGE_CALL_BUDGET"
  read -r answer
  [ "$answer" = yes ] || die "stopped: no model call made"
fi

mkdir -p "$OUT"
RUNNERS="$OUT/runners.json"
RESPONSES="$OUT/responses.jsonl"
SCORES="$OUT/scores.jsonl"

# Upstream's claude runner with the model replaced, and a judge runner that
# adds a cost cap per call (judge.py has no budget option).
jq --arg model "$MODEL" --arg judge_model "$JUDGE_MODEL" --arg cap "$JUDGE_CALL_BUDGET" '
  (.claude.command | index("--model")) as $i
  | if $i == null then error("upstream claude runner has no --model") else . end
  | .claude.command[$i + 1] = $model
  | {claude: .claude, codex: .codex,
     "claude-judge": (.claude | del(.budget_flag) | .command[$i + 1] = $judge_model | .command = [.command[0], "--max-budget-usd", $cap] + .command[1:])}
' "$UP/evals/runners.example.json" > "$RUNNERS"

# meta.json is the manifest of the experiment. A resume keeps the recorded one.
if [ "$RESUME" = 1 ]; then
  echo "resume in $OUT (meta.json matches)"
else
  jq -n --argjson identity "$IDENTITY" --arg version "$(claude --version 2>&1 | head -1)" \
    --arg date "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --arg budget "$BUDGET" --arg judge_cap "$JUDGE_CALL_BUDGET" \
    --arg upstream "$UPSTREAM_REPO" \
    '$identity + {claude_version:$version, date:$date, budget_usd_per_condition:($budget|tonumber),
      judge_call_cap_usd:($judge_cap|tonumber), retries:0, upstream:$upstream, candidate:"ADHD-STE.md",
      comparator:"skills/i-have-adhd/SKILL.md"}' > "$OUT/meta.json"
  echo "output directory: $OUT"
fi

run_condition() {
  local condition="$1"; shift
  echo "== generation: $condition"
  run_evals run --cases "$CASES" --runner claude --runner-config "$RUNNERS" --condition "$condition" "$@" \
    --trials "$TRIALS" --retries 0 --budget-usd "$BUDGET" --output "$RESPONSES" ||
    die "generation of $condition stopped (status $?). Budget used up or provider error. To resume, run the same command again with --out $OUT"
}
run_condition baseline
run_condition candidate --condition-skill "$CANDIDATE"
run_condition comparator --condition-skill "$COMPARATOR"

echo "== judge"
"$PY" "$UP/scripts/judge.py" --runner "$JUDGE_RUNNER" --cases "$CASES" --runner-config "$RUNNERS" --responses "$RESPONSES" \
  --conditions baseline candidate comparator --retries 0 --output "$SCORES" ||
  die "judge stopped (status $?). To resume, run the same command again with --out $OUT"

echo "== score"
run_evals score "$SCORES" | tee "$OUT/score.json"
echo "== measure"
run_evals measure "$RESPONSES" | tee "$OUT/measure.json"

echo "== candidate (ADHD-STE.md) minus comparator (i-have-adhd SKILL.md)"
jq -r '.conditions as $c
  | $c.candidate | to_entries[] | select(.value | type == "number")
  | select($c.comparator[.key] | type == "number")
  | "\(.key): \(.value) - \($c.comparator[.key]) = \((.value - $c.comparator[.key]) * 1000 | round / 1000)"' "$OUT/score.json"
echo "release gate (candidate against baseline): $(jq -c '.release_gate' "$OUT/score.json")"
