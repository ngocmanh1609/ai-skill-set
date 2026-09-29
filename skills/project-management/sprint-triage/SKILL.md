---
name: sprint-triage
description: >
  Triages a sprint in the team's issue tracker (Shortcut, Jira, or any tracker with an
  adapter): summarizes To Do and Backlog stories, checks each one against a Definition of
  Ready (API fields in the API contract, current design, required translations, blockers
  and link direction, unanswered PM questions, scope already built in code), flags
  concerns for the PM, and suggests owners from git history, current load, and
  availability. Mid-sprint, it triages only the stories added or changed since the last
  run, keeps existing owners, and checks whether the new work fits the days left. After
  explicit approval it applies owner and state changes and posts comments, then
  re-fetches to verify. Keeps a per-project config of tools and team, and offers to
  create it on first use.
when_to_use: >
  Use whenever the user wants to walk through, review, groom, refine, or triage sprint,
  iteration, or backlog stories; asks what is ready or who should take which story;
  prepares for sprint planning; says the PM added or changed stories mid-sprint; or wants
  sprint tasks assigned to the team, even without the word "triage".
argument-hint: "[sprint] [columns] | new | full | setup"
allowed-tools: >-
  Bash(${CLAUDE_SKILL_DIR}/scripts/*) Bash(git log *) Bash(git remote *) Bash(git rev-parse *)
  Bash(git check-ignore *) Bash(gh auth status*) Bash(gh pr list *) Bash(gh pr view *)
  Bash(glab auth status*) Bash(glab mr list *) Bash(glab mr view *)
  mcp__shortcut__iterations-search mcp__shortcut__iterations-get-stories
  mcp__shortcut__stories-get-by-id mcp__shortcut__stories-get-history
  mcp__shortcut__stories-search mcp__shortcut__users-get-current
---

# Sprint triage

Turns a sprint's stories into three things: a readiness verdict per story, concerns
worth raising with the PM, and a suggested owner plan. Then it applies only the tracker
changes the user approves.

The skill works with any tracker and code host that has an adapter:

| Kind | Adapter file | Status |
|---|---|---|
| Tracker: Shortcut | [adapters/tracker-shortcut.md](adapters/tracker-shortcut.md) | complete |
| Tracker: Jira | [adapters/tracker-jira.md](adapters/tracker-jira.md) | outline; tool names found at setup |
| Code host: GitHub | [adapters/host-github.md](adapters/host-github.md) | complete |
| Code host: GitLab | [adapters/host-gitlab.md](adapters/host-gitlab.md) | outline |

The steps below use operation IDs (T1–T9 for the tracker, H1–H3 for the code host),
defined in [adapters/_contract.md](adapters/_contract.md). Read only the two adapters the
project uses. To add a tool, write a new adapter from the contract. Nothing else changes.

The work splits into a **read-only half** (steps 1–4) and a **write half** (steps 5–6).
Tracker writes are visible to the whole team, notify people, and are made under the user's
account. So nothing is written until the user has seen the exact change list and approved
it. Write tools are left out of `allowed-tools` on purpose, so each one still asks for permission.

## Modes

| Mode | When | What it covers |
|---|---|---|
| **Start** | no report exists for this sprint yet, or `$ARGUMENTS` has `full` | every story in the requested columns (default: ready + backlog) |
| **Mid-sprint** | a report for this sprint exists, or `$ARGUMENTS` has `new` | only stories added, removed, or reopened since that report, in any state; existing owners kept; a check that new work fits the days left |

Mid-sprint mode changes steps 1, 2 and 4 as described in
[references/mid-sprint.md](references/mid-sprint.md). Read it when that mode applies.

`$ARGUMENTS` may also name a sprint ("Sprint 19", "next sprint") or columns. `setup`
re-runs the config setup.

Copy this checklist into the conversation and tick it off as you go:

```
Sprint triage:
- [ ] 0 Config: loaded (or created), health check passed
- [ ] 1 Scope: sprint resolved, mode chosen (start / mid-sprint), availability known
- [ ] 2 Collect: stories, blockers, load, expertise, API, open changes, code overlap
- [ ] 3 Assess: readiness verdict + evidence per story
- [ ] 4 Propose: owners and order (+ fit check mid-sprint); report + snapshot saved
- [ ] 5 Approve: user picked the exact changes
- [ ] 6 Apply + verify: writes done, re-fetched, change log + new snapshot saved
```

## 0. Config

Read `<project root>/.claude/sprint-triage.yml`. If it's missing (or the argument is
`setup`), follow the setup flow in [references/setup.md](references/setup.md). It detects
the tools, asks the user about the rest, and saves the config after they agree. Then run
the health check from the same file. Every later step takes its IDs, people, states, and
paths from this config, so never hard-code them.

## 1. Scope

- Find the sprint with **T1**: the current one, or the next one when the user is preparing planning.
- Choose the mode. Look in `reports_dir` for reports of this sprint: their snapshot block
  has `sprint: <id>`. See the Modes table above.
- Availability: start from `team.members[].capacity`. If the user hasn't said who is away
  this sprint, ask once with `AskUserQuestion` (multi-select over the members). Capacity
  drives every later pick, so asking is cheaper than guessing.
- Start mode: if `reports_dir` has a report for the previous sprint, read its "Ask the PM"
  list. Questions that still have no answer carry over as concerns.

## 2. Collect: one parallel batch, then follow-ups

In one turn of parallel calls:
- **T2** for the sprint. From it, take:
  - **Scope:**
    - Start mode: the team's non-archived stories in the requested states.
    - Mid-sprint mode: the diff against the snapshot, in every state.
  - **Load:** everything team members own that isn't `done`, **including owned stories
    still in `ready`**. Mid-sprint, that is most of the committed work.
  - **Cross-team dependencies:** other teams' stories in the same sprint.
- **T3** for every in-scope story, using the adapter's cheap form first.
- `scripts/expertise.sh --repo <root> --area <each code.areas glob>`, plus one `--alias
  <email>=<name>` per member and "other" email, and one `--skip <email>` per
  `team.skip_git_emails` entry. Add `--id-pattern <tracker.story_id_pattern>`.

Then, in parallel, follow what those results point to:
- **T3** (full form, where the adapter says it's needed) for blockers, related stories
  outside the scope, and stories whose links or comment dates matter.
- The API contract check. For `api_contract.type: openapi`, run
  `scripts/openapi_fields.sh "<url>" schema.field ...` for the fields each integration
  story lists. Get the URL from `url_from` / `url_env` / `url`, and never print it.
- **H1** on `code_host.related_repos` for open changes to the specs the stories cite.
- Grep `code.model_paths` and the code for each story's key fields and widgets, to see
  whether the scope is already built.

## 3. Assess

Run every in-scope story through
[references/readiness-checklist.md](references/readiness-checklist.md) and give a verdict:
**Ready**, **Ready once …**, or **Not ready**. Two rules catch most surprises:

- The **newest PM comment beats the description.** "On hold", "design changed", and
  "I'll update the ticket" turn a planned story into Not ready.
- **Verify the claim, not the label.** A story marked blocked may be unblocked in code.
  An API story marked done may not have its fields in the contract. A story may already
  be built by another story that is in QA.

Split concerns into **Ask the PM** (needs a decision, with the exact question) and
**Smaller issues**. Attach evidence to each one.

## 4. Propose

Suggest owners with [references/assignment-guide.md](references/assignment-guide.md):
readiness first, then capacity, then affinity. Keep stories that share a screen with one
person. Give each person one "now" story, and give one line of evidence per pick.
Mid-sprint: keep existing owners, and run the fit check from
[references/mid-sprint.md](references/mid-sprint.md) before suggesting owners.

Write the report with [references/report-template.md](references/report-template.md).
It always ends with a **snapshot block**: every team story in the sprint, with its state
and owners. The next mid-sprint run compares against it, so don't skip it on a read-only
run. Save the report to `<reports_dir>/<sprint id>-<YYYY-MM-DD>.md` (add `-mid` in
mid-sprint mode). If the user's instructions ask for a plain-language pass (e.g. the
`plain-english` skill), apply it before showing the report.

## 5. Approve

Turn the proposal into a numbered change list. One line per tracker operation: story,
field, current value → new value. Include the full text of each comment. Then ask the
user which changes to apply (`AskUserQuestion`, multi-select by group: owners, state
moves, comments). If the user already said exactly what to apply, their message is the
approval: restate the list and go ahead.

Watch for these before applying:
- **Moving a Not-ready story to `ready`.** The ready column tells the team "start this".
  If the user asks for it, do it, but put what still blocks the story in the change log.
- **How the tracker handles owners (T4).** Some trackers replace the whole owner list;
  others allow one assignee. Follow the adapter's rules so nobody is dropped by accident.
- **Comments:** one per story. Mention the scope owner so they get notified (**T6**). Say
  what you saw, why it matters, and the exact ask. Apply the user's plain-language rule
  to the text, if they have one.
- Don't edit descriptions, links, estimates, or priorities unless the user asks. The PM
  owns story content, so ask them in a comment instead. Moving stories out of the sprint
  also waits for the PM's answer.

## 6. Apply and verify

- Send all approved writes in one parallel batch (**T4**, **T5**, **T6**).
- Re-fetch with **T2** (and **T3** where comments matter). Compare every changed story
  against the approved list.
- Report with the change-log format from the report template: what changed, what was
  verified, comment links, what was proposed but not applied, and caveats that still
  apply. Append the change log to the saved report, and **replace its snapshot block**
  with the state after the changes.

## Timing

Triage works best 1–2 days **before** sprint planning. That leaves the PM time to answer
questions, fix links, and update descriptions before anyone pulls a story. Run on day 1 of
a sprint, the same questions block work instead. Run mid-sprint mode whenever the PM adds
stories, before anyone starts them.
