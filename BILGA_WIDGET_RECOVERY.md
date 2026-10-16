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

## Evidence so far (final checks still pending)

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

## Remaining verification / limits

Finish real overlay + Done, Notes preview/tags/reopen/revoke, theme and Recents flows;
final APK/native checks and final source checkpoint. Do not mark these as passed early.
Launcher-retained snapshots cannot be erased reliably. App-owned cache invalidation
and secure defaults remain mandatory. Android notification/overlay/battery policies
and user lock settings are respected; other OEM/API versions have not been runtime
certified by the API31 tablet tests. Existing AGP Kotlin migration warnings remain;
SDK/JDK/Gradle versions were not changed for this task.
