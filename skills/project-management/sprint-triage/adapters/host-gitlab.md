# Code host adapter: GitLab

Status: **outline**. The commands below follow the `glab` documentation. Confirm them on
the first real project and remove this note.

## Access

`glab` CLI. Self-managed instances need `GITLAB_HOST` set or `glab auth login --hostname <host>`.
If a GitLab MCP server is connected, you can use it instead. Save its tool names in
`code_host.tools`.
- Logged-in check (**H3**): `glab auth status`
- Read-only: `glab mr list`, `glab mr view`, `glab api` GET calls
- Writes: never needed by this skill

## Operations

**H1 List open changes**

By text in the title or description (open is the default state):
```bash
glab mr list -R <group/project> --search "<term>" -F json
```

By a file path the change touches: `glab mr list` can't filter by path. List the open MRs,
then read each candidate's changed files:
```bash
glab api "projects/<url-encoded group%2Fproject>/merge_requests/<iid>/diffs" | jq -r '.[].new_path'
```
(Older GitLab versions use `.../merge_requests/<iid>/changes`, with the paths under `.changes[]`.)

**H2 Read a change**
```bash
glab mr view <iid> -R <group/project> -F json
```
Approval state comes from `glab api "projects/<id>/merge_requests/<iid>/approvals"`.

## Quirks

- MRs have an `iid` (per project) and an `id` (global). The CLI and URLs use `iid`.
- Nested groups: the repo path can be `group/subgroup/project`. URL-encode `/` as `%2F` in API paths.

## Config keys

`code_host.repo`, `code_host.related_repos[]`, `code_host.host` (self-managed only), `code_host.tools.*` (MCP only)
