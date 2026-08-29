# ADHD + Simplified Technical English output style

One rules file that makes a coding agent answer first and explain second. It works as a global output style for Claude Code, Codex, and opencode.

It merges two rule sets. The shape rules (answer first, numbered steps, one named next action, no preamble) come from [ayghri's i-have-adhd](https://github.com/ayghri/i-have-adhd), MIT License. The language rules (one meaning per word, active voice, short sentences) come from [L1nefeed's ASD-STE100 gist](https://gist.github.com/L1nefeed/4164ecaaf77879e76dca3c06f142f1c2), which adapts the ASD-STE100 Simplified Technical English standard.

[`ADHD-STE.md`](ADHD-STE.md) is the entire config. Installing means putting that one file where your harness reads global instructions. Full rules and attribution are inside it.

## Quick start

Claude Code, three lines:

```bash
mkdir -p ~/.claude
curl -fsSL https://raw.githubusercontent.com/ookla-ariel-ride/adhd-ste/main/ADHD-STE.md -o ~/.claude/ADHD-STE.md
grep -qxF '@ADHD-STE.md' ~/.claude/CLAUDE.md 2>/dev/null || printf '\n@ADHD-STE.md\n' >> ~/.claude/CLAUDE.md
```

Start a new session. Codex and opencode put the same file somewhere else; see [Config per harness](#config-per-harness). Or skip the terminal and [let your agent install it](#install-with-your-agent).

## What the rules say

The file has two halves. The shape half tells the agent how to structure an answer:

- Lead with the next action or the result. If the answer is a command, it goes on line one.
- Number multi-step work, one bounded action per step, and cap lists at five items.
- End with one concrete next action the reader can do in under two minutes.
- Restate state every turn ("Step 3 of 5 done"), give time estimates in real units, keep errors matter-of-fact.
- No preamble, no recap, no "hope this helps."

The language half tells it how to write each sentence: one meaning per word, one verb per action (always "check", never "verify"), active voice, simple tenses, 20 words or fewer per instruction, one instruction per sentence.

There is an exceptions list (explain fully when asked, confirm before destructive actions, stop and ask after three failed fix attempts) and a pre-send check. Say "normal mode" in a session to relax all of it.

## What it changes

The same question, "My tests fail with ModuleNotFoundError: No module named requests", asked in real sessions.

Without the config, the fix arrives four paragraphs in:

> This error means the Python interpreter running your tests can't see the `requests` package, and the root cause is almost always one of two things...

With it, the answer starts with the fix:

> Install `requests` into the environment your tests use: `python -m pip install requests`

and ends with one next action.

In a controlled test on Claude Code (claude-fable-5, twelve fresh headless sessions, a harder production-debugging prompt), the configured answers averaged 35% shorter than vanilla (26% when the built-in Concise style was already on), opened with one diagnosis instead of a survey, and ended with one bounded next action. [`results/RESULTS.md`](results/RESULTS.md) has the full test, with a [side-by-side view](https://htmlpreview.github.io/?https://github.com/ookla-ariel-ride/adhd-ste/blob/main/results/before-after.html). You can rerun it with [`scripts/run-matrix.sh`](scripts/run-matrix.sh).

## Install with your agent

Paste this into Claude Code, Codex, or opencode:

> Fetch https://github.com/ookla-ariel-ride/adhd-ste and follow the install steps in README.md for this harness. Show me ADHD-STE.md before you install it, and preserve my existing global instructions.

The agent should find its harness below and run those steps. The raw rules file is always at:

```text
https://raw.githubusercontent.com/ookla-ariel-ride/adhd-ste/main/ADHD-STE.md
```

## Config per harness

### Claude Code

The config is the rules file plus one import line in `~/.claude/CLAUDE.md`:

```bash
mkdir -p ~/.claude
curl -fsSL https://raw.githubusercontent.com/ookla-ariel-ride/adhd-ste/main/ADHD-STE.md -o ~/.claude/ADHD-STE.md
grep -qxF '@ADHD-STE.md' ~/.claude/CLAUDE.md 2>/dev/null || printf '\n@ADHD-STE.md\n' >> ~/.claude/CLAUDE.md
```

Recommended: on Claude Code 2.1.237 or later, also set the built-in "Concise" output style (`/config` → Output style → Concise). It trims narration at the system-prompt level; this file shapes the structure and language. The two compose, and the test results show the pair beating either one alone.

Start a new session to load it.

### Codex

Codex reads global instructions from `~/.codex/AGENTS.md` and does not expand Claude Code's `@` import syntax, so the rules go into that file directly. No `config.toml` entry is needed.

If `~/.codex/AGENTS.md` does not exist:

```bash
mkdir -p ~/.codex
curl -fsSL https://raw.githubusercontent.com/ookla-ariel-ride/adhd-ste/main/ADHD-STE.md -o ~/.codex/AGENTS.md
```

If it already exists, download to a temp file and append the rules to `AGENTS.md` instead of overwriting it. If `~/.codex/AGENTS.override.md` exists, Codex loads that file instead; merge the rules there, and do not remove the override without understanding why it exists.

Start a new Codex session; the instruction chain is built once at startup.

### opencode

opencode reads `~/.claude/CLAUDE.md` but does not expand its `@` import lines, so the Claude Code install alone does nothing here. Instead, list the rules file in the `instructions` array of `~/.config/opencode/opencode.json` (create the file if needed):

```json
{
  "$schema": "https://opencode.ai/config.json",
  "instructions": ["~/.config/opencode/ADHD-STE.md"]
}
```

```bash
mkdir -p ~/.config/opencode
curl -fsSL https://raw.githubusercontent.com/ookla-ariel-ride/adhd-ste/main/ADHD-STE.md -o ~/.config/opencode/ADHD-STE.md
```

If you already installed for Claude Code, you can point at that copy instead: `"instructions": ["~/.claude/ADHD-STE.md"]`. Use an absolute path or one that starts with `~`. A bare relative name resolves against the project directory and fails silently.

Quit and restart opencode; config is read once at startup. Subagents inherit the rules.

## Install by hand

Open a terminal and run the commands above for your harness. Review `~/.claude/ADHD-STE.md` (or wherever you saved it) before you start a new session: it becomes a global instruction file for every future session. Re-running the download overwrites the file, so re-review after any update.

## Other harnesses

Only Claude Code, Codex, and opencode are tested. Other agents (Cursor, Gemini CLI, Copilot CLI, and the rest) each load global instructions from their own location. The same approach should work: download `ADHD-STE.md` and register it through that agent's instruction mechanism. Expect to consult that agent's docs, and run the check below in a fresh session before trusting it.

## Check the install

Start a new session and ask:

> According to the global instruction file, what exact phrase relaxes the output style for the current session? Reply with only that phrase.

The answer should be `normal mode`. If the agent answers anything else, the file is not loading: check the path, the import line, and that you started a fresh session.

## Turn it off

Say "normal mode" in a session to relax the style for that session. In long sessions the style can drift back, since the rules reload into context every turn; repeat the phrase if it does.

To uninstall: remove the `@ADHD-STE.md` line from `~/.claude/CLAUDE.md` and delete the rules file (Claude Code), remove the ADHD-STE section from `~/.codex/AGENTS.md` (Codex), or remove the `instructions` entry (opencode). Then start a new session.

## Repository layout

```text
ADHD-STE.md                 the config; the only file a harness needs
results/RESULTS.md          the 2x2 test (ADHD-STE on/off × Concise on/off), n=3 per cell
results/before-after.html   side-by-side view of one before/after pair
scripts/run-matrix.sh       reruns the 2x2 on your machine with Claude Code
scripts/summarize.py        turns the run output into the results table
```

## Reproduce the test

Requires the `claude` CLI, `jq`, and Python 3, with the config already installed for Claude Code. The script swaps your `~/.claude/CLAUDE.md` between cells and restores it on exit, so close other Claude Code sessions first.

```bash
scripts/run-matrix.sh 3          # 3 replicates per cell, 12 runs, roughly $8 and 10 minutes
python3 scripts/summarize.py runs/
```

To test a different prompt, edit `scripts/prompt.txt`.

## Contributing

Changes to the rules go in `ADHD-STE.md`. Keep the attribution block at the top, and keep each rule traceable to one of the two upstream sources or mark it as new. If you change a rule, rerun the test and update `results/RESULTS.md`.

## License

The repository's own files (README, scripts, results) are MIT, see [`LICENSE`](LICENSE). `ADHD-STE.md` carries its own attribution: the shape rules are MIT from ayghri, and the language rules derive from L1nefeed's gist, which states no license.

Last reviewed: 2026-08-29.
