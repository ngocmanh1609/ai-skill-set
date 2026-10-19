# Adapter: second-opinion reviewer

Another AI coding CLI reviews the same diff independently, read-only, and its report joins
the candidates in step 2g. `scripts/second_opinion.sh` runs it the same way for every
tool: it inlines the diff in the prompt (so no reviewer needs a shell), runs the tool in a
throwaway worktree at HEAD, stops it after a timeout, and checks afterward that the
worktree is unchanged. The user's checkout is never the reviewer's working directory.

## Operations

| ID | Operation | Must return / do |
|---|---|---|
| R1 | Independent review | given the diff range, ignore globs, and a PR summary, return the reviewer's report as text: one `path:line — severity — cause — fix` line per defect, or "No defects found." |
| R2 | Availability | the tool is installed and logged in; if not, say how to fix it (exit 3) |

## Tools

| `use` | CLI it runs | Read-only by | Logged-in check | Model examples |
|---|---|---|---|---|
| `claude` | `claude -p` | only `Read`, `Grep`, `Glob` available, `--permission-mode dontAsk` | none needed when Claude Code runs the skill | `sonnet`, `opus`, `haiku` |
| `codex` | `codex exec` | `--sandbox read-only` (enforced by the OS sandbox) | `codex login status` says "Logged in using …" | the account's Codex models |
| `cursor` | `cursor-agent -p` | `--mode ask` (`--trust` only trusts the worktree folder) | `cursor-agent status` doesn't say "Not logged in" | `cursor-agent models` lists them |
| `command` | any shell template | whatever the tool offers; the worktree check still runs | the template's own errors | — |

`command` covers any other CLI. `{prompt_file}` and `{repo}` are replaced in the template,
which runs in the throwaway worktree, for example:
`gemini -p "$(cat {prompt_file})"`.

## Quirks

- Both logged-in checks exit 0 whether or not the user is logged in, so the script reads
  their output text.
- `cursor-agent` takes the prompt as an argument, not stdin. A very large diff can hit the
  OS argument limit; use `--since` or `--ignore` to shrink it, or pick another tool.
- `cursor-agent -p` refuses to start in a folder it hasn't been told to trust, and every
  throwaway worktree is a new folder, so the script passes `--trust`. That flag trusts the
  folder for this run only; it allows no commands. Never pass `--force` or `--yolo`, which do.
- `codex exec` writes its final message with `--output-last-message`, and its progress
  log goes to a file the script shows only on failure.
- A run takes minutes. Start it in the background right after step 2c and collect it in 2g.
- Exit 4 means the tool wrote to its worktree despite read-only mode. The user's checkout
  is untouched, but say so, and treat the report with suspicion.

## Config keys

```yaml
second_opinion:
  use: <claude | codex | cursor | command>   # default; --second-opinion=<tool>[:<model>] overrides
  model: <the tool's own model name>          # optional
  command: '<template>'                       # use: command only
  timeout_minutes: 15
```
