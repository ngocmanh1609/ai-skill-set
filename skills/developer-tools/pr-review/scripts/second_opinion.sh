#!/usr/bin/env bash
# Ask another AI coding CLI for an independent, read-only review of the PR diff, and print
# its report. The reviewer runs in a throwaway worktree at HEAD, so it can't touch the
# user's checkout even if a tool ignores its read-only mode.
#
# Usage: second_opinion.sh <tool>[:<model>] <base> [--since <sha>] [--ignore <glob>]...
#          [--summary <file>] [--command '<template>'] [--timeout <minutes>] [--dry-run]
#   tool       claude | codex | cursor | command
#   model      passed to the tool's --model (claude: sonnet, opus, …; codex: gpt-5-codex, …;
#              cursor: see `cursor-agent models`). Omit it to use the tool's default.
#   <base>, --since, --ignore   the same range and filters as diff.sh
#   --summary  file with one paragraph on what the PR does (and its linked issue)
#   --command  tool=command only: a shell template; {prompt_file} and {repo} are replaced
#   --timeout  minutes before the reviewer is stopped (default 15)
#   --dry-run  print the command and the prompt size; run nothing
#
# Read-only, per tool: claude gets only Read/Grep/Glob with --permission-mode dontAsk;
# codex runs with --sandbox read-only; cursor runs in --mode ask, with --trust so its
# headless mode starts in the new worktree (it trusts that folder; it allows no commands).
# The diff is inlined in the prompt, so no reviewer needs a shell.
#
# Exit: 0 report printed; 3 tool missing or not logged in; 4 the reviewer changed files in
# its worktree (report still printed; treat it with suspicion); 5 failed or timed out.
set -euo pipefail

usage() { sed -n '2,23p' "$0" >&2; exit 2; }
[ $# -ge 2 ] || usage
spec="$1"; base="$2"; shift 2
tool="${spec%%:*}"; model=""; case "$spec" in *:*) model="${spec#*:}" ;; esac
diff_args=(); summary=""; template=""; minutes=15; dry=""
while [ $# -gt 0 ]; do
  case "$1" in
    --since|--ignore) diff_args+=("$1" "$2"); shift 2 ;;
    --summary) summary="$2"; shift 2 ;;
    --command) template="$2"; shift 2 ;;
    --timeout) minutes="$2"; shift 2 ;;
    --dry-run) dry=1; shift ;;
    -h|--help) usage ;;
    *) echo "error: unknown argument: $1" >&2; usage ;;
  esac
done
here="$(cd "$(dirname "$0")" && pwd)"

# Is the tool there and logged in? (Both status commands exit 0 either way; read the text.)
case "$tool" in
  claude) bin=claude ;;
  codex)  bin=codex ;;
  cursor) bin=cursor-agent ;;
  command) bin=""; [ -n "$template" ] || { echo "error: tool=command needs --command '<template>'" >&2; exit 2; } ;;
  *) echo "error: unknown tool '$tool' (claude | codex | cursor | command)" >&2; exit 2 ;;
esac
if [ -n "$bin" ] && ! command -v "$bin" >/dev/null; then
  echo "error: $bin is not installed" >&2; exit 3
fi
logged_out() {  # a dry run only warns, so the command can still be inspected
  if [ -n "$dry" ]; then echo "warning: $1" >&2; else echo "error: $1" >&2; exit 3; fi
}
if [ "$tool" = codex ] && ! codex login status 2>&1 | grep -qi "logged in using"; then
  logged_out "codex is not logged in; run: codex login"
fi
if [ "$tool" = cursor ] && cursor-agent status 2>&1 | grep -qi "not logged in"; then
  logged_out "cursor-agent is not logged in; run: cursor-agent login"
fi

work=$(mktemp -d "${TMPDIR:-/tmp}/pr-review-second-opinion.XXXXXX")
repo="$work/repo"; prompt="$work/prompt.md"; out="$work/report.txt"
cleanup() { git worktree remove --force "$repo" >/dev/null 2>&1 || true; rm -rf "$work"; }
trap cleanup EXIT

diff=$("$here/diff.sh" "$base" ${diff_args[@]+"${diff_args[@]}"})
[ -n "$diff" ] || { echo "error: the diff is empty; nothing to review" >&2; exit 5; }
{
  cat <<'EOF'
You are a second, independent reviewer of a pull request. This is read-only: do not
edit, create, or delete files, and do not commit, push, or post anything.

The repository is your working directory, checked out at the PR's head. The PR's diff is
at the end of this message. Read any file in the repository for context: callers, files
that include or reference what changed, sibling files that follow the same pattern.

Report only defects you are confident about: bugs, broken references, contradictions
between files, missing failure handling, steps in a wrong order, tests that can't fail,
security problems. No style preferences, no praise, no summary of the PR.

Your final message holds only the defect lines, one per defect, in this form:
- path:line — critical|major|minor — what is wrong and why — the fix

No preamble and no closing remarks. If you find nothing, reply exactly: No defects found.
EOF
  if [ -n "$summary" ] && [ -f "$summary" ]; then printf '\n## What the PR does\n\n'; cat "$summary"; fi
  printf '\n## Diff\n\n```diff\n%s\n```\n' "$diff"
} > "$prompt"

case "$tool" in
  claude) cmd=(claude -p ${model:+--model "$model"} --permission-mode dontAsk
               --tools "Read,Grep,Glob" --allowedTools "Read,Grep,Glob" --output-format text) ;;
  codex)  cmd=(codex exec --sandbox read-only --cd "$repo" --ephemeral --color never
               ${model:+--model "$model"} --output-last-message "$out" -) ;;
  cursor) cmd=(cursor-agent -p --mode ask --trust --output-format text --workspace "$repo"
               ${model:+--model "$model"}) ;;
  command) t="${template//\{prompt_file\}/$prompt}"; cmd=(bash -c "${t//\{repo\}/$repo}") ;;
esac

if [ -n "$dry" ]; then
  echo "tool: $tool${model:+  model: $model}  timeout: ${minutes}m"
  echo "prompt: $(wc -l < "$prompt" | tr -d ' ') lines, $(wc -c < "$prompt" | tr -d ' ') bytes"
  printf 'command:'; printf ' %q' "${cmd[@]}"; [ "$tool" = cursor ] && printf ' "<prompt>"'; echo
  exit 0
fi

git worktree add -q --detach "$repo" HEAD
head_before=$(git -C "$repo" rev-parse HEAD)

# alarm survives exec, so the tool is stopped after the timeout without GNU timeout.
limited() { perl -e 'alarm shift; exec @ARGV' "$((minutes * 60))" "$@"; }
status=0
case "$tool" in
  codex)  limited "${cmd[@]}" < "$prompt" > "$work/tool.log" 2>&1 || status=$? ;;
  cursor) (cd "$repo" && limited "${cmd[@]}" "$(cat "$prompt")") > "$out" 2> "$work/tool.log" || status=$? ;;
  *)      (cd "$repo" && limited "${cmd[@]}" < "$prompt") > "$out" 2> "$work/tool.log" || status=$? ;;
esac

if [ "$status" -ne 0 ] || [ ! -s "$out" ]; then
  [ "$status" -eq 142 ] && echo "error: $tool timed out after ${minutes}m" >&2 \
    || echo "error: $tool failed (exit $status)" >&2
  # The log can echo the whole prompt; show only its error lines.
  grep -iE "error|denied|not found|upgrade" "$work/tool.log" | sort -u | tail -5 >&2 || tail -5 "$work/tool.log" >&2
  exit 5
fi

echo "=== second opinion: $tool${model:+ ($model)}"
cat "$out"

changed=$(git -C "$repo" status --porcelain)
if [ -n "$changed" ] || [ "$(git -C "$repo" rev-parse HEAD)" != "$head_before" ]; then
  echo "warning: $tool changed its worktree despite read-only mode; your checkout is untouched:" >&2
  printf '%s\n' "$changed" | head -10 >&2
  exit 4
fi
