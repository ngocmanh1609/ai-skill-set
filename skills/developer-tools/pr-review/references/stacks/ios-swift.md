# Stack pack: iOS / Swift

Failure modes are read on every review (review-guide § Failure modes). Seed conventions
are read only during setup. A project rule, an "Enforced by tooling" line, or a
"Don't flag" entry that checks the same behavior drops the matching pack line. A
project rule that checks only part of a line leaves the rest in force.

**Detect:** `Package.swift`, `*.xcodeproj`, or `*.xcworkspace`.

**Checks:**
- analyze: `swiftlint lint {files}` if `.swiftlint.yml` exists
- test: `xcodebuild test -scheme <scheme> -only-testing:<target>/<class>` (slow: run only when the user asks, or when the project's CLAUDE.md says to)
- test_for: `{ from: '(.*)/([^/]*)\.swift', to: '$1Tests/$2Tests.swift' }` (adjust to the targets)

**ignore_paths:** `Package.resolved`, `Podfile.lock`, `Pods/**`, `**/*.generated.swift`, `**/R.generated.swift`, `*.pbxproj` (review by hand only when targets or settings change)

**Failure modes:**
- An escaping closure captures `self` strongly in a long-lived object
- UI work runs off the main actor, or a view model that drives UI is missing `@MainActor`
- A force unwrap, `try!`, or `as!` is used on a value that can fail at runtime — grep: 'try!|as!|[A-Za-z)\]]!\.'
- A `Task {}` has no cancellation path
- `@StateObject` and `@ObservedObject` ownership is wrong, or `body` does heavy work
- A secret or token is stored in `UserDefaults` instead of the Keychain
- A copy drops a field a reader still uses

**Seed conventions:**
- Hardcoded strings instead of `String(localized:)` / `NSLocalizedString` — grep: 'Text\("'
