#!/usr/bin/env python3
"""Summarize run-matrix.sh output into a markdown table.

Reads only the run files that manifest.json marks ok. A directory without a
manifest (written by an older run-matrix.sh) gets every run file read, with a
warning on stderr. Skips the runs that failed (empty or invalid JSON, is_error,
no result, empty result) and lists them on stderr. A run without usage data
counts for words and characters.

Usage: python3 scripts/summarize.py runs/<UTC timestamp>/
"""
import glob
import json
import os
import re
import statistics
import sys

out = sys.argv[1] if len(sys.argv) > 1 else "runs"
pat = re.compile(r"adhd-(on|off)_concise-(on|off)_rep\d+\.json$")


def run_files(directory):
    """Return the run files to read in `directory`.

    With a manifest.json: only the files that it marks ok. Without one (a run
    directory of an older run-matrix.sh): every file that matches the name
    pattern, with a warning, because such a directory can hold stale runs.
    """
    manifest = os.path.join(directory, "manifest.json")
    if not os.path.exists(manifest):
        print(f"warning: no manifest.json in {directory}/; reading every run file there. "
              "Runs of an earlier experiment count too, when the directory holds them.", file=sys.stderr)
        return sorted(glob.glob(os.path.join(directory, "*.json")))
    try:
        with open(manifest, encoding="utf-8") as f:
            data = json.load(f)
        runs = data["runs"]
        if not isinstance(runs, list) or not all(isinstance(r, dict) for r in runs):
            raise ValueError("`runs` is not a list of objects")
    except (OSError, ValueError, KeyError, TypeError) as e:
        sys.exit(f"{manifest}: not a usable manifest ({e}). No run file read.")
    if data.get("complete") is not True:
        print(f"warning: {manifest} is not marked complete; the experiment stopped early", file=sys.stderr)
    rejected = [r for r in runs if r.get("ok") is not True]
    if rejected:
        print(f"{len(rejected)} run(s) marked failed in {manifest}, not read", file=sys.stderr)
    # A name with a directory part is not a run of this directory.
    return [os.path.join(directory, r["file"]) for r in runs
            if r.get("ok") is True and isinstance(r.get("file"), str) and os.path.basename(r["file"]) == r["file"]]


cells = {}
skipped = []
for path in run_files(out):
    m = pat.search(path)
    if not m:
        continue
    try:
        with open(path, encoding="utf-8") as f:
            d = json.load(f)
    except OSError as e:
        skipped.append((path, f"not readable ({e.strerror})"))
        continue
    except ValueError as e:
        skipped.append((path, "empty file" if os.path.getsize(path) == 0 else f"invalid JSON ({e})"))
        continue
    if not isinstance(d, dict):
        skipped.append((path, "not a JSON object"))
        continue
    if d.get("is_error"):
        skipped.append((path, f"is_error: {str(d.get('result', ''))[:80]}"))
        continue
    text = d.get("result")
    if not isinstance(text, str):
        skipped.append((path, "no result field"))
        continue
    if not text.strip():
        skipped.append((path, "empty result"))
        continue
    usage = d.get("usage")
    toks = usage.get("output_tokens") if isinstance(usage, dict) else None
    cells.setdefault((m.group(1), m.group(2)), []).append((len(text.split()), len(text), toks))

for path, why in skipped:
    print(f"skipped {path}: {why}", file=sys.stderr)
if skipped:
    print(f"{len(skipped)} failed run(s) skipped", file=sys.stderr)
if not cells:
    sys.exit(f"no usable run files in {out}/")


def fmt(vals):
    vals = [v for v in vals if isinstance(v, (int, float))]
    if not vals:
        return "n/a"
    if len(vals) == 1:
        return f"{vals[0]:,}"
    return f"{statistics.mean(vals):,.0f} ({min(vals):,}–{max(vals):,})"


print("| ADHD-STE | Concise | n | Words | Characters | Output tokens (incl. hidden reasoning) |")
print("|---|---|---:|---:|---:|---:|")
for adhd in ("off", "on"):
    for concise in ("off", "on"):
        rows = cells.get((adhd, concise))
        if not rows:
            continue
        words, chars, toks = zip(*rows)
        print(f"| {adhd} | {concise} | {len(rows)} | {fmt(words)} | {fmt(chars)} | {fmt(toks)} |")
