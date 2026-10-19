#!/usr/bin/env bash
# Print one JSON object with everything the review needs to know about a GitHub PR,
# so the model makes one call instead of a dozen and never re-types the parsing.
#
# Usage: pr_context.sh [<pr number | PR URL>] [--ignore <glob>]...
#   No PR given: uses the open PR for the current branch.
#   --ignore: paths left out of `files` (generated code, lock files). Globs follow
#             .gitignore style: a pattern without "/" matches at any depth, "**" spans dirs.
#
# Output keys:
#   repo number url title body state isDraft author base head headSha me
#   files            [{path, additions, deletions, hunks: [[first, last], ...]}]  (reviewable)
#   ignored          [path]                    (matched --ignore; not reviewed)
#   reviewableLines  additions + deletions over `files`
#   existingComments [{path, line, author, authorBot, resolved, outdated, excerpt, replies, lastReply}]
#                    one per review thread; excerpt is the first comment, lastReply
#                    {author, excerpt} is the latest reply or null
#   openFromOthers   [{login, openThreads, outdatedThreads, changesRequested}]  reviewers
#                    other than you and the PR author (bots left out) who started
#                    unresolved threads, or whose latest approve/request-changes review
#                    still requests changes. outdatedThreads counts the open threads on
#                    code that has since changed
#   reviewBodies     [{author, state, commit, submittedAt, excerpt}]  reviews with a body
#                    (general findings often live only here)
#   myLastReview     {commit, submittedAt} | null   (latest review by the current user)
#   lastApproval     {author, commit, submittedAt} | null  (latest approval by someone else)
#   linkedIssues     [{number, title, repo}]  issues the PR closes
#   threadsTruncated present only when the PR has more than 100 review threads
#   diffError        present only when `gh pr diff` failed (very large PRs); hunks are empty
#
# Hunks are new-file line ranges from GitHub's own diff, which is what review comments
# anchor to. A line outside every hunk cannot take a line comment.
set -euo pipefail

usage() { sed -n '2,32p' "$0" >&2; exit 2; }
command -v gh >/dev/null || { echo "error: gh CLI not found" >&2; exit 1; }
command -v jq >/dev/null || { echo "error: jq not found" >&2; exit 1; }

pr=""; ignores=()
while [ $# -gt 0 ]; do
  case "$1" in
    --ignore) [ $# -ge 2 ] || usage; ignores+=("$2"); shift 2 ;;
    -h|--help) usage ;;
    *) pr="$1"; shift ;;
  esac
done

if [ -z "$pr" ]; then
  pr=$(gh pr view --json number -q .number 2>/dev/null) \
    || { echo "error: no open PR for the current branch; pass a PR number or URL" >&2; exit 1; }
fi

# .gitignore-style glob -> anchored ERE. Placeholders keep "**" apart from "*".
glob_to_regex() {
  local g="$1" prefix=""
  case "$g" in */*) ;; *) prefix='(.*/)?' ;; esac
  g=$(printf '%s' "$g" | sed -e 's/[.+^$(){}|]/\\&/g' \
    -e 's#\*\*/#@DSLASH@#g' -e 's#\*\*#@DSTAR@#g' -e 's#\*#[^/]*#g' -e 's#?#[^/]#g' \
    -e 's#@DSLASH@#(.*/)?#g' -e 's#@DSTAR@#.*#g')
  printf '^%s%s$' "$prefix" "$g"
}

ignore_re='^$'
if [ ${#ignores[@]} -gt 0 ]; then
  ignore_re=""
  for g in "${ignores[@]}"; do ignore_re="${ignore_re:+$ignore_re|}($(glob_to_regex "$g"))"; done
fi

meta=$(gh pr view "$pr" --json number,url,title,body,state,isDraft,author,baseRefName,headRefName,headRefOid,files)
repo=$(jq -r '.url | capture("github\\.com/(?<r>[^/]+/[^/]+)/pull/").r' <<<"$meta")
number=$(jq -r .number <<<"$meta")
me=$(gh api user -q .login)

# "path<TAB>first<TAB>last" per hunk that adds or keeps lines on the new side.
diff_error=""; hunks=""
raw=$(mktemp); trap 'rm -f "$raw"' EXIT
if gh pr diff "$number" --repo "$repo" >"$raw" 2>&1; then
  hunks=$(awk '
    /^diff --git / { path = ""; next }
    /^\+\+\+ / { path = substr($0, 5); sub(/^b\//, "", path); if (path == "/dev/null") path = ""; next }
    /^@@ / && path != "" {
      split($3, n, ","); start = n[1]; sub(/^\+/, "", start)
      len = (2 in n) ? n[2] : 1
      if (len > 0) printf "%s\t%d\t%d\n", path, start, start + len - 1
    }' "$raw")
else
  diff_error="gh pr diff failed: $(head -1 "$raw")"
fi

# Threads (with text and resolved state), review bodies, and linked issues in one call.
threads=$(gh api graphql -f owner="${repo%%/*}" -f name="${repo#*/}" -F n="$number" -f query='
query($owner:String!,$name:String!,$n:Int!){repository(owner:$owner,name:$name){pullRequest(number:$n){
  reviewThreads(first:100){totalCount nodes{isResolved isOutdated path line originalLine
    comments(first:50){totalCount nodes{author{login __typename} body}}}}
  reviews(last:100){nodes{author{login __typename} state body submittedAt commit{oid}}}
  closingIssuesReferences(first:10){nodes{number title repository{nameWithOwner}}}}}}' \
  --jq '.data.repository.pullRequest')

jq -cn \
  --argjson meta "$meta" --arg repo "$repo" --arg me "$me" --arg ignore "$ignore_re" \
  --arg hunks "$hunks" --argjson gql "$threads" \
  --arg diffError "$diff_error" '
  def clip($n): gsub("<[^>]+>"; "") | gsub("\\s+"; " ") | ltrimstr(" ") | .[0:$n];
  ($gql.reviewThreads.nodes | map(
    (.comments.nodes) as $c | {
      path, line: (.line // .originalLine), author: ($c[0].author.login // "ghost"),
      authorBot: ($c[0].author.__typename == "Bot"),
      resolved: .isResolved, outdated: .isOutdated, excerpt: ($c[0].body | clip(240)),
      replies: (.comments.totalCount - 1),
      lastReply: (if ($c | length) > 1
        then {author: ($c[-1].author.login // "ghost"), excerpt: ($c[-1].body | clip(160))}
        else null end)})) as $comments
  | ($gql.reviews.nodes | map(select(.state != "PENDING"))) as $reviews
  | ($reviews | map(select((.author.login // "") == $me))
      | last | if . then {commit: .commit.oid, submittedAt} else null end) as $last
  | ($reviews | map(select(.state == "APPROVED" and (.author.login // "") != $me))
      | last | if . then {author: .author.login, commit: .commit.oid, submittedAt} else null end) as $approval
  | ($meta.author.login) as $prAuthor
  | def other($login; $bot): ($login != $me and $login != $prAuthor and ($bot | not));
  # A COMMENTED review does not lift an earlier request for changes; only a later
  # approval or a dismissal does, so read the latest decisive review per reviewer.
  ($reviews | map(select(.state == "APPROVED" or .state == "CHANGES_REQUESTED" or .state == "DISMISSED")
      | select(other(.author.login // "ghost"; .author.__typename == "Bot")))
    | group_by(.author.login) | map(max_by(.submittedAt))
    | map(select(.state == "CHANGES_REQUESTED") | .author.login)) as $blocking
  | ($comments | map(select((.resolved | not) and other(.author; .authorBot)))) as $open
  | ((($open | map(.author)) + $blocking) | unique | map(. as $l | {
      login: $l,
      openThreads: ($open | map(select(.author == $l)) | length),
      outdatedThreads: ($open | map(select(.author == $l and .outdated)) | length),
      changesRequested: ($blocking | index($l) != null)})) as $openFromOthers
  |
  ($hunks | split("\n") | map(select(length > 0) | split("\t"))
    | reduce .[] as $h ({}; .[$h[0]] += [[($h[1] | tonumber), ($h[2] | tonumber)]])) as $hmap
  | ($meta.files | map(select(.path | test($ignore) | not))) as $keep
  | {
      repo: $repo, number: $meta.number, url: $meta.url, title: $meta.title, body: $meta.body,
      state: $meta.state, isDraft: $meta.isDraft, author: $meta.author.login,
      base: $meta.baseRefName, head: $meta.headRefName, headSha: $meta.headRefOid, me: $me,
      files: ($keep | map({path, additions, deletions, hunks: ($hmap[.path] // [])})),
      ignored: ($meta.files | map(select(.path | test($ignore))) | map(.path)),
      reviewableLines: ($keep | map(.additions + .deletions) | add // 0),
      existingComments: $comments,
      openFromOthers: $openFromOthers,
      reviewBodies: ($reviews | map(select((.body // "") != "")
        | {author: (.author.login // "ghost"), state, commit: .commit.oid, submittedAt,
           excerpt: (.body | clip(1500))})),
      myLastReview: $last,
      lastApproval: $approval,
      linkedIssues: ($gql.closingIssuesReferences.nodes
        | map({number, title, repo: .repository.nameWithOwner}))
    }
  + (if $gql.reviewThreads.totalCount > 100 then {threadsTruncated: $gql.reviewThreads.totalCount} else {} end)
  + (if $diffError == "" then {} else {diffError: $diffError} end)'
