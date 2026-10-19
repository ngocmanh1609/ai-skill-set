# Stack pack: Flutter / Dart

Failure modes are read on every review (review-guide § Failure modes). Seed conventions
are read only during setup. A project rule, an "Enforced by tooling" line, or a
"Don't flag" entry that checks the same behavior drops the matching pack line. A
project rule that checks only part of a line leaves the rest in force.

**Detect:** `pubspec.yaml` with a `flutter:` dependency. If `.fvmrc`/`.fvm/` exists, prefix commands with `fvm`.

**Checks:**
- analyze: `flutter analyze {files}` (accepts paths)
- test: `flutter test {tests}`
- test_for: `{ from: 'lib/(.*)\.dart', to: 'test/$1_test.dart' }`

**ignore_paths:** `**/*.g.dart`, `**/*.freezed.dart`, `**/*.gr.dart`, `**/*.config.dart`, `**/*.mocks.dart`, `**/*.gen.dart`, `lib/gen/**`, `pubspec.lock`, `ios/Podfile.lock`, `**/generated_plugin_registrant.*`

**Failure modes:**
- A `TextEditingController`, `FocusNode`, `AnimationController`, `ScrollController`, stream, or subscription created in a `State` is not disposed in `dispose()`
- `setState` or `emit` runs after dispose or close, because an async callback finished late
- `BuildContext` is used after an `await` without a `mounted` / `context.mounted` check
- A `Future` whose result or error matters is not awaited (`unawaited` must be deliberate)
- A list row that holds state (a field, a selection, an expansion) has no stable key when items can move
- Parsing, sorting, fetching, or navigation runs inside `build()`
- A `copyWith` builds the next UI model and drops a field the screen or a later emit still reads
- A log, analytics event, or error report includes a token, a phone number, or a request or cart body

**Seed conventions:**
- `const` constructors where possible in new widgets (only if the lints don't enforce it)
- Hardcoded user-facing strings instead of the project's localization, including snack bars, dialog titles, button labels, and semantics labels — grep: 'Text\(['"]'
- Platform-specific code guarded (`Platform.isIOS` / `kIsWeb`) where the app runs on several platforms
- Generated files are regenerated in the same PR when annotated classes change (`build_runner`)

**UI tokens:** look for the project's theme class (`AppTheme`, `context.theme`, a `ThemeExtension`) and sizing helpers (`flutter_screenutil` / `flutter_scale_kit`: `.w`, `.h`, `.sp`, `.r`).
