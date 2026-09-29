# Tracker adapter: Shortcut

## Access

MCP server `shortcut`. Tools are named `mcp__shortcut__<tool>`. Load their schemas with
`ToolSearch` (`select:mcp__shortcut__iterations-search,...`) before the first call.
- Connected check: `mcp__shortcut__users-get-current` returns the user.
- Read-only: `iterations-*` reads, `stories-get-by-id`, `stories-search`, `teams-*`,
  `workflows-*`, `users-*`.
- Writes: `stories-update`, `stories-create-comment` (and anything with create, update,
  or delete in its name).

## Operations

**T1 Find sprint:** `mcp__shortcut__iterations-search` with `name` = `tracker.sprint_name_hint`
(e.g. "Sprint") and `state` = `started` (current) or `unstarted` (next). Pick by dates when
more than one matches. Iterations can have empty `team_ids`, so don't filter by team and
don't rely on `iterations-get-active`.

**T2 List sprint stories:** `mcp__shortcut__iterations-get-stories` with
`includeStoryDescriptions: false`. Keep stories where `team_id` = `tracker.team.id` and
`archived` is false. Map `workflow_state_id` to semantic states through `tracker.states`.

**T3 Get story:** `mcp__shortcut__stories-get-by-id` with `full: false` by default. The
slim record has the description, comments (oldest first, **without dates**), label names,
`related_stories` (IDs only, **no direction**), PR URLs, branches, and the `blocked` /
`blocker` flags, at a fraction of the size of `full: true`. Fetch `full: true` only for
the stories where you need:
- link direction (`story_links[].verb` "blocks" / "relates to", with `subject_id` →
  `object_id`) to check an inverted or stale blocker, or
- comment dates, `moved_at` (to spot a bulk move to Backlog), or custom-field names (Priority).

**T4 Set owners:** `mcp__shortcut__stories-update` with `owner_ids` (user UUIDs). Several
owners are allowed. **The list replaces the current owners**, so include existing owners
you want to keep.

**T5 Set state:** `mcp__shortcut__stories-update` with `workflow_state_id` =
`tracker.states.<semantic>.id`.

**T6 Add comment:** `mcp__shortcut__stories-create-comment` with `storyPublicId` and
`text` (Markdown). Mention people with `@<mention_name>`; Shortcut turns it into a
notification. It returns the comment URL. Put that in the change log.

**T7 Story URL:** `https://app.shortcut.com/<tracker.workspace>/story/<id>`

**T8 Setup discovery:**
- Current user: `mcp__shortcut__users-get-current`; their teams: `mcp__shortcut__users-get-current-teams`
- Teams: `mcp__shortcut__teams-list`; members and workflow: `mcp__shortcut__teams-get-by-id`
- States: `mcp__shortcut__workflows-get-by-id` (the team's `default_workflow_id`)
- Users (names, mention names, UUIDs): `mcp__shortcut__users-list`
- Workspace slug: the path segment in any `app_url`

**T9 When a story joined the sprint:**
- Created after a date: `mcp__shortcut__stories-search` with `created: "<YYYY-MM-DD>..*"`
  and `team: <team mention>`. Then keep only the IDs that are in the sprint's T2 list.
- Moved in later: `mcp__shortcut__stories-get-history`. It returns entries oldest first,
  each with a `changed_at` time:
  - a `create` action whose `iteration_id` is the sprint means the story was born in the sprint
  - `changes.iteration_id.new` equal to the sprint means it was moved in at that time

  History entries include full description diffs, so they're large. Call it only on the
  few candidates the search can't place.

## Quirks

- Size lives in labels (e.g. `complexity:S/M/L`), the `estimate` field, or a section of
  the description. Record which one the team uses in `tracker.size_signal`.
- Priority is a custom field. The slim record shows only value IDs; the full record's
  `relatedEntities.custom_fields` maps IDs to names.
- Story IDs in commits and branches look like `sc-12345`. Default `tracker.story_id_pattern`: `[Ss][Cc]-[0-9]+`.
- Stories owned by other teams (API, design) often block ours. Fetch them to read their
  state and owner, but never change them.

## Config keys

`tracker.workspace`, `tracker.team.id`, `tracker.related_teams[]` (optional: teams whose stories block ours), `tracker.workflow_id`, `tracker.sprint_name_hint`, `tracker.states.*.id`,
`tracker.size_signal`, `tracker.story_id_pattern`, `team.members[].tracker_id`, `team.members[].mention`
