# Adapter contract

SKILL.md never names a host, design, or tracker tool directly. It asks for the operations
below, and the adapter named in the project config says how to do each one. To support a
new tool, copy this file to `adapters/<kind>-<type>.md` and fill in every operation. If the
tool can't do one, write **"Not supported"** and say what the user should do by hand.

Each adapter also lists **Access** (CLI or MCP, how to check login, which calls write),
**Quirks** (anything that doesn't behave as the operation name suggests), and **Config
keys** it reads.

## Code host

| ID | Operation | Must return / do |
|---|---|---|
| H1 | PR context | the `pr_context.sh` JSON shape: metadata, reviewable files with new-side hunk ranges, existing review threads, review bodies, the current user's last reviewed commit, the last approval by someone else, other reviewers with open threads or a standing request for changes (`openFromOthers`), linked issues |
| H2 | Safe checkout | refuse on a dirty tree; check out the PR head (fork-safe); fetch the base; confirm HEAD = head SHA |
| H3 | Existing comments | per thread: path, line, author, resolved, outdated, first-comment excerpt, latest reply; plus review bodies (part of H1 on GitHub) |
| H4 | Post review | one review holding line comments (single line or a line range), file comments, and a body; event COMMENT, or APPROVE when the input asks for it, refused when a finding is an issue, the PR is a draft, or it's the user's own PR; never request changes; report any comment the host rejected |
| H5 | Confirm posted | list what the host stored for that review (type, path, line), read from an endpoint that returns the real anchor |
| H6 | Current head SHA | to detect a push made during the review |
| H7 | Auth check | the CLI or MCP server is logged in |

## Design

| ID | Operation | Must return / do |
|---|---|---|
| D1 | Fetch frame | parse a design link into its IDs and return a rendered image of that frame; say what to use when exact values are needed |

## Second opinion (optional; only with --second-opinion)

| ID | Operation | Must return / do |
|---|---|---|
| R1 | Independent review | run another AI tool read-only on the diff and return its report as text, one `path:line — severity — cause — fix` line per defect |
| R2 | Availability | the tool is installed and logged in; if not, say how to fix it |

## Tracker (optional; only for finding design links)

| ID | Operation | Must return / do |
|---|---|---|
| K1 | Story → design link | given a story ID from the branch name, return any design URLs in its description, links, or custom fields |
