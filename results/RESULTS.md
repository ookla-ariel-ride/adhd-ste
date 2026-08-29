# Results: before and after

A controlled test of this config on Claude Code. Twelve fresh headless sessions (`claude -p`, claude-fable-5, 2026-08-23): three replicates for each combination of two variables — whether `~/.claude/CLAUDE.md` imports `ADHD-STE.md`, and whether Claude Code's built-in Concise output style is on.

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
