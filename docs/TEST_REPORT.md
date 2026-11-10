## Recurring tasks verified — 2026-11-10

**Stage A remains IN PROGRESS.** Daily, selected-weekday/interval weekly, monthly and yearly recurrence now work through the editor, encrypted storage, backups, list completion and native notification completion. Tasks schema 10 adds series/occurrences without changing existing task rows; portable Tasks content schema 8 imports older content versions 6/7. Completing an occurrence preserves its history and creates exactly one successor. Editing defaults requires an explicit future-occurrences switch; ordinary edits affect only that task. Month-end anchors, leap years, end dates, missed-date skipping and local wall-clock DST behavior are covered. Trashing the current head stops its series; restoring it requires explicitly enabling repeat.

Verification: **183 Flutter tests PASS** (66 seconds), analyzer no issues, 43 × 364 catalog keys, nine manifest/target guards, 17 Python verifier tests, Java calendar checks and real New York Dart DST checks PASS. The Blackview Tab16/API31 passed **22 scenario cases** (28 including hooks) in **147 seconds**. Its new recurring notification case completes the actual native PendingIntent, observes the atomic successor in SQL, then waits for the next real Android reminder without Dart publishing again. The successor has no inherited widget consent or exposed title. Separate native instrumentation passed **13 Notes widget checks and 46 task checks**, using synthetic caches/databases. The instrumentation runner verifies review-only merged targets and matching installed signatures before any installation; it never invokes the production package.

Machine evidence: `docs/evidence/recurrence-tablet-2026-11-10.json`. The prior ordinary review APK and native-keyboard check remain separately recorded at source `a0d7463`; the recurrence integration APK is a test runner, not an owner-review build. Production Bilga and its data remain untouched. Reboot/Doze, permission-denied behavior, manual notification-drawer gestures and release performance remain unverified. Subtasks/projects/custom templates are the next task work; broader reminders, journal history/calendar/categories, durable links, app PIN and Drive media remain required. No owner acceptance, main merge, publication or paid activation is claimed.

The following sections preserve earlier checkpoint evidence.

---

# November 10 continuation validation

The latest local source checkpoint passes **166 Flutter tests** (39 seconds), including rich Notes/backup/history and a reproduced trial-overlay navigation regression. `flutter analyze --no-pub` reports no issues. Catalog structure: **43 languages × 336 keys**. Python verifier: **17 tests PASS**, including acknowledgment races, outages, pending/canceled purchases, malformed receipts, request limits, private key generation and ledger failures. Python-issued grant fixtures also pass in Dart. Production/review manifest guards: **7 tests PASS**. First-party non-voice source guard PASS. No translation received native-speaker certification.

Toolchain: official Flutter 3.47.8 / Dart 3.13.7, Temurin Java 21.0.13, Android SDK 36/build-tools 36.0.0, NDK 28.2.13676358. Local SDK/cache paths are ignored under `.bilga-tools/`. The cold Android build completed in 1440.7 seconds; its post-build script was edited while running and failed during subsequent parsing, before any install. A clean rerun completed APK signature/package/permission verification. Later incremental builds take roughly 25–35 seconds. Third-party `video_player_android` still emits Kotlin migration warnings; there is no native compilation failure from them.

Real USB tablet: Blackview Tab16, Android 12/API31, 1200×2000, arm64. The third guarded integration run passed **19 scenario cases** (runner reports 25 including six setup/teardown hooks) in 39 seconds. This includes Notes v1–v10 row-preserving upgrades, Tasks v1 upgrade, rollback, trash-batch restoration, encrypted habit reopen, current plaintext-to-encrypted migration including FTS virtual tables, formatting autosave/reopen, task completion, habit completion, cross-module search, and encrypted backup round-trip/merge. The final expanded run passed **21 scenario cases** (27 including hooks) in **101 seconds**: all ten main routes, 14 palette/mode combinations, Arabic RTL, physical editor rotation, and actual quiet notification delivery, snooze/re-delivery and native PendingIntent task completion. See TABLET_TEST_REPORT.md and the sanitized JSON evidence for exact scope.

Device-discovered failures and fixes:

1. The tablet's system SQLite omits JSON1. Plain fixture opens now use the bundled Android SQLCipher engine without a password, preserving standard plaintext files and consistent SQL features. Production encrypted opens retain their existing key and cipher settings.
2. Injected encrypted backup fixtures incorrectly selected the plaintext ATTACH path. Restore now detects the connection's cipher support and the target file's plaintext header, supplying the explicit existing key (or an empty key for plaintext). An injected database no longer implies an unencrypted file. Atomic failure/repeated-import checks pass on the tablet.
3. The SQLCipher export's virtual-table schema was stale on the source connection. Migration now closes the export connection, reopens the staged encrypted file, verifies integrity and every table count, and only then renames the plaintext original. The original file remains untouched on failed validation. Real encrypted migration passes. [SQLCipher export source](https://github.com/sqlcipher/sqlcipher/blob/v4.10.0/src/sqlcipher.c) inserts virtual-table schema entries directly; the new-connection check avoids relying on that connection's cached schema.
4. Live first-open navigation found the trial overlay sharing the app Navigator's HeroController. A host regression reproduced both the shared-controller and missing-navigator assertions before the fix. The overlay now has `HeroControllerScope.none`; all 166 host tests pass. Existing tests had mounted the gate as a home route and missed its actual `MaterialApp.builder` placement.

The first tablet attempt failed 16 scenario cases, the second failed one, and the third passed all 19. Later expanded UI checks exposed test-timing issues after route and theme transitions; the journey now waits for settled animations and treats missed hit targets as failures. The final expanded run passes all 21 scenarios. No failed run is recorded as passing. Earlier driver defaults removed only the synthetic review package after two runs; the runner now uses `--keep-app-running`, checks any installed review certificate before launch, and preserves review data on subsequent upgrades. The production app was never installed over, uninstalled, cleared or used for fixtures.

Builds in `build/review/` are isolated development APKs, not completed Stage A or owner acceptance. No real Play purchase, verifier deployment, release-signing upgrade, reboot/Doze/timezone recovery, biometric authentication or Drive media acceptance is certified by these tests. Notification completion was dispatched through the actual notification-owned PendingIntent using an isolated-debug-only probe, not through a manual notification-drawer gesture. Historical results below apply only to their named revisions.

---

# Test report — 2026-11-09

Environment: Ubuntu 26.04.1 / Linux x64, Flutter 3.47.8 at official revision `737ba8f885dc774b53b442759999a312c9461e4e`, Dart 3.13.7. SDK and pub caches installed in /tmp; they are not committed. SQLite runtime is the host's libsqlite3.so.0 via sqflite_common_ffi. No Android SDK, Java installation or connected Android device was found. The Linux desktop entry in doctor is not an Android test device.

| Command | Observed result | Scope |
| --- | --- | --- |
| `flutter pub get` | PASS, exit 0 | First cold SDK/package download completed; dependency resolution succeeded |
| `dart pub get --offline` with FLUTTER_ROOT | PASS, exit 0 | Final lock updated after removing unused file_picker and excluded flutter_tts |
| `dart format --output=none --set-exit-if-changed lib test` | PASS, 125 files / zero changes | Source formatting |
| `flutter analyze --no-pub` | PASS, no issues, 5.2s | Current code after fixes |
| Focused search/planner tests | 6 PASS | Cross-module search, trash/archive, transaction rollback, paging, backup reconstruction, Notes 13/Tasks 8 upgrade, planner civil dates, 6000-record benchmark |
| Read-only data browser widget test | 1 PASS, 2s | Reads complete note and history with no edit controls; DB unchanged |
| Purchase/access focused tests | 15 PASS | Offline trial, preserved legacy grants, pending/forged purchases, acknowledgement retry, signed Core grant/revocation and mounted editor protection |
| Home/tags/widgets/reminder regression group | 53 PASS, 21s | Corrected large-text layout and historical fixture tests |
| `flutter test --no-pub --concurrency=2 --reporter expanded` | **158 PASS, exit 0, 64s** | Complete current Flutter suite |
| `python3 tool/check_catalogs.py` | PASS, 43 × 324 strings | Structural coverage, not native-language review |
| `python3 tool/check_schema.py` | PASS, Notes v1–v10 / Tasks v1–v5 | Static extraction covers legacy direct SQL only; helper-based upgrades are verified by Flutter runtime tests |
| `dart tool/check_private_rules.dart` | 30 PASS | Finance validation and authenticated chunk-encryption/security rules |
| Dart habit-plan / task-rules / command-grammar checks | PASS: 19 habit-plan checks; task boundary/timezone checks; 14 grammar/calendar checks | Grammar code is preserved but speech and phone actions are not exposed |
| `python3 tool/test_play_manifest.py` | 4 PASS | Release-manifest gate rejects obsolete Billing, wrong identity/target and microphone permission |
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
- Hosted CI has a configured build environment. Run 42668103911 succeeded for source f2bb128: debug APK, ZIP/v2 signature and merged-manifest checks passed; see RELEASE_READINESS.md for the real artifact and hash.
- No release-signing, real Play purchase/refund, actual reminder delivery, SQLCipher-on-device or Drive-account test has run here.

Policy-required dependency change: in_app_purchase 3.3.1 / in_app_purchase_android 0.5.5, declaring Play Billing 9.1.0. Analyzer and the complete 158-test suite were repeated after this change and passed. See PLAY_POLICY_REVIEW.md.

Hosted CI 42667262437 at source 600ebb7: analyzer, locked resolution, formatting, catalogs and Python manifest tests passed; full suite **157 PASS / 1 FAIL** (48s). Existing note-widget disclosure test tapped the switch while its callback was still disabled during an asynchronous reload. Corrected its wait to require the expected state **and** an enabled callback, keeping the database/privacy assertions. APK stages were skipped. A subsequent run is required; do not call this run successful.

Final hosted retry: **42668103911 SUCCESS**, source f2bb128ed4d4d6adef20fc28a7595de5d00fee2a. Pinned Flutter 3.47.8 / Dart 3.13.7, analyzer no issues (8.9s), full Flutter suite **158 PASS (49s)**, 4 Python gate tests PASS, debug APK build PASS (~7m43s), ZIP integrity/APK v2 signature PASS, actual manifest target 36/Billing 9.1.0/no microphone PASS, artifact uploaded successfully. Hosted synthetic FFI benchmark: 6000 inserts 397 ms, two paged queries 10 ms. These are host results, not Android runtime/device measurements.
