# Test report — 2026-11-09

Environment: Ubuntu 26.04.1 / Linux x64, Flutter 3.47.8 at official revision `737ba8f885dc774b53b442759999a312c9461e4e`, Dart 3.13.7. SDK and pub caches installed in /tmp; they are not committed. SQLite runtime is the host's libsqlite3.so.0 via sqflite_common_ffi. No Android SDK, Java installation or connected Android device was found. The Linux desktop entry in doctor is not an Android test device.

| Command | Observed result | Scope |
| --- | --- | --- |
| `flutter pub get` | PASS, exit 0 | First cold SDK/package download completed; dependency resolution succeeded |
| `dart pub get --offline` with FLUTTER_ROOT | PASS, exit 0 | Final lock updated after removing unused file_picker and excluded flutter_tts |
| `dart format --output=none --set-exit-if-changed lib test` | PASS, 125 files / zero changes | Source formatting |
| `flutter analyze --no-pub` | PASS, no issues, 2.7s | Current code after fixes |
| Focused search/planner tests | 6 PASS | Cross-module search, trash/archive, transaction rollback, paging, backup reconstruction, Notes 13/Tasks 8 upgrade, planner civil dates, 6000-record benchmark |
| Read-only data browser widget test | 1 PASS, 2s | Reads complete note and history with no edit controls; DB unchanged |
| Purchase/access focused tests | 15 PASS | Offline trial, preserved legacy grants, pending/forged purchases, acknowledgement retry, signed Core grant/revocation and mounted editor protection |
| Home/tags/widgets/reminder regression group | 53 PASS, 21s | Corrected large-text layout and historical fixture tests |
| `flutter test --no-pub --concurrency=2 --reporter expanded` | **158 PASS, exit 0, 63s** | Complete current Flutter suite |
| `python3 tool/check_catalogs.py` | PASS, 43 × 324 strings | Structural coverage, not native-language review |
| `python3 tool/check_schema.py` | PASS, Notes v1–v10 / Tasks v1–v5 | Static extraction covers legacy direct SQL only; helper-based upgrades are verified by Flutter runtime tests |
| Dart habit-plan / task-rules / command-grammar checks | PASS: 19 habit-plan checks; task boundary/timezone checks; 14 grammar/calendar checks | Grammar code is preserved but speech and phone actions are not exposed |
| `git diff --check`, shell syntax and new literal translation-key audit | PASS | Diff hygiene, build-helper syntax and new UI catalog lookup |

Search benchmark on this host: 3000 Notes + 3000 Tasks inserted transactionally with FTS triggers in **677 ms**; two paged prefix queries in **16 ms**. This is a synthetic host-FFI measurement, not an Android performance claim.

Failures encountered and corrected:

- Initial sandbox runs could not create the analyzer cache or loopback test socket. Verification was rerun with the needed environment permissions.
- First focused run found an FTS metadata type mismatch hiding active results. Added explicit integer conversion; regression tests passed.
- Reader widget test initially ran SQLite work in fake asynchronous time. Fixed the test's I/O zone; its real persistence assertions pass.
- First complete suite: **153 PASS / 5 FAIL**. One real large-font home-title overflow was fixed with a flexible ellipsized title. Four older schema fixtures were incomplete for the new derived search migration; corrected them to represent actual prior schemas, including removing newer derived objects from deliberately downgraded test fixtures. All 53 affected checks then passed. No production database is downgraded, dropped or deleted.

Android artifact attempts:

- `flutter doctor -v`: Android SDK unavailable; no Android device. Flutter's detached pinned tag is reported as an unknown channel; this is expected for this temporary checkout.
- `flutter build apk --debug --no-pub` and `flutter build appbundle --release --no-pub` were started, then interrupted during Android engine setup after doctor confirmed missing toolchain. They generated **no APK/AAB** and are not passing builds (the interrupted AAB setup returned 0, which is not evidence of an artifact).
- Hosted CI has a configured build environment; its current branch run/result is recorded separately in RELEASE_READINESS.md after pushing.
- No release-signing, real Play purchase/refund, actual reminder delivery, SQLCipher-on-device or Drive-account test has run here.
