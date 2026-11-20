# ADHD + Simplified Technical English output style

One rules file that makes a coding agent answer first and explain second, in short plain sentences. It works as a global output style for Claude Code and Codex.

[`ADHD-STE.md`](ADHD-STE.md) is the entire config. To install it, put that one file where your harness reads global instructions.

It merges two rule sets. The shape rules (answer first, numbered steps, one named next action, no preamble) come from [ayghri's i-have-adhd](https://github.com/ayghri/i-have-adhd), MIT License. The language rules (one meaning per word, active voice, short sentences) come from [L1nefeed's ASD-STE100 gist](https://gist.github.com/L1nefeed/4164ecaaf77879e76dca3c06f142f1c2), which adapts the ASD-STE100 Simplified Technical English standard.

## Quick start

Claude Code, three lines:

```bash
mkdir -p ~/.claude
curl -fsSL https://raw.githubusercontent.com/ookla-ariel-ride/adhd-ste/main/ADHD-STE.md -o ~/.claude/ADHD-STE.md
grep -qxF '@ADHD-STE.md' ~/.claude/CLAUDE.md 2>/dev/null || printf '\n@ADHD-STE.md\n' >> ~/.claude/CLAUDE.md
```

Read `~/.claude/ADHD-STE.md` before you start a new session, because it becomes an instruction for every session. Then start a new session and [check the install](#check-the-install).

For Codex, see [Install](#install). To install a fixed version that does not change under you, see [Pin a version](#pin-a-version).

## What you get

The same question, "My tests fail with ModuleNotFoundError: No module named requests", asked in real sessions.

Without the config, the fix arrives four paragraphs in:

> This error means the Python interpreter running your tests can't see the `requests` package, and the root cause is almost always one of two things...

With it, the answer starts with the fix:

> Install `requests` into the environment your tests use: `python -m pip install requests`

and ends with one next action.

### The rules in short

The file has two halves. The shape half tells the agent how to structure an answer:

- Lead with the next action or the result. If the answer is a command, it goes on line one, in code the reader can copy.
- Ask before you invent. If the request is unclear after a look at the context, the one clarifying question goes first, and it asks for everything that decides the action. If only the form of the fix is unknown, give the exact line as a conditional example ("If the test uses supertest, add ...").
- Number multi-step work, one bounded action per step. A step that only opens a file or finds a line is not a step.
- Group long lists into sets of about five, and say when items are held back.
- End with one concrete next action that the reader can do in under two minutes, or with nothing when nothing is open. The next action does not hand back work that the agent can do.
- Restate state every turn ("Step 3 of 5 is in progress"), exactly as the evidence gives it, and give a time estimate only when it helps the reader plan.
- Keep errors matter-of-fact, and name a cause only when the evidence shows it. Never weaken a check or a security control to make a test pass, and never print a secret value in a diagnostic check.
- Answer a social message, such as thanks, with one short, warm sentence.
- No preamble, no recap, no "hope this helps."

The language half tells it how to write each sentence: one meaning per word, one verb per action (always "check", never "verify"), active voice, simple tenses, 20 words or fewer per instruction, one instruction per sentence. A long explanation or plan gets a lighter form of these rules.

A scope section says where the rules stop: code, quotes, proper names and text that a program reads stay as they are, and a reader who writes in another language gets an answer in that language.

There is an exceptions list (explain fully when asked, confirm before destructive actions, stop and ask after three failed fix attempts) and a pre-send check. Say "normal mode" in a session to relax all of it.

## Install

### Claude Code

The config is the rules file plus one import line in `~/.claude/CLAUDE.md`:

```bash
mkdir -p ~/.claude
curl -fsSL https://raw.githubusercontent.com/ookla-ariel-ride/adhd-ste/main/ADHD-STE.md -o ~/.claude/ADHD-STE.md
grep -qxF '@ADHD-STE.md' ~/.claude/CLAUDE.md 2>/dev/null || printf '\n@ADHD-STE.md\n' >> ~/.claude/CLAUDE.md
```

Start a new session to load it.

### Codex

Codex reads global instructions from `~/.codex/AGENTS.md` and does not expand Claude Code's `@` import syntax, so the rules go into that file directly. No `config.toml` entry is needed in the default case; see the size limit below.

If `~/.codex/AGENTS.md` does not exist:

```bash
mkdir -p ~/.codex
curl -fsSL https://raw.githubusercontent.com/ookla-ariel-ride/adhd-ste/main/ADHD-STE.md -o ~/.codex/AGENTS.md
```

If it already exists, download to a temp file and append the rules to `AGENTS.md` instead of overwriting it. If `~/.codex/AGENTS.override.md` exists and holds more than whitespace, Codex loads that file instead; merge the rules there, and do not remove the override without understanding why it exists.

Start a new Codex session; the instruction chain is built once at startup.

Check the size. Codex stops adding instruction files once their combined size reaches `project_doc_max_bytes`, which is 32 KiB (32,768 bytes) by default. The count covers the whole chain: the global file plus the `AGENTS.md` files of the project you work in. `ADHD-STE.md` is about 20 KB, so it fits alone, but a long existing `AGENTS.md` or a large project file can push the chain over the limit, and Codex then leaves out what does not fit.

```bash
F=~/.codex/AGENTS.md; grep -q '[^[:space:]]' ~/.codex/AGENTS.override.md 2>/dev/null && F=~/.codex/AGENTS.override.md
wc -c "$F"
```

The first line picks the global file that Codex loads: the override when it exists and holds more than whitespace.

Add the size of the project's `AGENTS.md` files to that number. If the total is near 32,768, raise the limit in `~/.codex/config.toml` and restart Codex:

```toml
project_doc_max_bytes = 65536
```

### With your agent

Paste this into Claude Code or Codex:

> Fetch https://github.com/ookla-ariel-ride/adhd-ste and follow the install steps in README.md for this harness. If I give you a commit SHA or a tag, fetch ADHD-STE.md from that ref and not from main. Show me the full ADHD-STE.md and its Version line, and wait for my approval before you install it. Preserve my existing global instructions.

The agent should find its harness below and run those steps. To pin the install, add the ref to the prompt, for example "Use commit `<sha>`". The raw rules file on `main` is at:

```text
https://raw.githubusercontent.com/ookla-ariel-ride/adhd-ste/main/ADHD-STE.md
```

### Other harnesses

Only Claude Code and Codex are tested. Other agents (Cursor, Gemini CLI, Copilot CLI, and the rest) each load global instructions from their own location. The same approach should work: download `ADHD-STE.md` and register it through that agent's instruction mechanism. Expect to consult that agent's docs, and run the check below in a fresh session before trusting it.

## Check the install

Start a new session and ask:

> According to the global instruction file, what exact phrase relaxes the output style for the current session? Reply with only that phrase.

The answer should be `normal mode`. If the agent answers anything else, the file is not loading: check the path, the import line, and that you started a fresh session.

Also check which version you have. Run `grep -m1 'Version:'` on the installed file, or ask the agent for the version line of the global instruction file. See [Pin a version](#pin-a-version).

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

Do not run the Quick start or the Claude Code install commands after this. They fetch `main` and write over the pinned file.

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

## Use it with the built-in Concise style

Claude Code has a built-in output style named Concise. An output style is a set of instructions that Claude Code sends with every request. The [Claude Code docs](https://code.claude.com/docs/en/output-styles) describe Concise this way: the first sentence of a response states what happened or what the answer is, and Claude leaves out the lead-in, the step-by-step narration, and the closing recap. Claude still writes at full length when you ask for an explanation, and for what you need to act safely, such as error reports and confirmations before destructive actions. Concise needs Claude Code v2.1.237 or later.

Concise and this file work at different levels, and they combine. Concise is one instruction about length from the harness. `ADHD-STE.md` is a `CLAUDE.md` import that also sets the structure (numbered steps, one next action, restated state) and the language of each sentence. The docs say that `CLAUDE.md` stays loaded whichever style you pick.

To turn Concise on, use one of these:

- Run `/output-style concise`.
- Run `/config` and select **Output style**.
- Set `"outputStyle": "Concise"` in a settings file. The value is case-sensitive; a value that does not match gives the Default style without an error. `~/.claude/settings.json` makes it your default for all projects.

The command and the menu save the choice for the current project only, in `.claude/settings.local.json`.

In the length test of this version, on one debugging prompt, Concise alone cut the answer by 24%, this file alone by 16%, and both together by 28%. Concise changes the length only. This file also sets the structure and the language, with or without Concise. An output style does not apply to subagents, which run their own system prompt.

## Turn it off

Say "normal mode" in a session to relax the style for that session. The rules file stays in context for the whole session, and Claude Code reads `CLAUDE.md` again after a compaction, so in long sessions the style can drift back. Repeat the phrase if it does.

To uninstall: remove the `@ADHD-STE.md` line from `~/.claude/CLAUDE.md` and delete the rules file (Claude Code), or remove the ADHD-STE section from the Codex file that holds it (Codex): `~/.codex/AGENTS.md`, or `~/.codex/AGENTS.override.md` if you installed into the override. Then start a new session.

## What to expect

These numbers come from the tests of the current file on Claude Code with claude-fable-5-2: 14 test cases with 6 trials each and a blind judge that is a different model, plus a length test on one debugging prompt. [`results/RESULTS.md`](results/RESULTS.md) has every table.

| Measure | No rules | With this file |
|---|---:|---:|
| Quality score of the judge, 1 to 5 | 3.99 | 4.36 |
| Answers with a blocking error, of 84 | 22 | 10 |
| Answers that sound like a chatbot, of 84 | 40 | 2 |
| Answers that read as natural, of 84 | 30 | 44 |
| Answers that read as stiff, of 84 | 14 | 38 |
| AI writing patterns per answer, lower is better | 1.29 | 0.40 |
| Words per answer | 305 | 270 |

What changes:

- The chatbot voice goes away. The lead-in, the flattery, and the closing offer are gone from almost every answer.
- Short and medium answers get shorter, by a third or more in 7 of 11 such cases. The answer to an unclear request shrinks from 115 words to a 42-word question.
- Quality goes up, most where the request is unclear or the work has steps. No test case scored clearly below the answers without rules.
- Safety does not drop. The safety score is 4.65 with the file and 4.61 without.

What does not change, and what it costs:

- Explanations and plans stay long. When you ask for a walk-through or a migration plan, the answer is as long as without the file, and it scores the same.
- Some answers read stiff. The judge called 38 of 84 answers stiff: clipped, repetitive, or like a manual. Without rules it was 14 of 84. Long explanations are the weak spot: there the answers do not read better than without the file.
- Errors still happen. One answer in eight had an error that the judge counts as blocking, against one in four without rules. Check the answer as you do now.
- It does not save output tokens. The model reasons more to write less. Billed output was 9% higher in the 14 cases and 11% higher on the long debugging prompt. The file also adds 20 KB of input to every request.
- The tests are narrow. One model, one judge, 14 cases. Codex and other harnesses load the file, but these numbers are from Claude Code only.

A smaller variant exists. [`variants/ADHD-STE-lite.md`](variants/ADHD-STE-lite.md) has the same shape rules and nine short language rules, with no verb list and no word limits. In the same tests it scored the same for quality (4.35) and for readability, with more AI writing patterns (0.55) and a file that is 3 KB smaller. To use it, install it under the name `ADHD-STE.md`.

## More

- [`CHANGELOG.md`](CHANGELOG.md): what each version changed.
- [`results/RESULTS.md`](results/RESULTS.md): every test run, with tables.
- [`CONTRIBUTING.md`](CONTRIBUTING.md): how to change a rule and rerun the tests.

## License

The repository's own files (README, scripts, results) are MIT, see [`LICENSE`](LICENSE). `ADHD-STE.md` merges two upstream works, and [`THIRD-PARTY-NOTICES.md`](THIRD-PARTY-NOTICES.md) has the details. The shape rules come from ayghri's i-have-adhd under the MIT License. Its copyright and permission notice is in that file and at the end of `ADHD-STE.md`, so a single-file install carries it. The language rules derive from L1nefeed's gist, which states no license; they are used with attribution. ASD-STE100 is a copyrighted standard of ASD. This project paraphrases it and does not reproduce it.

Last reviewed: 2026-11-20.
