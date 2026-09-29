---
name: github-cli
description: >
  Use this skill whenever the user wants to interact with GitHub using the `gh` CLI.
  Trigger on phrases like: "create a PR", "open a pull request", "update PR #123",
  "add a label to the PR", "check CI status", "check workflow run", "review this PR",
  "leave a comment on PR", "create a release", "tag this commit", "merge this PR",
  "list open PRs", "check what's failing in CI", "add inline comment",
  "request changes on PR", "approve PR", "add reviewers", "update PR description",
  "update PR title", "is the build passing?", "what's the status of my branch?",
  "open PR for current branch", "start a review", "submit my review".
  Always invoke this skill proactively when the user mentions GitHub actions, even
  indirectly (e.g. "can you push this as a PR?" or "review PR #X and leave comments").
---

# GitHub CLI Skill

You are an expert at using the `gh` CLI to interact with GitHub. Your job is to:
1. Understand what the user wants to do on GitHub
2. Construct the correct `gh` command(s)
3. Run them and present the results clearly

Always run commands rather than just showing them, unless the action is destructive
(e.g. deleting a branch, closing issues in bulk) — in those cases, confirm first.

---

## Project Conventions

This project follows these conventions. Apply them automatically:

**Branches**
- `develop` — main development branch (default base for PRs)
- `main` — stable/production
- `release/x.y.z` — release branches (PR to `main`)

**Labels**
- `type : feature`
- `type : bug`
- `type : chore`
- `type : release`

**PR Templates**
- Default: `.github/PULL_REQUEST_TEMPLATE.md` — requires What happened, Insight, Proof of Work
- Release: `.github/PULL_REQUEST_TEMPLATE/release_template.md` — requires Features, Chores, Bugs sections

**Issue Templates**
- Feature → title: "Add X", label: `type : feature`
- Bug → title: "Fix: X", label: `type : bug`
- Chore → title: "Update X", label: `type : chore`
- Story → title: "[Type] As a user, I can X", label: `type : feature`

---

## Common Tasks

### Creating a PR

1. Determine the current branch: `git rev-parse --abbrev-ref HEAD`
2. Determine the base branch (default: `develop`; use `main` for release branches)
3. Read `.github/PULL_REQUEST_TEMPLATE.md` for the body template
4. Fill in the template based on context from recent commits and the user's description
5. Create the PR:
   ```bash
   gh pr create --title "..." --body "$(cat <<'EOF'
   ...filled template...
   EOF
   )" --base develop
   ```
6. Apply the appropriate label after creation if the type is known

**Release PR**: use `--body-file .github/PULL_REQUEST_TEMPLATE/release_template.md` as a starting point and fill in the issue references. Set `--base main`.

### Updating a PR

**Title:**
```bash
gh pr edit <number> --title "new title"
```

**Description:**
```bash
gh pr edit <number> --body "$(cat <<'EOF'
...new body...
EOF
)"
```

If the user gives partial info (e.g. "update the What happened section"), fetch the current body first, merge the update, then write back:
```bash
gh pr view <number> --json body -q '.body'
```

**Adding labels:**
```bash
gh pr edit <number> --add-label "type : feature"
```

**Adding reviewers:**
```bash
gh pr edit <number> --add-reviewer username1,username2
```

### Reviewing a PR (Full Review Session)

Inline comments should always be submitted as part of a **single batched review**, not as individual standalone comments. This is the standard GitHub review flow.

**Step 1 — Gather context**
```bash
# Get PR details and HEAD SHA
gh pr view <number> --json headRefOid,title,body,files
```

**Step 2 — Submit the full review in one API call**

Use the GitHub Reviews API to batch all inline comments + overall verdict together:

```bash
gh api repos/{owner}/{repo}/pulls/<number>/reviews \
  --method POST \
  --input - <<'EOF'
{
  "commit_id": "<headRefOid>",
  "body": "Overall review comment here",
  "event": "REQUEST_CHANGES",
  "comments": [
    {
      "path": "lib/feature/home/presentation/home_screen.dart",
      "line": 42,
      "side": "RIGHT",
      "body": "This widget is doing heavy work inside build(). Consider moving to initState."
    },
    {
      "path": "lib/feature/home/presentation/home_view_model.dart",
      "line": 18,
      "side": "RIGHT",
      "body": "Missing null check — `user` could be null if the API returns an empty payload."
    }
  ]
}
EOF
```

Valid `event` values:
- `"APPROVE"` — approve the PR
- `"REQUEST_CHANGES"` — request changes (requires `body`)
- `"COMMENT"` — general comment without approval decision

**Step 3 — Reply to an existing inline comment thread**

To add a follow-up to an existing inline thread (not part of a new review):
```bash
gh api repos/{owner}/{repo}/pulls/<number>/comments \
  --method POST \
  -f body="Follow-up reply here" \
  -f commit_id="<sha>" \
  -f path="path/to/file.dart" \
  -F in_reply_to=<parent_comment_id>
```

Resolve `{owner}/{repo}` with:
```bash
gh repo view --json nameWithOwner -q '.nameWithOwner'
```

**Quick single-verdict review** (no inline comments needed):
```bash
gh pr review <number> --approve --body "LGTM!"
gh pr review <number> --request-changes --body "Please address X"
gh pr review <number> --comment --body "Some thoughts..."
```

### Checking CI / Workflow Runs

**PR status (checks summary):**
```bash
gh pr checks <number>
```

**Current branch status** (when the user asks "is my branch passing?"):
```bash
gh pr checks   # uses current branch automatically if a PR exists
```

**List recent workflow runs:**
```bash
gh run list --limit 10
```

**Specific run details:**
```bash
gh run view <run-id>
```

**Stream logs of a failing job:**
```bash
gh run view <run-id> --log-failed
```

**Re-run failed jobs:**
```bash
gh run rerun <run-id> --failed
```

### Releases and Tags

**Create a release:**
```bash
gh release create v1.2.3 \
  --title "v1.2.3" \
  --notes "Release notes here" \
  --target main
```

**List releases:**
```bash
gh release list
```

**Create a tag (git + push):**
```bash
git tag v1.2.3 && git push origin v1.2.3
```

### Chained PRs (Stacked Branches)

Use this workflow when a feature is split across multiple branches that depend on each other, e.g.:

```
develop <- feature/1-abc <- feature/2-xyz <- feature/3-abc
```

Each PR targets the branch below it, not `develop` directly.

**Step 1 — Create the chain**

Branch each layer off the previous one:
```bash
git checkout develop && git checkout -b feature/1-abc
# ... make changes ...
git checkout feature/1-abc && git checkout -b feature/2-xyz
# ... make changes ...
git checkout feature/2-xyz && git checkout -b feature/3-abc
```

**Step 2 — Create PRs with the correct base**

Each PR must target its parent branch, not `develop`:
```bash
gh pr create --title "[SC-XXX] feature/1-abc" --base develop
gh pr create --title "[SC-XXX] feature/2-xyz" --base feature/1-abc
gh pr create --title "[SC-XXX] feature/3-abc" --base feature/2-xyz
```

Add a note in each PR body (under Insight or a "Chained PRs" section) listing the full chain so reviewers have context:
```
**Chained PRs:**
- #1 feature/1-abc → develop ← merge this first
- #2 feature/2-xyz → feature/1-abc
- #3 feature/3-abc → feature/2-xyz (this PR)
```

**Step 3 — Rebase downstream branches after upstream changes**

When `feature/1-abc` gets new commits (e.g. from review feedback), rebase the branches that depend on it one at a time. If conflicts arise during a rebase, stop and let the user resolve them manually — do not attempt to auto-resolve. Wait for the user to confirm conflicts are resolved before continuing to the next branch.

```bash
git checkout feature/2-xyz && git rebase feature/1-abc
# If conflicts: pause, tell the user which files conflict, and wait for them to resolve + run `git rebase --continue`
git push --force-with-lease origin feature/2-xyz

git checkout feature/3-abc && git rebase feature/2-xyz
# If conflicts: pause again and wait
git push --force-with-lease origin feature/3-abc
```

**Step 4 — Merging order**

Always merge from the bottom of the chain upward. After merging `feature/1-abc` into `develop`:
1. GitHub will automatically retarget `feature/2-xyz`'s PR base to `develop` if you're using GitHub's "update branch" feature — but verify this.
2. Safer: manually rebase `feature/2-xyz` onto `develop` after the merge, then merge it, and repeat up the chain.

```bash
git checkout feature/2-xyz && git rebase develop
# If conflicts: stop and let the user resolve them manually, then `git rebase --continue`
# Wait for user confirmation before pushing
git push --force-with-lease origin feature/2-xyz
# then merge feature/2-xyz PR, repeat for feature/3-abc
```

**Handling ambiguity**

- If the user mentions "stacked PRs", "chained PRs", or "PR depends on another PR", apply this workflow.
- If the user doesn't specify base branches, ask: "Should each PR target the previous branch, or all target `develop`?"
- If a PR's base branch has already been merged, remind the user to rebase and update the base to `develop` before merging.

---

### Repo Management

**View repo info:**
```bash
gh repo view
```

**Clone:**
```bash
gh repo clone owner/repo
```

**Fork:**
```bash
gh repo fork owner/repo --clone
```

---

## Handling Ambiguity

- If the user says "the PR" without a number, check the current branch for an associated PR:
  ```bash
  gh pr view --json number -q '.number'
  ```
- If "current branch" is mentioned for CI status, run `gh pr checks` (which defaults to the current branch's PR).
- If the user asks about a label that doesn't match the project's known labels, suggest the closest match and confirm before applying.
- For inline comments, always confirm the file path and line number if not explicitly stated.

---

## Output Format

- After running a command, show the key result concisely (PR URL, run status, issue number, etc.).
- For CI checks, format the output as a short summary: which checks passed, which failed, and the URL for failed ones.
- For PR creation, always return the PR URL.
- Don't dump raw JSON at the user — extract and present the relevant fields.
