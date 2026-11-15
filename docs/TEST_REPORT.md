## Offline Books reader acceptance — 2026-11-15

Books now imports and reads PDF/EPUB/TXT inside Bilga, with encrypted managed files or explicit persistent references, covers, continue/progress, bookmarks/highlights/notes, typography, native PDF controls, knowledge cards/Leitner review, active-reading statistics, shelves, deterministic help, templates, durable cross-module links and full local encrypted recovery. Optional bibliographic details remain advanced. Notes DB **17**, Tasks **13**, portable reading content **15**. Format bounds and limitations: [BOOKS_OFFLINE_READER.md](BOOKS_OFFLINE_READER.md).

Final runtime **ff59d5b** CI **43708926430 succeeds with287 tests**, analyzer, DST/backend, Android build/verification. Physical Tab16 passes the expanded20-scenario suite, final6-case current UI suite, actual SAF12-case suite and real-process-restart12-case suite (overlapping scopes, not a summed suite). The latter prove PDF154/bookmark and persisted external TXT survive Review process death. [Acceptance/artifact checkpoint](BOOKS_READER_ACTIVE_CHECKPOINT.md) links exact evidence and failed-attempt history.

Ordinary **`build/review/bilga-reader-review-app.apk`** is signer-checked, installed in place and launched; real home → Kitoblar opens the new library. SHA256 **`400d37d158e2615698afe6400e908ccb5f51ec35671dc258d8969092d3740bae`**. Test runners are absent. Production package metadata is identical before/after; production data was not read or modified. Generated tablet documents were hash-verified and removed. Owner ZIP is preserved.

**The wider six-module product remains IN PROGRESS.** No manual TalkBack/native-keyboard, release performance, second-device recovery or full translation acceptance is claimed. No main merge, publication, paid activation or voice work. Earlier checkpoints below describe older artifacts/schemas and are historical.

---

## Book library and deterministic Habit guidance — 2026-11-15

**The full six-module product remains IN PROGRESS.** The owner's new professional-completion directive and ZIP references were inspected. The ZIP contained four text files and seven externally linked images; all seven images were downloaded and visually reviewed. Research attribution and useful patterns are preserved in `references/README.md`; third-party images remain local/ignored and are not shipped in Bilga.

Book library now has optional versioned author/publication/ISBN/status/dates/pages/rating/favorite metadata, custom shelves/tags/categories, bounded thin pagination, FTS search/filter/sort, guarded editing, complete source reading/export and compatible idempotent backup. Legacy reads do not rewrite or invent metadata and metadata edits preserve chapters/history/bookmark. See `BOOK_LIBRARY_DATA_MODEL.md`.

Habits now has a searchable 22-template category gallery with preview/cancel and a prefilled real editor. Only explicit Save creates a habit; the catalogue contains no completions or personal records. A reusable local deterministic tutorial engine highlights actual keyed widgets, allows real target interactions, gates actions on success, supports Back/Next/Skip/Exit and stores only version/step/active state. The first six-step Habit journey opens the real form and explains the actual dashboard after successful persistence. Text entry stays highlighted until the user confirms Next. Failed/expired saves retain drafts and remain at the save step; Back never replays a confirmed save. Missing anchors fall back to unobstructed help. See `GUIDANCE_SYSTEM.md` and `INTERACTION_MATRIX.md`.

**268 full Flutter tests PASS in 127 seconds**, analyzer clean, format clean (201 files), **43 × 568** catalog keys, nine manifest guards and non-voice guard PASS. Supplemental Book UI verification passes all four cases after adding actual-field refocusing, exact synthetic field checks and bounded navigation waiting. Host coverage includes route-wide 360px/2× RTL/dark guidance, real spotlight hit tests/rotation/fallback, explicit resume/version errors, preview no-write, safe save retry, Book validation/legacy preservation/search/filter race/rollback/backup and read-only content. `docs/evidence/books-guidance-host-2026-11-15.json` records the scope.

The focused Book-editor suite now passes **3 physical scenarios / 5 including hooks in 160 seconds**, including invalid ISBN → correction → real save/reopen/filter/search and both other UI regressions. An earlier combined run passed **13 of 14 scenarios** (16 runner cases including hooks, 251 seconds): real startup/all ten routes/14 palettes/Arabic RTL, six encrypted Book database/backup fixtures, three Habit template/guide/retry/skip journeys and four actual synthetic screenshots. Its one failed Book case was a retained-focus-cache problem in the live test helper; explicitly tapping the real EditableText before injected input fixes it. Four supplemental host UI cases pass too. Product validation was not weakened. The runtime app source did not change between those scoped runs. **The combined target was not rerun as an all-pass suite after this fixture fix**; evidence preserves that distinction in `docs/evidence/books-guidance-tablet-2026-11-15.json` and dated failed attempts. Manual native-keyboard and native rotation acceptance are not asserted by this focused work.

Schema remains Notes **16**, Tasks **13**; portable Notes content remains 13 normally/14 with Finance accounts and Tasks content 11. No new dependency or backup framing is introduced. Finance report CI **43064321644 succeeded** at e520971, and its ordinary APK was installed/started before this continuation; newly saved evidence files describe that earlier artifact precisely. Current checkpoint's CI and ordinary APK are separate.

Remaining scope is substantial: other five modules' tours/shared searchable Help Hub; advanced Habits schedules/categories/reminders/statistics; Finance categories/budgets/goals/recurrence/debt deadlines/reminders; Experiences templates/timeline/calendar/history/tags/favorites/follow-up; Books covers/sessions/statistics/cards/review scheduling; durable cross-module links and full localization/accessibility/performance acceptance. English/Uzbek/Russian new copy is draft, other catalogs currently use English fallback. No main merge, publication, paid activation or voice work occurred. Original production installation/data/signing remain preserved.

Earlier checkpoint evidence follows.

---

## Projects verified — 2026-11-11

**The six-module product remains IN PROGRESS.** Projects now work over existing nested task-list folders: create/edit details, active/paused/closed status, a date-only deadline, nested-task progress/overdue counts, conversion from/to ordinary lists, stale-editor protection, transactional search, complete reader/export and portable backup. Status is organizational and never silently completes tasks or changes their reminders. Empty projects show 0/0 without claiming 100%. Trashed folders, hidden ancestors and unrelated projects are excluded from progress.

Tasks schema **13** adds project metadata without rewriting tasks, lists, subtasks, templates or series. Portable content **11** imports older versions 6–10 and remaps project-folder ownership with idempotent restoration. Source-reader dates now retain the year and relevant timestamp time; a regression test caught the previous omission. **208 full Flutter tests PASS** after the keyboard correction (62 seconds), analyzer/formatting clean; **43 × 396** catalog keys, nine manifest guards, non-voice and static legacy-schema checks PASS.

The reidentified Blackview Tab16/API31 passes **43 scenario cases**, **49 including hooks**, in **274 seconds**. Six new encrypted project cases verify migration, nested progress/hidden data, stale edits, rollback, search/trash and backup. The real UI creates a project, creates a nested list/task, completes the task, sees 1/1 progress, changes project status and converts it to a normal list while preserving all tasks. The earlier two IME/scroll failures are fixed: tests unfocus before scrolling and use a stable status key; template/project editors dismiss keyboards on drag/save. The corrected template journey passes too. Evidence: `docs/evidence/projects-tablet-2026-11-11.json`; the failed first attempt remains recorded separately.

Native instrumentation against the project-capable review app also passes **13 Notes widget and 46 task checks**, both raw RESULT_OK (`/tmp/bilga-projects-native-tests.log`).

The temporary approval-review usage-limit interruption is resolved; authorized host/ADB/GitHub work resumed. The exact template CI failure was fetched: **43034401498 failed before application tests because apt could not resolve azure.archive.ubuntu.com**, exit 100. Workflow setup now retries package downloads three times and fails explicitly if index refresh is incomplete; the next hosted CI result is pending. Evidence: `docs/evidence/template-ci-setup-failure-2026-11-11.json`. This is an environment correction, not a claimed application-test pass. Original production Bilga remains untouched; main was not merged and no publishing/paid activation occurred.

Next source work is the remaining six-module functionality. Finance accounts/transfers/reconciliation are being prepared in the unreferenced local `lib/features/finance/account_ledger.dart`; this unverified file is excluded from the project checkpoint. Preserve integer minor units, explicit currency and atomic record revisions; never initiate bank operations or invent rates. Task tags/calendar/sorting/bulk/history, broader reminders, complete Habits/Finance/Experiences/Books workflows, durable links, app PIN, Drive media and full interaction/accessibility/performance acceptance remain required. Voice stays deferred until explicit owner approval.

Earlier checkpoint evidence follows.

---

## Custom task templates verified — 2026-11-11

Resumed `development/global-launch` from `42cee8d`, whose hosted CI **42796563471 succeeded**. The new owner directive is preserved in `FINAL_ENGINEERING_DIRECTIVE_2026-11-11.md`: six core modules, no voice before explicit owner approval, original production data preserved, no main merge/publication/paid activation. **The full product remains IN PROGRESS.** Finance and Books are explicitly included in the feature matrix with their actual gaps.

Custom task templates now support creation, preview/cancel, application, editing, deletion and saving an existing task as a template. They retain title, description, priority and ordered subtask titles; each use creates independent unchecked task/checklist rows. Existing dates, recurrence, reminders, attachment ownership and widget consent are not transferred. Template edits/deletion do not change earlier tasks. Revision checks reject stale edits/deletes. Folder ancestry is validated and failed instantiation rolls back all rows. Nested collection/trash routes now preserve the injected repository used by isolated tests.

Tasks schema **12** adds the encrypted template table without rewriting existing task/checklist/series rows. Portable Tasks content **10** imports versions 6–9; template IDs are remapped and repeated imports stay idempotent. **199 full Flutter tests PASS** (55 seconds), analyzer no issues, 43 × **384** catalog keys, nine manifest/target guards and non-voice source guard PASS. The reidentified USB device is Blackview Tab16/API31 with existing production and review packages. Its review-only suite passes **36 scenarios**, **42 including hooks**, in **222 seconds**, including six encrypted template fixture cases and a complete create/preview/apply/edit/snapshot/delete journey. Small-screen 2× text/RTL draft cancellation is host evidence. Proof: `docs/evidence/task-templates-tablet-2026-11-11.json`.

Native instrumentation against this template-capable review app also passed **13 Notes widget and 46 task checks**, both raw RESULT_OK (`/tmp/bilga-templates-native-tests.log`).

Builds/tests now use an exclusive local lock; review Gradle builds disable persistent daemons and retain the existing 2 GiB heap / two-worker / no-parallel settings. No simultaneous expensive Flutter/Gradle/emulator jobs were used. Host available memory was approximately 5.7–6.3 GiB during monitoring; no OOM occurred in this run. Build warnings remain for third-party video_player_android Kotlin migration and SDK XML version parsing; the build and binary identity/signature/no-microphone gates passed.

Exact next work: projects are being implemented over existing nested task-list folders. `lib/features/todo/todo_project_store.dart` is an unreferenced, unverified working file and is excluded from this template checkpoint. Continue project metadata/overview, migration, search/backup, UI and tests together. Task tags/sorting/bulk/calendar/history work and the remaining six-module capabilities are still required; see FEATURE_MATRIX.md and KNOWN_LIMITATIONS.md. No final owner-review readiness is claimed.

Earlier checkpoint evidence follows.

---

## Subtasks, progress and duplication verified — 2026-11-10

**Stage A remains IN PROGRESS.** Tasks now have ordered one-level subtasks/checklists with editable titles, completion, removal/reordering and progress. Draft changes save atomically with the parent, reminder and any explicit series-default edits. Recurring successors start unchecked and retain the completed occurrence's progress; current-only versus future edits remain distinct. Duplication creates independent task/checklist IDs without inheriting recurrence, reminders, media ownership or widget disclosure consent. Task and unified search index subtask titles transactionally. Read-only source display and plain-text export include complete subtask content.

Tasks schema **11** adds the checklist table without changing existing tasks/series. Portable Tasks content schema **9** imports versions 6–8 and remaps checklist ownership; repeated merges remain idempotent. **191 full Flutter tests PASS** under CI's concurrency=2 configuration (87 seconds), analyzer no issues, formatting and **43 × 373** catalog keys PASS. All nine manifest/target guards and first-party non-voice checks pass. The corrected Tab16/API31 run passes **29 scenarios**, **35 including hooks**, in **173 seconds**: six new encrypted subtask fixture cases and a real editor/progress/duplication journey, plus the existing storage/notes/navigation/themes/notification suite and native recurring checklist generation. Evidence: `docs/evidence/checklist-tablet-2026-11-10.json`; design/semantics: `TASK_DATA_MODEL.md`.

Native instrumentation against the checklist-capable review app also passed **13 Notes widget checks and 46 task checks**, both with raw RESULT_OK codes (`/tmp/bilga-checklist-native-tests.log`).

The first expanded tablet build passed its existing 22 scenarios but the seven new fixture/UI cases failed before writing because the test helper used a nonexistent temporary parent directory. The corrected unique-directory helper passes all 29. Host tests also caught and corrected progress semantics and derived display fields leaking into task row maps. An earlier `a0d7463` CI run timed out in a widget test while a database transaction awaited fake-time callbacks. That read now pumps pending callbacks with a bounded deadline; current host CI-configured tests pass. The recurrence source `2684629` independently passed hosted CI **42793370183**. The prior ordinary recurrence review APK is installed separately from production and recorded in `docs/evidence/recurrence-review-apk-2026-11-10.json`; the newer subtask test APK is not an owner-review build.

Next: custom task templates and projects, then task tags/sorting/bulk operations and remaining cross-module features. Broader reminders, journal history/calendar/categories, durable relationships, app PIN, Drive media and full interaction/accessibility/performance acceptance still require work. Production Bilga remains untouched. No main merge, publication, paid activation or owner acceptance is claimed.

Earlier checkpoint evidence follows.

---

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

Ordinary owner-usable Review APK at **9528234** is built, signer-checked, installed in place and launched successfully (COLD, 5295 ms debug Activity; not a release benchmark). Artifact: `build/review/bilga-books-guidance-review-app.apk`, SHA-256 `d524a0bb28fb60561fbb38cd67c055ed679a1c44901a8572788187c27025737d`. Its kernel contains Books/guidance/Finance reports and excludes integration runners and research images. Metadata: `docs/evidence/books-guidance-review-apk-2026-11-15.json`. Production is preserved. Current hosted CI remains pending until push.

## Hosted verification and artifact storage — 2026-11-15

Run **43687503754** at **4ac793c** passes **268 Flutter tests in 196s**, backend, analyzer, format, catalogs, non-voice/manifest guards, DST, Android debug build and APK verification. Hosted debug APK SHA-256 is `e9bd6caae23e32939142569e7bebf40c503c9ab0271c15147e32c90fdeec55ff`. Its final **upload fails because GitHub artifact storage quota is full**, so the overall run is failure and no hosted artifact/download is claimed. The separately built ordinary Review APK is already installed and available locally at source 9528234. Evidence: `evidence/books-guidance-ci-2026-11-15.json`.

CI now keeps every automatic test/build/verification step, writes a verified digest to the job summary, and offers cloud APK upload only through the explicit manual `upload_debug_artifact` boolean (default false, one-day retention). An opted-in upload remains strict and can fail if storage is unavailable. No existing artifact was deleted and no paid service was activated. Local YAML/conditional checks and an executed summary-digest fixture pass; hosted verification of this workflow-only correction is pending its push. Do not describe a skipped optional upload as a successful upload.
