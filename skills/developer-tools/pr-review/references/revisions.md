# Revising a finding before it is posted

The fix attached to a finding is a proposal. The user knows the codebase and its history
better than one review pass does, so treat a rewrite as a correction, not an objection.

Two forms, possibly several at once (`edit 2, 5`) and mixed with a selection (`all, 3: …`):
- **`edit 3`**: they want [3] changed but haven't said how. Ask one short question, then apply the answer.
- **`3: use a nullable getter instead`**: the fix is in the message. Apply it; don't ask.

When applying one:
1. **Write the new fix in your own words.** Don't paste their sentence, and don't
   attribute it to them in the posted comment. The PR should read as one recommendation.
2. **Keep the problem statement** unless they disputed it too. If they reject the
   premise, drop the finding instead of rewriting it.
3. **Say so if their fix has a real problem**: it doesn't compile, breaks a rule in
   `rules_file`, or brings back something verification already disproved. Say it in a
   sentence or two and wait. If they confirm, apply it as given. Don't argue again.
4. **Re-verify** (review-guide.md) if the new fix makes a factual claim the old one didn't.
5. **Re-derive the placement** if the anchor line moves, and update the severity if asked.

Then re-print only the changed findings, keeping their number (`[n]`, `[Sn]`, or `[Bn]`;
a revision doesn't move a finding across the confidence bar), and ask the selection
question again. Stay in this loop until the user gives a selection or `none`.
