#!/usr/bin/env python3
"""Lint prose against the language rules of ADHD-STE.md that a script can check.

Input: markdown or text files, a run-matrix.sh output directory (lints the
`result` field of each run, grouped per cell), or stdin when no path is given.
In a run directory it reads only the files that manifest.json marks ok; without
a manifest it reads every run file and prints a warning on stderr.
Ignores fenced code blocks, inline code, quoted lines (`>`) and table rows.

Checks: sentences over 25 words (over 20 as a second column, the limit for
instructions), perfect tenses, non-preferred verbs from the standard-verb list,
forbidden openers and closers (shape rule 10), em-dashes.

The checks are heuristics. The linter has no part-of-speech data, so a noun
such as "the display" or "a launch" counts as a non-preferred verb, and
"have fixed costs" counts as a perfect tense. Read the numbers as a comparison
between inputs, not as a certificate.

Usage: python3 scripts/ste-lint.py [--json] [--max-violations N] [path ...]
Exit status: 0, or 1 when --max-violations is given and the total is over N.
"""
import argparse
import glob
import json
import os
import re
import sys

RUN_PAT = re.compile(r"adhd-(on|off)_concise-(on|off)_rep\d+\.json$")

# "present" is on the list in ADHD-STE.md but is skipped: mostly a noun or an adjective.
VERB_FORMS = {
    "check": ["verify", "verifies", "verified", "verifying", "confirm", "confirms", "confirmed", "confirming",
              "validate", "validates", "validated", "validating", "inspect", "inspects", "inspected", "inspecting"],
    "make sure": ["ensure", "ensures", "ensured", "ensuring", "guarantee", "guarantees", "guaranteed", "guaranteeing"],
    "start": ["initiate", "initiates", "initiated", "initiating", "launch", "launches", "launched", "launching",
              "commence", "commences", "commenced", "commencing"],
    "stop": ["terminate", "terminates", "terminated", "terminating", "halt", "halts", "halted", "halting",
             "cease", "ceases", "ceased", "ceasing"],
    "use": ["utilize", "utilizes", "utilized", "utilizing", "utilise", "utilises", "utilised", "utilising",
            "leverage", "leverages", "leveraged", "leveraging", "employ", "employs", "employed", "employing"],
    "show": ["display", "displays", "displayed", "displaying", "exhibit", "exhibits", "exhibited", "exhibiting"],
    "find": ["locate", "locates", "located", "locating", "discover", "discovers", "discovered", "discovering",
             "identify", "identifies", "identified", "identifying"],
    "change": ["modify", "modifies", "modified", "modifying", "alter", "alters", "altered", "altering",
               "adjust", "adjusts", "adjusted", "adjusting"],
    "remove": ["eliminate", "eliminates", "eliminated", "eliminating"],
    "need": ["require", "requires", "required", "requiring", "necessitate", "necessitates", "necessitated",
             "necessitating"],
}
PREFERRED = {form: good for good, forms in VERB_FORMS.items() for form in forms}
VERB_RE = re.compile(r"\b(" + "|".join(sorted(PREFERRED, key=len, reverse=True)) + r")\b", re.I)

IRREGULAR = (
    "been|become|begun|broken|brought|built|bought|caught|chosen|come|cut|done|drawn|driven|eaten|fallen|felt|"
    "found|forgotten|given|gone|got|gotten|grown|heard|held|hidden|hit|kept|known|led|left|lost|made|meant|met|"
    "paid|put|read|run|said|seen|sent|set|shown|shut|spent|split|stood|taken|taught|told|thought|understood|"
    "won|written"
)
PERFECT_RE = re.compile(
    r"(?:\b(?:have|has|had|having)|['’]ve|\b(?:haven|hasn|hadn)['’]t)\s+"
    r"(?:(?:not|never|ever|now|just|also|already|since|still|\w+ly)\s+){0,2}"
    r"(?:\w+ed|" + IRREGULAR + r")\b",
    re.I,
)

OPENERS = ["great question", "let me", "i'll", "sure!", "sure,", "looking at your", "to answer your question"]
CLOSERS = ["let me know if", "hope this helps", "hope that helps", "happy to clarify", "feel free to ask"]

# A fence: 3 or more backticks or tildes, then the info string. CommonMark
# permits 3 spaces of indent; a fence in a list item sits deeper, so any indent counts.
FENCE_RE = re.compile(r"^\s*(`{3,}|~{3,})(.*)$")
# An inline code span: N backticks close on the next run of exactly N backticks.
CODE_SPAN_RE = re.compile(r"(?<!`)(`+)(?!`).+?(?<!`)\1(?!`)")
LIST_RE = re.compile(r"^\s*(?:[-*+]|\d+[.)])\s+")
WORD_RE = re.compile(r"[A-Za-z0-9][\w'’-]*")
SPLIT_RE = re.compile(r"(?<=[.!?])[\"')\]]*\s+(?=[\"'(\[]*[A-Z0-9])")


def prose_units(text):
    """Return the prose of `text` as a list of units (paragraphs, list items, headings)."""
    units, para, fence = [], [], None  # fence: (character, length) of the open fence

    def flush():
        if para:
            units.append(" ".join(para))
            para.clear()

    for line in text.splitlines():
        m = FENCE_RE.match(line)
        if fence:
            # Only a fence of the same character, at least as long as the
            # opening one and with no info string, closes the block.
            if m and m.group(1)[0] == fence[0] and len(m.group(1)) >= fence[1] and not m.group(2).strip():
                fence = None
            continue
        # A backtick fence with a backtick in its info string is inline code, not a fence.
        if m and not (m.group(1)[0] == "`" and "`" in m.group(2)):
            fence = (m.group(1)[0], len(m.group(1)))
            flush()
            continue
        stripped = line.strip()
        if stripped.startswith(">") or stripped.startswith("|"):
            flush()
            continue
        if not stripped or re.fullmatch(r"[-*_=\s]{3,}", stripped):
            flush()
            continue
        if stripped.startswith("#") or LIST_RE.match(line):
            flush()
            stripped = LIST_RE.sub("", line).strip().lstrip("#").strip()
        para.append(stripped)
        if line.lstrip().startswith("#"):
            flush()
    flush()
    cleaned = []
    for unit in units:
        unit = CODE_SPAN_RE.sub(" x ", unit)  # inline code counts as one word
        unit = re.sub(r"!?\[([^\]]*)\]\([^)]*\)", r"\1", unit)  # keep the link text
        unit = re.sub(r"https?://\S+", " ", unit)
        cleaned.append(unit.replace("’", "'"))
    return cleaned


def lint(text):
    units = prose_units(text)
    sentences = [s for unit in units for s in SPLIT_RE.split(unit) if WORD_RE.search(s)]
    lengths = [len(WORD_RE.findall(s)) for s in sentences]
    prose = "\n".join(units)
    verbs = {}
    for m in VERB_RE.finditer(prose):
        verbs[m.group(1).lower()] = verbs.get(m.group(1).lower(), 0) + 1
    first = units[0].lower().lstrip("*_ ") if units else ""
    low = prose.lower()
    return {
        "runs": 1,
        "sentences": len(sentences),
        "over_20": sum(n > 20 for n in lengths),
        "over_25": sum(n > 25 for n in lengths),
        "perfect_tense": len(PERFECT_RE.findall(prose)),
        "non_preferred_verbs": sum(verbs.values()),
        "openers": int(any(first.startswith(o) for o in OPENERS)),
        "closers": sum(low.count(c) for c in CLOSERS),
        "em_dashes": prose.count("—"),
        "verb_detail": verbs,
    }


COUNTS = ["over_25", "perfect_tense", "non_preferred_verbs", "openers", "closers", "em_dashes"]


def merge(reports):
    out = {k: sum(r[k] for r in reports) for k in ["runs", "sentences", "over_20"] + COUNTS}
    detail = {}
    for r in reports:
        for word, n in r["verb_detail"].items():
            detail[word] = detail.get(word, 0) + n
    out["verb_detail"] = dict(sorted(detail.items(), key=lambda kv: (-kv[1], kv[0])))
    out["violations"] = sum(out[k] for k in COUNTS)
    return out


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


def load_runs(directory):
    """Lint the `result` of each run file in `directory`, grouped per cell."""
    cells, skipped = {}, 0
    for path in run_files(directory):
        m = RUN_PAT.search(path)
        if not m:
            continue
        try:
            with open(path, encoding="utf-8") as f:
                d = json.load(f)
            if not isinstance(d, dict) or d.get("is_error") or not isinstance(d.get("result"), str):
                raise ValueError("is_error or no result field")
            if not d["result"].strip():
                raise ValueError("empty result")
        except (OSError, ValueError) as e:
            print(f"skipped {path}: {e}", file=sys.stderr)
            skipped += 1
            continue
        cells.setdefault(f"adhd-{m.group(1)} concise-{m.group(2)}", []).append(lint(d["result"]))
    if skipped:
        print(f"{skipped} failed run(s) skipped", file=sys.stderr)
    if not cells:
        print(f"no usable run files in {directory}/", file=sys.stderr)
    return {name: merge(reports) for name, reports in sorted(cells.items())}


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("paths", nargs="*", help="files or run directories; stdin when none")
    ap.add_argument("--json", action="store_true", help="print a JSON object, not a markdown table")
    ap.add_argument("--max-violations", type=int, metavar="N", help="exit 1 when the total is over N")
    args = ap.parse_args()

    results = {}
    missing = False  # an input that gave no text to lint
    if not args.paths or args.paths == ["-"]:
        results["stdin"] = merge([lint(sys.stdin.read())])
    for path in args.paths:
        if path == "-":
            continue
        if os.path.isdir(path):
            cells = load_runs(path)
            missing = missing or not cells
            results.update(cells)
            continue
        try:
            with open(path, encoding="utf-8") as f:
                results[path] = merge([lint(f.read())])
        except (OSError, UnicodeDecodeError) as e:
            print(f"skipped {path}: {e}", file=sys.stderr)
            missing = True

    total = sum(r["violations"] for r in results.values())
    if args.json:
        print(json.dumps({"inputs": results, "total_violations": total}, indent=2))
    else:
        print("| Input | n | Sentences | Over 20 words | Over 25 words | Perfect tense "
              "| Non-preferred verbs | Openers | Closers | Em-dashes | Violations |")
        print("|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|")
        for name, r in results.items():
            print(f"| {name} | {r['runs']} | {r['sentences']} | {r['over_20']} | {r['over_25']} "
                  f"| {r['perfect_tense']} | {r['non_preferred_verbs']} | {r['openers']} | {r['closers']} "
                  f"| {r['em_dashes']} | {r['violations']} |")
        print("\nViolations = all columns from \"Over 25 words\" to \"Em-dashes\". "
              "\"Over 20 words\" is the limit for instructions only and does not count.")
    if missing:
        # No evidence is not zero violations.
        sys.exit("error: at least one input gave nothing to lint (see the messages above)")
    if args.max_violations is not None and total > args.max_violations:
        sys.exit(1)


if __name__ == "__main__":
    main()
