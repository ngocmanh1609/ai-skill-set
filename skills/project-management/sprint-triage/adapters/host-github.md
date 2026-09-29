# Code host adapter: GitHub

## Access

`gh` CLI (preferred: short JSON output, works in any session). If the GitHub MCP server
is connected (`mcp__github__*`), you can use it instead.
- Logged-in check (**H3**): `gh auth status`
- Read-only: `gh pr list`, `gh pr view`, `gh api` GET calls
- Writes: never needed by this skill

## Operations

**H1 List open changes**

By text in the title or body:
```bash
gh pr list --repo <owner/repo> --state open --search "<term> in:title,body" \
  --json number,title,author,updatedAt,reviewDecision,url
```

By a file path the change touches (use this for spec files like `docs/specs/<name>.md`):
```bash
gh pr list --repo <owner/repo> --state open --limit 50 --json number,title,updatedAt,files \
  --jq '.[] | select(any(.files[]?; .path | test("<path regex>"))) | {number,title,updatedAt}'
```

**H2 Read a change**
```bash
gh pr view <number> --repo <owner/repo> --json title,body,files,reviewDecision,state,url
```
An approved but unmerged PR (`reviewDecision: APPROVED`, `state: OPEN`) will probably
merge soon. Treat its changes as coming, and name the rules it touches.

## Config keys

`code_host.repo` (this repo), `code_host.related_repos[]` (e.g. where specs or the API live)
