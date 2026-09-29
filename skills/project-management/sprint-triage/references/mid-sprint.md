# Mid-sprint mode

Stories added after planning are extra scope for a team that's already committed. So this
mode answers three questions, and nothing more:
1. What changed since the last triage?
2. Are the new stories ready?
3. Do they fit the time left, and if so, who takes them?

It doesn't re-triage stories that were already checked, and it doesn't touch owners the
team already chose. Under the Scrum Guide, scope "may be clarified and renegotiated with
the Product Owner" during a sprint. If the new work doesn't fit, the answer is a question
for the PM, not silent overload.

## Contents
- When it runs
- Find what changed
- No snapshot for this sprint (fallback)
- Capacity left
- Fit check
- Owners
- Report

## When it runs

- **Automatically:** `reports_dir` has a report whose snapshot says `sprint: <current sprint id>`.
  Use the newest one as the baseline.
- `$ARGUMENTS` contains `new`: force this mode (use the fallback if there's no snapshot).
- `$ARGUMENTS` contains `full`: skip this mode and run a full triage.

## Find what changed

Compare the snapshot's `stories` with a fresh **T2** of the team's stories in the sprint,
**in every state**, not just the ready and backlog columns:

| Group | Rule | What to do |
|---|---|---|
| **Added** | in the sprint now, not in the snapshot (skip ones already `done`) | full readiness check, then suggest owners |
| **Removed** | in the snapshot, gone from the sprint now | list them; their size frees capacity |
| **Reopened** | in both, but lost its owner, or moved back to `backlog` from a later state | re-check readiness; suggest an owner if it lost one |
| Everything else | unchanged, moved forward, or handed to another member | don't re-triage; use the current state and owner for load, and mention owner changes in one line (the team decided those) |

Also re-read the snapshot report's "Ask the PM" list. For each question, check whether a
scope owner replied since (**T3** comments). List the ones still open.

If a story in the Added group already has an owner, the PM or a developer assigned it.
Keep that owner, count its load, and still run the readiness check.

## No snapshot for this sprint (fallback)

This happens when the sprint was planned without this skill.
1. Ask when planning happened. Default to the sprint start date from **T1**.
2. Build candidates cheaply:
   - team stories in the sprint with **no owner** (any state except `done`)
   - stories **created** on or after the planning date. Use the tracker's search with a
     created-date filter, then keep only IDs that are in the sprint.
3. Use **T9** (when did it join the sprint) only for candidates you can't place. History
   calls are large, so don't run them on every story.
4. Show the candidate list and ask the user to confirm or edit it before triaging. The
   user usually knows which stories are new.

## Capacity left

Per member, in days:
- **Days left:** `scripts/workdays.sh <today> <sprint end>`, minus leave or holidays the user mentions.
- **Available:** days left × `capacity` × 0.7. The 0.7 is the same focus factor as the
  assignment guide: meetings, reviews, and support eat about 30% of any day.
- **Committed:** for each story they own that isn't `done`, its size in days
  (`tracker.size_days`) × the remaining fraction from the assignment guide (`ready` 1.0,
  `in_progress` 0.5, `in_review` 0.2, `qa` 0.1). A story with no size counts as M. Say
  how many had no size, because the numbers are only as good as the sizes.
- **Room:** available − committed. Negative means already overloaded.

These are rough numbers for a conversation, not a plan. Show them rounded to half a day.

## Fit check

Compare the total size of the **ready** Added and Reopened stories with the team's total
positive room.
- **Fits:** suggest owners (see below).
- **Doesn't fit:** say by how many days. Then propose what could move out of the sprint,
  in this order:
  1. stories in the ready column that turn out not to be ready (blocked, on hold)
  2. unstarted stories with the lowest priority
  3. the largest unstarted story that isn't needed for the sprint goal

  Write it as a question for the scope owner ("To add 80701 (M), we could move 80513 (S)
  and 80516 (M) out. OK?"), drafted as a comment on the added story. Don't move anything
  out without that answer and the user's approval.
- **Added stories that aren't ready:** flag them to the PM with the specific gap, and
  don't give them an owner.

## Owners

- **Keep existing owners.** Don't propose changing an owner the team already set, unless
  the user asks to rebalance.
- Suggest owners for the new ready stories using room first (who can actually absorb it),
  then affinity from the assignment guide.
- If someone's room is already negative, say so as information. Suggest moving one of
  their unstarted stories to someone else only when the user asks to rebalance.

## Report

A short version of the report template:
1. **Context:** sprint, days left, the snapshot you compared against (date), and the
   fallback if it was used.
2. **What changed:** Added / Removed / Reopened, with one line each.
3. **Readiness of the added stories:** same verdicts and evidence as a full triage.
4. **Capacity:** one row per member: days left, available, committed, room.
5. **Fit:** fits, or short by N days, plus the swap question for the PM.
6. **Suggested owners** for the new ready stories, with evidence.
7. **Open PM questions:** carried over from the snapshot report.
8. **Suggested tracker changes**, then a **new snapshot** after applying.

Save it as a new file (`<sprint id>-<YYYY-MM-DD>-mid.md`), so the next mid-sprint run
compares against the latest state.
