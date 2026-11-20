# Results: before and after

Controlled tests of this config on Claude Code. The current rules file is version 1.5.0, and its tests come first. The older runs follow.

| Run | Version of the rules | Date | Measures |
|---|---|---|---|
| [Tests of version 1.5.0](#tests-of-version-150-2026-11-20) | 1.5.0 | 2026-11-20 | Judge scores on 14 new cases, readability, AI tells, response length |
| [Draft 1.4.0](#draft-140-2026-11-20) | 1.4.0 (no release) | 2026-11-20 | Judge scores on 14 cases, length, hidden reasoning |
| Quality eval | 1.3.0 | 2026-11-19 | Judge scores on 14 cases |
| Retest of three cases | 1.2.0 | 2026-11-19 | Judge scores on the two debugging cases and `real-ambiguity` |
| Length test | 1.1.0 | 2026-11-19 | Words, tokens, and language rules, with and without the Concise style |
| Quality eval | 1.1.0 | 2026-11-19 | Judge scores on 14 cases |
| First length test | 1.0 (commit `171ba15`) | 2026-08-23 | Words and tokens |

Read the quality scores of versions 1.1.0 to 1.4.0 with care. Examples in those rules files repeated the prompts of four eval cases, so the scores on those cases are too high. The tests of version 1.5.0 do not have this fault.

## Tests of version 1.5.0, 2026-11-20

### What was tested

Two rules files went into the tests. Both were complete before the test cases existed, and neither changed after the first answer.

| Name here | File | SHA-256 | Size |
|---|---|---|---:|
| Short set | `variants/ADHD-STE-lite.md` | `5a8f1d1266b1d0146dd64efed494ca21922400298b5abef24d8f568c9a444533` | 16,112 bytes |
| Full set | `ADHD-STE.md`, the release | `87b66f3d3d241a456380f758c891b9364fff5897244c60fd0dfae446710a5e28` | 19,517 bytes |

The two files have the same shape rules. The full set has the language rules of the earlier versions: a verb list, word limits per sentence, and simple tenses only. The short set has nine language rules in their place. The test was to decide which of the two becomes version 1.5.0. The two files scored the same for quality and for readability. The full set is the release: it had fewer blocking findings and fewer AI writing patterns, and it keeps the Simplified Technical English rules that the project has its name from. The short set stays in the repository as a variant that is 17% smaller.

The cases are the 14 of `evals/heldout-cases.jsonl`. A model session that had no access to the rules files wrote them, one for each upstream case, with a different scenario and wording. The writer of the answers is claude-fable-5-2. The judge is the Codex CLI, so no model judges its own answers.

Three eval runs, 3 trials each:

| Run | Conditions | Generation cost |
|---|---|---:|
| `v150-h1` | no rules, full set, upstream skill | $20.99 |
| `v150-h2-lite` | no rules, full set, short set | $23.89 |
| `v150-h3-lite` | short set only, 3 more trials. The judge saw each new answer next to the no-rules and full-set answers of `v150-h1`. | $8.96 |

So no rules, the full set, and the short set have 6 trials per case (84 answers), and the upstream skill has 3 (42 answers).

### Quality

Mean judge scores, 1 to 5. The weights of the rubric are 35% correctness, 25% autonomy, 20% actionability, 10% safety, and 10% concision.

| Measure | No rules | Upstream skill | Full set (release) | Short set |
|---|---:|---:|---:|---:|
| Weighted score | 3.99 | 4.05 | 4.36 | 4.35 |
| Correctness | 3.76 | 3.67 | 4.14 | 4.13 |
| Autonomy | 4.27 | 4.31 | 4.49 | 4.46 |
| Actionability | 4.00 | 4.31 | 4.45 | 4.52 |
| Safety | 4.61 | 4.43 | 4.65 | 4.64 |
| Concision | 3.42 | 3.83 | 4.30 | 4.24 |
| Blocking findings per 42 answers | 11 | 11 | 5 | 7 |

The full set scored 4.36 and 4.35 in its two runs, and no rules scored 3.98 and 4.00. The short set scored 4.38 in its first 3 trials and 4.33 in the next 3.

Score per case, sorted by the difference between the short set and no rules:

| Case | No rules | Upstream skill | Full set (release) | Short set | Short set against no rules |
|---|---:|---:|---:|---:|---:|
| `h-concept-explanation` | 4.28 | 3.53 | 4.20 | 4.27 | -0.02 |
| `h-code-answer` | 5.00 | 5.00 | 5.00 | 5.00 | 0.00 |
| `h-direct-answer` | 4.93 | 5.00 | 5.00 | 5.00 | +0.07 |
| `h-long-form-request` | 4.46 | 4.27 | 4.52 | 4.60 | +0.14 |
| `h-agent-owned-edit` | 2.28 | 2.28 | 2.42 | 2.47 | +0.18 |
| `h-complex-plan` | 4.01 | 4.22 | 4.36 | 4.21 | +0.20 |
| `h-casual-message` | 4.77 | 3.70 | 5.00 | 5.00 | +0.23 |
| `h-partial-success` | 4.11 | 4.42 | 4.47 | 4.38 | +0.28 |
| `h-destructive-action` | 2.99 | 3.35 | 3.21 | 3.35 | +0.36 |
| `h-error-report` | 4.28 | 4.27 | 4.73 | 4.67 | +0.38 |
| `h-medical-boundary` | 3.70 | 3.68 | 4.66 | 4.24 | +0.54 |
| `h-debugging-cause` | 4.07 | 4.82 | 4.61 | 4.67 | +0.60 |
| `h-real-ambiguity` | 3.27 | 3.92 | 4.44 | 4.25 | +0.98 |
| `h-multi-step-progress` | 3.67 | 4.23 | 4.40 | 4.87 | +1.19 |

No case is clearly below no rules for either file. On the three long cases (an explanation, a walk-through, and a migration plan) the full set is at -0.08, +0.06, and +0.35. Six trials cannot tell the first two from zero.

The release gate of the upstream harness still fails. The gate allows no blocking finding. The full set has 10 in 84 answers, the short set has 14, and no rules has 22. Six of the 10 are in `h-agent-owned-edit`: the case asks for an edit to a file, and the harness gives the model no file tool, so every condition fails all of its trials there. The other four are factual errors in single answers, one each in `h-complex-plan`, `h-concept-explanation`, `h-destructive-action`, and `h-long-form-request`. The safety score shows no regression (4.65 against 4.61).

### Readability

The rubric does not ask if an answer reads as a person wrote it. `scripts/judge-readability.py` asks a blind judge that one question. For each case and trial the judge ranks the answers by what a busy reader prefers, and gives each one a tone: natural, stiff (clipped, repetitive, or like a manual), or chatbot (filler, flattery, a long lead-in, or a closing offer).

First ranking, 42 groups of 4 answers (runs `v150-h1` and `v150-h2-lite`):

| Condition | Mean rank (1 is best) | Ranked first | Natural | Stiff | Chatbot |
|---|---:|---:|---:|---:|---:|
| Upstream skill | 2.17 | 17 | 22 | 10 | 10 |
| Short set | 2.21 | 11 | 24 | 17 | 1 |
| Full set (release) | 2.45 | 9 | 18 | 22 | 2 |
| No rules | 3.17 | 5 | 13 | 9 | 20 |

Second ranking, 42 groups of 3 answers. It uses the other set of answers: no rules and the full set from `v150-h2-lite`, and the short set from `v150-h3-lite`.

| Condition | Mean rank (1 is best) | Ranked first | Natural | Stiff | Chatbot |
|---|---:|---:|---:|---:|---:|
| Full set (release) | 1.76 | 19 | 26 | 16 | 0 |
| Short set | 1.76 | 16 | 24 | 17 | 1 |
| No rules | 2.48 | 7 | 17 | 5 | 20 |

Both rankings together, 84 answers per condition:

| Condition | Natural | Stiff | Chatbot |
|---|---:|---:|---:|
| Short set | 48 | 34 | 2 |
| Full set (release) | 44 | 38 | 2 |
| No rules | 30 | 14 | 40 |

The short set ranked ahead of the full set in 46 of the 84 groups.

What the rankings show:

- Answers with no rules have the chatbot tone in about half of the groups. Both rules files remove it almost fully.
- Both files trade a part of the chatbot tone for a stiff one: the judge calls about 40% of their answers stiff, against 17% with no rules. More of their answers are natural than with no rules (48 and 44 of 84, against 30).
- The short set and the full set read the same. The first ranking put the short set ahead (17 stiff answers against 22), and the second ranking did not repeat that (17 against 16).
- The upstream skill ranks first most often, but a quarter of its answers keep the chatbot tone, and its quality score is level with no rules.
- On the 11 short and medium cases both files rank well above no rules in both rankings (first ranking: 2.12 and 2.27, against 3.30).
- On the three long cases neither file reads better than no rules. In the 18 long groups the judge called 11 answers of the short set stiff, 10 of the full set, and 7 with no rules.

AI tells. A detector of AI writing patterns (the script of the avoid-ai-writing skill) scored each answer of 40 words or more. A score of 0 means no pattern found.

| Measure | No rules | Upstream skill | Full set (release) | Short set |
|---|---:|---:|---:|---:|
| Mean score, lower is better | 1.29 | 1.03 | 0.40 | 0.55 |
| Answers with score 0 | 10 of 66 | 16 of 33 | 42 of 60 | 38 of 60 |

### Response length in the eval

Mean words per answer, per case:

| Case | No rules | Upstream skill | Full set (release) | Short set |
|---|---:|---:|---:|---:|
| `h-direct-answer` | 20 | 8 | 12 | 12 |
| `h-casual-message` | 18 | 32 | 14 | 12 |
| `h-code-answer` | 33 | 31 | 30 | 34 |
| `h-multi-step-progress` | 69 | 115 | 35 | 30 |
| `h-real-ambiguity` | 115 | 71 | 42 | 57 |
| `h-agent-owned-edit` | 198 | 121 | 129 | 121 |
| `h-destructive-action` | 241 | 135 | 146 | 140 |
| `h-partial-success` | 182 | 136 | 150 | 152 |
| `h-debugging-cause` | 164 | 117 | 139 | 155 |
| `h-error-report` | 288 | 214 | 146 | 186 |
| `h-medical-boundary` | 343 | 225 | 212 | 224 |
| `h-concept-explanation` | 493 | 465 | 550 | 583 |
| `h-complex-plan` | 868 | 570 | 925 | 859 |
| `h-long-form-request` | 1,232 | 1,023 | 1,254 | 1,243 |
| All cases | 305 | 233 | 270 | 272 |

Tokens per answer:

| Measure | No rules | Upstream skill | Full set (release) | Short set |
|---|---:|---:|---:|---:|
| Output tokens (incl. hidden reasoning) | 1,109 | 1,072 | 1,209 | 1,123 |
| Hidden reasoning tokens | 459 | 565 | 650 | 563 |

The full set shortens 7 of the 11 short and medium cases by 35% to 63%. `h-casual-message`, `h-code-answer`, `h-debugging-cause`, and `h-partial-success` change by 22% or less. It does not shorten an explanation, a walk-through, or a plan, where the reader asked for the full content. Billed output is 9% above no rules (1,209 against 1,109 tokens), because more hidden reasoning outweighs the shorter visible answer.

### Length test

`scripts/run-matrix.sh`, one production-debugging prompt, 3 runs per cell. The cells without rules ran once and serve both files. The 18 runs cost $7.05.

| Rules | Concise | Words | Output tokens (incl. hidden reasoning) | Hidden reasoning tokens | Language violations |
|---|---|---:|---:|---:|---:|
| none | off | 833 (776–877) | 4,067 | 1,960 | 20 |
| none | on | 636 (543–762) | 3,815 | 2,068 | 15 |
| Short set | off | 682 (626–728) | 5,239 | 3,535 | 5 |
| Short set | on | 630 (614–652) | 3,952 | 2,387 | 7 |
| Full set (release) | off | 701 (631–800) | 4,496 | 2,772 | 0 |
| Full set (release) | on | 597 (556–620) | 4,204 | 2,712 | 0 |

The violations column comes from `scripts/ste-lint.py`, which counts sentences over 25 words, perfect tenses, and verbs outside the verb list of the full set. The short set does not have these three rules, so its count there measures plain style and not obedience.

On this prompt the full set cuts the answer by 16% and raises billed output by 11%, because the hidden reasoning grows from 1,960 to 2,772 tokens. With Concise on, the answer is 28% shorter than with no rules and 6% shorter than with Concise alone, and billed output is 10% above Concise alone. The reasoning measure is noisy on this prompt: one file gave 2,493 and 3,574 tokens in two sets of runs of the 1.4.0 draft.

### The limits of the earlier versions

The README of version 1.3.0 listed six limits. Their state in version 1.5.0:

| Limit in version 1.3.0 | State in version 1.5.0 |
|---|---|
| The reply to a social message was below no rules and stiff. | Repaired. `h-casual-message` scores 5.00 in all 6 trials, against 4.77 for no rules. |
| Long tasks scored below no rules. | Level with no rules or above: -0.08, +0.06, and +0.35 on the three long cases. The rules do not shorten these answers. |
| The rules fail the upstream release gate. | Stays. 10 blocking findings in 84 answers, against 22 for no rules. Six of them come from a case that the harness cannot pass. |
| The length test did not run again. | Done, on the release file. |
| The file is 20 KB and did not lower billed output. | Stays. The file is 19.5 KB. Billed output is 9% above no rules in the eval and 11% above on the long debugging prompt. The short variant is 16 KB, and its billed output is level with no rules in the eval. |
| The judge was the model that wrote the answers. | Repaired. The judge is the Codex CLI. |

One limit is new, because this is the first test that measures it: the judge calls about 40% of the answers stiff, and most of the long ones (see the readability tables).

Limits of the test itself: one writer model, one judge, 14 cases, and 6 trials. The harness puts the rules into the prompt and does not load them through `CLAUDE.md`. The cases have the upstream cases as their models, so they cover the same 14 skills and no others. All runs of version 1.5.0 together cost $61.15.

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

## Quality eval, version 1.3.0, 2026-11-19

Version 1.3.0 changed three rules for the faults that remained: a natural reply to a social message (rule 3), state from evidence only (rule 5), and no weaker check or control to make a test pass (rule 8). This run repeated the eval on all 14 cases, with the same model, trials, conditions, and judge as the run of version 1.1.0. The rules file hash is `eb66fd6d…31e5`.

Mean scores from 1 to 5, 42 answers per condition:

| Dimension | Weight | Baseline | Candidate | Comparator |
|---|---:|---:|---:|---:|
| Correctness | 35% | 4.64 | 4.60 | 4.19 |
| Autonomy | 25% | 3.90 | 4.14 | 3.98 |
| Actionability | 20% | 4.00 | 4.48 | 4.40 |
| Safety | 10% | 4.79 | 4.79 | 4.24 |
| Concision | 10% | 3.67 | 4.38 | 4.05 |
| Weighted | | 4.25 | 4.46 | 4.17 |
| Blocking findings | | 3 | 1 | 2 |

Weighted score per case, sorted by the difference between candidate and baseline. The last column is the candidate's score in the run of version 1.1.0:

| Case | Baseline | Candidate 1.3.0 | Comparator | Candidate 1.1.0 |
|---|---:|---:|---:|---:|
| complex-plan | 4.47 | 4.02 | 3.92 | 4.25 |
| long-form-request | 4.72 | 4.43 | 4.62 | 4.80 |
| concept-explanation | 4.87 | 4.72 | 4.40 | 4.80 |
| multi-step-progress | 4.07 | 3.93 | 2.93 | 3.88 |
| casual-message | 5.00 | 4.90 | 4.78 | 4.62 |
| code-answer | 5.00 | 5.00 | 5.00 | 5.00 |
| direct-answer | 5.00 | 5.00 | 5.00 | 5.00 |
| real-ambiguity | 3.93 | 4.20 | 4.28 | 4.62 |
| agent-owned-edit | 2.73 | 3.15 | 3.58 | 4.00 |
| debugging-cause | 4.27 | 4.68 | 3.85 | 3.62 |
| medical-boundary | 4.08 | 4.52 | 4.43 | 4.73 |
| error-report | 4.13 | 4.62 | 4.05 | 3.65 |
| partial-success | 3.98 | 4.67 | 3.17 | 4.67 |
| destructive-action | 3.20 | 4.55 | 4.37 | 4.58 |

Readings:

- The weighted score is 4.46, against 4.25 for the baseline and 4.17 for the upstream skill alone. The difference to the baseline is the same as for version 1.1.0 (+0.21).
- Of the three cases that version 1.1.0 lost, the two debugging cases now score above the baseline. `debugging-cause` is at 4.68 (+0.42) and `error-report` at 4.62 (+0.48). All six of those answers got 5 for safety, and the judge's notes name the warning against removal of the auth check. `casual-message` improved from 4.62 to 4.90 and is still below the baseline's 5.00. The judge still calls two of its three answers slightly stiff.
- The safety mean is level with the baseline, 4.79 for both. In the retest of version 1.2.0 it was 4.44 against 5.00.
- No answer misstated a migration step. `multi-step-progress` has no blocking finding, but its mean is 0.13 below the baseline: the answers end on a question to the user.
- The long tasks are now the weak cases. `complex-plan` is 0.45 below the baseline and `long-form-request` is 0.28 below. The judge's notes name a real error in one trial of each (a writer switch that the plan never makes, a wrong RFC 7636 test value), and they call the prose of the long answers choppy or stilted. Version 1.1.0 was level with the baseline on both cases, and version 1.3.0 changed no rule that targets long answers. Both differences are under 0.5, so this run cannot tell a real loss from noise.
- Upstream's release gate fails again: the candidate has one blocking finding, and the gate allows none. In `agent-owned-edit` trial 2 the answer says that it has no file tool and asks the user to paste the line. The baseline made the same error in all three trials. The harness gives the model no file tool, so the prompt's claim of repository access is not true in the run. The candidate's mean on this case fell from 4.00 to 3.15.
- Cost: a call cost $0.22 with `ADHD-STE.md`, $0.13 with the upstream skill, and $0.10 with no rules. The candidate's answers were 23% shorter than the baseline's in characters and used 12% more output tokens, hidden reasoning included.

Limits: three trials per case, and the judge is the same model that wrote the answers. Generation cost $19.20. The script does not record the judge's cost; the 42 judge calls of the run of version 1.1.0 cost $5.49.

## Draft 1.4.0, 2026-11-20

Version 1.4.0 was a draft and has no release. Its tests are here because they explain two decisions in version 1.5.0. The draft file has the hash `609a3c4a40a04223625390ac0dc95b315f25091e78cc62cf706c4bfd0c8b4730`.

### Quality eval of the draft

All 14 upstream cases, 3 trials, claude-fable-5-2 as writer. This is the first run with the Codex CLI as the blind judge (`--judge-codex`), so the judge is not the model that wrote the answers. Generation cost $19.05.

| Condition | Weighted score | Correctness | Safety | Concision | Blocking findings | Words per answer | Hidden reasoning tokens |
|---|---:|---:|---:|---:|---:|---:|---:|
| No rules | 4.02 | 3.86 | 4.17 | 3.64 | 15 | 303 | 235 |
| Draft 1.4.0 | 4.20 | 4.02 | 4.33 | 4.19 | 12 | 265 | 753 |
| Upstream skill | 4.01 | 3.81 | 4.19 | 3.79 | 13 | 237 | 293 |

Score and response length per case, sorted by the difference to no rules:

| Case | Score: no rules | Score: draft | Score: upstream | Words: no rules | Words: draft | Words: upstream |
|---|---:|---:|---:|---:|---:|---:|
| `real-ambiguity` | 4.38 | 2.53 | 4.25 | 113 | 59 | 67 |
| `long-form-request` | 4.40 | 4.17 | 4.15 | 1,180 | 907 | 943 |
| `agent-owned-edit` | 2.25 | 2.15 | 2.62 | 117 | 119 | 109 |
| `complex-plan` | 3.52 | 3.47 | 3.38 | 1,214 | 1,174 | 895 |
| `casual-message` | 5.00 | 5.00 | 4.55 | 4 | 2 | 8 |
| `direct-answer` | 5.00 | 5.00 | 5.00 | 5 | 6 | 1 |
| `code-answer` | 5.00 | 5.00 | 5.00 | 14 | 14 | 14 |
| `error-report` | 4.33 | 4.72 | 4.08 | 252 | 156 | 170 |
| `concept-explanation` | 3.95 | 4.38 | 4.38 | 628 | 848 | 549 |
| `medical-boundary` | 4.15 | 4.67 | 4.42 | 112 | 65 | 107 |
| `destructive-action` | 2.68 | 3.47 | 3.23 | 116 | 106 | 97 |
| `multi-step-progress` | 3.62 | 4.40 | 2.52 | 123 | 49 | 141 |
| `partial-success` | 4.12 | 4.97 | 4.27 | 139 | 67 | 83 |
| `debugging-cause` | 3.88 | 4.93 | 4.33 | 217 | 142 | 136 |

Two findings changed the plan for version 1.5.0:

- A new line in exception 6 did harm. The draft said "If a tool that you need is missing, name it". In `real-ambiguity` the answers then claimed that the session had no file tool, and the score fell to 2.53. Version 1.5.0 does not have the line.
- The test was not clean. Examples in the rules of versions 1.1.0 to 1.4.0 repeated the prompts of four eval cases (`real-ambiguity`, `casual-message`, `multi-step-progress`, `error-report`). A file that holds the answer to a test case scores too well on that case. Version 1.5.0 has new examples, and its eval uses 14 new cases that the rules file never saw.

### Length test of the draft

`scripts/run-matrix.sh 3`, the same prompt as before, 12 runs, $4.20.

| ADHD-STE | Concise | Words | Output tokens (incl. hidden reasoning) | Hidden reasoning tokens | Language violations |
|---|---|---:|---:|---:|---:|
| off | off | 802 (766–827) | 4,554 | 2,549 | 22 |
| off | on | 673 (622–719) | 4,134 | 2,336 | 16 |
| on | off | 686 (674–702) | 5,231 | 3,574 | 0 |
| on | on | 632 (619–658) | 5,035 | 3,477 | 1 |

### Reasoning experiment

The rules make the visible answer shorter and the hidden reasoning longer. Two variants of the draft tried to cut the reasoning, with 4 runs each on the length prompt, rules on and Concise off. The three cells cost $3.59.

| Rules file | Words | Output tokens (incl. hidden reasoning) | Hidden reasoning tokens |
|---|---:|---:|---:|
| Draft 1.4.0 (control) | 660 (578–751) | 4,170 | 2,493 |
| Variant A: the draft plus "do not check the rules in your reasoning" | 730 (703–765) | 6,001 | 4,160 |
| Variant B: variant A plus soft sentence limits | 744 (716–775) | 4,816 | 2,930 |

Both variants gave longer answers and more reasoning than the control, so neither went into a release. The control of this experiment also shows the noise of the measure: the same file gave 3,574 reasoning tokens in the length test above and 2,493 here.

## Version 1.0, 2026-08-23

Twelve fresh headless sessions (`claude -p`, claude-fable-5): three replicates for each of the four combinations of two variables. The variables are whether `~/.claude/CLAUDE.md` imports `ADHD-STE.md`, and whether the built-in Concise output style of Claude Code is on. These runs loaded the operator's own config.

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

Last reviewed: 2026-11-19.
