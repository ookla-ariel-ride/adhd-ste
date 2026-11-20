# ADHD + Simplified Technical English output style

One rules file that makes a coding agent answer first and explain second. It works as a global output style for Claude Code and Codex.

It merges two rule sets. The shape rules (answer first, numbered steps, one named next action, no preamble) come from [ayghri's i-have-adhd](https://github.com/ayghri/i-have-adhd), MIT License. The language rules (one meaning per word, active voice, short sentences) come from [L1nefeed's ASD-STE100 gist](https://gist.github.com/L1nefeed/4164ecaaf77879e76dca3c06f142f1c2), which adapts the ASD-STE100 Simplified Technical English standard.

[`ADHD-STE.md`](ADHD-STE.md) is the entire config, now at version 1.2.0. To install it, put that one file where your harness reads global instructions. The full rules and the attribution are inside it.

## Quick start

Claude Code, three lines:

```bash
mkdir -p ~/.claude
curl -fsSL https://raw.githubusercontent.com/ookla-ariel-ride/adhd-ste/main/ADHD-STE.md -o ~/.claude/ADHD-STE.md
grep -qxF '@ADHD-STE.md' ~/.claude/CLAUDE.md 2>/dev/null || printf '\n@ADHD-STE.md\n' >> ~/.claude/CLAUDE.md
```

Start a new session. Codex puts the same file somewhere else; see [Config per harness](#config-per-harness). Or skip the terminal and [let your agent install it](#install-with-your-agent).

These commands fetch the file from the `main` branch, which changes over time. To install a fixed version, see [Pin a version](#pin-a-version).

## What the rules say

The file has two halves. The shape half tells the agent how to structure an answer:

- Lead with the next action or the result. If the answer is a command, it goes on line one, in code the reader can copy.
- Ask before you invent. If the request is unclear after a look at the context, the one clarifying question goes first. If only the form of the fix is unknown, give the exact line as a conditional example ("If the test uses supertest, add ...").
- Number multi-step work, one bounded action per step. A step that only opens a file or finds a line is not a step.
- Group long lists into sets of about five, and say when items are held back.
- End with one concrete next action that the reader can do in under two minutes, or with nothing when nothing is open. The next action does not hand back work that the agent can do.
- Restate state every turn ("Step 3 of 5 done"), and give a time estimate only when it helps the reader plan.
- Keep errors matter-of-fact, name a cause only when the evidence shows it, and never print a secret value in a diagnostic check.
- No preamble, no recap, no "hope this helps."

The language half tells it how to write each sentence: one meaning per word, one verb per action (always "check", never "verify"), active voice, simple tenses, 20 words or fewer per instruction, one instruction per sentence.

A scope section says where the rules stop: code, quotes, proper names and text that a program reads stay as they are, and a reader who writes in another language gets an answer in that language.

There is an exceptions list (explain fully when asked, confirm before destructive actions, stop and ask after three failed fix attempts) and a pre-send check. Say "normal mode" in a session to relax all of it.

## What it changes

The same question, "My tests fail with ModuleNotFoundError: No module named requests", asked in real sessions.

Without the config, the fix arrives four paragraphs in:

> This error means the Python interpreter running your tests can't see the `requests` package, and the root cause is almost always one of two things...

With it, the answer starts with the fix:

> Install `requests` into the environment your tests use: `python -m pip install requests`

and ends with one next action.

### Test results

Three runs on Claude Code (claude-fable-5-2, 2026-11-19) measured version 1.1.0 and the current version 1.2.0:

| Test | Version | Result |
|---|---|---|
| Length: one production-debugging prompt, 12 runs | 1.1.0 | Answers averaged 18% shorter than vanilla, and 12% shorter when the built-in Concise output style was already on. Violations of the language rules (long sentences, perfect tenses, non-preferred verbs) fell from 14 to 1 over three answers. |
| Quality: 14 cases, 3 trials, blind judge | 1.1.0 | The rules scored 4.44 of 5, against 4.23 with no rules and 4.17 with the upstream skill alone. |
| Quality retest: 3 cases, 3 trials | 1.2.0 | Both debugging cases scored above no rules: 4.43 against 4.38, and 4.38 against 4.15. |

The quality tests use the eval harness of i-have-adhd.

### Where it falls short

- Version 1.1.0 scored clearly below no rules on three cases. Two are debugging cases, where the answers padded their numbered steps and handed the edit back to the user. Version 1.2.0 changed rules 1, 2, 3, and 6 for these, and the retest shows the gain. The third case is a reply to a thank-you, which the judge called robotic. It has no retest.
- Eleven of the 14 cases have no test with version 1.2.0.
- The rules failed the release gate of the upstream harness in both quality runs. Version 1.1.0 had one blocking finding, where the gate allows none; the answers with no rules had two. In the retest, the safety score of version 1.2.0 was 4.44 against 5.00 with no rules.
- The file is about 19 KB of input on every request, and it did not lower billed output tokens in these runs.
- The judge is the same model that wrote the answers.

A test of the first version in August, on an older model, measured 35% shorter answers. [`results/RESULTS.md`](results/RESULTS.md) has all four runs, with a [side-by-side view](https://htmlpreview.github.io/?https://github.com/ookla-ariel-ride/adhd-ste/blob/main/results/before-after.html) of one August pair, which the third-party htmlpreview.github.io service renders. To rerun the tests, see the section "Reproduce the test" below.

## Install with your agent

Paste this into Claude Code or Codex:

> Fetch https://github.com/ookla-ariel-ride/adhd-ste and follow the install steps in README.md for this harness. If I give you a commit SHA or a tag, fetch ADHD-STE.md from that ref and not from main. Show me the full ADHD-STE.md and its Version line, and wait for my approval before you install it. Preserve my existing global instructions.

The agent should find its harness below and run those steps. To pin the install, add the ref to the prompt, for example "Use commit `<sha>`". The raw rules file on `main` is at:

```text
https://raw.githubusercontent.com/ookla-ariel-ride/adhd-ste/main/ADHD-STE.md
```

## Pin a version

The install commands fetch `ADHD-STE.md` from `main`, so the same command can return a different file next month. The file becomes a global instruction for every session, so you may want a copy that does not change until you choose to update it.

The repository has no release tags yet. Pin to a commit SHA. Find the current one with:

```bash
git ls-remote https://github.com/ookla-ariel-ride/adhd-ste HEAD
```

Then download that commit to a temporary file. Do not write over the installed file yet. A tag name works in place of the SHA once tags exist.

```bash
REF=<full commit SHA or tag>
TMP="$(mktemp)"
curl -fsSL "https://raw.githubusercontent.com/ookla-ariel-ride/adhd-ste/$REF/ADHD-STE.md" -o "$TMP" || echo "download failed; do not install $TMP"
```

Read the temporary file, and compare it with the copy you have:

```bash
grep -m1 'Version:' "$TMP"
diff ~/.claude/ADHD-STE.md "$TMP"
shasum -a 256 "$TMP"
```

Record the hash. Two downloads of the same commit SHA give the same hash. This repository does not publish checksums, so the hash to trust is the one you recorded after your own review.

Install the file only after the download succeeded and you accept its content. These three lines are a complete Claude Code install, for a first install and for an update. The `mv` replaces an old copy in one step, and the last line adds the import when it is missing:

```bash
mkdir -p ~/.claude
mv "$TMP" ~/.claude/ADHD-STE.md
grep -qxF '@ADHD-STE.md' ~/.claude/CLAUDE.md 2>/dev/null || printf '\n@ADHD-STE.md\n' >> ~/.claude/CLAUDE.md
```

Do not run the Quick start or the Claude Code commands under [Config per harness](#config-per-harness) after this. They fetch `main` and write over the pinned file.

For Codex the rules live inside an instruction file, so do not move the download over it. Codex loads `~/.codex/AGENTS.override.md` when that file exists and holds more than whitespace. In all other cases it loads `~/.codex/AGENTS.md`. Pick the same file:

```bash
F=~/.codex/AGENTS.md; grep -q '[^[:space:]]' ~/.codex/AGENTS.override.md 2>/dev/null && F=~/.codex/AGENTS.override.md
echo "$F"
```

Then do these steps in order, and stop if one fails:

1. Make a backup: `mkdir -p ~/.codex && { [ ! -f "$F" ] || cp "$F" "$F.bak"; } && echo "backup ok"`. Go on only when you see `backup ok`.
2. Open `"$F"` and remove the old ADHD-STE section by hand. Keep your other instructions.
3. Append the reviewed download: `cat "$TMP" >> "$F"`.

To see later which version is installed, and that it did not change:

```bash
grep -m1 'Version:' ~/.claude/ADHD-STE.md
shasum -a 256 ~/.claude/ADHD-STE.md
```

## Config per harness

### Claude Code

The config is the rules file plus one import line in `~/.claude/CLAUDE.md`:

```bash
mkdir -p ~/.claude
curl -fsSL https://raw.githubusercontent.com/ookla-ariel-ride/adhd-ste/main/ADHD-STE.md -o ~/.claude/ADHD-STE.md
grep -qxF '@ADHD-STE.md' ~/.claude/CLAUDE.md 2>/dev/null || printf '\n@ADHD-STE.md\n' >> ~/.claude/CLAUDE.md
```

Start a new session to load it.

#### Use it with the built-in Concise style

Claude Code has a built-in output style named Concise. An output style is a set of instructions that Claude Code sends with every request. The [Claude Code docs](https://code.claude.com/docs/en/output-styles) describe Concise this way: the first sentence of a response states what happened or what the answer is, and Claude leaves out the lead-in, the step-by-step narration, and the closing recap. Claude still writes at full length when you ask for an explanation, and for what you need to act safely, such as error reports and confirmations before destructive actions. Concise needs Claude Code v2.1.237 or later.

Concise and this file work at different levels, and they combine. Concise is one instruction about length from the harness. `ADHD-STE.md` is a `CLAUDE.md` import that also sets the structure (numbered steps, one next action, restated state) and the language of each sentence. The docs say that `CLAUDE.md` stays loaded whichever style you pick.

To turn Concise on, use one of these:

- Run `/output-style concise`.
- Run `/config` and select **Output style**.
- Set `"outputStyle": "Concise"` in a settings file. The value is case-sensitive; a value that does not match gives the Default style without an error. `~/.claude/settings.json` makes it your default for all projects.

The command and the menu save the choice for the current project only, in `.claude/settings.local.json`.

In the test of version 1.1.0, Concise alone cut answer length by 10%, this file alone by 18%, and both together by 21%. Only this file changed the language of the sentences. [`results/RESULTS.md`](results/RESULTS.md) has the numbers, and the larger numbers of the August test. An output style does not apply to subagents, which run their own system prompt.

### Codex

Codex reads global instructions from `~/.codex/AGENTS.md` and does not expand Claude Code's `@` import syntax, so the rules go into that file directly. No `config.toml` entry is needed in the default case; see the size limit below.

If `~/.codex/AGENTS.md` does not exist:

```bash
mkdir -p ~/.codex
curl -fsSL https://raw.githubusercontent.com/ookla-ariel-ride/adhd-ste/main/ADHD-STE.md -o ~/.codex/AGENTS.md
```

If it already exists, download to a temp file and append the rules to `AGENTS.md` instead of overwriting it. If `~/.codex/AGENTS.override.md` exists and holds more than whitespace, Codex loads that file instead; merge the rules there, and do not remove the override without understanding why it exists.

Start a new Codex session; the instruction chain is built once at startup.

Check the size. Codex stops adding instruction files once their combined size reaches `project_doc_max_bytes`, which is 32 KiB (32,768 bytes) by default. The count covers the whole chain: the global file plus the `AGENTS.md` files of the project you work in. `ADHD-STE.md` is about 19 KB, so it fits alone, but a long existing `AGENTS.md` or a large project file can push the chain over the limit, and Codex then leaves out what does not fit.

```bash
F=~/.codex/AGENTS.md; grep -q '[^[:space:]]' ~/.codex/AGENTS.override.md 2>/dev/null && F=~/.codex/AGENTS.override.md
wc -c "$F"
```

The first line picks the global file that Codex loads: the override when it exists and holds more than whitespace.

Add the size of the project's `AGENTS.md` files to that number. If the total is near 32,768, raise the limit in `~/.codex/config.toml` and restart Codex:

```toml
project_doc_max_bytes = 65536
```

## Install by hand

Open a terminal and run the commands above for your harness. Review `~/.claude/ADHD-STE.md` (or wherever you saved it) before you start a new session: it becomes a global instruction file for every future session. Re-running the download overwrites the file, so re-review after any update.

## Other harnesses

Only Claude Code and Codex are tested. Other agents (Cursor, Gemini CLI, Copilot CLI, and the rest) each load global instructions from their own location. The same approach should work: download `ADHD-STE.md` and register it through that agent's instruction mechanism. Expect to consult that agent's docs, and run the check below in a fresh session before trusting it.

## Check the install

Start a new session and ask:

> According to the global instruction file, what exact phrase relaxes the output style for the current session? Reply with only that phrase.

The answer should be `normal mode`. If the agent answers anything else, the file is not loading: check the path, the import line, and that you started a fresh session.

Also check which version you have. Run `grep -m1 'Version:'` on the installed file, or ask the agent for the version line of the global instruction file. See [Pin a version](#pin-a-version).

## Turn it off

Say "normal mode" in a session to relax the style for that session. The rules file stays in context for the whole session, and Claude Code reads `CLAUDE.md` again after a compaction, so in long sessions the style can drift back. Repeat the phrase if it does.

To uninstall: remove the `@ADHD-STE.md` line from `~/.claude/CLAUDE.md` and delete the rules file (Claude Code), or remove the ADHD-STE section from the Codex file that holds it (Codex): `~/.codex/AGENTS.md`, or `~/.codex/AGENTS.override.md` if you installed into the override. Then start a new session.

## Repository layout

```text
ADHD-STE.md                   the config; the only file a harness needs
THIRD-PARTY-NOTICES.md        upstream license notice and the status of each source
results/RESULTS.md            the length tests (ADHD-STE on/off x Concise on/off) and the quality evals
results/before-after.html     side-by-side view of one before/after pair
scripts/run-matrix.sh         reruns the 2x2 length test on your machine with Claude Code
scripts/prompt.txt            the prompt of the length test
scripts/summarize.py          turns the run output into the results table
scripts/ste-lint.py           counts language-rule violations in answers or files
scripts/run-quality-eval.sh   runs the upstream i-have-adhd quality eval on this file
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

To test a different prompt, edit `scripts/prompt.txt`.

### Quality, not only length

The length test cannot tell a shorter answer from a worse one. `scripts/run-quality-eval.sh` runs the eval harness of i-have-adhd (14 cases, a blind judge, a scoring rubric) with three conditions: no rules, this file, and the upstream skill alone. It needs Python 3.10 or later.

```bash
scripts/run-quality-eval.sh --plan   # prints the plan and the expected cost; no model calls
scripts/run-quality-eval.sh          # asks before it spends
```

To run only some cases, name them: `scripts/run-quality-eval.sh --cases debugging-cause,error-report`.

The script shows a maximum cost and asks for a typed "yes". The maximum is the sum of the budget caps it gives the CLI, with one attempt per call. The CLI can pass a cap by the cost of one request, so read the number as a close limit and not as an exact one. Each run writes to its own new directory under `runs/quality-eval/`. To resume a stopped run, pass its directory with `--out`; the script resumes only when the model, the rules file, the upstream commit, and the cases are the same.

The harness puts the rules file into the prompt. It does not load the file through `CLAUDE.md` as an install does.

[`results/RESULTS.md`](results/RESULTS.md) has the results of two runs. The run of all 14 cases cost about $24 on claude-fable-5-2. That is four times the script's estimate, which comes from upstream's cost on an older model, so start that run with `--budget 10`. The retest of three cases cost $3.51 for generation, plus nine judge calls.

## Contributing

Changes to the rules go in `ADHD-STE.md`. Keep the attribution block at the top, and keep each rule traceable to one of the two upstream sources or mark it as new. If you change a rule:

1. Raise the `Version:` line and add the change to the list "Changes that come from neither source".
2. Rerun the length test, and the quality eval for the cases that the rule affects.
3. Update `results/RESULTS.md` and the numbers in this README.

## License

The repository's own files (README, scripts, results) are MIT, see [`LICENSE`](LICENSE). `ADHD-STE.md` merges two upstream works, and [`THIRD-PARTY-NOTICES.md`](THIRD-PARTY-NOTICES.md) has the details. The shape rules come from ayghri's i-have-adhd under the MIT License. Its copyright and permission notice is in that file and at the end of `ADHD-STE.md`, so a single-file install carries it. The language rules derive from L1nefeed's gist, which states no license; they are used with attribution. ASD-STE100 is a copyrighted standard of ASD. This project paraphrases it and does not reproduce it.

Last reviewed: 2026-11-19.
