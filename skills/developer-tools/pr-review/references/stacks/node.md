# Stack pack: Node.js services (TypeScript or JavaScript)

Failure modes are read on every review (review-guide § Failure modes). Seed conventions
are read only during setup. A project rule, an "Enforced by tooling" line, or a
"Don't flag" entry that checks the same behavior drops the matching pack line. A
project rule that checks only part of a line leaves the rest in force.

**Detect:** `package.json` without `react`, with a server framework (`express`, `fastify`, `@nestjs/*`, `hono`, `koa`).

**Checks:**
- analyze: `<pm> exec eslint {files}`; `<pm> exec tsc --noEmit` if TypeScript
- test: `<pm> exec vitest run {tests}` or `<pm> exec jest {tests}`
- test_for: `{ from: 'src/(.*)\.ts', to: 'test/$1.test.ts' }` (adjust to the project layout)

**ignore_paths:** lockfiles, `dist/**`, `**/*.generated.*`, `prisma/migrations/**/migration_lock.toml`, `**/*.snap`

**Failure modes:**
- Input is used before schema or DTO validation
- A query is built from a string that includes user input — grep: '(query|execute|raw)\([`'"].*\$\{'
- A promise is left floating, a `catch {}` swallows the error, or an `async` route handler does not forward errors
- A secret or token is logged or hardcoded — grep: '(api[_-]?key|secret|password|token)[ ]*[:=][ ]*['"'][^'"]{8,}'
- A new route or resolver has no auth or permission check
- An outbound HTTP call has no timeout, or `Promise.all` runs over a list whose size the user controls
- A migration does not match the model change, cannot be reversed, or runs for a long time on a big table with no plan
- A spread builds the next object and drops a field a reader still uses

**Seed conventions:**
- Env vars are read through the project's config module, not `process.env` scattered in code — grep: 'process\.env\.'
