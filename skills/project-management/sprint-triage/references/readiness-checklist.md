# Definition of Ready: per-story checks

A story is **Ready** when a developer could start it today and finish it this sprint
without waiting on anyone. Each check below says what to look at and what counts as a
red flag. Record evidence (comment date, file path, API schema, story link) for every
flag, so the PM can act on it without re-investigating.

Verdicts:
- **Ready**: no blocking flags.
- **Ready once …**: one named, small condition (a translation, an updated description, a link fix).
- **Not ready**: waiting on another team, a design round, a spec decision, or unanswered questions.

## Contents
1. Latest signal from the PM
2. Acceptance criteria
3. Design
4. Copy and translations
5. API
6. Dependencies and links
7. Already built?
8. Contradictions between stories
9. Open questions
10. Spec changes in flight
11. The team's own checks
12. Housekeeping

## 1. Latest signal from the PM

Read comments newest first. The newest comment from a `team.scope_owners` person overrides
the description. Red flags: "on hold", "design changed / updated design", "I'll update the
description", "let me reframe". Several stories moved back to backlog at the same moment
(the adapter's full story record shows when a story moved) usually means a deliberate
decision. Ask why instead of guessing.

## 2. Acceptance criteria

Needs a testable AC list (Given/When/Then or plain bullets), plus what's out of scope.
Flag vague phrases that two developers would read differently, and quote them
(for example "aligned with design when that pricing still comes from existing product fields").

## 3. Design

Needs a design link (Figma or similar) for every new screen or state. Flag it when:
- A comment mentions a newer handoff or a design change after the description was last updated.
- Sibling stories that touch the same screen link different design frames. One of them is stale.

## 4. Copy and translations

Every new user-facing string needs every language in `readiness.locales`. Flag:
- the `readiness.missing_translation_marker` placeholder
- copy in only one language ("the app localizes it")
- dynamic strings with no stated source (API or app)

## 5. API

- The story names its endpoint or the API story it depends on.
- The blocking API story is done. Not started means **Not ready**: the UI can be built
  against sample data, but the story can't be finished.
- The fields actually exist in the contract:
  - With `api_contract.type: openapi`, run `scripts/openapi_fields.sh <url> schema.field ...`
    for the fields the story's contract table lists. "NOT FOUND" means the API hasn't
    shipped, even if its story says done.
  - With `none`, rely on the API story's state and say that the fields weren't verified.
- Everything the UI shows has a data source. Flag labels like "qualifying product count"
  or "validity date" with no field named.

## 6. Dependencies and links

- **Stale blocker:** the blocker is merged or in `qa`, but the story still shows as
  blocked (a blocked flag, or an unresolved "blocked by" link). The code is unblocked.
  Say so, because the flag scares people off.
- **Inverted link:** A "blocks" B, but A's feature navigates *into* B (so A needs B).
  The link should be reversed or removed.
- **Missing link:** two stories change the same screen, or one extends the other's data,
  with no link between them. Sequence them and give both to one person where you can.
- **Cross-team:** a dependency owned by another team's sprint is a risk to plan around.
  Name its state and owner.

## 7. Already built?

Grep `code.model_paths` and the source for the story's key API fields and screen or widget
names. Remember that code usually renames JSON fields (e.g. `discount_total` becomes `discountTotal`):

```bash
grep -rnE "discountTotal|isGift|partiallyDelivered" <source dir> | grep -vE '<generated-file pattern>'
```

If another story (often one in `qa`) already built most of the scope, the story needs a
new, smaller scope or closing. Name the files that already do it.

## 8. Contradictions between stories

Compare sibling stories in the same epic or on the same screens. Flag rules that conflict
(for example one says "don't list promotion names" while the current app or another
story lists them), different row orders for the same breakdown, or totals that won't add
up (a collapsed total that excludes a fee its expanded breakdown includes).

## 9. Open questions

A developer's question with no reply from a scope owner blocks whoever takes the story.
List each with the asker, the date, and a one-line summary.

## 10. Spec changes in flight

If the story cites a spec document, check `code_host.related_repos` for open changes that
touch it (**H1** by file path, then **H2** to read the change). Map each rule the change
edits (rule or section numbers) to the stories that cite it. Stories whose rules aren't
touched can go ahead.

## 11. The team's own checks

Apply every item in `readiness.extra_checks`. Those are the team's agreed Definition of
Ready and override the defaults above when they conflict.

## 12. Housekeeping

These don't block a story, but list them together at the end: missing priority, missing
size (see `tracker.size_signal`), a title that no longer matches the scope, an on-hold
story still in the sprint.
