# ai-skill-set

Backup of my Claude Code skills, grouped by category.

| Category | Skill | What it does |
|---|---|---|
| writing | [plain-english](skills/writing/plain-english/SKILL.md) | Rewrites dense or jargon-heavy text into plain language, keeping every fact. |
| documents | [epub-reader](skills/documents/epub-reader/SKILL.md) | Reads, searches, summarizes, and extracts text and metadata from `.epub` files. |
| developer-tools | [github-cli](skills/developer-tools/github-cli/SKILL.md) | Works with GitHub through the `gh` CLI: PRs, reviews, CI status, releases. |
| developer-tools | [pr-review](skills/developer-tools/pr-review/SKILL.md) | Reviews a teammate's PR against the project's own rules, lint, tests, design, and API contract, then posts only the findings you pick as one review. Works with GitHub or GitLab and Shortcut, Jira, or Linear through adapters. |
| qa | [analytics-debugview-qa](skills/qa/analytics-debugview-qa/SKILL.md) | QAs Firebase Analytics (GA4) events on a device: pulls the expected events from the ticket and specs, then compares them with what the device logged and DebugView shows. |
| project-management | [sprint-triage](skills/project-management/sprint-triage/SKILL.md) | Reviews a sprint's stories for readiness, suggests owners, and handles stories added mid-sprint. Works with Shortcut or Jira and GitHub or GitLab through adapters. |

## Layout

```
skills/<category>/<skill-name>/SKILL.md
```

Each skill folder is exactly what goes into `~/.claude/skills/<skill-name>/`.

## Restore

Copy a skill back into your personal skills folder:

```bash
cp -R skills/writing/plain-english ~/.claude/skills/
```

Or link it, so edits made in Claude Code land straight in this repo:

```bash
ln -s "$PWD/skills/writing/plain-english" ~/.claude/skills/plain-english
```

## Notes

- **sprint-triage** keeps per-project settings (tracker, team, states) in
  `<project>/.claude/sprint-triage.yml`, not in the skill. It offers to create that
  file the first time it runs in a project. Its reports go to
  `~/.claude/sprint-triage/reports/`. Neither is backed up here.
- **pr-review** keeps its per-project config in `<project>/.claude/pr-review.yml` and
  its rules in `<project>/.claude/pr-review/rules.md`. It offers to create both the
  first time it runs in a project. Neither is backed up here. Its replay benchmark
  (`evals/replay-argus/`) is built from a private repo, so it stays local only and
  `evals.json`'s `quality_benchmark` points at a file that isn't in this backup.
- No skill stores credentials. sprint-triage reads the API docs URL from the
  project's `CLAUDE.local.md`.
