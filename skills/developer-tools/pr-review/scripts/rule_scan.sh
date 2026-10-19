#!/usr/bin/env bash
# Grep only the lines this PR adds for rules that carry a `grep:` pattern, so mechanical
# rule breaks are found without the model reading every line. Hits are leads to check,
# not findings: a match can sit in a comment, a test, or an allowed exception.
#
# Usage: rule_scan.sh <rules.md> <base> [--since <sha>] [--ignore <glob>]... [--file <path>]...
#   Rule lines look like (grep: must be the last field; paths: and exclude: are optional):
#     - [R07] No hardcoded colors ... — src: CONVENTIONS.md#Theming — paths: 'lib/**' — grep: 'Color\(0x'
#     - [R14] Only known config keys — src: … — exclude: '\{\{config\.(base_branch|pm_tool)\}\}' — grep: '\{\{config\.'
#   The pattern is an extended regex (grep -E). paths: is a .gitignore-style glob.
#   exclude: is removed from the line before grep: is tested, so allowed values don't hit.
#
# Output: "path:line  R<id>  <added line, trimmed>", at most 15 hits per rule.
set -euo pipefail

usage() { sed -n '2,13p' "$0" >&2; exit 2; }
[ $# -ge 2 ] || usage
rules="$1"; base="$2"; shift 2
[ -f "$rules" ] || { echo "error: rules file not found: $rules" >&2; exit 1; }
here="$(cd "$(dirname "$0")" && pwd)"

glob_to_regex() {
  local g="$1" prefix=""
  case "$g" in */*) ;; *) prefix='(.*/)?' ;; esac
  g=$(printf '%s' "$g" | sed -e 's/[.+^$(){}|]/\\&/g' \
    -e 's#\*\*/#@DSLASH@#g' -e 's#\*\*#@DSTAR@#g' -e 's#\*#[^/]*#g' -e 's#?#[^/]#g' \
    -e 's#@DSLASH@#(.*/)?#g' -e 's#@DSTAR@#.*#g')
  printf '^%s%s$' "$prefix" "$g"
}

added=$(mktemp); trap 'rm -f "$added"' EXIT
"$here/diff.sh" "$base" -U0 "$@" | awk '
  /^\+\+\+ / { path = substr($0, 5); sub(/^b\//, "", path); next }
  /^@@ / { split($3, n, ","); line = n[1]; sub(/^\+/, "", line); next }
  /^\+/ && path != "/dev/null" { printf "%s\t%d\t%s\n", path, line, substr($0, 2); line++ }
' >"$added"

[ -s "$added" ] || { echo "(no added lines)"; exit 0; }

hits=0
while IFS= read -r rule; do
  id=$(printf '%s' "$rule" | sed -n 's/^- \[\(R[0-9A-Za-z_-]*\)\].*/\1/p')
  pattern=$(printf '%s' "$rule" | sed -n "s/.* grep: '\(.*\)'[[:space:]]*$/\1/p")
  [ -n "$id" ] && [ -n "$pattern" ] || continue
  scope=$(printf '%s' "$rule" | sed -n "s/.* paths: '\([^']*\)'.*/\1/p")
  scope_re='.*'; [ -z "$scope" ] || scope_re=$(glob_to_regex "$scope")
  exclude=$(printf '%s' "$rule" | sed -n "s/.* exclude: '\([^']*\)' — grep: .*/\1/p")
  # Patterns go through ENVIRON: awk -v would eat the backslashes in "\(".
  out=$(RE="$pattern" SCOPE="$scope_re" EXCL="$exclude" awk -F'\t' -v id="$id" '
    { t = $3; if (ENVIRON["EXCL"] != "") gsub(ENVIRON["EXCL"], "", t) }
    $1 ~ ENVIRON["SCOPE"] && t ~ ENVIRON["RE"] {
      n++
      if (n <= 15) { t = $3; gsub(/^[ \t]+/, "", t); printf "%s:%s  %s  %s\n", $1, $2, id, substr(t, 1, 110) }
    }
    END { if (n > 15) printf "  ... %s: %d more hits\n", id, n - 15 }' "$added")
  if [ -n "$out" ]; then printf '%s\n' "$out"; hits=1; fi
done < <(grep -E "^- \[R[^]]*\].* grep: '" "$rules")

[ "$hits" -eq 1 ] || echo "(no rule hits)"
