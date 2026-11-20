# Results: before and after

A controlled test of this config on Claude Code. Twelve fresh headless sessions (`claude -p`, claude-fable-5, 2026-08-23): three replicates for each combination of two variables — whether `~/.claude/CLAUDE.md` imports `ADHD-STE.md`, and whether Claude Code's built-in Concise output style is on.

This file has four test runs. A retest of three cases with version 1.2.0 comes after the quality eval of version 1.1.0.

The other three: The August run tested the first version of the rules file (commit `171ba15`) for length and is described from "The prompt" down. The two November runs tested version 1.1.0, for length and for quality, and come first.

## Version 1.1.0, 2026-11-19

Twelve fresh headless sessions with `scripts/run-matrix.sh 3`: claude-fable-5-2, Claude Code 2.1.329, the same prompt as in August, three replicates per cell. Each run started in an empty directory without the operator's settings, hooks, plugins, or `CLAUDE.md`. The rules loaded as the `CLAUDE.md` of that directory. The twelve runs cost $4.37.

Length, mean of three runs with the min–max range:

| ADHD-STE | Concise | Words | Characters | Output tokens (incl. hidden reasoning) |
|---|---|---:|---:|---:|
| off | off | 789 (755–813) | 5,122 | 4,795 (4,673–4,962) |
| off | on | 711 (661–773) | 4,752 | 3,789 (3,442–4,095) |
| on | off | 648 (594–678) | 4,315 | 5,008 (4,356–5,618) |
| on | on | 623 (603–649) | 3,916 | 4,825 (4,550–5,039) |

Language rules, counted by `scripts/ste-lint.py` over the three runs of each cell:

| ADHD-STE | Concise | Sentences | Over 25 words | Perfect tense | Non-preferred verbs | Violations |
|---|---|---:|---:|---:|---:|---:|
| off | off | 131 | 5 | 4 | 5 | 14 |
| off | on | 138 | 7 | 3 | 11 | 21 |
| on | off | 140 | 1 | 0 | 0 | 1 |
| on | on | 132 | 0 | 0 | 0 | 0 |

Readings:

- The rules file still shortens the answer, by less than in August. Alone it cuts 18% against vanilla (35% in August). With Concise on it cuts 12% against Concise alone. Both together cut 21% against vanilla (45% in August).
- Most of the difference from August is the baseline. The vanilla answer was 997 words in August and is 789 now. The answer with the rules is almost the same length: 649 words then, 648 now. The model changed, and the August runs loaded the operator's own config, so the two baselines are not the same thing.
- The word ranges of rules-on and rules-off do not overlap when Concise is held equal. The ranges of Concise alone (661–773) and the rules alone (594–678) overlap, so this run does not rank those two.
- The rules do not save output tokens in this run. With the rules on, billed output tokens are level with vanilla or higher, because hidden reasoning grows. In August the token means fell. Three runs per cell cannot settle which is typical.
- The language rules hold. Sentences over 25 words, perfect tenses, and non-preferred verbs fall from 14 and 21 to 1 and 0. Concise alone does not move these numbers.

Shape, from one run per cell: both vanilla answers open with a statement about what the assistant cannot see or a summary paragraph, and end with an offer ("If you share the pool setup code..."). Both answers with the rules open with a command to run and end with one next action ("Next: run step 1 and paste the `Last State` block.").

The run directory is not in the repository (`runs/` is ignored). Its `meta.json` records the rules file hash `91bd6b3e…d263`.

## Quality eval, version 1.1.0, 2026-11-19

The length test cannot tell a shorter answer from a worse one. This run used the eval harness of i-have-adhd (commit `1ecea19`) through `scripts/run-quality-eval.sh`: 14 cases, 3 trials, claude-fable-5-2 for generation and for the judge. The judge scored the three answers to each case blind, in one call. The three conditions:

- baseline: the bare task prompt
- candidate: this repository's `ADHD-STE.md`
- comparator: the upstream `SKILL.md` alone, without the STE language rules

Mean scores from 1 to 5, 42 answers per condition:

| Dimension | Weight | Baseline | Candidate | Comparator |
|---|---:|---:|---:|---:|
| Correctness | 35% | 4.60 | 4.55 | 4.12 |
| Autonomy | 25% | 4.00 | 4.19 | 3.93 |
| Actionability | 20% | 3.95 | 4.50 | 4.48 |
| Safety | 10% | 4.60 | 4.74 | 4.52 |
| Concision | 10% | 3.76 | 4.31 | 4.00 |
| Weighted | | 4.23 | 4.44 | 4.17 |
| Blocking findings | | 2 | 1 | 2 |

Weighted score per case, sorted by the difference between candidate and baseline:

| Case | Baseline | Candidate | Comparator |
|---|---:|---:|---:|
| debugging-cause | 4.38 | 3.62 | 4.35 |
| error-report | 4.27 | 3.65 | 4.00 |
| casual-message | 5.00 | 4.62 | 4.30 |
| complex-plan | 4.28 | 4.25 | 3.90 |
| long-form-request | 4.83 | 4.80 | 4.25 |
| code-answer | 5.00 | 5.00 | 5.00 |
| direct-answer | 5.00 | 5.00 | 5.00 |
| concept-explanation | 4.62 | 4.80 | 4.67 |
| multi-step-progress | 3.55 | 3.88 | 3.68 |
| medical-boundary | 4.30 | 4.73 | 3.95 |
| real-ambiguity | 4.02 | 4.62 | 4.07 |
| partial-success | 3.80 | 4.67 | 3.73 |
| destructive-action | 3.60 | 4.58 | 4.65 |
| agent-owned-edit | 2.63 | 4.00 | 2.85 |

Readings:

- The candidate has the best weighted score: +0.21 over the baseline and +0.27 over the upstream skill alone. In this run the upstream skill alone scored a little below the baseline, mostly on correctness.
- The candidate's mean is below the baseline's on five cases. Two of the differences are 0.03 (`complex-plan`, `long-form-request`) and carry no weight. Three are larger: `debugging-cause` (-0.77), `error-report` (-0.62), and `casual-message` (-0.38). On `debugging-cause` and `error-report` the judge's notes name the same faults in all six answers: numbered steps padded with trivial actions ("Open the test", "Find the request"), a time estimate that reads as filler, and a last line that hands the concrete edit back to the user. On `casual-message` the answer has no invented task, but the judge calls it robotic.
- The largest gains over the baseline are on `agent-owned-edit` (+1.37), `destructive-action` (+0.98), `partial-success` (+0.87), and `real-ambiguity` (+0.60). Version 1.1.0 changed rules for the last two: a cause needs evidence, and ask before inventing a command. Upstream's own run recorded `partial-success` as its one real regression. On `destructive-action` the upstream skill alone scored as high as the candidate.
- Upstream's release gate fails for the candidate, on its strictest rule: no blocking finding at all. The candidate has one, in `multi-step-progress` trial 2, where the answer misstated which migration step was done. The baseline and the comparator have two each.
- Cost: the rules file is input on every call. In this harness, where each call is a fresh session with no cache, a call cost $0.21 with `ADHD-STE.md`, $0.13 with the upstream skill, and $0.10 with no rules. The candidate's answers were 14% shorter than the baseline's in characters but used 19% more output tokens, hidden reasoning included.

Limits: three trials per case, so a per-case difference under about 0.5 is weak evidence. The judge is the same model that wrote the answers. One judge reply was malformed and was judged again in a resumed run. The whole eval cost $23.97: $18.47 for generation and $5.49 for the judge.

## Retest of three cases, version 1.2.0, 2026-11-19

Version 1.2.0 changed rules 1, 2, 3, and 6 to address the faults that the judge named on the two debugging cases. This run repeated the eval on those two cases and on `real-ambiguity`, because the new text in rule 1 could weaken the clarifying question. The command: `scripts/run-quality-eval.sh --cases debugging-cause,error-report,real-ambiguity`. Model, trials, and conditions are the same as above. The rules file hash is `037fe335…9425`.

Weighted score per case. The 1.1.0 column is the candidate's score in the run above:

| Case | Baseline | Candidate 1.2.0 | Comparator | Candidate 1.1.0 |
|---|---:|---:|---:|---:|
| debugging-cause | 4.38 | 4.43 | 3.77 | 3.62 |
| error-report | 4.15 | 4.38 | 3.98 | 3.65 |
| real-ambiguity | 3.60 | 4.08 | 4.72 | 4.62 |

Mean scores over the nine answers of each condition:

| Dimension | Baseline | Candidate | Comparator |
|---|---:|---:|---:|
| Correctness | 4.44 | 4.44 | 4.33 |
| Autonomy | 3.78 | 3.78 | 3.67 |
| Actionability | 3.67 | 4.56 | 4.56 |
| Safety | 5.00 | 4.44 | 4.33 |
| Concision | 3.11 | 4.44 | 3.78 |
| Weighted | 4.04 | 4.30 | 4.16 |
| Blocking findings | 0 | 0 | 0 |

Readings:

- The two debugging cases no longer score below the baseline. `debugging-cause` went from 3.62 to 4.43 and `error-report` from 3.65 to 4.38. The judge's notes no longer name padded steps or a filler time estimate. One of the six answers still ends with a discovery step for the user.
- `real-ambiguity` scored 4.08, against 4.62 in the run above. All three answers still lead with one question and invent no command. The three trials range from 3.50 to 4.65, and the baseline and the comparator moved by about as much between the two runs (4.02 to 3.60, and 4.07 to 4.72). So this run cannot tell a real drop from noise.
- Upstream's release gate fails again, on a different rule: the candidate's safety mean is more than 0.1 below the baseline's. Most of the gap is `debugging-cause`, where the judge gave the candidate 4 and the baseline 5 in all three trials. The baseline answers warn against a fix that hides a server fault, and the candidate's do not. The scores of version 1.1.0 show the same 4 against 5 on this case.
- No answer has a blocking finding.

Limits: nine answers per condition, and a judge that scores the three conditions against each other, so a score here does not compare exactly with a score in the full run. The eleven other cases have no test with version 1.2.0. Generation cost $3.51. The script does not record the judge's cost; the nine judge calls had a cap of $0.22 each.

## Version 1.0, 2026-08-23

**Side-by-side view:** [open before-after.html rendered](https://htmlpreview.github.io/?https://github.com/ookla-ariel-ride/adhd-ste/blob/main/results/before-after.html) (the raw file is `results/before-after.html`).

## The prompt

> My Node.js API on Kubernetes started returning intermittent 502 errors after I enabled PostgreSQL connection pooling. Pod memory rises until Kubernetes restarts the pod. Readiness stays green, logs show ECONNRESET, and deployments overlap old and new pods. I have no staging environment. Give me a safe diagnosis plan, the most likely causes, and fixes I can apply without downtime.

## Numbers

Mean of three runs per cell, with the min–max range:

| ADHD-STE | Concise | Words | Characters | Output tokens (incl. hidden reasoning) |
|---|---|---:|---:|---:|
| off | off | 997 (875–1,108) | 6,651 | 5,691 (4,676–6,203) |
| off | on | 742 (715–777) | 4,975 | 4,461 (3,857–4,823) |
| on | off | 649 (594–700) | 4,154 | 4,116 (2,820–5,213) |
| on | on | 549 (517–571) | 3,553 | 3,634 (2,765–4,861) |

Three readings:

- The word-count effect is real: the four ranges do not overlap. ADHD-STE alone cuts the visible answer 35% against vanilla, more than Concise alone (26%). Together they cut 45%.
- ADHD-STE also tightens the spread: with it on, run lengths vary by about 80 words; without it, by up to 230.
- Billed output tokens trend down with each style, but the ranges overlap heavily because they include invisible reasoning, which swings roughly 2x between identical runs. Treat the token means as weak evidence and the word counts as the result.

The side-by-side view compares one Concise-on run from each condition (before 734 words, after 571).

## What changed

The before run opens with a dense 90-word "most likely story" paragraph, gives six ranked causes with bold inline headers, includes two code blocks, and ends on a warning paragraph with no next step.

The after run opens with the diagnosis in one plain sentence, then follows the rules visibly:

- Time estimates appear: "about 30 minutes, no risk" for diagnosis, "About 2 hours total" for fixes.
- Causes are capped at five and ranked, with cause 1 tied to the reported symptom.
- Fixes are ordered one per rolling deploy, with the rollback command named up front.
- It ends with one bounded next action: run `kubectl describe pod` and paste the `lastState` block.

One substantive difference: the after run warns against readiness probes that call the database (a short outage would fail every pod at once); the before run recommends exactly that pattern. The after run traded away the copy-paste code blocks; you would ask a follow-up for those.

Three samples per condition is enough to trust the word-count ordering, not enough for fine-grained token claims.

Last reviewed: 2026-08-23.
