# Project config: format, setup, health check

## Contents
- Where the config lives
- Config format
- Setup flow (no config yet)
- Health check (every run)
- Keeping the config current

## Where the config lives

`<project root>/.claude/sprint-triage.yml`. The project root is `${CLAUDE_PROJECT_DIR}`, or
the git top level (`git rev-parse --show-toplevel`). One fixed path, so every run finds it
the same way.

The file holds IDs and names, never secrets. Whether it gets shared depends on the repo:
if `git check-ignore -q .claude/sprint-triage.yml` succeeds, it stays private to this
machine. Otherwise it can be committed so teammates share it. Tell the user which one
applies when you create it.

## Config format

```yaml
# Sprint triage config. Created by the sprint-triage skill; safe to edit by hand.
version: 1
project: <short name, used for the reports folder>

tracker:
  type: shortcut                 # reads adapters/tracker-<type>.md
  # --- keys the adapter lists under "Config keys" go here, e.g. for Shortcut:
  workspace: <slug>
  team: { id: <team id>, name: <team name> }
  sprint_name_hint: Sprint
  states:                        # semantic state -> this tracker's state
    backlog:     { id: <id>, name: Backlog }
    ready:       { id: <id>, name: To Do }
    in_progress: { id: <id>, name: In Progress }
    in_review:   { id: <id>, name: In Review }
    qa:          { id: <id>, name: Ready for QA }
    done:        { id: <id>, name: Done }
  size_signal: <where size lives, e.g. 'labels complexity:S/M/L'>
  size_days: { S: 1, M: 3, L: 5 }  # rough working days per size; ask the team, and fix
                                   # it once a few sprints show real numbers
  story_id_pattern: '[Ss][Cc]-[0-9]+'
  tools: {}                      # only for adapters that discover tool names at setup (Jira)

code_host:
  type: github                   # reads adapters/host-<type>.md
  repo: <owner/repo>
  related_repos:                 # other repos stories depend on
    - { repo: <owner/repo>, holds: <what, e.g. 'specs in docs/specs/*.md'> }

team:
  members:                       # the people owners are suggested from
    - name: <display name>
      aka: [<nicknames the user uses>]
      tracker_id: <user id in the tracker>
      mention: <mention handle, if the tracker uses one>
      git_emails: [<every email they commit with, including GitHub/GitLab noreply ones>]
      capacity: 1.0              # share of a normal sprint; the lead is usually lower
      role: <optional, e.g. lead>
      is_user: <true for the person running the skill>
  others:                        # recognised in git history, but not suggested as owners
    - { name: <name>, git_emails: [...] }
  skip_git_emails: [<bots and assistants>]
  scope_owners:                  # who answers scope/design/copy questions
    - { name: <name>, mention: <handle>, tracker_id: <id>, role: <e.g. PM> }

code:
  areas: ['lib/feature/*']       # globs passed to scripts/expertise.sh --area
  model_paths: '<glob for API response models>'   # where to grep for "already built?"

api_contract:
  type: openapi                  # openapi | none
  url_from: CLAUDE.local.md      # or: url_env: <ENV_VAR>, or: url: <URL without credentials>

readiness:
  locales: [en]                  # languages every user-facing string needs
  missing_translation_marker: '<text stories use for missing copy, if any>'
  extra_checks: []               # the team's own Definition of Ready items, in plain words

reports_dir: ~/.claude/sprint-triage/reports/<project>
```

Keep the semantic state names exactly as shown. Load weights and readiness rules refer to them.

## Setup flow (no config yet)

Tell the user the config is missing and what it's for. Ask with `AskUserQuestion` whether
to create it now (options: create it now / cancel). Then:

1. **Detect the tools.**
   - Tracker: which MCP tools are loaded or findable with `ToolSearch` ("shortcut", "jira",
     "atlassian", "linear"). Check `CLAUDE.md` / `CLAUDE.local.md` for mentions too.
   - Code host: `git remote get-url origin` (github.com, gitlab.*, or another host), then
     `gh auth status` or `glab auth status`.
   - Ask the user to confirm tracker and code host (`AskUserQuestion`, with the detected
     one marked "Recommended").
   - If `adapters/tracker-<type>.md` or `adapters/host-<type>.md` doesn't exist, say so.
     Offer to write one from `adapters/_contract.md`, and stop setup until it exists.
     Without it the skill would be guessing at tool behavior.
2. **Discover the tracker** with the adapter's T8 operations: list teams or projects and
   ask which one. Read the workflow states and pre-map them to the semantic states by
   name. Ask only about the states that don't match clearly.
3. **Build the team.**
   - Take the tracker team's members, plus recent git authors:
     `git -C <root> log --since="180 days ago" --format='%an <%ae>' | sort | uniq -c | sort -rn`.
   - Match them by email and name. Show the proposed list and ask:
     - who is assignable
     - who has reduced capacity (the lead, part-timers)
     - any nicknames
     - who owns scope questions (the PM)
   - Put GitHub/GitLab noreply emails under the right person. Put bots in `skip_git_emails`.
4. **Code areas.** Look at the layout (`lib/feature/*`, `src/modules/*`, `packages/*`,
   `apps/*`) and propose globs that separate the product areas. Confirm them.
5. **API contract.** Look for an OpenAPI/Swagger URL in `CLAUDE.md`, `CLAUDE.local.md`, or
   env vars. If it has credentials, store only where to find it (`url_from` or `url_env`).
6. **Readiness and sizing.** Detect the locales from localization files (`*.arb`,
   `locales/*.json`, `*.strings`). Ask for any Definition of Ready items the team already
   agreed on, and roughly how many working days each size takes (`tracker.size_days`).
7. **Write and confirm.** Show the full YAML and say whether the path is gitignored. Write
   it only after the user agrees. Then run the health check below.

## Health check (every run)

Before triage, check these quickly, and stop with a specific message if any fail:
- The config exists and has `tracker.type`, `code_host.type`, `tracker.states` (all six
  semantic states), and at least one `team.members` entry.
- `adapters/tracker-<type>.md` and `adapters/host-<type>.md` exist.
- The tracker answers a cheap read (the adapter's connected check), and the code host is logged in (H3).

## Keeping the config current

During a run, point out drift instead of silently working around it:
- A story owner or active git author who isn't in `team.members` or `team.others`.
- A tracker state that isn't mapped.
- A member with no commits in the expertise window.

Offer a one-line config edit for each. Apply it only if the user agrees.
