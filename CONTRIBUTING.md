# Contributing

This file is for people who change the rules or rerun the tests. To install and use the rules, read [`README.md`](README.md).

## Change a rule

Changes to the rules go in `ADHD-STE.md`. Keep the attribution block at the top.

1. Raise the `Version:` line.
2. Add the change to [`CHANGELOG.md`](CHANGELOG.md), so that each rule stays traceable to one of the two upstream sources or is marked as new.
3. Do not copy the prompt of an eval case into a rule or an example. A file that holds the answer to a test case scores too well on that case.
4. Rerun the length test, and the quality eval for the cases that the rule affects.
5. Update [`results/RESULTS.md`](results/RESULTS.md) and the numbers in the README section "What to expect".

Keep version history out of the README. It describes the current version only.

## Release checklist

A new version of `ADHD-STE.md` merges only when all of these are true:

1. Each limitation in the README section "What to expect" has a change that targets it, or a written reason why it stays.
2. The quality eval ran on all 14 cases of `evals/heldout-cases.jsonl` with the exact file that ships. A subset of cases is not sufficient. Freeze the file before the run, and do not edit it after you see the answers.
3. The judge was not the model that wrote the answers. Use `--judge-codex` or `--judge-model`.
4. The length test ran on the same file.
5. A case whose difference to the baseline is under 0.5 ran again with more trials before the README calls it a gain or a loss.
6. `results/RESULTS.md` records the hash of the tested file, and the hash matches the file in the commit.
7. `results/RESULTS.md` reports the response length of every test: words per cell for the length test, and words per case and per condition for the quality eval.
8. The readability judge and the AI-tell count ran on the answers of the eval, and `results/RESULTS.md` reports both.
9. `CHANGELOG.md` has the version, and the README numbers match `results/RESULTS.md`.

## Repository layout

```text
ADHD-STE.md                   the config; the only file a harness needs
CHANGELOG.md                  the rules that come from neither upstream source, by version
THIRD-PARTY-NOTICES.md        upstream license notice and the status of each source
results/RESULTS.md            the length tests (ADHD-STE on/off x Concise on/off) and the quality evals
results/before-after.html     side-by-side view of one before/after pair
evals/heldout-cases.jsonl     14 eval cases that the rules file never saw
variants/ADHD-STE-lite.md     a variant with nine short language rules, tested next to version 1.5.0
scripts/run-matrix.sh         reruns the 2x2 length test on your machine with Claude Code
scripts/prompt.txt            the prompt of the length test
scripts/summarize.py          turns the run output into the results table
scripts/ste-lint.py           counts language-rule violations in answers or files
scripts/run-quality-eval.sh   runs the upstream i-have-adhd quality eval on this file
scripts/judge-readability.py  blind ranking and tone label of the eval answers
```

## Reproduce the test

The length test has four cells: `ADHD-STE.md` on or off, and the Concise output style on or off.

Requires the `claude` CLI, `jq`, and Python 3. The script tests the `ADHD-STE.md` in this checkout, not your installed copy, and it does not write to `~/.claude`. Each run starts in an empty directory under `~/.cache/adhd-ste` without your user settings, hooks, plugins, or `CLAUDE.md`.

```bash
CHECK_ONLY=1 scripts/run-matrix.sh   # two small calls: checks that the rules load in the "on" cells only
scripts/run-matrix.sh 3              # 3 replicates per cell, 12 runs; the November run cost $4.37
```

Each run goes to a new directory, `runs/<UTC timestamp>-<process id>`, and the script prints the path. Give that path to the two report scripts:

```bash
python3 scripts/summarize.py runs/<run directory>
python3 scripts/ste-lint.py runs/<run directory>    # sentence length, tenses, and verb list per cell
```

The script refuses a directory that already holds runs, so old replicates cannot mix with new ones. It lists every run in `manifest.json`, moves the output of a failed run to `failed/`, and the report scripts count only the runs that the manifest marks as good.

The model defaults to `claude-fable-5-2`. Set `MODEL` to change it. The script writes the model, the CLI version, and a hash of the rules file to `meta.json` in the run directory, and it exits with an error when a run fails. If you set `CLAUDE_CODE_OAUTH_TOKEN` (from `claude setup-token`) or `ANTHROPIC_API_KEY`, the runs use a separate config directory and nothing of your own config loads. The header of the script describes the modes.

To test a different prompt, edit `scripts/prompt.txt`. To test a different rules file, set `RULES`. To run only some cells, set `CELLS`, for example `RULES=variants/ADHD-STE-lite.md CELLS="on:off on:on" scripts/run-matrix.sh 3`.

### Quality, not only length

The length test cannot tell a shorter answer from a worse one. `scripts/run-quality-eval.sh` runs the eval harness of i-have-adhd (14 cases, a blind judge, a scoring rubric) with three conditions: no rules, this file, and the upstream skill alone. It needs Python 3.10 or later.

```bash
scripts/run-quality-eval.sh --plan   # prints the plan and the expected cost; no model calls
scripts/run-quality-eval.sh          # asks before it spends
```

The judge must not be the model that wrote the answers. `--judge-codex` uses the Codex CLI as the judge and adds no API cost. `--judge-model MODEL` uses a different Claude model.

The upstream cases are the default. Examples in older versions of the rules repeated four of their prompts, so a release test uses the cases of this repository:

```sh
scripts/run-quality-eval.sh --judge-codex --cases-file evals/heldout-cases.jsonl --budget 12
```
The third condition is the upstream skill. To compare with a different rules file, set `COMPARATOR`, for example `COMPARATOR=variants/ADHD-STE-lite.md`. To run only some cases, name them: `--cases h-debugging-cause,h-error-report`.

The script shows a maximum cost and asks for a typed "yes". The maximum is the sum of the budget caps it gives the CLI, with one attempt per call. The CLI can pass a cap by the cost of one request, so read the number as a close limit and not as an exact one. Each run writes to its own new directory under `runs/quality-eval/`. To resume a stopped run, pass its directory with `--out`; the script resumes only when the model, the judge, the rules file, the comparator, the upstream commit, and the cases are the same. The budget cap counts the money that the condition already spent, so a resume needs a `--budget` above that amount.

The harness puts the rules file into the prompt. It does not load the file through `CLAUDE.md` as an install does.

A run of all 14 cases with 3 trials costs about $21 for generation on claude-fable-5-2: about $0.11 per answer without rules and $0.24 with a rules file. The estimate of the script comes from an older run and is lower, so start with `--budget 12`.

### Readability
The rubric of the eval scores correctness, autonomy, actionability, safety, and concision. It does not ask if the answer reads as a person wrote it, which is the purpose of this project. Two more measures cover that:

```sh
scripts/judge-readability.py --cases evals/heldout-cases.jsonl \
  --take runs/quality-eval/<run>:baseline=none,candidate=rules,comparator=upstream \
  --out runs/quality-eval/<run>-readability.jsonl
```
The judge (Codex by default) sees the answers to one case under blind labels. It ranks them by what a busy reader prefers and gives each one a tone: natural, stiff, or chatbot. Add a second `--take` to bring in a condition of a different run. A rerun of the same command judges only the groups that failed.

For the AI-tell count, run a detector of AI writing patterns over each answer of 40 words or more and take the mean score per condition. The runs in `results/RESULTS.md` used the detector of the [avoid-ai-writing](https://github.com/conorbronsdon/avoid-ai-writing) skill.
