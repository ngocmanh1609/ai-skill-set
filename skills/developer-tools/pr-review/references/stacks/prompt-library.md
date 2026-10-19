# Stack pack: Prompt library (prompts, skills, agents)

Failure modes are read on every review (review-guide § Failure modes). Seed conventions
are read only during setup. A project rule, an "Enforced by tooling" line, or a
"Don't flag" entry that checks the same behavior drops the matching pack line. A
project rule that checks only part of a line leaves the rest in force. Combine it with
the pack for the code the repo also ships (a TypeScript installer next to the prompts →
also `node`).

**Detect:** most reviewable files are Markdown instructions: `prompts/`, `agents/`,
`commands/`, `skills/**/SKILL.md`, `.claude/{agents,commands,skills}/`, `*.prompt.md`,
`AGENTS.md`. Or templates with include syntax (`{{> partial}}`, `{% include %}`). Or an
eval harness (`promptfooconfig.yaml`, `evals/*.json`).

**Checks:**
- analyze: the Markdown linter if one is configured (`markdownlint`, `remark`); otherwise none
- render: the command that assembles the prompts (a build, or the installer's build
  mode). Set `checks.render` so a broken include fails the review
- test: the repo's tests plus any eval checks that run without API keys (template-render
  evals, fixture checks). Leave out evals that call a model unless CI runs them

**composed_paths:** the committed rendered output, if there is one (for example
`packages/.claude/**`). Keep it in `ignore_paths` too: it is read for the composed view
and never commented on.

**ignore_paths:** rendered output, `**/dist/**`, eval result folders (`.promptfoo*/`,
`**/results/**`)

**Failure modes:**
- A reference to a section, step, partial, or file ("see X below", "Step 4", `{{> name}}`) does not resolve in the rendered prompt
- An included partial contradicts a constraint of the prompt that includes it
- A partial's first heading level does not fit where it is included
- A decision step has no criterion or threshold
- A step that asks the user or makes a choice does not say where the answer is recorded, so the next step or another role cannot find it
- A new stop, refusal, or required input leaves no route for a kind of input that reached that step before
- A section is marked optional with no condition for when to include it — grep: '\((optional|if applicable|if relevant)\)'
- An agent or command changes something its role does not own; changes to specs, stories, or another role's output skip the owner
- A tool name does not say which MCP server or CLI provides it

**Seed conventions:**
- Framework-agnostic prompts don't hard-code a stack, branch, or file extension — grep: '(\.\.\.?|diff |log )(origin/)?(develop|master)([^A-Za-z_-]|$)|--include=.?\*\.(rb|erb|py|kt|swift|dart|go)([^A-Za-z]|$)'
- New domain terms match the glossary
- A new command, agent, or skill is registered where the installer looks for it and listed in the docs
- Tests on prompt text assert on one section, not on the whole file through a regex with the `s` flag — grep: 'toMatch\(/[^/]*\.\*[^/]*/[a-z]*s[a-z]*\)'
