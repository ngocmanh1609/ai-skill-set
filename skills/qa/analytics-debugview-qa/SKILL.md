---
name: analytics-debugview-qa
description: QA of Firebase Analytics (GA4) events on a real phone or emulator, confirmed in DebugView. First finds the expected events and params in the ticket (Shortcut, Jira, Linear, GitHub), specs, and PR, then compares them with what the device logged: missing, extra, and wrong params, wrong counts, events that must not fire, and Firebase errors. Works for any app using Firebase Analytics (Android, iOS, Flutter, React Native) and any way of driving it (Marionette, Maestro, Patrol, Appium, Espresso, XCUITest, adb, or a person). Use whenever someone asks to QA, verify, or test analytics tracking, a PR or story that adds or changes analytics events, GA4/Firebase events such as `view_promotion`, `select_item`, `add_to_cart`, `purchase`, or `screen_view`, or says "check it in DebugView" or "verify the events fire", even without naming DebugView.
---

Prove that each analytics event in a change matches what the team asked for. A case passes only when three things agree:

- **Expected**: the events and params written down before the run, taken from the ticket, the specs, and the PR. Never from the code under test.
- **The device's Firebase log**: exactly what the SDK logged and uploaded. A script compares it with the expected events, param by param.
- **DebugView**: the live Google Analytics page that shows what the server received from a debug device. It's the proof people ask for, so every verdict ends there.

This skill owns the analytics side. It doesn't care how the app is driven. If the project has its own skill or agent for driving the app (starting a build, signing in, tapping through flows), use it for the "act" part of each case, and follow its rules for devices and accounts.

Android is the tested path. The iOS notes in step 3 come from the Firebase docs and haven't been tried with this skill. Say so before relying on them.

The skill folder has two helper scripts:

- `compare_events.py` compares the logged events of one case with what was expected.
- `fa_events.sh` prints a quick list of logged events.

Both read an Android logcat capture.

## 1. Gather the project facts

Find these before touching the device:

- **App id of the build you'll test.** On Android this is `applicationId` plus any `applicationIdSuffix` for the flavor, in `app/build.gradle(.kts)`. On iOS it's the bundle id of the scheme. Prefer a dev or staging build, so test traffic stays out of production data.
- **Firebase project.** Read `project_info.project_id` in the `google-services.json` for that build (often `app/src/<flavor>/google-services.json`). On iOS, read `PROJECT_ID` in its `GoogleService-Info.plist`.
- **GA4 property id.** Open the project's DebugView in the Firebase console (step 4) and follow **View more in Google Analytics**. The property id is the `p<digits>` part of the URL. You can also find it under Project settings → Integrations → Google Analytics.
- **Where events are logged.** Search for `logEvent`, `FirebaseAnalytics`, `Analytics.logEvent`, or the project's own analytics wrapper. You need this to know which actions to test, not what to expect.
- **A device.** Use `adb devices -l` on Android, or the project's device tooling. The device must be awake, unlocked, and not in use by anyone else.

Done when you have the app id, Firebase project id, property id, the event code, and a device id.

## 2. Find the expected results, then plan the cases

The code is what you're testing, so it can't tell you what's right. Find the expected events in what the team wrote down, in this order:

1. **The ticket.** Look in the team's tracker: Shortcut, Jira, Linear, or a GitHub issue. Use the tracker's tools or CLI when they're connected. The ticket id is often in the branch name or the PR title (for example `sc-12345` is a Shortcut story). Read the description, acceptance criteria, comments, and linked docs.
2. **Specs or tracking plans in the repo.** Look for an event-tracking spec, a tracking plan, or a feature spec, under folders like `docs/`, `specs/`, or `analytics/`. The ticket or PR often cites the exact rule (for example "BR-49").
3. **The PR description.** It may cite a spec change that hasn't merged yet, and it may have its own verification table. Reuse its case numbers so the reports line up.
4. **Anything the user links**, such as a tracking sheet or a design note.

When the sources disagree, or none of them covers a param or event the code sends, don't guess. List it as an open question and ask the user before the run.

Then write one case per behavior, in four kinds:

- **Fires**: the action logs the event the expected number of times, with the expected params.
- **Must not fire**: a nearby action logs nothing. For example, dismissing a promo dialog logs no `select_promotion`.
- **Caps and repeats**: a once-per-session or once-per-launch rule holds within a launch, and resets when the rule says it should (a new launch, sign-out).
- **Regression**: an event that shares code the change refactored still logs.

Some cases need a side effect outside the app: a real order or payment, signing out and in with a one-time code, or changing admin data. Don't do those by default. List them and ask the user. If unit tests cover them, say so.

Write the expectations to `<scratch>/expected.json`, one entry per case. The full format is in the header of `compare_events.py`:

```json
{
  "ignore": [],
  "cases": [
    {
      "id": "2",
      "title": "Tap the promo creative",
      "events": [
        {
          "name": "select_promotion",
          "match": {"creative_slot": "popup"},
          "count": 1,
          "params": {"creative_slot": "popup", "promotion_id": "*", "promotion_name": "*"},
          "optional": {},
          "items": [{"item_id": "*", "item_name": "*"}],
          "source": "SC-12345 AC 2; docs/specs/event-tracking.md BR-49"
        }
      ],
      "absent": ["add_to_cart"]
    }
  ]
}
```

- **`params` lists every param the app should send**, not just the important ones. Any other param the app sends shows up as **extra**. Params Firebase adds by itself are never counted as extra.
- **Value rules:** `"*"` means present and not empty, `"re:<regex>"` must match the whole value, and anything else must match exactly. Use `"*"` or a regex for values from the server, such as ids. Replace them with exact values once step 5 shows the real data.
- **Items:** list every item's fields, in order. Leave `items` out when the event must carry no items.
- **`match`** picks which logged events of that name belong to the entry. Use it when one event name serves several places, such as `creative_slot`.
- **`absent`** lists events that must not fire in this case.
- **`source`** says where each expectation came from, so the report can cite it.
- **`ignore`** is only for params you agreed with the user not to check.

Show the user the case table: # | Case | Expected | Source. Add any open questions. Wait for answers only when there are questions.

Done when every case has an entry in `expected.json`, and every open question is answered.

## 3. Turn on debug mode and capture the log

**Android.** Turn on Firebase debug mode for the app, and verbose Firebase logging:

```bash
adb -s <device> shell setprop debug.firebase.analytics.app <app-id>
adb -s <device> shell setprop log.tag.FA VERBOSE
adb -s <device> shell setprop log.tag.FA-SVC VERBOSE
```

Set it before the app starts. If the app is already running, force-stop it (`adb shell am force-stop <app-id>`) and launch it again, because the app reports debug mode when its process starts. A framework's hot reload or hot restart does not restart the process.

Start the log capture in the background, writing to a scratch file:

```bash
adb -s <device> logcat -c && adb -s <device> logcat -v time -s FA-SVC:V FA:V > <scratch>/fa.log
```

Then launch the app the project's usual way.

Done when `fa.log` shows all three signs:

- `Faster debug mode event logging enabled` under the `FA` tag, printed when the app starts in debug mode;
- a `_dbg` param with `int_value: 1` on each event in an uploaded batch;
- `Network upload successful with code, uploadAttempted: 204, true`.

Together they prove the device sends debug events and the server accepts them.

**iOS (untested here).** The Firebase docs turn on debug mode with the `-FIRDebugEnabled` launch argument (or `-FIRAnalyticsDebugEnabled`). An Xcode scheme's arguments apply only when Xcode launches the app. Check whether the scheme already lists the argument but has it switched off (`isEnabled = "NO"` in the `.xcscheme`). The docs also say the setting persists until `-FIRDebugDisabled` turns it off. Events then show in the Xcode console as `Logging event:` lines. The helper scripts read Android logs only, so on iOS compare the console lines with `expected.json` by hand.

## 4. Open DebugView

Use a browser that's signed in to a Google account with access to the property. An automated browser may not be signed in, and you can't type the user's password, so ask which browser to use.

Two URLs reach DebugView:

```
https://analytics.google.com/analytics/web/#/p<property-id>/realtime/debugview
https://console.firebase.google.com/project/<firebase-project-id>/analytics/app/android:<app-id>/debugview
```

The Firebase console page only embeds the Google Analytics one.

Things that look broken but aren't:

- **Error page, or a sad-face icon in the Firebase console.** An ad blocker or privacy shield (Brave Shields, uBlock, and similar) blocks `analytics.google.com`. Ask the user to allow that site and reload.
- **No events from your device, or "Debug Device 0".** DebugView first shows another tester's device, or none. Open the **Debug Device** menu and pick yours; it's listed by model, such as "Samsung SM-A528B". The list can be empty right after a page load, so wait a few seconds and open it again. Then check that "User properties active now" shows your test user, not someone else's.
- **New events don't appear.** Clicking an event pauses the stream ("Click to unpause"), and newer events stay hidden. Reload the page and pick the device again.

How the details panel works: click an event to open it. The **Parameters** tab lists every param name. It's an accordion, so expanding one param to see its value collapses the others: expand them one at a time. Items are on the **Items** tab.

Firebase adds its own params, which show in DebugView as `debug_event`, `firebase_event_origin`, `firebase_screen`, `firebase_screen_class`, `firebase_screen_id`, `ga_session_id`, `ga_session_number`, and sometimes `engagement_time_msec` or `firebase_previous_*`. They aren't extra params from the app.

Done when DebugView shows your device's recent events.

## 5. Check the test data

An event only fires if the screen or element that logs it shows, and that often depends on server data. Before you blame the code, check the API response behind it, in the app's network log or the tool that drives it. An empty list means the element never shows. A rebuild or reinstall doesn't change what the server returns.

When the data is missing, ask the user to choose:

- **Real data**: they create or enable it on the backend or admin. DebugView then shows real ids.
- **Local mock**: a small temporary change in the data layer that returns real-looking data, with the analytics code untouched. Reusing a live record of another type keeps real ids and working navigation. If the mock reuses an id that another element also logs, check that a dedupe or cap keyed by id won't swallow the event you're testing. Keep the change out of commits, save it as a patch in a scratch or ignored folder, and remove it during clean up.

Once the data shows, replace the `"*"` placeholders in `expected.json` with the exact values from the API response wherever the expectation is "equals the record's id or name".

Done when the element that logs the event shows on the device, and `expected.json` holds exact values where they are known.

## 6. Run each case and compare

For each case:

1. Note the time (`date +%T`).
2. Get to the starting state. For caps and anything that happens "on launch", you need a fresh launch:
   - A full relaunch (`adb shell am force-stop <app-id>`, then launch) always works.
   - A framework hot restart (Flutter, React Native) also resets in-app state such as in-memory caps and singletons, and keeps the debug session attached. It does not restart the native process.
   - Allow time for splash screens and dialogs that open after launch.
3. Act, with whatever drives the app. Take a screenshot when the screen proves part of the case, such as the page a tap opens.
4. Wait about 5 seconds, then compare what the device logged in that window with the case's expectations:

   ```bash
   ~/.claude/skills/analytics-debugview-qa/compare_events.py <scratch>/expected.json <scratch>/fa.log --case <id> --since <HH:MM:SS> [--until <HH:MM:SS>]
   ```

   It reads the `FA-SVC` lines, or the `FA` lines when there are none. For each expected event it prints how many were logged and PASS or FAIL. For each failure it names the problem:

   - **missing**: an expected param or `items` isn't there;
   - **extra**: the app sent a param, or `items`, that the expectations don't list;
   - **wrong**: a value, or the number of items, doesn't match;
   - **firebase**: Firebase attached `firebase_error` because the app sent something invalid.

   It also flags any event under **must not fire** that was logged anyway. It notes events of the same name that matched no entry, and log lines it couldn't parse. For each event it prints the params DebugView should show. The script exits 1 on any failure.

   For a quick look at everything logged, run `~/.claude/skills/analytics-debugview-qa/fa_events.sh <scratch>/fa.log <HH:MM:SS> [name-regex]`.

The script compares text, so it can't see types. When the expectations say a param is a number (`value`, `price`, `quantity`), check the uploaded batch in `fa.log`. The param must show a number field such as `int_value` or `double_value`, not `string_value`.

Treat every FAIL as a finding, not something to explain away. If you think the expectation itself is wrong, say so and ask. Don't edit `expected.json` to make a case pass.

Done when every case has a compare result.

## 7. Confirm in DebugView

Reload DebugView, pick the device, and match every event from step 6 by name and time. DebugView shows times in the property's time zone. When that matches the device's, the times agree to within a second. Otherwise they are off by whole hours.

For each event the change adds or modifies, open it and check:

- **The param names** on the Parameters tab, apart from the Firebase params listed in step 4, match the "DebugView should show params" line from the compare script. A param in the device log but missing from DebugView means the server dropped it, and that's a FAIL.
- **Each param's value** matches `expected.json`. Expand the params one at a time.
- **The Items tab** has the expected number of items and fields.
- **`debug_event`** is `1`.

Then check the counts in **Top events** against the cases. A must-not-fire case passes only when the count for that event didn't go up.

Done when each case has its DebugView evidence: event, time, and the param values you read.

## 8. Clean up

Clean up before you write the report, so the report is the last thing the user sees.

1. Remove the mock and check that `git status` shows only what was there before.
2. Stop the log capture and any app run or driver session you started.
3. Turn debug mode off so the device stops sending debug events to everyone's DebugView:

   ```bash
   adb -s <device> shell setprop debug.firebase.analytics.app .none.
   ```

   Undo anything else you changed on the device, such as `svc power stayon`.
4. Close the browser tabs you opened, unless the user wants them kept.

Done when nothing you started is still running and debug mode is off.

## 9. Report

End the run with the report as one fenced code block tagged `markdown`, after a one-line summary. The user copies the raw Markdown from that block and pastes it into a PR, a ticket, or a doc, so put nothing else inside it.

Fill in this template. Replace every `<…>` placeholder, and keep the headings and table columns:

````markdown
## Analytics QA: <PR or story title>

**Result: <✅ PASS | ❌ FAIL | ⛔ BLOCKED>**: <n> passed, <n> failed, <n> not covered. <One sentence on why, when not PASS.>

| | |
|---|---|
| **Ticket** | [<ticket id>](<link>) |
| **PR** | [#<number>](<link>) |
| **Build** | `<branch>` @ `<short commit>`, <variant> |
| **Device** | <model>, <OS and version> |
| **DebugView** | GA4 property `<name or id>`, device "<name in the Debug Device menu>" |
| **Expected from** | <ticket acceptance criteria>, `<spec path>` (<rule ids>), PR description |
| **Test data** | <Real, or "Mocked: " plus what was faked and why> |
| **Tested on** | <YYYY-MM-DD>, times in <time zone> |

### Results

| # | Case | Expected | Device log | DebugView | Result |
|---|---|---|---|---|---|
| 1 | <action> | `<event>` ×<count>: `<param>`=`<value>`, … | ✅ <hh:mm:ss> | ✅ <time>, params match | ✅ |
| 2 | <action> | no `<event>` | ✅ none logged | ✅ count unchanged | ✅ |
| 3 | <action> | `<event>` ×1: … | ❌ missing `<param>` | ❌ `<param>` not listed | ❌ |

### Findings

1. ❌ **Case <#>**: `<event>` <is missing `<param>` / sends extra `<param>`=`<value>` / sends `<param>`=`<actual>`, expected `<expected>`>. Expected by <source>. Seen in the device log at <time> and in DebugView at <time>.

### Param check

#### `<event>` (case <#>)

| Param | Expected | Actual | Check |
|---|---|---|---|
| `<param>` | `<value or rule>` | `<value>` | ✅ |
| `<param>` | any value | none | ❌ missing |
| `<param>` | not expected | `<value>` | ❌ extra |
| `items[1].<field>` | `<value or rule>` | `<value>` | ✅ |

### Open questions

- <An expectation the sources didn't settle.>

### Not covered

- **Case <#>** (<what>): <why it wasn't run>. <Covered by unit tests, or not covered anywhere.>

### Notes

- <A blocker you worked around, or server data someone has to restore.>
````

Rules for filling it in:

- **Evidence for every ✅.** A case is ✅ only when the compare script passed it and you saw it in DebugView. Give the time from each source.
- **The overall result.** It's PASS only when every case that ran passed. It's FAIL when there is any finding. It's BLOCKED when a missing precondition stopped the run; say which one.
- **Findings** has one numbered line per problem, naming the event, the param, and the source that expects otherwise. Write "None." when there are no findings.
- **Param check** has one table per event the change adds or modifies. Build it from the first logged occurrence. List every expected param, then every extra one, then the item fields. When an event logged several times with the same params, say so in its Results row instead of adding tables.
- **Leave out empty sections**: drop Open questions, Not covered, and Notes when they have nothing in them. Drop the Ticket or PR row when there isn't one.
- **Keep the Markdown portable.** Use only inline code inside the report, never a triple-backtick block, so the fence around it stays intact. Write `\|` for a `|` inside a table cell. Don't use HTML such as `<details>`, because some trackers show it as raw text.
- **Redact personal data.** Replace user ids, emails, phone numbers, and tokens with `<redacted>`. Promotion, product, and order ids can stay.
- **Shorten long text values** (titles, names) to about 40 characters, ending with "…". Keep ids in full, because a shortened id can hide a mismatch.

Post the report to a PR or tracker only when the user asks.
