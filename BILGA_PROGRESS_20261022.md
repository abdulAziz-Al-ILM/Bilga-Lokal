# Bilga recovery — 2026-10-22

Private Bilga-Lokal / wip/todo-widget-recovery. Starting local and remote commit:
407feea3e4fe1424c283fa66f4c69465e02e48b4; clean tree, zero divergence, fsck passed.
No main merge, release, database reset or Core voice-command change.

## Stability gate

One selected existing Flutter test passed (2s): cached-engine Todo channel rebind
retries SQL sync and consumes queued creation. This does not certify RAM stability.
Stop after any new runtime SIGSEGV; preserve diagnostics and WIP first.

**Stopped at 20:38:05 Asia/Tashkent:** native build's single-use OpenJDK21.0.12.1
daemon crashed after22s with SIGSEGV / SEGV_MAPERR in
`G1ParScanThreadState::trim_queue_to_threshold`, GC Thread#1 (PID17726/thread17755).
This is a host JVM crash, not an Android test assertion. A specific hardware or
software cause is not established. No retry, JDK/SDK/Gradle/GC change or cleanup.
Raw local ignored log: `hs_err_pid17726.log`; build log:
`.buildlog/recovery-20261022/custom-native-build.log`.

Before that: the selected stability test PASS, all18 relevant Todo Flutter tests
PASS (14s), analyze no issues (10.8s). Native test APK assembly FAILED, so native
tests, new debug APK and tablet flow were NOT verified. No APK install or device
data/UI change occurred; only `adb devices -l` confirmed Tab16NEU0045423 connected.
Native source checkpoints2ca5c87/0e8f407 were already pushed and their remote SHAs
verified. The tree was clean at the crash. Heavy work and later stages stopped.

## Stage 1 — WIP, not yet device verified

Reuse the prepared native-channel-ready synchronization fix. Widget custom time
was absent from the native preset menu and custom timestamps from widget IDs were
explicitly rejected. Add a user-launched, nonexported native picker with immutable
capability, lock/access checks on open and submit, committed spinner input, future
validation, and the existing SQLCipher reminder-only transaction/single alarm path.
No Flutter MainActivity, overlay permission or foreground service is needed for
the widget picker. Add opt-in persistent task summary after verifying custom time.
Then check Notes/Todo/Core theme regressions, analyze, tests, APK and Tab16 flows.

## Stage 2 — pending

Inventory main cards from code, distinguish implemented/partial/missing features,
and assess database, search, UI/theme, offline, backup/restore, privacy, widgets and
usability. Produce an evidence-based prioritized backlog, not an untested PASS list.
Preliminary inventory gathered before the crash is in `BILGA_CARD_AUDIT_20261022.md`.
It is a code audit, not runtime certification or a completed cross-card audit.

## Stage 3 — pending

Upgrade Habits using its existing encrypted data, schedule, history and backup
structures. Verify schedule/streak/calendar/progress/archive/edit/check-in, add
reminders/widget where useful, retain 43 locales and all palettes, then checkpoint.
