#!/usr/bin/env bash
# Who has worked where, from git history. Used to justify owner suggestions.
# Works with any git remote (GitHub, GitLab, Bitbucket): it only reads local history.
# Written for bash 3.2 (macOS default): no associative arrays, no mapfile.
#
# Usage:
#   expertise.sh [--repo DIR] [--since WHEN] [--area GLOB]... [--alias EMAIL=NAME]...
#                [--skip EMAIL]... [--id-pattern ERE]
#
#   --repo        git working tree (default: current directory)
#   --since       any `git log --since` value (default: "90 days ago": about six
#                 two-week sprints, long enough to show ownership, short enough that
#                 people who moved on from an area don't dominate it)
#   --area        path glob that names an area, e.g. 'lib/feature/*' or 'src/modules/*'.
#                 `*` matches one path segment; the area is the matched prefix
#                 (lib/feature/checkout). Repeatable. Default: '*/*'.
#   --alias       merge an email into one person, e.g. 'x+me@users.noreply.github.com=Manh Tran'.
#                 NAME '-' skips that author. Repeatable.
#   --skip        drop an author email (bots, assistants). Repeatable.
#   --id-pattern  extended regex for story IDs in commit subjects
#                 (default: '[Ss][Cc]-[0-9]+|[A-Z][A-Z0-9]+-[0-9]+', i.e. Shortcut or Jira keys)
#
# Output, per person, most commits first: commits per area (top 8) and the 12 most
# recent distinct story IDs.
set -euo pipefail

repo="."
since="90 days ago"
id_pattern='[Ss][Cc]-[0-9]+|[A-Z][A-Z0-9]+-[0-9]+'
areas=()
alias_file="$(mktemp)"
rules_file="$(mktemp)"
trap 'rm -f "$alias_file" "$rules_file"' EXIT

while [ $# -gt 0 ]; do
  case "$1" in
    --repo) repo="$2"; shift 2 ;;
    --since) since="$2"; shift 2 ;;
    --area) areas+=("$2"); shift 2 ;;
    --alias) printf '%s\t%s\n' "${2%%=*}" "${2#*=}" >> "$alias_file"; shift 2 ;;
    --skip) printf '%s\t-\n' "$2" >> "$alias_file"; shift 2 ;;
    --id-pattern) id_pattern="$2"; shift 2 ;;
    -h|--help) sed -n '2,26p' "$0"; exit 0 ;;
    *) echo "error: unknown argument: $1 (see --help)" >&2; exit 2 ;;
  esac
done
[ ${#areas[@]} -gt 0 ] || areas=('*/*')

if ! git -C "$repo" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "error: $repo is not a git repository" >&2
  exit 1
fi

# Each area glob becomes "<segment count>\t<regex>", e.g. lib/feature/* -> 3  ^lib/feature/[^/]+$
for g in "${areas[@]}"; do
  g="${g%/}"
  segs=$(printf '%s' "$g" | awk -F/ '{print NF}')
  re=$(printf '%s' "$g" | sed -e 's/[].+?^${}()|[\\]/\\&/g' -e 's/\*/[^\/]+/g')
  printf '%s\t^%s$\n' "$segs" "$re" >> "$rules_file"
done

log="$(git -C "$repo" log --since="$since" --no-merges --name-only \
  --pretty=format:'@@%ae|%an|%s')"

if [ -z "$log" ]; then
  echo "No commits since \"$since\"."
  exit 0
fi

echo "# Expertise since \"$since\" (areas: ${areas[*]})"
echo

printf '%s\n' "$log" | awk -F'\t' -v rulesfile="$rules_file" -v idre="$id_pattern" '
  function norm(e) { e = tolower(e); gsub(/[^a-z0-9@._+-]/, "", e); return e }
  BEGIN {
    nr = 0
    while ((getline line < rulesfile) > 0) {
      split(line, parts, "\t")
      nr++; rule_segs[nr] = parts[1]; rule_re[nr] = parts[2]
    }
    close(rulesfile)
  }
  FILENAME == ARGV[1] { if (NF >= 2) alias[norm($1)] = $2; next }
  /^@@/ {
    split(substr($0, 3), a, "|")
    email = norm(a[1])
    who = (email in alias) ? alias[email] : a[2]
    skip = (who == "-" || a[2] ~ /\[bot\]/)
    if (skip) next
    split("", seen)
    subj = a[3]
    if (match(subj, idre)) {
      id = tolower(substr(subj, RSTART, RLENGTH))
      key = who SUBSEP id
      if (!(key in has_id) && nids[who] < 12) {
        has_id[key] = 1; ids[who] = ids[who] " " id; nids[who]++
      }
    }
    total[who]++
    next
  }
  skip { next }
  NF {
    n = split($0, p, "/")
    for (r = 1; r <= nr; r++) {
      k = rule_segs[r]
      if (n <= k) continue
      prefix = p[1]
      for (j = 2; j <= k; j++) prefix = prefix "/" p[j]
      if (prefix ~ rule_re[r]) {
        if (!(prefix in seen)) { seen[prefix] = 1; cnt[who, prefix]++ }
        break
      }
    }
  }
  END {
    for (x in cnt) { split(x, xx, SUBSEP); print "A\t" xx[1] "\t" cnt[x] "\t" xx[2] }
    for (w in total) print "T\t" w "\t" total[w] "\t" ids[w]
  }
' "$alias_file" - | sort -t$'\t' -k1,1 -k3,3nr | awk -F'\t' '
  $1 == "A" { if (shown[$2] < 8) { areas[$2] = areas[$2] (areas[$2] ? ", " : "") $4 " " $3; shown[$2]++ } next }
  $1 == "T" { tot[$2] = $3; st[$2] = $4; order[++n] = $2 }
  END {
    for (i = 1; i <= n; i++) {
      w = order[i]
      printf "## %s — %d commits\n", w, tot[w]
      printf "areas:  %s\n", (areas[w] ? areas[w] : "(no files in the given areas)")
      printf "stories:%s\n\n", (st[w] ? st[w] : " (none tagged)")
    }
  }
'
