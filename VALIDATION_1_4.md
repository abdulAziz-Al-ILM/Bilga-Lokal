# Bilga 1.4.0 validation — 2026-10-05

## Executed in the build workspace

- Standalone Dart 3.13.4 analyzer against Flutter 3.44.0 framework/package sources: app, tests, integration tests and tools. Result: `No issues found!`. Exact command output is in `CHECK_RESULTS.txt` at the package root.
- `tool/check_schema.py`: real SQLite execution of extracted Dart migration SQL, preserving existing Unicode text, deleted flags and other sampled fields. Notes schemas 1–10; todo schemas 1–5; integrity check after migration. This does not execute Android SQLCipher.
- `tool/check_agent_rules.dart`: offline grammar, argument retention, boundary matching, unsafe phone input rejection, day/streak calculations.
- `tool/check_private_rules.dart`: 30 finance and authenticated streaming encryption checks including tamper/truncation handling.
- `tool/check_habit_plan.dart`: 19 schedule, partial progress, legacy completion, pause, history, leap-date and month-specific budget checks.
- `tool/check_catalogs.py`: same non-empty keys in all 43 JSON catalogs. Structural presence is not linguistic review.
- Shell syntax check for test APK and release bundle scripts.
- Update installer on an isolated copy: preflight, installation, idempotent rerun, modified-file rejection, checksum validation and preservation of a sentinel config file. See generated installer-check log in this package.

## Added/updated tests requiring Flutter/Android

- `test/editor_persistence_test.dart`: failed write leaves editor text intact; successful retry closes it.
- `test/habits_test.dart`: quantified habit and partial-day note survive backup/restore.
- `test/support/data_safety_cases.dart`: real Flutter/sqflite migration fixtures through notes schema 10 to 11.
- `test/template_test.dart`: load every locale explicitly; schema 11 assertion.
- `integration_test/private_device_test.dart`: create secure habit, persist quantified plan, close/reopen, inspect non-plaintext header; migrate legacy notes while retaining Unicode content.

The Flutter widget suite and Android integration suite have NOT been executed in this environment. The previous version's 42 passing user-device tests do not establish that this version passes. No release APK/AAB or performance benchmark is claimed. Run `bash tool/check_start.sh` and the device checklist before publishing.

## Privacy and reliability design decisions

- No cloud AI, analytics SDK, background microphone, bank access or automatic message sending introduced.
- Default build removes the llama Flutter dependency; opt-in implementation retained under optional/turbo. Existing models are not deleted from users' devices by this update.
- Private database migration remains additive. New habit plan data is in encrypted notes schema 11 and included in backup validation/restore. No downgrade or database deletion.
- Financial values use bounded integer minor units; invalid dates, overpayment and invalid monthly budgets are rejected.
- Persistence happens before navigation; on failure the current form retains its content. This is not crash-proof draft autosave for every editor.
- Release billing requires real Play products/licensing config and Play installation. Local signature verification is not equivalent to server-side subscription/refund infrastructure.

## References informing implementation

- Google Sign-In Android configuration and signing SHA: https://pub.dev/packages/google_sign_in_android
- Android memory guidance: https://developer.android.com/topic/performance/memory-overview
- Gradle JVM/worker configuration: https://docs.gradle.org/current/userguide/build_environment.html
- Lally et al., habit formation (2010): https://doi.org/10.1002/ejsp.674 — cues and repeated behaviour inform the habit plan. No fixed “21-day” promise, clinical efficacy claim or punishment for one missed day.
