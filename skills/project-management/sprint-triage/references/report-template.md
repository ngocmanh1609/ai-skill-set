# Report template

Use this structure for the triage report. Keep tables scannable. Put evidence (paths,
dates, story links) next to the claim it supports. Link every story ID the first time it
appears, using the adapter's story URL (**T7**).

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

## 2. Concerns
**Ask the PM (<scope owner>) before or early in the sprint**
1. **<one-line claim>.** <evidence> → Ask: <the exact question>.
**Smaller issues**
<n>. ...

## 3. Which stories are ready
| Ready now | Ready once … | Not ready this sprint |

## 4. Suggested owners
Existing load: <per person: stories and their states>
| Story | Suggested owner | Why (evidence) |
**Order:** Day 1 … / Next …
**Backup plan if held stories come back** (not part of the proposal)

## 5. Suggested tracker changes (not done; your call)
| # | Story | Change | From → To |
Comments to post (full text):
> ...

## Config notes
<drift found this run: unknown owners, unmapped states, members with no commits; suggested config edits>

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
Comments: [<id>](<comment URL>): <one-line summary of the ask>.
Not changed: <anything proposed but not approved>.
```
