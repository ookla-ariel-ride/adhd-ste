#!/usr/bin/env python3
"""Summarize run-matrix.sh output into a markdown table.

Usage: python3 scripts/summarize.py runs/
"""
import glob
import json
import os
import re
import statistics
import sys

out = sys.argv[1] if len(sys.argv) > 1 else "runs"
pat = re.compile(r"adhd-(on|off)_concise-(on|off)_rep\d+\.json$")
cells = {}
for path in sorted(glob.glob(os.path.join(out, "*.json"))):
    m = pat.search(path)
    if not m:
        continue
    with open(path) as f:
        d = json.load(f)
    text = d.get("result", "")
    cells.setdefault((m.group(1), m.group(2)), []).append(
        (len(text.split()), len(text), d["usage"]["output_tokens"])
    )

if not cells:
    sys.exit(f"no run files matched in {out}/")


def fmt(vals):
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
