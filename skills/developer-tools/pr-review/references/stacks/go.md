# Stack pack: Go

Failure modes are read on every review (review-guide § Failure modes). Seed conventions
are read only during setup. A project rule, an "Enforced by tooling" line, or a
"Don't flag" entry that checks the same behavior drops the matching pack line. A
project rule that checks only part of a line leaves the rest in force.

**Detect:** `go.mod`.

**Checks:**
- analyze: `go vet ./...` and `golangci-lint run` if `.golangci.yml` exists (package-level, not per file)
- test: `go test ./<changed package dirs>/...`
- test_for: `{ from: '(.*)\.go', to: '$1_test.go' }`

**ignore_paths:** `go.sum`, `**/*.pb.go`, `**/*_gen.go`, `**/zz_generated*.go`, `vendor/**`, `**/mock_*.go`

**Failure modes:**
- An error is ignored (`_ =` or an unchecked return) — grep: '_ = [A-Za-z.]+\(|_, _ = '
- A goroutine has no way to stop, or leaks on an early return
- A loop variable is captured by a goroutine or closure on a module below Go 1.22
- `defer` runs inside a loop, or an HTTP response body is not closed
- `context.Background()` is used deep in a request path, or a context is stored in a struct — grep: 'context\.Background\(\)'
- A map or slice is written from several goroutines without a lock
- A struct update drops a field a reader still uses

**Seed conventions:**
- Errors are wrapped without `%w` when the project wraps errors
- Exported identifiers have doc comments if the project lints for it
