# Stack pack: Android / Kotlin

Failure modes are read on every review (review-guide § Failure modes). Seed conventions
are read only during setup. A project rule, an "Enforced by tooling" line, or a
"Don't flag" entry that checks the same behavior drops the matching pack line. A
project rule that checks only part of a line leaves the rest in force.

**Detect:** `build.gradle(.kts)` with `com.android.application` or `com.android.library`.

**Checks:**
- analyze: `./gradlew detekt` / `./gradlew ktlintCheck` / `./gradlew lint`, whichever is configured (module-level)
- test: `./gradlew :<module>:testDebugUnitTest --tests '<class>'`
- test_for: `{ from: '(.*)/src/main/(java|kotlin)/(.*)\.kt', to: '$1/src/test/$2/$3Test.kt' }`

**ignore_paths:** `**/build/**`, `gradle/wrapper/**`, `**/*.lock`, `**/generated/**`

**Failure modes:**
- A coroutine is launched in `GlobalScope` or a scope that outlives the screen — grep: 'GlobalScope\.'
- A flow is collected in UI without `repeatOnLifecycle` or `collectAsStateWithLifecycle`
- IO or database work runs on the main thread
- A `!!` is used on a value that can be null at runtime — grep: '!!'
- A composable runs a side effect in composition instead of `LaunchedEffect`, or a lazy list keys rows by position when those rows hold state
- A `Context` or `View` is held by a ViewModel or a singleton
- A new permission or an exported component in the manifest is exposed with no check that it should be
- A `copy()` drops a field a reader still uses

**Seed conventions:**
- Compose state is hoisted
- Hardcoded strings or dimensions instead of resources or theme — grep: 'Text\("'
