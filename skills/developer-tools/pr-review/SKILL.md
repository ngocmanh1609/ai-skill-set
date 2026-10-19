---
name: pr-review
description: >
  Reviews a teammate's pull request in any language or framework. It checks the change
  against the project's own distilled rules, its lint and tests, the design, the API
  contract, and the PR's stated scope. It shows numbered, verified findings, with a better
  fix when one is clearly better, a few optional design suggestions, and a separate list
  of lower-confidence findings below the bar, and posts only the ones the user picks, as
  line or file comments in one review. The review is a comment, or an approval when the
  user asks for one and nothing picked is an issue.
  Keeps a per-project config and rules file, and offers to create them on first use.
when_to_use: >
  Use when the user asks to review a PR or MR ("review PR #123", a pull request URL,
  "look at Don's PR"), to re-review after the author pushed, or to check a coworker's
  change before approving. Not for the user's own uncommitted work.
argument-hint: "[PR number | URL] [--deep] [--second-opinion[=<tool>[:<model>]]] [--full] | setup"
allowed-tools: >-
  Bash(${CLAUDE_SKILL_DIR}/scripts/pr_context.sh *) Bash(${CLAUDE_SKILL_DIR}/scripts/diff.sh *)
  Bash(${CLAUDE_SKILL_DIR}/scripts/rule_scan.sh *) Bash(${CLAUDE_SKILL_DIR}/scripts/rules_check.sh *)
  Bash(${CLAUDE_SKILL_DIR}/scripts/openapi_fields.sh *)
  Bash(git status*) Bash(git branch --show-current) Bash(git fetch *) Bash(git rev-parse *)
  Bash(git show *) Bash(git log *) Bash(git diff *) Bash(git grep *) Bash(git remote *)
  Bash(git check-ignore *) Bash(git merge-base --is-ancestor *)
  Bash(gh auth status*) Bash(gh pr view *) Bash(gh pr diff *) Bash(gh issue view *)
  mcp__figma__get_screenshot mcp__shortcut__stories-get-by-id
---

# PR review

Turns a PR into a short list of **verified** findings, then posts only what the user picks.
Work goes from cheapest to most expensive, and nothing is posted until the user selects.
Each finding carries one fix: the better one when it is clearly better and fits the PR,
otherwise the minimal one. Design suggestions for code that already works are kept apart
from defects and are optional.

The skill works with any code host, design tool, or tracker that has an adapter:

| Kind | Adapter | Status |
|---|---|---|
| Code host: GitHub | [adapters/host-github.md](adapters/host-github.md) | complete |
| Code host: GitLab | [adapters/host-gitlab.md](adapters/host-gitlab.md) | outline |
| Design: Figma | [adapters/design-figma.md](adapters/design-figma.md) | complete |
| Tracker: Shortcut / Jira / Linear | [adapters/tracker-shortcut.md](adapters/tracker-shortcut.md), [tracker-jira.md](adapters/tracker-jira.md), [tracker-linear.md](adapters/tracker-linear.md) | Shortcut complete; others outline |
| Second opinion: Claude Code / Codex / Cursor / any CLI | [adapters/second-opinion.md](adapters/second-opinion.md) | complete |

Operation IDs (H1–H7, D1, K1, R1–R2) are defined in [adapters/_contract.md](adapters/_contract.md).
Read only the adapters the project config names. The scripts below speak GitHub. On
another host, do each step with that host's adapter instead.

## Modes

| Mode | When | Review covers |
|---|---|---|
| **Full** | first review of this PR, or `--full` | every reviewable file |
| **Incremental** | `myLastReview` exists and its commit is an ancestor of HEAD | only `diff.sh --since <commit>`, limited to the PR's files |
| **Deep** (`--deep`) | only when the user asks | adds the architecture agent, plus files skipped for size |
| **Second opinion** (`--second-opinion[=<tool>[:<model>]]`) | only when the user asks | adds another AI CLI (Claude Code, Codex, Cursor, or any command) as an independent, read-only reviewer |
| **Setup** (`setup`) | no config yet, or the user asks | builds the config and rules file |

**Focus since approval** combines with Full: when someone else approved an earlier commit
and the author pushed after it, those later commits get read first and hardest (step 1.4).

Copy this checklist into the conversation and tick it off as you go:

```
PR review:
- [ ] 0 Config loaded, rules fresh
- [ ] 1 PR context, safe checkout, scope + linked issue, mode + focus
- [ ] 2 Review: checks → rule scan → understand → read → (UI) → (API) → (deep / second opinion) → fixes → verify
- [ ] 3 Findings, suggestions, and body draft presented; user selected
- [ ] 4 Posted and confirmed; rules feedback; branch offer
```

## 0. Config

Read `<repo root>/.claude/pr-review.yml`. If it's missing, or the argument is `setup`,
follow [references/setup.md](references/setup.md), which detects the stack and tools,
drafts the config and rules file, and writes them only after the user agrees. Then run
the health check:
- `scripts/rules_check.sh <rules_file>`. On `stale`, name the changed sources and offer
  to rebuild the rules (setup step 5). Don't rebuild without a yes; a stale file is still usable.
- The adapters named in the config exist, and H7 (auth) passes.

Every later step takes paths, commands, and tools from the config. Never hard-code them.

## 1. Prepare

1. `scripts/pr_context.sh [<pr>] --ignore <glob>...` (one `--ignore` per `ignore_paths`
   entry). Keep the JSON; it is the source for everything below. Stop if `state` is
   closed or merged. Note if `isDraft` is true, but continue.
2. Scope: from `body`, list what the PR says it covers and what it defers ("part 1 of
   N", "follow-up"). If `linkedIssues` has an issue in this repo, read it
   (`gh issue view <n> --json title,body`): its acceptance criteria are what the PR must
   deliver. The PR description still decides what is deferred. A criterion that is
   neither met nor deferred is a scope finding.
3. Check out safely, as H2 says: record the original branch, stop on a dirty tree
   (the user decides what happens to their changes), `gh pr checkout <n>` (not a fetch
   of the head ref, which fails for forks), `git fetch origin <base>`, and confirm
   `git rev-parse HEAD` equals `headSha`. That value is `reviewedSha`.
4. Mode: incremental if `myLastReview.commit` exists, `--full` wasn't passed, and
   `diff.sh … --since` doesn't exit 3. On exit 3 (history rewritten), say so and do a full review.
   Focus: if `lastApproval` is set, its commit isn't `headSha`, and
   `git merge-base --is-ancestor <lastApproval.commit> HEAD` succeeds, the approver never
   saw the later commits. Read `diff.sh <base> --since <lastApproval.commit> --file <PR files>`
   first and spend the most effort there. Still review the rest.
5. Size: if `reviewableLines` > `large_pr.lines` and not `--deep`, review the files
   with the most logic first (skip tests, fixtures, and ARB/JSON first), and list the
   files you didn't read under "Not checked".

## 2. Review: cheapest first

Read [references/review-guide.md](references/review-guide.md) once before 2c. It holds
how to understand the change, what to look for, the failure modes, how far to read
beyond the hunks, the procedures for prompt and instruction changes, the bar for better
fixes and suggestions, the confidence bar, and the false-positive list.

a. **Tooling.** Run `checks.analyze` on the changed files, and `checks.test` on the
   tests `checks.test_for` maps them to (only the ones that exist). If `checks.render` is
   set, run it; a render that fails is a finding. Don't hand-review anything the
   analyzer already reports, or any rule under "Enforced by tooling".
b. **Rule scan.** `scripts/rule_scan.sh <rules_file> <base> [--since …] --ignore …`.
   Each hit is a lead to confirm in context, not a finding.
c. **Understand.** Before looking for defects, read `diff.sh <base> --stat` and write
   the change model (review-guide § Understand the change first): what the PR is for,
   the 2–3 design decisions it makes, what must be true for each, the paths it removes
   or blocks, and their risk order. These are working notes; they are not presented.
d. **Read.** Read `rules_file`, then the **Failure modes** list in each pack named in
   `stack:` (`references/stacks/<name>.md`; review-guide § Failure modes). Then read
   `scripts/diff.sh <base> [--since …] --ignore …`, in risk order. Check correctness,
   consistency, conventions, tests, scope, design, and those failure modes. A pack line
   that "Enforced by tooling" or "Don't flag" already covers is not a second check. A
   project rule that covers only part of a pack line leaves the rest in force. For a
   pack line with a `grep:`, search the added lines and treat a hit as a lead, the same
   as a rules.md hit.
   Read surrounding code by line range around each hunk; open a whole file only when a
   finding depends on it. Search for dependents of what changed and for the routes of
   what it removes (review-guide § Beyond the hunks), and mark every hit stale or fine.
   If the diff changes prompts, skills, agent instructions, or templates,
   run the procedures in review-guide § Prompt and instruction changes.
e. **UI.** Only if the PR touches UI and a design link is found (look in `design.look_in`
   order; for `tracker`, match `tracker.story_id_pattern` in the branch name, then use
   K1). Then read [references/ui-check.md](references/ui-check.md) and the design adapter.
   No link: add "UI check skipped: no design source" to Not checked.
f. **API.** Only if the diff changes DTOs, API clients, or schemas and `api_contract`
   is set. Check just those fields with `scripts/openapi_fields.sh "<url>" schema.field …`.
   Get the URL from `url_from` / `url_env` / `url`, and never print it.
g. **Other reviewers.** Their findings are claims to verify in 2i, like yours.
   - `--deep`: dispatch `architecture.reviewer` with the Agent tool. The prompt opens with
     `architecture.report_only_prompt` verbatim, then gives: the repo path, the diff
     command, one paragraph on what the PR does, and the findings so far with "don't
     repeat these". Ask it to say plainly if it finds nothing.
   - `--second-opinion`: the tool and model come from the flag (`=codex`,
     `=claude:sonnet`), else from `second_opinion.use` and `.model`, else ask the user
     which one (list the installed ones, adapters/second-opinion.md). Right after 2c,
     write the PR-intent paragraph to a scratch file and start
     `scripts/second_opinion.sh <tool>[:<model>] <base> [--since …] --ignore … --summary <file>`
     (plus `--command`, `--timeout` from the config) in the background; it takes minutes.
     Collect its report here. Exit 3: say which tool is missing or logged out and how to
     fix it, and go on without it. Exit 4: it wrote to its throwaway worktree; say so and
     distrust its report. Exit 5: list the failure under Not checked. The script is not
     pre-approved on purpose: it runs another agent on the user's account.
   - Without a flag, list "Architecture agent: not run (use --deep)" under Not checked.
h. **Fixes and suggestions.** Work out the minimal fix for each finding, and look for a
   better one (review-guide § Fixes). Each finding keeps **one** fix: the better fix when
   it meets the bar and fits in this PR, otherwise the minimal fix. A better fix too big
   for this PR becomes a design suggestion instead. Then collect design suggestions under
   the same bar, at most `suggestions.max` in all (default 3; 0 turns them off). A
   suggestion is not a defect: the code works as it is. A finding that scores below the
   confidence bar (review-guide § Confidence bar) keeps the minimal fix; don't search
   for a better one.
i. **Verify and de-duplicate** as the review guide says. That includes fixes: a regex,
   snippet, or restructure you propose is proven in a scratch worktree
   (`git worktree add <scratchpad>/verify <reviewedSha>`), never in the user's checkout,
   and a fix to a prompt or instruction is also walked through. De-duplicate against both `existingComments` threads and `reviewBodies` entries,
   open or resolved (review-guide § Verify, step 5).

Record for each finding: kind (issue | suggestion), path, line, what is wrong (or what
could be better), the one fix (and its axis, when it's the better fix), dimension,
severity (critical / major / minor; suggestions have none), confidence score (issues
only; it decides whether the finding is listed under Issues or Below the bar), and
**placement**, using `files[].hunks`:

| Condition | Placement |
|---|---|
| The line falls inside a hunk | `line` |
| The file is in `files`, but the line is outside every hunk | `file` (a comment on the file) |
| The file isn't in the PR | `body` (goes in the review body) |

Never move a finding to another line to get it inline. GitHub silently drops a comment
outside every hunk, and a nearby line points the reader at the wrong code. A fix meant
as a suggested change replaces a line range: record `start_line` too when it spans
several lines, and keep both ends in the same hunk.

## 3. Present

Read [references/comment-style.md](references/comment-style.md) once here: it holds
the review body template and status rules used below, and the comment rules for step 4.

If no finding reaches the bar, say so. List what you checked, what you couldn't, and
the analyzer and test results. If any finding scored below the bar, list it under
"Below the bar", as in the template below. If `openFromOthers` isn't empty, list those
threads under "Open threads from other reviewers", as in the template below. Show a
draft body-only review: "Ready to merge from my side. Reviewed …", or "Ready to merge
from my side, apart from @a's open comments. Reviewed …" when another reviewer has open
threads (comment-style.md § The review body). Then ask how to post it: `approve`,
`comment`, `body: <text>` (replaces the body, then ask again), or `none`; when the Below
the bar list isn't empty, the user may also pick `B` numbers or `all+B`, which makes it a
normal selection (the rules after the template apply). Leave `approve` out, and say why,
when `isDraft` is true or `author` equals `me`. Post only on `approve` or `comment`, or
on a selection, through step 4.2–4.4, then go to rules feedback and the branch offer.

Otherwise:

```
## PR Review: #{number} — {title}   ({full | incremental since abc1234}{; focus: since def5678, approved by {login}})

### Scope (from PR description{ and #issue})
- {item} … (Out of scope: {deferred items, or "none noted"})

### Positives
- {what was done well}

### Issues Found ({N})
[1] path/to/file.ext:{line} [{SEVERITY}] ({score})
    {What is wrong.}
    Fix: {the one fix; when it's the better fix, add the axis, e.g. "(covers 4 more instances)"}
[2] path/to/file.ext [{SEVERITY}] ({score}) — line not in diff, posts as a file comment
[3] path/to/file.ext:{line} [{SEVERITY}] ({score}) — file not in PR, posts in the review body

### Suggestions (optional, {M})
[S1] path/to/file.ext:{line}
    {What could be simpler or sturdier, the change, and why it's better.}

### Below the bar ({K}, scored under 60; posted only if picked)
[B1] path/to/file.ext:{line} [{SEVERITY}] ({score})
    {What is wrong, and why it scored under the bar.}
    Fix: {the minimal fix}

### Checks
analyze: {clean | N issues}   tests: {passed | N failed | none mapped}   render: {ok | failed | not set}

### Not checked
- {skipped dimension, unread file, or unverified lead}

### Open threads from other reviewers
- @{login}: path/to/file.ext:{line} — {first line of the comment}{ (outdated)}
- @{login}: requested changes in their latest review

### Review body (draft)
{Status}. {What you reviewed.} {Concern that ties the comments together, only if real.}

Post which? Numbers (1,3,S1,B2), 'all' (Issues Found only), add '+S' for suggestions or '+B' for below-the-bar findings ('all+S+B'), or 'none'. Add `approve` when nothing you pick is an issue (`approve` alone posts only the body; `S1 approve`). `body: <text>` replaces the body. `edit n` to rework one, or `n: <your fix>`.
```

Order the Issues and Below the bar lists by severity, then score, highest first. Leave
out the Suggestions section when there are none, the Below the bar section when nothing
scored under the bar, and the Open threads section when `openFromOthers` is empty. For a
reviewer in `openFromOthers`, list each unresolved thread they started from
`existingComments` (mark `outdated` ones, whose code has since changed), plus the
"requested changes" line when `changesRequested` is true. Leave out
the `approve` hint when `isDraft` is true or `author` equals `me`. The fix shown is the
fix posted; never show a second one. If the user wants a different fix ("use the smaller
one"), that is a revision (`edit n` or `n: …`).

The body's status follows the severities of what the user selects (comment-style.md §
The review body). If the selection changes them, re-derive the status and show the final
body in the dry run. The event follows the selection too:
- It holds an issue (a below-the-bar finding counts as one): the event is `COMMENT`. If
  the user also said `approve`, say that an approval needs a selection with no issues,
  and ask them to drop the issues or post as a comment.
- It holds no issues (body only, or suggestions only): the event is `APPROVE` when the
  user said `approve`, and `COMMENT` when they said `comment`. If they said neither, ask
  `approve` or `comment` before the dry run.

On `edit n` or `n: …`, follow [references/revisions.md](references/revisions.md). A
revised finding is posted only when its number is selected.

## 4. Post

On `none`: report in chat only, then do the rules feedback and branch offer below.

Otherwise:
1. Rewrite each selected comment with its fix, and the body, as comment-style.md says. If `comments.rewrite_skill` is set and available, run the
   texts through it in one batch. Code in suggestion blocks is passed through unchanged.
2. H6: if the PR head is no longer `reviewedSha`, the author pushed. Re-checkout, re-run
   `pr_context.sh`, re-locate each selected finding, and re-derive its placement. Drop
   findings whose code is gone, and name them. If the event is `APPROVE`, stop there and
   tell the user: the approval would cover commits you haven't read. Offer to review the
   new commits first (incremental mode) or to post as a comment.
3. Write `{pr, event, body, findings:[{path, line, start_line?, placement, severity, text}]}`
   to a file in the scratchpad (`event` is `COMMENT` or `APPROVE`; suggestions use
   severity `suggestion`; `findings` is empty for a body-only review). Run
   `scripts/post_review.sh <file> --dry-run`, then without it. This script is not
   pre-approved on purpose, so the user sees the post before it happens. It refuses
   `APPROVE` when a finding is an issue, the PR is a draft, or the PR is the user's own.
4. Report the review URL, the event, and the landed / moved-to-body rows. If a row is
   missing, say which finding and give its text so it can be posted by hand.
5. Rules feedback (setup.md § Keeping them current). Propose a one-line edit when a
   rule's grep produced only false leads (a tighter pattern or an `exclude:`), or when
   a finding is a pattern a rule could catch next time. In incremental mode, also say
   how the author handled your earlier threads (fixed, declined with a reason, still
   open), and offer to add declined ones to the rules file's "Don't flag" section.
   Change the rules file only on a yes.
6. Offer to switch back to the original branch, only if you switched away from it.

## Hard rules

- Never edit source files, and make sure the architecture agent and second-opinion
  reviewer don't either. Fixes are proven in a scratch worktree, which is removed afterward.
- Post nothing before the user selects. The review event is `COMMENT`, or `APPROVE` only
  when the user said `approve` and nothing selected is an issue. Never approve on your
  own judgment, on a draft, on the user's own PR, or on a head you didn't review. Never
  `REQUEST_CHANGES`. The body never says "Approved" or "LGTM"; the event carries the
  approval.
- Never present a finding you haven't verified, including one the user rewrote, if it
  makes a new factual claim. The same goes for a better fix or a suggestion.
- A suggestion is never presented or posted as a defect, and is posted only when the
  user selects it by its `S` number or with `+S`.
- A below-the-bar finding is listed only under Below the bar, never mixed into Issues
  Found, and is posted only when the user selects it by its `B` number or with `+B`.
- Never check out over a dirty working tree. Always diff against `origin/<base>`.
- Scratch files (test probes, findings JSON, verify worktrees) go in the scratchpad and
  are deleted afterward.
