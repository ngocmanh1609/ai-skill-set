# Tracker adapter: Linear (design-link lookup only)

Status: **outline**. At setup, find the "get issue" tool with `ToolSearch` ("linear issue")
and save its name as `tracker.tools.get_issue`.

**K1 Story → design link:** match `tracker.story_id_pattern` (e.g. `[A-Za-z]+-[0-9]+`;
Linear branch names look like `user/eng-123-title`) in the branch name, call the tool,
and search the description and attachments for `figma.com`.

**Config keys:** `tracker.type: linear`, `tracker.story_id_pattern`, `tracker.tools.get_issue`
