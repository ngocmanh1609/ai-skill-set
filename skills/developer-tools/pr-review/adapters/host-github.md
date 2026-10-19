# Code host adapter: GitHub

## Access

`gh` CLI. Scripts in `scripts/` are written for it.
- **H7** Auth: `gh auth status`
- Read-only: `gh pr view`, `gh pr diff`, `gh api` GET calls, `pr_context.sh`, `diff.sh`
- Writes: `post_review.sh` only (review + comments). It is left out of `allowed-tools` so each post asks first.

## Operations

**H1 PR context** (also H3): `scripts/pr_context.sh <pr|url> --ignore <glob>...`
Hunks come from `gh pr diff`, which is GitHub's own view, so they match what comments can
anchor to. If `diffError` is set (very large PRs), compute the hunks locally after
checkout instead: `scripts/diff.sh <base> -U0 | grep -E '^(\+\+\+|@@)'`.

**H2 Safe checkout**
```bash
git branch --show-current          # remember as originalBranch
git status --porcelain             # non-empty → stop; the user decides about their changes
gh pr checkout <n>                 # skip if already on the head branch
git fetch origin <base>
git rev-parse HEAD                 # must equal headSha from H1 → reviewedSha
```
Use `gh pr checkout`, never `git fetch origin <head>`: a fork's head branch isn't on `origin`.

**H4 Post review:** `scripts/post_review.sh <findings.json>` (run `--dry-run` first).
It opens a pending review, adds each thread through GraphQL `addPullRequestReviewThread`
(`subjectType: LINE` with `line` and `side: RIGHT`, plus `startLine` for a range, or `subjectType: FILE`), moves
rejected threads into the body, and submits with the file's `event`: `COMMENT` (the
default) or `APPROVE`. It refuses `APPROVE`, before writing anything, when a finding's
severity isn't `suggestion`, when the PR is a draft, or when the PR is the user's own.

**H5 Confirm posted:** the script's last block lists what GitHub stored for the review.
File comments show `-` as the line.

**H6 Current head SHA:** `gh pr view <n> --json headRefOid -q .headRefOid`

## Quirks

- A rejected thread returns HTTP 200 with `thread: null` (line outside every hunk, or
  path not in the diff). Never trust the status code alone. The script handles this.
- The REST "create review" `comments` array can't hold file-level comments. That's why
  the script uses a pending review plus GraphQL.
- GitHub answers 422 ("Can not approve your own pull request") when you approve your own
  PR, after the pending review is already open. The script checks first so this can't
  leave a pending review behind.
- An approval attaches to the head commit at submit time. That's why SKILL.md step 4.2
  stops an `APPROVE` when the head moved after the review.
- One pending review per user per PR. If one is left over, the script says how to
  find and delete it.
- Comments anchor to the new side (`RIGHT`). A finding about a deleted line gets `file` placement.
- `reviews/{id}/comments` returns `line` and `subject_type` as null for every comment, so
  it can't confirm anchors. Read `pulls/{n}/comments` filtered by `pull_request_review_id`.
  After a later push changes the line, `line` turns null and `original_line` keeps it.
- A multi-line range (`startLine` to `line`) must sit inside one hunk. A ```` ```suggestion ````
  block in the comment replaces exactly that range.

## Config keys

`code_host.type: github`
