#!/usr/bin/env bash
# Post the selected findings as ONE GitHub review: line comments and file-level comments
# together, plus the review body. The event is COMMENT, or APPROVE when the file asks for
# it. Never requests changes.
#
# Usage: post_review.sh <findings.json> [--dry-run]
#   findings.json:
#     { "pr": 123, "repo": "owner/name" (optional; defaults to this checkout's repo),
#       "event": "COMMENT" | "APPROVE" (optional; default COMMENT),
#       "body": "Status. What was reviewed. ..." (optional; without it the body is
#               "Left N inline comments."; findings may be [] when body is set),
#       "findings": [ { "path": "lib/a.dart", "line": 42 | null,
#                       "start_line": 40 (optional; a multi-line range ending at line),
#                       "placement": "line" | "file" | "body",
#                       "severity": "critical" | "major" | "minor" | "suggestion",
#                       "text": "..." } ] }
#   --dry-run  print what would be posted; call nothing that writes.
#   APPROVE is refused when any finding is an issue (severity other than "suggestion"),
#   when the PR is a draft, and when it is your own PR (GitHub rejects that with a 422).
#   A ```suggestion block in text replaces lines start_line..line (or just line). When a
#   finding moves to the body, the block is shown as plain code.
#
# Why a pending review + GraphQL threads: the REST "create review" comments array takes
# only path/line/side, so it cannot carry a file-level comment.
# A rejected thread does NOT error: GraphQL answers 200 with `thread: null` (line outside
# every hunk, or path not in the diff). Those findings are moved into the body, so nothing
# the user selected silently disappears.
#
# Output: review URL, then one row per finding: landed (line|file) or moved-to-body.
set -euo pipefail

usage() { sed -n '2,29p' "$0" >&2; exit 2; }
[ $# -ge 1 ] || usage
input="$1"; dry=""; [ "${2:-}" = "--dry-run" ] && dry=1
[ -f "$input" ] || { echo "error: $input not found" >&2; exit 1; }
jq -e '.pr and (((.findings // []) | length > 0) or ((.body // "") != ""))' "$input" >/dev/null \
  || { echo "error: $input needs .pr and a non-empty .findings or .body" >&2; exit 1; }

pr=$(jq -r .pr "$input")
repo=$(jq -r '.repo // empty' "$input")
[ -n "$repo" ] || repo=$(gh repo view --json nameWithOwner -q .nameWithOwner)

event=$(jq -r '.event // "COMMENT"' "$input")
case "$event" in
  COMMENT) ;;
  APPROVE)
    issues=$(jq -r '[(.findings // [])[] | select(.severity != "suggestion")] | length' "$input")
    [ "$issues" -eq 0 ] || {
      echo "error: event APPROVE with $issues issue finding(s); approve only when every finding is a suggestion" >&2
      exit 1
    }
    pr_meta=$(gh pr view "$pr" --repo "$repo" --json author,isDraft)
    [ "$(jq -r .isDraft <<<"$pr_meta")" != true ] \
      || { echo "error: PR #$pr is a draft; post it as COMMENT" >&2; exit 1; }
    [ "$(jq -r .author.login <<<"$pr_meta")" != "$(gh api user -q .login)" ] \
      || { echo "error: PR #$pr is your own; GitHub doesn't let you approve it" >&2; exit 1; }
    ;;
  *) echo "error: event must be COMMENT or APPROVE, not $event" >&2; exit 1 ;;
esac

summary=$(jq -r '.body // empty' "$input")

compose_body() {  # $1: "outside the diff" entries, $2: comments that landed inline
  local out=""
  if [ -n "$summary" ]; then out="$summary"
  elif [ -z "$1" ]; then
    if [ "$2" -eq 1 ]; then out="Left 1 inline comment."; else out="Left $2 inline comments."; fi
  fi
  [ -z "$1" ] || out="${out:+$out$'\n\n'}### Findings outside the diff"$'\n\n'"$1"
  printf '%s\n' "$out"
}

body_block() {  # one "outside the diff" entry; a suggestion block can't apply here
  jq -r '"**`\(.path)\(if .line then ":\(if .start_line then "\(.start_line)-" else "" end)\(.line)" else "" end)` — \(.severity // "issue")**\n\n\(.text | gsub("```suggestion"; "```"))\n"' <<<"$1"
}

if [ -n "$dry" ]; then
  echo "repo: $repo  pr: $pr  event: $event  (dry run: nothing posted)"
  jq -r '(.findings // [])[] | "\(.placement)\t\(.path):\(if .start_line then "\(.start_line)-" else "" end)\(.line // "-")\t\(.text | gsub("\n"; " ") | .[0:90])"' "$input"
  echo "--- body, if every line/file comment lands:"
  n=$(jq '[(.findings // [])[] | select(.placement != "body")] | length' "$input")
  outside=""
  while IFS= read -r f; do outside+="$(body_block "$f")"$'\n'; done \
    < <(jq -c '(.findings // [])[] | select(.placement == "body")' "$input")
  compose_body "$outside" "$n"
  exit 0
fi

review_id=$(gh api "repos/$repo/pulls/$pr/reviews" --method POST --jq .id 2>&1) || {
  echo "error: could not open a pending review: $review_id" >&2
  echo "If you already have a pending review on this PR, submit or delete it first:" >&2
  echo "  gh api repos/$repo/pulls/$pr/reviews --jq '.[] | select(.state==\"PENDING\") | .id'" >&2
  exit 1
}
cleanup() {
  [ "${submitted:-}" = 1 ] && return
  echo "error: stopped before submit. Pending review $review_id is visible only to you." >&2
  echo "  delete it: gh api repos/$repo/pulls/$pr/reviews/$review_id --method DELETE" >&2
}
trap cleanup EXIT
review_node=$(gh api "repos/$repo/pulls/$pr/reviews/$review_id" --jq .node_id)

q_line='mutation($rid:ID!,$body:String!,$path:String!,$line:Int!){addPullRequestReviewThread(input:{pullRequestReviewId:$rid,body:$body,path:$path,line:$line,side:RIGHT,subjectType:LINE}){thread{id}}}'
q_file='mutation($rid:ID!,$body:String!,$path:String!){addPullRequestReviewThread(input:{pullRequestReviewId:$rid,body:$body,path:$path,subjectType:FILE}){thread{id}}}'
q_range='mutation($rid:ID!,$body:String!,$path:String!,$start:Int!,$line:Int!){addPullRequestReviewThread(input:{pullRequestReviewId:$rid,body:$body,path:$path,startLine:$start,startSide:RIGHT,line:$line,side:RIGHT,subjectType:LINE}){thread{id}}}'

landed=0; outside=""; report=""
while IFS= read -r f; do
  placement=$(jq -r .placement <<<"$f"); path=$(jq -r .path <<<"$f")
  line=$(jq -r '.line // empty' <<<"$f"); start=$(jq -r '.start_line // empty' <<<"$f")
  text=$(jq -r .text <<<"$f")
  loc="${start:+$start-}${line:--}"
  thread=""
  if [ "$placement" = "line" ] && [ -n "$line" ] && [ -n "$start" ] && [ "$start" != "$line" ]; then
    thread=$(gh api graphql -f query="$q_range" -f rid="$review_node" -f body="$text" \
      -f path="$path" -F start="$start" -F line="$line" --jq '.data.addPullRequestReviewThread.thread.id // empty' 2>/dev/null || true)
  elif [ "$placement" = "line" ] && [ -n "$line" ]; then
    thread=$(gh api graphql -f query="$q_line" -f rid="$review_node" -f body="$text" \
      -f path="$path" -F line="$line" --jq '.data.addPullRequestReviewThread.thread.id // empty' 2>/dev/null || true)
  elif [ "$placement" = "file" ]; then
    thread=$(gh api graphql -f query="$q_file" -f rid="$review_node" -f body="$text" \
      -f path="$path" --jq '.data.addPullRequestReviewThread.thread.id // empty' 2>/dev/null || true)
  fi
  if [ -n "$thread" ]; then
    landed=$((landed + 1)); report+="landed ${placement}  $path:$loc"$'\n'
  else
    outside+="$(body_block "$f")"$'\n'
    if [ "$placement" = "body" ]; then report+="body         $path:$loc"$'\n'
    else report+="MOVED-TO-BODY $path:$loc (GitHub rejected the $placement comment)"$'\n'; fi
  fi
done < <(jq -c '(.findings // [])[]' "$input")

body=$(compose_body "$outside" "$landed")

url=$(gh api "repos/$repo/pulls/$pr/reviews/$review_id/events" --method POST \
  -f event="$event" -f body="$body" --jq .html_url)
submitted=1

echo "review: $url  ($event)"
printf '%s' "$report"
echo "check (what GitHub stored for this review):"
# The reviews/{id}/comments endpoint returns line and subject_type as null, so every row
# would read "line …:-". The PR comments endpoint carries the real anchor. line turns null
# once a later push changes the line (outdated); original_line keeps where it was posted.
gh api --paginate "repos/$repo/pulls/$pr/comments" --jq ".[] | select(.pull_request_review_id == $review_id)
  | \"  \(.subject_type)\t\(.path):\(if .start_line then \"\(.start_line)-\" else \"\" end)\(.line // .original_line // \"-\")\(if .line == null and .original_line != null then \" (outdated)\" else \"\" end)\""
