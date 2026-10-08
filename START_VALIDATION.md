# Bilga Start 1.2.0 validation

Status: source preview; not a tested release build.

Completed:
- Python SQLite migration checker: all 13 paths passed (notes v1–8, to-do v1–5),
  preserving the checker's existing sample records.
- Existing translation catalog: 43 languages × 164 keys passed. New Start UI
  has Uzbek/English/Russian strings with English fallback for other languages.
- 15 Android XML files parsed successfully; new shell scripts pass bash syntax.
- Earlier in this work session, the standalone Dart command/date checker
  passed 14 checks. The unchanged command/date rules cover three languages,
  unsafe phone strings, and calendar boundaries. The temporary Dart executable
  is no longer available after workspace continuation, so it was not rerun.
- Changed Dart source was formatted earlier; small follow-up fixes were manually
  reviewed after the formatter became unavailable.

Additional Flutter tests supplied, not executed here:
- Agent command parsing (test/agent_command_test.dart).
- Habit persistence, idempotent check-in, archive, backup/restore and legacy
  schema acceptance (test/habits_test.dart).
- Repeated carousel swipes at narrow width and large text
  (test/home_layout_test.dart).

Not verified:
- Dependency resolution/pubspec.lock regeneration.
- Full Dart analyzer, Flutter tests, Kotlin/Gradle build, APK/AAB.
- Actual UI appearance/overflow, Android widget, speech/TTS availability,
  media foreground service and device lifecycle.
- Live Play product, purchase, restore, cancellation, pending and refund flows.
- Existing Google Drive sign-in/backups in a Play-installed build.

Flutter initialization was blocked by automatic security review because it
attempted access to the environment's link-local metadata endpoint. The block
was not bypassed. Run `bash tool/check_start.sh` in your development environment
and follow START_1_2_UZ.md for device and Play internal tests.

The installer is separately checked against a disposable extraction of the
original ZIP for preflight, application, unchanged files, second-run idempotence,
and refusal of conflicting edits. This does not validate application runtime.
