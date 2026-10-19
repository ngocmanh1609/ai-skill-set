# Review guide

## Contents
- Understand the change first
- What to look for
- Failure modes
- How much code to read
- Beyond the hunks
- Prompt and instruction changes
- Fixes: minimal, better, and suggestions
- Verify every finding
- Confidence bar
- Not a finding (false positives)

## Understand the change first

Before looking for defects, write working notes (not shown to the user):

1. **Intent.** One or two sentences on what the PR is for, from the body, the linked
   issue, and the diff stat.
2. **Decisions.** The 2–3 design choices the PR makes: a new abstraction, a data shape,
   where it hooks into the flow, what it deliberately leaves out. For each, write what
   must be true for it to be right, and the obvious alternative.
3. **Removed paths.** What the PR takes away or blocks: a fallback, a default, a branch
   of a condition, an accepted input, or a new stop, refusal, or required precondition.
   For each, note who reached it before.
4. **Risk order.** Rank the decisions and removed paths by what breaks, and for whom, if
   the assumption is wrong. Read in that order, not in file order.

A finding that challenges a decision names the assumption that fails. "I'd have done it
differently" is not a finding.

## What to look for

| Dimension | Look for |
|---|---|
| correctness | logic errors, wrong conditions, missing `await`/error handling, null or empty cases, races, state that can go invalid, resource leaks, off-by-one, broken contracts with callers, an input that used to work and now has no route. In instructions: steps in an order that loses work, a failure or edge state with no path, a step the agent can't do with what it was given, a decision whose result is never recorded where the next step reads it |
| consistency | the change leaves another file stale or contradicted: a renamed path, heading, field, key, term, or rule still used in its old form elsewhere |
| convention | breaks of a rule in `rules_file` that tooling doesn't already enforce |
| architecture | layer and dependency rules in `rules_file` (the cheap ones; `--deep` goes further) |
| design | a clearly simpler or sturdier shape exists (see Fixes), or the change rebuilds something the repo already has |
| testing | new behavior with no test, tests that can't fail, assertions that pass whatever the code says, test rules in `rules_file` |
| scope | something the PR description or linked issue promises is missing from the diff, or the diff carries unrelated changes. Deferred items aren't findings |
| ui | differences from the design (see ui-check.md) |
| api | DTO fields, types, or optionality that don't match the contract |
| security | secrets in code, injection, unchecked input at a trust boundary, auth checks removed |

Weight effort by risk: the decisions you ranked first, then logic, state, and data
handling; renames and copy last.

## Failure modes

These six are bugs in every language. Walk them on every review, then walk the local
shape in each pack named in `config.stack` (`references/stacks/<name>.md`, the
**Failure modes** list only). Seed conventions in those packs are setup-only. Do not
apply them at review time.

A pack line that a `rules_file` rule already checks is the same check, not a second
finding. A line under "Enforced by tooling" or "Don't flag" drops the matching pack
line. A project rule that covers only part of a pack line leaves the rest in force.
For a pack line with a `grep:`, search the added lines and treat a hit as a lead, the
same as a rules.md hit.

The confidence bar still applies. A named mode is not a finding until it is verified
and scored (§ Confidence bar).

1. **A resource is never released.** A subscription, controller, handle, lock,
   transaction, file, or task is created and has no dispose, cancel, or close on the
   path that leaves the screen or the request.
2. **An error is swallowed.** The caller sees success, an empty value, or the previous
   state when the call failed. A deliberate `unawaited`, or a documented choice to keep
   the current value, is not this.
3. **Work runs on the wrong thread or actor.** UI work runs off the main actor,
   blocking work runs on the UI thread, or a callback touches a disposed or unmounted
   owner.
4. **A list row is identified by its position.** Items can move, and the row holds
   state (a field, a selection, an expansion). A static list with no per-row state is
   not this.
5. **Data crosses a trust boundary with no check.** Untrusted input is used raw, an
   auth check is missing on a new entry point, or a secret, token, or private payload
   is written to a log or an analytics event.
6. **An update drops a field a reader still uses.** A copy, `copyWith`, or spread
   builds the next value and leaves out a field the screen, the next call, or a later
   emit still reads.

## How much code to read

- Start from the diff. For context, read by line range: about 30 lines around each hunk,
  plus the signature of anything the hunk calls or overrides.
- Open a whole file, or search for callers, only when a candidate finding depends on it
  (for example, "this can be null": find where the value comes from).
- Don't read generated files, lock files, or anything in `ignored`, except the composed
  view below.
- Incremental mode: read only the new range, but check whether it breaks something
  said in an existing comment thread.

## Beyond the hunks

Read outside the diff when the change can break something there:

- **Dependents.** For each path, heading, identifier, config key, field, or term the PR
  renames, removes, or gives a new meaning, run `git grep -n` over the whole repo,
  including docs, prompts, tests, and generated mirrors. Do the same for each concept
  the PR removes or moves (a responsibility, a step, a phase, an artifact): list the
  names and phrasings it goes by, and grep for each. Mark every hit stale or fine in the
  working notes, and present nothing while a hit is unmarked. A stale use in a file the
  PR didn't touch is a `body` finding.
- **Removed paths.** For each removed path in the change model, search by behavior, not
  by the removed text: the docs, flows, and callers that relied on it rarely quote it.
  Look for each kind of input that reached the path (the rules file's "Walkthrough
  inputs", when it has them) and for docs that describe the old behavior. Each one needs
  a route after the PR, or the PR description must drop it on purpose and say why.
- **Siblings.** When the PR adds something that has siblings (a command next to other
  commands, an adapter next to adapters, a test group), open one sibling and compare.
  What do the others do that this one skips, and is the skip on purpose? A sibling that
  does the same thing is also evidence that a pattern is deliberate.
- **Callers and includers.** For a changed function, its callers. For a changed partial
  or template, the files that include it.

## Prompt and instruction changes

When the diff changes prompts, skills, agent definitions, commands, or templates, the
code runs inside a model. Run these four checks, in order:

1. **Composed view.** For each changed partial or template, find its includers
   (`git grep -n "{{> name"`, or the project's include syntax) and read one includer the
   way the model receives it: the rendered file under `composed_paths`, or the output of
   `checks.render`. Look for headings that appear twice, a heading level that doesn't
   fit where the partial lands, and an included instruction that contradicts the host
   prompt's own rules. Composed files are read, never commented on: anchor the finding
   in the source file.
2. **Walkthrough.** Follow the instructions step by step as the agent would: first the
   common case, then each kind of input that reaches the changed steps. Take the kinds
   from the rules file's "Walkthrough inputs" when it has them, otherwise from what the
   docs and the code's branches tell apart, and include at least one the PR doesn't
   name. Where does the agent get stuck, need something it wasn't given, lose work to
   step order, or face two instructions that can't both hold? At each decision point
   (ask the user, choose, stop), follow every branch to where its result is recorded and
   who reads it next. A result with no recorded place, or one the next reader won't
   find, is a finding.
3. **Authority.** When an instruction lets an agent or role change something (a spec,
   a story, a config, a branch, another role's output), check who owns it elsewhere in
   the repo. A new permission that another prompt forbids, or that skips an approval,
   is a finding.
4. **Wording the model will misread.** "Optional" sections with no condition (models
   tend to include them), lists that read as "output all of these" when one is meant,
   criteria with no threshold ("large", "many", "e.g. 10+"), terms that differ from the
   glossary, and tool names without the MCP server or CLI that provides them.

## Fixes: minimal, better, and suggestions

Every finding gets a **minimal fix**: the smallest change that removes the defect.

Add a **better fix** only when it is strictly better on an axis you can name, and say
which one:
- it removes a class of bug, not just this instance (count the other instances and give
  the number)
- it reuses something the repo already has (name it)
- it makes the rule structural, so a table column, a type, a test, or a schema holds it
  instead of prose someone must remember
- it deletes more than it adds

It must also be concrete (show the change), verified (build, render, or test it in the
scratch worktree), and small enough for this PR, or labeled as a follow-up.

**One fix per finding.** The user and the author see the same single fix:
- the better fix, when it meets the bar and fits in this PR;
- otherwise the minimal fix. A better fix too big for this PR becomes a design suggestion
  ("Optional: as a follow-up, …"), not a second fix on the finding.

A **design suggestion** is a better shape for code that already works. Raise at most
`suggestions.max` (default 3) per review, each meeting the same bar. Good candidates come
from the change model: a decision whose obvious alternative is simpler, or a new piece
that duplicates one the repo has. A suggestion has no severity and is never counted as
an issue.

What misses the bar stays dropped: taste, "consider", a pattern from another codebase, or
a rewrite bigger than the PR.

Example. Finding: a config guide says every feature flag needs an owner, but the flag
this PR adds has none. Minimal fix: add an owner to the new flag. Better fix: make
`owner` a required field in the flag schema, so a flag without one fails validation
instead of depending on a reviewer to notice (axis: makes the rule structural). Every
existing flag already has an owner, so it's a one-line schema change that fits the PR,
and the finding shows the better fix only.

## Verify every finding

Apply this to your findings, rule-scan hits, and other reviewers' claims alike:

1. **Context.** Read the code around it. Is it already handled upstream or downstream?
2. **Cheap proof.** When a claim is about runtime behavior, a scratch test in the
   scratchpad often settles it. Delete the test afterward. A proven claim can be worded
   firmly. Fixes get the same treatment: run the regex, render the template, apply the
   snippet and run the test. A fix to a prompt or instruction also gets the walkthrough
   (§ Prompt and instruction changes, item 2) on the fixed text: a render and passing
   tests show that it builds, not that the agent can follow it.
3. **PR description.** If the author documented the behavior as deliberate, it isn't a
   finding, unless their reasoning is wrong. Test the reasoning before accepting it: for
   a removed path, against every kind of input that reached it (§ Beyond the hunks,
   Removed paths). If it fails, answer that reasoning directly.
4. **Quote-check the rule.** For a convention finding, grep the `src:` section the
   rule cites and confirm it says what you claim. An agent citing a rule is not proof
   that the rule exists.
5. **Duplicates.** Drop it if an `existingComments` thread (open or resolved) or a
   `reviewBodies` entry already raises the same problem. If a thread was resolved
   without a fix and the problem is still there, you may raise it again; say so.

Anything that fails these steps is dropped. If it's worth mentioning but unconfirmed,
put it under "Not checked", not in the findings list.

## Confidence bar

Score each surviving finding 0–100. The bar is **60**:
- **100**: confirmed by running the code, or a direct, quoted rule break.
- **75**: checked in context, very likely hit in practice, or explicitly named in `rules_file`.
- **60**: checked in context and real, but whether it bites depends on data, a path, or
  an outside behavior (a backend, a device) you couldn't confirm.
- **50**: real but minor or rare.
- **25 or lower**: possible, unverified, or a style preference not in the rules. Drop it.

A finding at **60 or higher** is an issue. A finding **above 25 and below 60** goes under
"Below the bar": the user sees it and may still choose to post it. It passed every
Verify step, so its claims are true; the score only says it matters less or is less
likely to bite. It carries a severity, a placement, and the minimal fix (skip the search
for a better one).

Severity is separate from confidence: **critical** = wrong behavior, data loss, or a
security hole; **major** = a rule break or a bug in a less common path; **minor** = small
convention or clarity issues.

Better fixes and suggestions aren't scored: they meet the bar in Fixes, or they're dropped.

## Not a finding (false positives)

- Problems on lines the PR didn't touch, unless the PR makes them worse or newly
  reachable, or leaves them stale (see Dependents).
- Anything the analyzer, compiler, formatter, or a rule under "Enforced by tooling" catches.
- Behavior changes that are clearly intended and follow from the PR's purpose.
- A rule break silenced in the code on purpose (an ignore comment with a reason).
- Anything under the rules file's "Don't flag" section.
- General wishes (more tests, more docs, more abstraction) that no rule asks for. A
  concrete better fix that meets the bar in Fixes is not a wish.
- Pedantic nits a senior engineer wouldn't raise.
- Items the PR description defers to a follow-up.
