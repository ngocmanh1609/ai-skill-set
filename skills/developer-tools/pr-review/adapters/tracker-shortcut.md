# Tracker adapter: Shortcut (design-link lookup only)

**Access:** MCP server `shortcut`; load `mcp__shortcut__stories-get-by-id` with `ToolSearch`. Read-only.

**K1 Story → design link:** match `tracker.story_id_pattern` (e.g. `[Ss][Cc]-[0-9]+`) in
the head branch name, keep the digits, then call `mcp__shortcut__stories-get-by-id` with
`full: false`. Search the description and external links for `figma.com`. If there's
no hit, retry once with `full: true` for custom fields.

**Config keys:** `tracker.type: shortcut`, `tracker.story_id_pattern`
