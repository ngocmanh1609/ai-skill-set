# Project config and rules file: format, setup, health check

## Contents
- Where the files live
- Config format
- Rules file format
- Setup flow
- Keeping them current

## Where the files live

- Config: `<repo root>/.claude/pr-review.yml`
- Rules: `<repo root>/.claude/pr-review/rules.md` (or wherever `rules_file` points)

The repo root is `git rev-parse --show-toplevel`. Neither file holds secrets. Run
`git check-ignore -q <path>`: if it succeeds, the file stays on this machine; otherwise
it can be committed so teammates share it. Tell the user which applies.

## Config format

```yaml
# pr-review config. Created by the pr-review skill; safe to edit by hand.
version: 1
project: <short name>
code_host: { type: github }          # reads adapters/host-<type>.md; repo comes from the git remote
stack: [<stack pack names, e.g. flutter>]   # failure modes: every review; seed conventions: setup only
rules_file: .claude/pr-review/rules.md
rule_sources: [<docs the rules were distilled from, e.g. CLAUDE.md, CONTRIBUTING.md>]
ignore_paths: [<generated, vendored, lock, and l10n output globs>]
composed_paths: [<rendered prompt output to read for the composed view; omit if none>]
checks:
  analyze: '<lint/typecheck command; {files} = changed files, space-separated>'
  test: '<test command; {tests} = mapped test files>'
  test_for: { from: '<regex on a source path>', to: '<test path with $1>' }
  render: '<command that assembles templates or prompts; omit if none>'
architecture:                         # used only with --deep; omit if there is no such agent
  reviewer: <agent type, e.g. argus:architect>
  report_only_prompt: '<first line of the prompt that stops it editing files>'
second_opinion:                       # used only with --second-opinion; omit to be asked each time
  use: <claude | codex | cursor | command>   # default tool; --second-opinion=<tool>[:<model>] overrides
  model: <optional; the tool's own model name>
  command: '<use: command only; {prompt_file} and {repo} are replaced>'
  timeout_minutes: 15
suggestions: { max: 3 }               # design suggestions per review; 0 turns them off
design:                               # omit if the project has no design tool
  type: figma                         # reads adapters/design-<type>.md
  look_in: [pr_body, pr_comments, tracker]
  compare: [padding, gap, radius, text style, colors]
tracker:                              # omit if design links never live in tickets
  type: shortcut                      # reads adapters/tracker-<type>.md
  story_id_pattern: '<regex matched against the branch name>'
api_contract:                         # omit if none
  type: openapi
  url_from: CLAUDE.local.md           # or url_env: <VAR>, or url: <URL without credentials>
comments: { rewrite_skill: <skill name, e.g. plain-english; omit for none> }
large_pr: { lines: 800 }              # above this, read by risk and list the rest as Not checked
```

A check command without `{files}` runs on the whole project. That's fine for fast
analyzers, but prefer the per-file form when the tool supports it.

## Rules file format

```
<!-- source: CLAUDE.md <git blob hash> -->          one stamp per rule source
# Review rules: <project>

## Enforced by tooling (don't hand-review; the analyzer or CI reports these)
- <what the linter/formatter/custom lint already enforces> — src: <file>#<section>

## Conventions
- [R01] <rule in one line> — src: <file>#<section> — paths: '<glob>' — exclude: '<ERE>' — grep: '<ERE>'
## Architecture
## Testing
## Scope and PR rules
## Walkthrough inputs
- <kind of input>: <value>, <value>, … — src: <file>#<section>
## UI tokens (for the design check)
<how design values map to the project's tokens>
## Don't flag
- [N01] <kind of finding the team declined, and why> — src: PR #<n> thread
```

- One line per rule, written as something a reviewer can check **in a diff**. Leave out
  process rules (how to commit, how to run the app).
- `src:` is required: the file and heading a reviewer can grep to quote-check the rule.
- `paths:` is optional (a .gitignore-style glob). `grep:` is optional and must be the
  **last** field. Add it only when an extended regex on a single added line has few
  false positives. Test each pattern on a match and a non-match before saving. Patterns
  run in `awk`, so use `([^A-Za-z]|$)` instead of `\b`.
- `exclude:` is optional and goes before `grep:`. Text matching it is removed from the
  line before `grep:` is tested. Use it for allowed values the grep would otherwise hit,
  such as the config keys a template may use.
- "Don't flag" holds team decisions taken from declined review threads. A finding that
  matches one is dropped. Each entry cites the thread it came from.
- Rules the analyzer already enforces go under "Enforced by tooling" without an ID, so
  nobody reviews them by hand.
- "Walkthrough inputs" lists the kinds of input whose values change what the code or
  instructions do: request or ticket types, modes, configuration values, platforms,
  install targets. The walkthrough and the removed-paths check cover each kind that a
  change reaches. List only kinds with two or more values that behave differently. The
  entries are not rules and have no IDs.
- Aim for 20–50 rules and under ~2k tokens. It is read on every review.

## Setup flow

Say the config is missing and what it's for. Ask (`AskUserQuestion`: create it now /
cancel). Then:

1. **Code host.** Check `git remote get-url origin` (github.com, gitlab.*, other), then
   `gh auth status` or `glab auth status`. If `adapters/host-<type>.md` is missing, say
   so and offer to write one from `adapters/_contract.md`. Stop until it exists.
2. **Stack.** Detect it from manifests: `pubspec.yaml` → flutter; `package.json` →
   typescript-react or node (React/Next deps decide); `pyproject.toml`/`requirements*.txt`
   → python; `go.mod` → go; `build.gradle*` with Android → android-kotlin;
   `Package.swift`/`*.xcodeproj` → ios-swift. Mostly Markdown prompts, skills, agents,
   or prompt templates → prompt-library, as well as the pack for the code beside them.
   Monorepos can have several. Read the matching `references/stacks/<name>.md`. It gives
   default checks, ignore globs, failure modes, and seed conventions. If no pack matches, work from the
   project docs alone.
3. **Commands.** Look in, in order: `CLAUDE.md`, `Makefile`/`justfile`, `package.json`
   scripts, CI workflows (`.github/workflows/*.yml`, `.gitlab-ci.yml`), and the
   pack's defaults. Prefer the exact commands CI runs, including wrappers (`fvm`, `pnpm`, `poetry run`).
4. **Rule sources.** `CLAUDE.md`, `CLAUDE.local.md` (only for rules, never secrets),
   `CONTRIBUTING.md`, `docs/*conventions*`, `.argus/codebase/{CONVENTIONS,ARCHITECTURE,TESTING}.md`,
   `.cursor/rules/*`, `.github/copilot-instructions.md`, and the lint config
   (`analysis_options.yaml`, `.eslintrc*`, `ruff.toml`, `.golangci.yml`, `detekt.yml`,
   `.swiftlint.yml`). If a `.claude/commands/*review*.md` exists, read its checklists too.
5. **Draft the rules file** in the format above. Take the project's rules from the
   sources. From each pack, copy **Seed conventions** only where no project rule already
   checks that same behavior. Do not copy **Failure modes** into the rules file: every
   review reads those from the pack, including in a repo whose docs never mention them.
   A project rule that checks only part of a seed convention (a narrower grep, one
   widget, one call site) does not cover it. Copy the rest, or widen the project rule,
   and say which. Fill "Walkthrough inputs" from the docs and from the enums or validation lists
   in the code. Stamp the header with `scripts/rules_check.sh --stamp <source>...`. When sources
   disagree, the more specific one wins (the conventions doc beats a generic pack's seed
   convention). Say which conflicts you settled.
6. **Optional tools.** Design: Figma links in recent PR bodies (`gh pr list --state
   merged --limit 20 --json body`), or a connected Figma MCP. Tracker: connected MCP
   tools (`ToolSearch` "shortcut", "jira", "linear") and the ID pattern in branch names
   (`git branch -r`). If `.claude/sprint-triage.yml` exists, reuse its tracker type and
   `story_id_pattern`. Architecture agent: list agent types whose names contain
   "architect" or "reviewer", and ask whether to use one. Second opinion: check which of
   `claude`, `codex`, and `cursor-agent` are installed and logged in
   (adapters/second-opinion.md), and ask which one to use by default, or none.
   API contract: an OpenAPI/Swagger URL in the docs or env vars. If it has credentials,
   store only where to find it.
7. **Confirm and write.** Show the YAML and the rules file, and say whether the paths
   are gitignored. Write them only after the user agrees. Then run the health check in SKILL.md.

## Keeping them current

- `rules_check.sh` runs every review. When it reports `stale`, offer to redo step 5 for
  just the changed sources, and show the diff of the rules file before saving.
- At the end of every review (SKILL.md step 4.5), look back at the rule scan and the
  findings:
  - A rule whose grep produced only false leads: propose a tighter pattern or an
    `exclude:` for the allowed values.
  - A finding a grep or a one-line rule could catch next time: propose the rule.
    If it is already a failure mode in the stack pack, leave it there. Propose a pack
    edit only when that pack has no line for the same bug.
  - A finding that depended on a kind of input missing from "Walkthrough inputs":
    propose adding it.
  - In incremental mode, the author's replies to your earlier threads: a thread declined
    with a reason the user agrees with becomes a "Don't flag" entry, and a fixed thread
    whose kind keeps coming back becomes a rule. A stack bug goes in the pack's failure
    modes. A project convention goes in the rules file.
  Show the exact line to add or change. Apply it only if the user agrees.
