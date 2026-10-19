# Design adapter: Figma

## Access

Figma MCP server (`mcp__figma__*`). Load schemas with `ToolSearch` (`select:mcp__figma__get_screenshot`)
before the first call. Read-only for this skill.

## Operations

**D1 Fetch frame**
- Link forms: `figma.com/design/<fileKey>/<name>?node-id=<nodeId>` (also `/file/`,
  `/proto/`). Convert `-` to `:` in the node ID (`12-345` → `12:345`).
- No `node-id` in the link: treat it as no design source. Don't guess a node.
- Call `mcp__figma__get_screenshot` with `fileKey` and `nodeId`, then look at the image.
- Exact values, only when the screenshot is really ambiguous for a specific
  measurement: `mcp__figma__get_design_context` on that node. It is a design-to-code
  tool and much larger, so don't use it by default.

## Config keys

`design.type: figma`, `design.look_in`, `design.compare`
