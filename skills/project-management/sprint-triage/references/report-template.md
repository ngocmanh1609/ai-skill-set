# Report template

Use this structure for the triage report. Keep tables scannable. Put evidence (paths,
dates, story links) next to the claim it supports. Link every story ID the first time it
appears, using the adapter's story URL (**T7**).

The report has two parts the user acts on: the **story concerns** and the **suggested
owners**. Everything before them is information. The owners section is always last
(before the hidden snapshot), and it carries the change list. Capacity and fit are
reported, never drafted as a comment to the PM.

```markdown
# <Sprint name>: <Team>, <columns> review and suggested owners

## Context
Sprint <name> (<id>), <start> to <end>. <N> stories in scope (<n> ready column, <n> backlog).
Tools: <tracker> + <code host>. What was checked: story text/comments/links, blockers,
git history, code, API contract, open changes to cited specs.
Assumptions: <availability used>. **Nothing written to the tracker yet.**

## 1. What each story is
### <ready column name> (<n>)
| Story | What it does | Blockers and status |
### <backlog column name> (<n>)
| Story | What it does | Blockers and status |

## 2. Which stories are ready
| Ready now | Ready once … | Not ready this sprint |

## 3. Capacity
| Person | Available | Existing load (stories and states) | Room |
<If the work doesn't fit: short by N days, and what could move out. Information only; no comment.>

## 4. Story concerns
**Ask the PM (<scope owner>) before or early in the sprint**
1. **<story>: <one-line claim>.** <evidence> → Ask: <the exact question>.
**Smaller issues**
<n>. ...

## Config notes
<drift found this run: unknown owners, unmapped states, members with no commits; suggested config edits>

## 5. Suggested owners
| Story | Suggested owner | Why (evidence) |
**Order:** per person, Now … / Next …
**Backup plan if held stories come back** (not part of the proposal)

**Changes to apply (not done; your call)**
| # | Story | Change | From → To |
| 1 | <Ready story in backlog> | owner + state | none → <name>; backlog → ready |
| 2 | <Ready-once story> | owner | none → <name> (moves to ready when <condition>) |

<!-- sprint-triage-snapshot
sprint: <sprint id>
sprint_name: <name>
taken: <YYYY-MM-DD>
mode: start | mid-sprint
triaged: [<ids checked this run>]
stories:                # every team story in the sprint, all states, after any applied changes
  <id>: { state: <semantic state>, owners: [<aka names>] }
-->
```

The snapshot is an HTML comment: invisible when the report is rendered, but readable by
the next run. It lists **every** team story in the sprint, not just the ones checked, so
a mid-sprint run can tell new stories from old ones. Rewrite it after applying changes, so
it shows the state the team is actually working from.

For the mid-sprint report, use the shorter layout in [mid-sprint.md](mid-sprint.md)
(section "Report"), and end it with a snapshot block the same way.

## Change-log format (after applying)

```markdown
| Story | Change | Result |
|---|---|---|
| <id> | owner → <name> | ✅ verified |
| <id> | backlog → ready | ✅ verified. Still blocked by <id> |
Comments (only if the user asked for any): [<id>](<comment URL>): <one-line summary of the ask>.
Not changed: <anything proposed but not approved>.
```
