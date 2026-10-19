# Stack pack: TypeScript + React (Next.js, Vite, React Native)

Failure modes are read on every review (review-guide § Failure modes). Seed conventions
are read only during setup. A project rule, an "Enforced by tooling" line, or a
"Don't flag" entry that checks the same behavior drops the matching pack line. A
project rule that checks only part of a line leaves the rest in force.

**Detect:** `package.json` with `react` (plus `next`, `vite`, or `react-native`). Use the lockfile's package manager (`pnpm-lock.yaml` → pnpm, `yarn.lock` → yarn, else npm).

**Checks:**
- analyze: `<pm> exec eslint {files}` and `<pm> exec tsc --noEmit` (tsc runs on the whole project)
- test: `<pm> exec vitest run {tests}` or `<pm> exec jest {tests}`, whichever the project uses
- test_for: `{ from: 'src/(.*)\.(tsx?)', to: 'src/$1.test.$2' }` (or `__tests__/`, per the project)

**ignore_paths:** `*-lock.yaml`, `package-lock.json`, `yarn.lock`, `**/*.generated.*`, `**/__generated__/**`, `dist/**`, `build/**`, `.next/**`, `**/*.snap`

**Failure modes:**
- An effect that subscribes, starts a timer, or opens a socket does not return a cleanup
- State is updated from async work after unmount, or from a stale closure
- A hook is called conditionally, or an effect's dependency array omits a value it reads
- A list item is keyed by array index when items can move and the row holds state — grep: 'key=\{(i|index|idx)\}'
- `dangerouslySetInnerHTML` is used, or a URL or HTML string is built from user input — grep: 'dangerouslySetInnerHTML'
- A promise is not awaited or `.catch`-ed, or an `async` handler has no error path
- A secret or a server-only import reaches a client component
- A spread or copy builds the next state and drops a field a reader still uses
- `any`, a non-null `!`, or an `as` cast hides a value that can be null or the wrong type at runtime — grep: ': any[^A-Za-z]|as any'
- An interactive element is not a button or link, or has no accessible name; an image has no `alt`

**Seed conventions:**
- Leftover `console.log` / `debugger` — grep: 'console\.log\(|debugger;'

**UI tokens:** the design-token source (Tailwind config, CSS variables, a theme object) and spacing scale.
