# Writing the posted comments

The author reads each comment in a diff, often on a phone, next to many others, and may
be new to the code or the tool. Write **one short paragraph**, or two at most: the effect
first, then the cause, then the fix, linked with connecting words ("because", "so",
"however"). Don't add labels or bullet points to give it structure. Short means nothing
extra, not packed: explain a term a newcomer wouldn't know instead of cutting it. One short code
block is fine when the fix is easier to show than to say.

Cut from the posted text:
- **How you verified it** ("I traced both callers", "confirmed by running the tests").
  That was for the user in step 3. The author can't act on it.
- **Their own code quoted back at them**, unless the comment makes no sense without it.
- **Before/after snippet pairs.** One snippet (the fix), or none.
- **A second fix.** A comment carries the one fix shown in step 3. Don't add an
  alternative.
- **Alternatives that miss the better-fix bar** in the review guide.
- **Severity labels, dimension tags, finding numbers.** They mean nothing on the PR.
- **Hedging**: "worth considering", "you may want to", "just a nit but". Say the thing.

Keep:
- **Every fact, path, identifier, and line reference, exactly.** Shorter isn't vaguer.
- **The substance.** A real correctness bug with a non-obvious failure path can take two
  paragraphs. But a minor finding that grew past a short paragraph is usually carrying
  something from the cut list.
- **The reason a better fix is better**, when that's the fix posted: one clause naming
  the axis (the other instances it covers, what it reuses, what it makes structural).

**Suggested changes.** When the fix replaces the commented lines exactly, and you applied
it in the scratch worktree and it worked, put it in a ```` ```suggestion ```` block so the
author can apply it in one click. The block replaces every line from `start_line` to
`line`, so it must hold the full new text of those lines, indentation included. Don't use
one when the fix also touches other lines.

**Design suggestions** start with "Optional:", so the author can tell them from defects
at a glance. Then say what to change and why it's better, in one clause. The same length
limits apply.

**Too long:**

> `fromSelection(allSelected: true, anySelected: false)` is a contradiction, but the factory accepts it and quietly returns `full`. Since this is now the single shared entry point for tri-state resolution, it is worth guarding here rather than trusting each future caller. I checked both current callers and neither can produce the bad pair: one derives both flags from the same list, and the other always passes a non-empty list. So this is defensive, not a live bug.

**Right:**

> `fromSelection(allSelected: true, anySelected: false)` is a contradiction, but it returns `full`. Neither caller can produce it today, so add `assert(!allSelected || anySelected)` to stop the next one from doing it.

**Right, posting the better fix:**

> With the `s` flag, `.*` runs to the end of the file, so this assertion also matches text in a later section and passes even without the flag. A `section(text, heading)` helper would let each assertion see only the section it tests, which also fixes 4 other assertions in this file that use the same whole-file `.*` match.

**Right, a design suggestion:**

> Optional: `formatPrice` and `formatAmount` differ only in the currency symbol. One `formatMoney(value, { symbol })` would replace both and their three callers, so the two can't drift apart.

## The review body

Inline comments hold the specifics. The body holds what they can't: where the PR stands,
a concern that spans several comments, and what you looked at. `post_review.sh` puts the
"Findings outside the diff" section under it.

```
{Status}. {What you reviewed, in one clause.}
{Only if real: the concern or pattern that ties the comments together, 1–2 sentences.}
{Only if it affects the merge decision: what you didn't check.}
```

The status comes from the severities of the **selected** issues, not from how the review
felt:

| Status | When |
|---|---|
| Ready to merge from my side | nothing posted but the body, or only suggestions |
| Ready to merge from my side, apart from @a's open comments | the same, while `openFromOthers` lists other reviewers |
| Fine to merge once the comments are addressed | only minor issues; you don't need to look again |
| Needs changes before merge | at least one major or critical issue; you'll look again |
| Needs a decision | a design question you can't settle; name who decides |

Rules:
- Never write "Approved" or "LGTM". When the user chose `approve`, the event carries the
  approval, and the body reads the same as it would for a comment.
- **Other reviewers' open comments.** When the status is "Ready to merge from my side"
  and `openFromOthers` isn't empty, add the note and name every login in it with an
  `@`, in order: "apart from @a's open comments",
  "apart from @a's and @b's open comments", "apart from @a's, @b's, and @c's open
  comments". This covers a reviewer who only requested changes, too. Don't summarize,
  judge, or repeat their comments. Leave a login out only when the user says to. The
  `@` notifies them, which is the point: their open comments still need an answer.
- **Coverage** is a fact: "the commits after the approval at `abc1234`", "the full diff,
  including the assembled prompts for the changed partials". In incremental mode, say
  what happened to your earlier comments (fixed, still open).
- **The concern line** appears only when two or more comments share a cause, or a design
  issue is bigger than any one line. A forced theme is worse than none.
- **What you didn't check** appears only when someone deciding whether to merge would
  want to know it (for example, model-based evals that weren't run).
- 2–4 lines. No counts, no "Left N comments", no restating the inline comments, no
  praise, no summary of what the PR does.

**Right, minor issues with a shared cause:**

> Fine to merge once the comments are addressed. I reviewed the commits after the approval at `abc1234`: the new template sections and the checks that validate them. Both comments are cases where something looks enforced but isn't: a validation rule that rejects input the template itself produces, and a test that passes whether or not the flag is there.

**Right, a re-review:**

> Ready to merge from my side. Re-reviewed the commits since `def5678`: both earlier comments are fixed, and nothing new came up.

**Right, nothing found (body-only review):**

> Ready to merge from my side. Reviewed the full diff, including the assembled prompts for the three changed partials. No issues found.

**Right, nothing found while another reviewer has open threads:**

> Ready to merge from my side, apart from @a's open comments. Reviewed the full diff: the new analytics events, their call sites, and their tests.
