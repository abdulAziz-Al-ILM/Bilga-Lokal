# Notes / To-Do widget recovery — 2026-10-16

Branch: `wip/todo-widget-recovery`; private `abdulAziz-Al-ILM/Bilga-Lokal`.
Recovery base: `67d6990646c36a70b8f21b11a21ca5c843e51fa8`.
GitHub checkpoint policy is in `AGENTS.md`. No merge/release/public repository.

## Changes

- Todo database v8 adds device-local per-task title consent; portable backup v7
  remains compatible. Existing tasks gain no implicit consent or reminders.
- New task + chosen deadline/time enables reminder once. Explicit OFF and old
  task settings remain respected; snooze changes only the reminder instant.
- Widget uses per-task approved titles, date/status/countdown, inline native
  5/10/30/60-minute/tomorrow choices and direct completion on an unlocked device
  with AppLock off and a current access lease. Locked/AppLock/expired lease actions
  fail closed. Native writes use the existing SQLCipher engine/key, transaction,
  task version and immutable rotating capability; no plaintext DB or key export.
- SQLCipher initialization now reads result-bearing PRAGMAs properly. Missing
  compile dependencies use the exact versions already used by sqflite_sqlcipher.
- A durable blocked-task marker/SQL epoch protects interrupted native writes;
  blocked reminders do not create a repeating one-second alarm. Fresh SQL sync
  recovers the mirror. Progress visibility resets after closing inline snooze.
- Notes consent remains in DB13. Locked/unreadable encrypted widget configs are
  retained and never silently replaced with defaults. Old snapshots remain hidden
  by permission epoch. Preview adapts to 2/3 lines with space for tags.
- Core/Notes/To-Do widget and overlay colors follow all seven app palettes and
  light/dark/system brightness. A native-to-Dart theme refresh handles cached
  audio-service engines. Core microphone behavior is unchanged.
- MainActivity has one singleTask/default-affinity app task. Both handoff activities
  are excluded from Recents and open Main with NEW_TASK/CLEAR_TOP/SINGLE_TOP.

## Evidence so far (device checks still pending)

- Flutter analyze: no issues (27s); full Flutter suite: **223 PASS, 4m35s**.
  A later cached-engine theme refresh change requires its focused regression check.
- Initial debug APK build: PASS (142.4s); ZIP CRC/v2 signature PASS. APK SHA256
  `7ce6422e38ae5e158f0a921ea9d7d0cc802ce2bf816aec096404df586cf3c27e`.
- install-r: PASS; on-device Notes `bilga.db` and Todo `bilga_todo.db` SHA256 were
  identical before/after update, before first startup. No uninstall/data clear.
- Blackview Tab16, Android12/API31 arm64: initial Todo **36 PASS**, Notes **12 PASS**.
  New geometry/blocked-alarm tests require final native test run (13/37 expected).
- Real launcher: widget + opens a fresh editor; deadline/time -> reminder ON;
  synthetic task saved. Widget gear -> per-task consent dialog -> save -> real
  fixture title visible while unapproved tasks remain generic. Card consent ON
  also observed after reopening the app route. Inline snooze remains in launcher.
- Read-only native inspection of the unique UI-created synthetic fixture confirms:
  original deadline `2026-10-16T23:59`, reminder moved to `18:04:53.580+05:00`,
  SQL stores the same instant as `13:04:53.580Z`, fired=1, done=0. No IDs, tokens,
  keys or unrelated user data were exported. The first reminder elapsed before
  Calculator was foregrounded; this is NOT an external-overlay pass.
- Recents after Todo widget/gear/list flows: one Bilga main task. Notes/notification
  entry and cold-reopen checks remain pending.
- Self-targeted Java WidgetUiProbe observes only static/synthetic labels and control
  geometry, without idle waits or restarting Bilga. Standard uiautomator dump waits
  for idle and is unsuitable for a live per-second Chronometer. Test-only fixture
  actions require a visible synthetic task; production APK contains no UI probe.

### Later checks, 2026-10-16

- Cached-engine theme regression: PASS (all seven palettes, light/dark and system
  brightness); analyze then passed with no issues.
- Native production changes: Todo **37 PASS**, Notes **13 PASS** on Tab16. The
  306bdae APK passed ZIP/signature checks and install-r preserved both DB hashes
  before first startup.
- Actual due overlay appeared over foreground Calculator at **18:17:27** with
  APPLICATION_OVERLAY frame `[180,1438][1020,1937]`, visible/on-screen. User missed
  the visual check; the first automated overlay action did not pass. Display is
  confirmed, button execution/readability are not yet confirmed.
- A UI-created Notes fixture exposed a tag-selection/save race. Confirmed picker
  selections now update the editor before another asynchronous store read.
- After that change: analyze **no issues, 23.8s**; Notes tags/widget regressions
  **42 PASS, 1m19s**; debug APK build **PASS, 52.0s**.
- The subsequent test-APK assembly FAILED: host OpenJDK 21.0.12.1 SIGSEGV in
  `G1 Conc#0`, `libjvm.so` object-array marking, at **18:34:09**. This is not an
  Android test assertion failure. Cause is unproven; do not declare hardware fixed
  from earlier passing runs. Do not repeatedly rebuild or change Java/Gradle
  versions to conceal the failure. Crash log remains local and is not committed.
- Repeat due overlay appeared above Calculator at **18:41:29**. User confirmed
  readable/acceptable design and also pressed a button during automation. The
  resulting 18:51 reminder/app opening cannot establish which path automation
  exercised. Do not label this an overlay action pass.
- Actual Notes widget: synthetic tag filter + approved preview showed title,
  two body lines and RecoveryTest. Background-process close/reopen retained its
  ON consent. Revocation immediately removed the row; read-only native check
  reported app-owned snapshots empty. Other existing grants were preserved.
- Actual widget Done stayed in the launcher. Read-only SQL inspection confirmed
  synthetic task done=1, reminder=null, original deadline unchanged, mirror
  blocked=false. Notes/Todo handoff flows left one Bilga Recent Apps task.
- Follow-up WIP: notification Done/Snooze/content taps now use immutable native
  broadcasts; Snooze expands a private notification with five presets. Overlay
  custom time now uses bounded secure native date/time pickers instead of Flutter
  handoff. New native assertions cover notification broadcast type and custom
  reminder/deadline separation. **41 native tests PASS** cover this code; actual
  custom picker/notification interaction is still being verified on the tablet.
- Final native test-APK build passed with a fresh single-use daemon. Final Flutter
  debug APK passed in **15.3s**, CRC/v2 signature verified, SHA256
  `c7f58ba4fd2f7379db76ac49a9a421505e9d615e2d81b971fa8bf0019104aac8`.
  install-r preserved both SQLCipher database hashes before first app startup.
- Core widget public background sampled only in device memory: Ocean/dark
  `ff101418`, Amethyst/light `fffff7ff`, restored Amethyst/dark `ff151218`.
  Original preference enums were checked after restoration. No screenshot files
  or user-screen images were exported. Current overlay text/background contrast
  is 14.34:1 and primary button contrast 7.67:1.

## Remaining verification / limits

Finish the new native custom-picker/notification paths and final source checkpoint.
Do not mark those real flows as passed early.
Launcher-retained snapshots cannot be erased reliably. App-owned cache invalidation
and secure defaults remain mandatory. Android notification/overlay/battery policies
and user lock settings are respected; other OEM/API versions have not been runtime
certified by the API31 tablet tests. Existing AGP Kotlin migration warnings remain;
SDK/JDK/Gradle versions were not changed for this task.
