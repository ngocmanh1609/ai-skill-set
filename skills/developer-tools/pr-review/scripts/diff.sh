#!/usr/bin/env bash
# Print the PR diff with generated/lock files left out, optionally only what changed
# since a commit (re-review) or only some files.
#
# Usage: diff.sh <base> [--since <sha>] [--ignore <glob>]... [--file <path>]... [-U <n>] [--stat]
#   <base>     base branch name; diffs origin/<base>...HEAD (fetch it first)
#   --since    diff <sha>..HEAD instead: what the author pushed since your last review.
#              Exits 3 if <sha> is not an ancestor of HEAD (rebase or force-push), because
#              the result would be meaningless; do a full review then.
#   --ignore   .gitignore-style glob to exclude (repeatable)
#   --file     limit to these paths (repeatable). With --since, pass the PR's files so
#              a merge of <base> into the branch doesn't pull in unrelated changes.
#   -U         context lines (default 3). -U0 is enough for scanning added lines.
#   --stat     print a per-file summary instead of the patch
set -euo pipefail

usage() { sed -n '2,14p' "$0" >&2; exit 2; }
[ $# -ge 1 ] || usage
base="$1"; shift
since=""; ctx=3; stat=""; ignores=(); files=()
while [ $# -gt 0 ]; do
  case "$1" in
    --since) since="$2"; shift 2 ;;
    --ignore) ignores+=("$2"); shift 2 ;;
    --file) files+=("$2"); shift 2 ;;
    -U) ctx="$2"; shift 2 ;;
    -U[0-9]*) ctx="${1#-U}"; shift ;;
    --stat) stat="--stat"; shift ;;
    -h|--help) usage ;;
    *) echo "error: unknown argument: $1" >&2; usage ;;
  esac
done

if [ -n "$since" ]; then
  git cat-file -e "$since^{commit}" 2>/dev/null \
    || { echo "error: commit $since not found locally; run: git fetch origin" >&2; exit 3; }
  git merge-base --is-ancestor "$since" HEAD \
    || { echo "error: $since is not an ancestor of HEAD (history was rewritten); do a full review" >&2; exit 3; }
  range=("$since" HEAD)
else
  git rev-parse --verify -q "origin/$base" >/dev/null \
    || { echo "error: origin/$base not found; run: git fetch origin $base" >&2; exit 1; }
  range=("origin/$base...HEAD")
fi

pathspec=()
if [ ${#files[@]} -gt 0 ]; then pathspec+=("${files[@]}"); else pathspec+=("."); fi
for g in ${ignores[@]+"${ignores[@]}"}; do
  case "$g" in */*) ;; *) g="**/$g" ;; esac
  pathspec+=(":(exclude,glob)$g")
done

# -U implies --patch in git, so it only goes with a patch.
if [ -n "$stat" ]; then fmt=(--stat=120); else fmt=(-U"$ctx"); fi
git diff --no-color --no-ext-diff "${fmt[@]}" "${range[@]}" -- "${pathspec[@]}"
