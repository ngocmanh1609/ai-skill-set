# Tracker adapter: Jira (design-link lookup only)

Status: **outline**. Jira MCP servers differ (Atlassian's official server, community
ones). At setup, find the "get issue" tool with `ToolSearch` ("jira issue") and save its
name as `tracker.tools.get_issue`.

**K1 Story → design link:** match `tracker.story_id_pattern` (e.g. `[A-Z][A-Z0-9]+-[0-9]+`)
in the branch name, call the get-issue tool, and search the description, remote links,
and custom fields for `figma.com`. The description may be ADF JSON; search its text nodes.

**Config keys:** `tracker.type: jira`, `tracker.story_id_pattern`, `tracker.tools.get_issue`
