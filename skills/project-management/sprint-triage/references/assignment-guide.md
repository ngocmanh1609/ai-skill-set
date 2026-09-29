# Suggesting owners

The output is a **proposal the team confirms**, not an order. Under the Scrum Guide the
developers choose who does what, so every pick needs a short, checkable reason. If
someone disagrees in planning, the reason shows what to weigh instead.

Suggest owners only from `team.members`. Refer to people by the name the user uses (`aka`).

## 1. Only assign what's ready

Give owners to **Ready** and **Ready once …** stories. Leave **Not ready** stories
unowned unless the user asks. An owned story in the ready column looks startable, and
someone will start it. If the user wants a Not-ready story owned anyway, give it to the
person who owns the related ready work, and mark it "starts after <condition>".

## 2. Capacity first

Work out who has room before looking at expertise:
- **Availability:** `capacity` from the config (the lead is usually lower), adjusted for
  what the user said about leave this sprint.
- **Existing load:** every story the person owns that isn't `done`, as size in days
  (`tracker.size_days`) × the fraction of work likely left in its semantic state:

  | State | Fraction left | Why |
  |---|---|---|
  | `ready` (owned, not started) | 1.0 | nothing done yet, but already committed |
  | `in_progress` | 0.5 | on average about half done |
  | `in_review` | 0.2 | review fixes come back |
  | `qa` | 0.1 | QA fixes come back |

- **Size:** use the tracker's size signal (`tracker.size_signal`), converted with
  `tracker.size_days`. If a story has none, count it as M and say so.
- Don't plan anyone to 100%. About 70% of available time is a sane default for new work.
- **Keep existing owners.** Owners the team already chose stay, unless the user asks to
  rebalance. Their stories still count as load.

## 3. Then affinity, strongest signal first

1. **Same screen or same files as another story:** give both to the same person and do
   them in order. Two people editing one section in parallel means merge conflicts.
2. **Continuity:** the parent or follow-up of a story someone owns or just finished.
3. **Pre-read:** whoever asked the clarifying questions in the story's comments already
   holds the context.
4. **Code history:** the expertise output from step 2 (commits per area, recent story
   IDs). Cite the numbers and story IDs.

## 4. Sequence and limit work in progress

For each person, list one **now** story (day 1) and the **next** ones. Stories that unlock
others (shared data, a screen that others navigate to) go first. When two stories meet at
a boundary (a route, a callback, an API field), name who agrees the contract with whom on day 1.

## 5. Spread knowledge on purpose

If one person holds most of an area's history and has spare capacity for only one story,
consider giving the second story in that area to someone else, with the expert as
reviewer. Offer it as an alternative ("stretch option"), not the default, and only when
the sprint has slack.

## 6. Plan for slipping dependencies

Stories that wait on another team's work get a later slot and a backup ready story for
the same person. Say what that person does if the dependency isn't there by mid-sprint.

## 7. Backup plan for held stories

If a batch of stories is on hold (spec change, design round), sketch who would take them
if they come back mid-sprint. Label it clearly as not part of the proposal.

## Evidence format

One line per pick, with checkable facts, for example:

> **80517 → Don**: most commits in `lib/feature/promotion` (38 in 90 days); built the
> similar paged list in sc-80293 / sc-80530; only one story in progress.
