# Adapter contract

The workflow in SKILL.md never names a tool. It asks for the operations below, and the
adapter for the project's tracker (`adapters/tracker-<type>.md`) or code host
(`adapters/host-<type>.md`) says how to do each one. To support a new tool, copy this
file to `adapters/tracker-<type>.md` or `adapters/host-<type>.md` and fill in every
operation. If the tool can't do something, write **"Not supported"** and say what the
user should do by hand. Don't leave it silent.

Each adapter also lists:
- **Access:** MCP server or CLI, how to check it's connected or logged in, and which
  calls are read-only (safe to pre-approve) and which write.
- **Quirks:** anything that behaves differently from the plain meaning of an operation
  (for example, "setting owners replaces the whole list").
- **Setup discovery:** how to list the teams, states, and people the setup flow needs.
- **Config keys:** the `tracker.*` / `code_host.*` keys this adapter reads from the project config.

## Tracker operations

| ID | Operation | Must return / do |
|---|---|---|
| T1 | Find sprint (current, next, or by name) | id, name, start and end dates |
| T2 | List sprint stories | per story: id, title, type, state, owners, team/project, archived |
| T3 | Get story | description, comments in order (author, date if available, text), links with direction (blocks / blocked by / relates), labels, size, priority, linked PRs/branches, blocked flag |
| T4 | Set owners | assign people; say whether it replaces or adds, and whether several owners are allowed |
| T5 | Set state | move to the tracker state mapped to a semantic state (`backlog`, `ready`, `in_progress`, `in_review`, `qa`, `done`) |
| T6 | Add comment | post text that mentions people so they get notified |
| T7 | Story URL | link format for reports |
| T8 | Setup discovery | list teams/projects, workflow states, users; identify the current user |
| T9 | When a story joined the sprint | the date it was created in, or moved into, the sprint. Only used by the mid-sprint fallback, on a few candidates. Also say how to search for stories created after a date. |

## Code host operations

| ID | Operation | Must return / do |
|---|---|---|
| H1 | List open changes | open PRs/MRs in a repo matching a search term or touching a path: number, title, updated, approval state, URL |
| H2 | Read a change | title, body, files changed, review state |
| H3 | Auth check | confirm the CLI or MCP server is logged in |

Git history (who worked where) doesn't need an adapter: `scripts/expertise.sh` reads the
local clone, whatever the remote is.
