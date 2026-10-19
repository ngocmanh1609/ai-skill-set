# Code host adapter: GitLab

Status: **outline**. The scripts speak GitHub. Do each operation by hand with `glab`
until a GitLab variant of the scripts exists, and confirm these calls on the first
real project.

## Access

`glab` CLI (`GITLAB_HOST` or `glab auth login --hostname <host>` for self-managed).
- **H7** Auth: `glab auth status`
- Read-only: `glab mr view`, `glab mr diff`, `glab api` GET calls
- Writes: draft notes and `bulk_publish` (H4)

## Operations

**H1 MR context:** `glab mr view <iid> -F json` (title, description, source/target
branch, `sha`, `diff_refs`). Changed files and hunks: `glab mr diff <iid>`, parsed as in
`pr_context.sh`. Existing comments: `glab api projects/:id/merge_requests/<iid>/discussions`.
The current user's last review: the newest discussion note by `glab api user` → username;
use `diff_refs.head_sha` from that time only if it's recorded, otherwise do a full review.
`openFromOthers`: group the unresolved, resolvable discussions by the author of their
first note, leaving out you, the MR author, and bot accounts. Set `changesRequested`
from the reviewer's state where the GitLab version has one (`requested_changes`),
otherwise false.

**H2 Safe checkout:** same guard as GitHub, then `glab mr checkout <iid>` and `git fetch origin <target>`.

**H4 Post review** (one batch, like a GitHub review):
1. For each finding, `POST projects/:id/merge_requests/<iid>/draft_notes` with `note` and,
   for `line` placement, `position[position_type]=text`, `position[base_sha]`,
   `position[start_sha]`, `position[head_sha]` (from `diff_refs`), `position[new_path]`,
   `position[new_line]`. For `file` placement, use `position[position_type]=file`
   (GitLab 16.4+). If unavailable, put it in the summary note.
2. `POST .../draft_notes/bulk_publish`.
3. Post the body as a normal note only if some findings are outside the diff.
4. Only when the event is `APPROVE`: post the body as a normal note (an approval carries
   no text), then `glab mr approve <iid> --sha <reviewedSha>`, which fails if the head
   moved. Refuse first, as on GitHub, when a finding is an issue, the MR is a draft, or
   it's the user's own MR.
Never request changes or change the MR state in any other way.

**H5 Confirm posted:** list the discussions again and match path and line.

**H6 Current head SHA:** `glab mr view <iid> -F json | jq -r .sha`

## Quirks

- `iid` (per project) vs `id` (global): the CLI and URLs use `iid`.
- A position outside the diff is rejected with a 400 error, not dropped silently. Move
  that finding to the summary note.

## Config keys

`code_host.type: gitlab`, `code_host.host` (self-managed only)
