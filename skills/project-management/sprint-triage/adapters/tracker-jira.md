# Tracker adapter: Jira (Cloud)

Status: **outline**. The operations and quirks below are Jira's documented behavior.
Exact MCP tool names depend on which server the project connects, so the setup step
finds them and saves them in `tracker.tools`. Once this adapter has been used on a real
project, replace the "likely" notes with what was confirmed.

## Access

Pick one during setup, in this order:
1. **Atlassian's remote MCP server** (OAuth). Find its tools with `ToolSearch` (queries:
   "jira", "atlassian"). Likely names: `searchJiraIssuesUsingJql`, `getJiraIssue`,
   `editJiraIssue`, `getTransitionsForJiraIssue`, `transitionJiraIssue`,
   `addCommentToJiraIssue`, `lookupJiraAccountId`, `getVisibleJiraProjects`. Many calls
   need a `cloudId`: pass the site URL (`https://<site>.atlassian.net`), stored as `tracker.site`.
2. **Another Jira MCP server** (e.g. community `mcp-atlassian`). Same discovery; save the names.
3. **REST API with an API token** via `curl` (`/rest/api/3/...` and `/rest/agile/1.0/...`).
   The token stays in an env var named in `tracker.token_env`, never in the config.

Save the chosen tool per operation in `tracker.tools` (e.g. `search: <tool name>`).
Connected check: a cheap read, such as the current user or visible projects.

## Operations

**T1 Find sprint:** JQL `project = <tracker.project> AND sprint in openSprints()` (current)
or `sprint in futureSprints()` (next), then read the sprint name and dates from the
issues' sprint field. With board access, the Agile API lists sprints for
`tracker.board_id` directly.

**T2 List sprint stories:** JQL, e.g. `project = MOB AND sprint = <sprint id> AND status in ("Backlog","To Do")`.
Request only the fields you need: `summary, status, assignee, issuetype, labels, priority`, plus the story-points field.

**T3 Get story:** get the issue with `description, comment, issuelinks, assignee, status,
priority, labels, <story points field>`. The description and comments may come back as
Atlassian Document Format (JSON). Read the text nodes. Links: `issuelinks[].type.name`
"Blocks", with `inwardIssue` ("is blocked by") or `outwardIssue` ("blocks") giving the direction.
Jira has no "blocked" flag. Derive it from unresolved "is blocked by" links.

**T4 Set owners:** edit `assignee` with an **account ID**. **Only one assignee.** For a
pair, assign the main owner and name the partner in a comment (or a team-specific custom
field, if `tracker.pair_field` is set).

**T5 Set state:** states change through **transitions**, not by setting a field. List the
issue's available transitions, pick the one whose target status equals
`tracker.states.<semantic>.name`, then run it. If the workflow requires fields on that
transition (a resolution, for example), ask the user instead of guessing. If no
transition leads there from the current status, report it as a manual step.

**T6 Add comment:** add a comment. Mentions need the account ID: a mention node in ADF, or
`[~accountid:<id>]` in wiki markup, depending on what the tool accepts. Look up missing
IDs with the account lookup tool during setup, not while posting.

**T7 Story URL:** `https://<tracker.site>/browse/<ISSUE-KEY>`

**T9 When a story joined the sprint:**
- Created after a date: JQL `project = <tracker.project> AND sprint = <sprint id> AND created >= "<YYYY-MM-DD>"`.
- Moved in later: read the issue's changelog (`expand=changelog`). Find the entry where the
  `Sprint` field's new value includes this sprint, and take its `created` time.
  Changelogs are long, so only check the few candidates the JQL can't place.

**T8 Setup discovery:** visible projects → pick `tracker.project`; boards for the project →
`tracker.board_id`; statuses for the project's workflow → map to semantic states; users
assignable to the project → account IDs; the current user.

## Quirks

- Story points is a custom field whose ID differs per site (`customfield_NNNNN`). Find it
  by name during setup and save it as `tracker.size_field`.
- Issue keys in commits and branches look like `MOB-123`. Set
  `tracker.story_id_pattern` to `MOB-[0-9]+` for the project key.
- Team-managed and company-managed projects have different workflows and fields. Record
  which one it is in `tracker.project_style`.

## Config keys

`tracker.site`, `tracker.project`, `tracker.board_id`, `tracker.project_style`,
`tracker.tools.*`, `tracker.token_env` (REST only), `tracker.states.*.name`,
`tracker.size_field`, `tracker.pair_field`, `tracker.story_id_pattern`,
`team.members[].tracker_id` (account IDs)
