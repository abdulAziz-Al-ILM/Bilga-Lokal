# Bilga recovery — 2026-10-22

Private Bilga-Lokal / wip/todo-widget-recovery. Starting local and remote commit:
407feea3e4fe1424c283fa66f4c69465e02e48b4; clean tree, zero divergence, fsck passed.
No main merge, release, database reset or Core voice-command change.

## Stability gate

One selected existing Flutter test passed (2s): cached-engine Todo channel rebind
retries SQL sync and consumes queued creation. This does not certify RAM stability.
Stop after any new runtime SIGSEGV; preserve diagnostics and WIP first.

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

## Stage 3 — pending

Upgrade Habits using its existing encrypted data, schedule, history and backup
structures. Verify schedule/streak/calendar/progress/archive/edit/check-in, add
reminders/widget where useful, retain 43 locales and all palettes, then checkpoint.
