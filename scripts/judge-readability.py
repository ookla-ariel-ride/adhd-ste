#!/usr/bin/env python3
"""Blind readability judge for answers of the quality eval.

The upstream rubric scores correctness, autonomy, actionability, safety, and
concision. It does not ask if a person finds the answer natural to read. This
script asks a judge that one question: it shows the answers to one case and
trial under blind labels and gets a ranking and a tone label for each answer.

Usage:
  scripts/judge-readability.py --cases CASES.jsonl --take RUN_DIR:COND[=NAME],... 
                               [--take ...] --out FILE.jsonl [--judge codex|MODEL]
  scripts/judge-readability.py --summary FILE.jsonl

  --take   a run directory of run-quality-eval.sh and the conditions to take
           from it, each with an optional new name. Example:
             --take runs/quality-eval/h1:baseline,candidate,comparator=upstream
             --take runs/quality-eval/h2:comparator=lite
  --cases  the cases file of the runs, for the request text (repeatable)
  --judge  "codex" (default) uses the Codex CLI. Any other value is a Claude
           model id for `claude -p`.
  --out    one JSON line per case and trial; a rerun skips the judged ones.
"""
import argparse
import collections
import hashlib
import json
import subprocess
import sys
import tempfile

LABELS = "ABCDEFGH"
TONES = ("natural", "stiff", "chatbot")

PROMPT = """You compare answers that different assistants gave to the same request.
Judge only how the answers read for a person: a busy developer who reads fast
and loses focus in long or padded text. Do not judge technical correctness.

For each answer choose one tone:
- "natural": reads like a clear, direct person wrote it.
- "stiff": clipped, robotic, repetitive, or like a manual.
- "chatbot": filler, flattery, hedging, long lead-in, decorative formatting,
  or a closing offer; it sounds like a typical AI assistant.

Then rank the answers from the one that this reader would most prefer to read
and act on, to the one they would least prefer.

Reply with one JSON object and nothing else:
{{"ranking": ["<label>", ...], "tone": {{"<label>": "natural|stiff|chatbot", ...}}, "note": "<one sentence>"}}

REQUEST:
{request}

{answers}
"""


def read_jsonl(path):
    with open(path, encoding="utf-8") as f:
        return [json.loads(line) for line in f if line.strip()]


def labels_for(key, conditions):
    """A stable shuffle per group, so that a label does not reveal a condition."""
    ordered = sorted(conditions)
    labels = list(LABELS[: len(ordered)])
    digest = hashlib.sha256(("readability\0" + "\0".join(map(str, key))).encode()).digest()
    for i in range(len(labels) - 1, 0, -1):
        j = digest[i] % (i + 1)
        labels[i], labels[j] = labels[j], labels[i]
    return dict(zip(ordered, labels))


def call_judge(judge, prompt):
    with tempfile.TemporaryDirectory() as cwd:
        if judge == "codex":
            cmd = ["codex", "exec", "--ephemeral", "--ignore-user-config", "--sandbox", "read-only",
                   "--skip-git-repo-check", "--json"]
            done = subprocess.run(cmd, input=prompt, capture_output=True, text=True, cwd=cwd)
            if done.returncode:
                raise RuntimeError(done.stderr.strip() or done.stdout.strip())
            text = ""
            for line in done.stdout.splitlines():
                try:
                    event = json.loads(line)
                except ValueError:
                    continue
                item = event.get("item") or {}
                if event.get("type") == "item.completed" and item.get("type") == "agent_message":
                    text = item.get("text", "")
            return text
        cmd = ["claude", "--disable-slash-commands", "--print", "--output-format", "json",
               "--no-session-persistence", "--setting-sources", "", "--model", judge, "--tools", ""]
        done = subprocess.run(cmd, input=prompt, capture_output=True, text=True, cwd=cwd)
        if done.returncode:
            raise RuntimeError(done.stderr.strip() or done.stdout.strip())
        return json.loads(done.stdout).get("result", "")


def parse_verdict(text, labels):
    start, end = text.find("{"), text.rfind("}")
    if start < 0 or end < 0:
        raise ValueError("no JSON object in the judge reply")
    verdict = json.loads(text[start : end + 1])
    used = set(labels.values())
    ranking = verdict.get("ranking")
    tone = verdict.get("tone")
    if not isinstance(ranking, list) or set(ranking) != used or len(ranking) != len(used):
        raise ValueError(f"ranking does not name each label once: {ranking}")
    if not isinstance(tone, dict) or set(tone) != used or any(t not in TONES for t in tone.values()):
        raise ValueError(f"tone is not complete or has an unknown value: {tone}")
    return ranking, tone, str(verdict.get("note", ""))


def summary(path):
    rows = read_jsonl(path)
    if not rows:
        sys.exit(f"{path}: no rows")
    ranks = collections.defaultdict(list)
    tones = collections.defaultdict(collections.Counter)
    for row in rows:
        for condition, result in row["conditions"].items():
            ranks[condition].append(result["rank"])
            tones[condition][result["tone"]] += 1
    print(f"{len(rows)} groups judged ({rows[0].get('judge', '?')})\n")
    print("| Condition | Mean rank (1 is best) | Ranked first | Natural | Stiff | Chatbot |")
    print("|---|---:|---:|---:|---:|---:|")
    for condition in sorted(ranks, key=lambda c: sum(ranks[c]) / len(ranks[c])):
        r = ranks[condition]
        t = tones[condition]
        print(f"| {condition} | {sum(r) / len(r):.2f} | {r.count(1)} | {t['natural']} | {t['stiff']} | {t['chatbot']} |")


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--take", action="append", default=[])
    parser.add_argument("--cases", action="append", default=[])
    parser.add_argument("--out")
    parser.add_argument("--judge", default="codex")
    parser.add_argument("--summary")
    args = parser.parse_args()
    if args.summary:
        return summary(args.summary)
    if not args.take or not args.out:
        parser.error("--take and --out are needed (or --summary FILE)")

    groups = collections.defaultdict(dict)  # (case, trial) -> name -> response
    names = []
    for spec in args.take:
        run_dir, _, conds = spec.partition(":")
        wanted = {}
        for part in conds.split(","):
            cond, _, name = part.partition("=")
            wanted[cond] = name or cond
        names += list(wanted.values())
        for row in read_jsonl(f"{run_dir.rstrip('/')}/responses.jsonl"):
            if row["condition"] in wanted:
                groups[(row["case_id"], row["trial"])][wanted[row["condition"]]] = row["response"]
    if len(set(names)) != len(names):
        sys.exit(f"condition names repeat: {names}")
    prompts = {case["id"]: case["prompt"] for path in args.cases for case in read_jsonl(path)}
    missing = sorted({key[0] for key in groups} - set(prompts))
    if missing:
        sys.exit(f"no prompt for case(s) {missing}; give the cases file with --cases")

    judged = set()
    try:
        judged = {(r["case_id"], r["trial"]) for r in read_jsonl(args.out)}
    except FileNotFoundError:
        pass
    failed = 0
    with open(args.out, "a", encoding="utf-8") as out:
        for key in sorted(groups):
            answers = groups[key]
            if set(answers) != set(names):
                print(f"skip {key}: missing {sorted(set(names) - set(answers))}", file=sys.stderr)
                continue
            if key in judged:
                continue
            labels = labels_for(key, names)
            by_label = sorted((labels[n], answers[n]) for n in names)
            body = "\n\n".join(f"=== ANSWER {label} ===\n{text}" for label, text in by_label)
            prompt = PROMPT.format(request=prompts[key[0]], answers=body)
            try:
                ranking, tone, note = parse_verdict(call_judge(args.judge, prompt), labels)
            except (RuntimeError, ValueError) as exc:
                failed += 1
                print(f"failed {key}: {str(exc)[:300]}", file=sys.stderr)
                continue
            row = {"case_id": key[0], "trial": key[1], "judge": args.judge, "note": note,
                   "conditions": {n: {"rank": ranking.index(labels[n]) + 1, "tone": tone[labels[n]]} for n in names}}
            out.write(json.dumps(row) + "\n")
            out.flush()
            print(f"judged {key[0]}/trial {key[1]}")
    if failed:
        sys.exit(f"{failed} group(s) failed; run the same command again to retry them")
    summary(args.out)


if __name__ == "__main__":
    main()
