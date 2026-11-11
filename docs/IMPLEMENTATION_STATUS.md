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

The sections below are historical checkpoints; the newest scope above takes precedence.

## Verified USB tablet milestone — 2026-11-10

**Stage A remains IN PROGRESS.** The connected Blackview Tab16/API31 now passes **21 scenario tests** (runner count 27 including hooks), in 101 seconds. Tested: encrypted storage/reopen, Notes v1–v10 and Tasks v1 fixture migrations, current plaintext-to-encrypted conversion with FTS, rollback/trash/backup idempotence, rich editor/save/reopen/backup, real portrait/landscape rotation, tasks/habits/search, actual app startup, all ten main routes, 14 palette/light-dark combinations, Arabic RTL, real quiet notification delivery, snooze/re-delivery and native notification PendingIntent completion. Sanitized evidence: `docs/evidence/tablet-2026-11-10.json`; exact scope/failures: `TABLET_TEST_REPORT.md`.

The production installation and data remain untouched. Testing used only the debug-only review package, separate UID/storage/Keystore and stable local review signer. The installer refuses production APKs and mismatched review upgrades. Early Flutter driver defaults cleaned up only the synthetic review package; the runner now keeps it installed. A negative installer check with an invalid device serial rejected the production APK before any ADB call.

Device testing exposed and fixed vendor SQLite JSON1 differences, an encrypted-injection ATTACH error, stale virtual-table schema verification after SQLCipher export, and the trial overlay borrowing the main Navigator's HeroController. The navigation bug was reproduced in a failing host test before its scope fix. Latest host result: **166 Flutter tests PASS**; analyzer no issues; 43 × 336 catalog, 17 Python backend and seven manifest checks PASS. CI for prior checkpoint `382c437` succeeded: run `42778229175`; this milestone still needs its own pushed CI result.

Next exact work: preserve this source checkpoint and ordinary review APK, then implement occurrence-safe recurrence/subtasks/projects/custom templates and durable relationships. Broader note/habit reminders, journal history/calendar/categories, app PIN, Drive media backup and full acceptance remain engineering work. Real release signing, Play/license/verifier deployment/test purchases and final store approvals remain external setup. No main merge, paid service activation or publication is authorized.

## Purchase verifier implementation — 2026-11-10

Added `backend/purchase_verifier`: receipt RSA verification, fixed-host authenticated Google Play lookup/acknowledgment, cancellation-only signed revocations, exact Ed25519 client grants, bounded WSGI endpoint, persistent hashed token ledger and explicit non-overwriting key-generation tooling. No credentials were read, no production key was generated and no service was deployed. The README distinguishes anonymous restore/replay limitations, cached offline grants and required external setup.

Validation: 17 Python tests PASS in an isolated environment; dependency integrity check PASS. All 15 focused Dart verifier tests PASS, including a public fixture issued by the actual Python verifier. Static analysis has no issues. Combined full Flutter suite: **165 PASS** in 46 seconds, including the added fixture test. All seven production/review manifest gates PASS. A later audit found legacy reminder TTS still reachable; its settings and native speech path are now removed, with a first-party no-voice CI gate. Native recompilation/acceptance is pending; the earlier blanket no-TTS statement was too broad. Native tablet test harness is prepared with review-package storage guards; actual test execution is still pending the cold Android build.

# 2026-11-10 continuation checkpoint

Branch remains `development/global-launch`; draft PR #1 remains the review target. The new owner instruction is saved in NON_VOICE_OWNER_REVIEW_BRIEF.md. Stage A (complete non-voice implementation and verification) precedes Stage B (owner review). Voice and Play publication still require separate explicit approval.

Rich-text Notes are implemented with headings, bold/italic/underline/strikethrough, lists/checklists, links, undo/redo, existing autosave/attachments/tags/history and a read-only rich reader. Notes schema 15 adds nullable rich_body to notes/history; plain body remains searchable and compatible. Portable backup content schema 13 preserves formatting; old backup formats are still accepted. A narrowly patched MIT-licensed flutter_quill 11.6.0 is vendored to preserve disabled keyboard suggestions/autocorrect/IME learning. See vendor/flutter_quill/BILGA_PATCH.md.

Current host evidence: **164 full Flutter tests PASS**, analyzer no issues; all 43 catalogs have 336 keys. New cases cover formatting-only history, restoration and backup, invalid deltas/unsafe links, Notes 14 migration, no-op legacy opening, actual TextInput privacy flags, and large-font editing above the keyboard. Review APK compilation is running locally; no new APK/device feature pass is claimed yet.

The connected Blackview Tab 16 is USB-authorized, Android 12/API 31, arm64, 1200×2000. Existing production Bilga is version 1.4.0+9, target 36, debuggable, with certificate SHA-256 38ecfe0234e465924812ba3ee84ef838557a1d03d53713bd7a6d76478663bd6d (confirmed by apksigner). It has not been installed over, uninstalled, reset, launched for automation or had databases read. Test key differs. An explicitly opted-in debug-only `com.ilmmizan.bilga.review` build is being prepared, labeled Bilga Review, with a separate UID/storage/Keystore and stable local test key. The normal production ID is unchanged. No review installation existed when inspected.

Local toolchains now live in ignored `.bilga-tools/` so reboot no longer loses them: pinned Flutter 3.47.8/Dart 3.13.7, Temurin 21.0.13+9, Android SDK 36/build-tools 36.0.0/NDK 28.2. The USB tool must run with host/loopback access. The review build command is `bash tool/build_tablet_review.sh`; it verifies debug label, package isolation, signature and absence of microphone permission before any separate install action.

Next exact step: finish the current review APK build, verify its actual manifest and signer, install only the isolated review package after checking it remains absent or signature-compatible, then execute synthetic-data UI/integration journeys on the actual tablet. Continue other required modules and verifier backend while native builds run. The overall product remains IN PROGRESS; the historical checkpoint below is not a completion claim.

---

# Implementation status

Checkpoint date: 2026-11-09 (Asia/Tashkent)
Branch: `development/global-launch`
Starting commit: `8871b3ac007ab05402949b3eacd4327340c6913c`
Overall: **IN PROGRESS**, not release ready.

The owner supplied `FINAL_PRODUCT_SPEC.md`. Do not resume the superseded voice/per-feature-sales strategy from old root documents.

Completed source work in this checkpoint:

- Inspected all four GitHub repositories and primary branches/history; recovered missing backup source and newer WIP functionality (see SOURCE_RECOVERY.md).
- Retained package ID, DB filenames, existing encrypted storage and signing configuration. Recovered Notes DB 13 and Tasks DB 8; added non-destructive search migrations to Notes 14 / Tasks 9.
- Preserved 43 locales and seven palettes; added draft translations for new UI in seven priority languages, with English fallback text in the other 36 catalogs.
- Removed reachable voice/STT/TTS functionality and microphone permission; assistant is explicitly local, read-only text lookup.
- Added unified local FTS4 search with transactional source triggers, pagination, archive and type filters, source details, attachment export and note-history viewing.
- Added an explicit read/export route after trial expiry; existing editing routes remain covered by the access gate and AppLock.
- Added Today and next-seven-days views from original task/habit records, quick creation, and trial/purchase status in settings.
- Upgraded official billing packages to Play Billing 9.1.0 because the recovered Billing 7.1.1 is past its submission deadline; added a merged-manifest CI gate.
- Standardized the new sale product to `bilga_lifetime_unlock`, retaining legacy verified purchase compatibility. New purchases still require the recovered secure-verifier configuration.

Current verification: Flutter analyze PASS (no issues), full Flutter suite 158 PASS (64s), formatting PASS (125 files), 43 × 324 catalog structure PASS. Test failures and fixes are recorded in TEST_REPORT.md. Source checkpoint `61035a238141a89e478d0190e08f71939f3d6c6e` was pushed and its remote SHA verified. Draft PR: https://github.com/abdulAziz-Al-ILM/Bilga-Lokal/pull/1 . Validated/pushed source `f2bb128ed4d4d6adef20fc28a7595de5d00fee2a`. Hosted CI **42668103911 SUCCESS**: 158 tests, analyzer, debug APK, ZIP/v2 signature and merged-manifest checks pass. Artifact link and hash are in RELEASE_READINESS.md. Final documentation commits do not change application source. Local Android builds are blocked by absent Android SDK/Java; a hosted debug APK is available; no signed release APK/AAB is claimed.

Remaining required implementation includes rich-text editing, task recurrence/subtasks/projects/custom templates, standalone and habit/note reminder workflows, richer journal history/calendar/categories, cross-module relationships, backup media streaming to Drive and the complete interaction/accessibility/performance audit. See FEATURE_MATRIX.md and KNOWN_LIMITATIONS.md.

External configuration: Play product/license key/verification service credentials, OAuth client setup, existing release signing credentials, Android SDK/device access and store acceptance. Never publish, activate regional prices, replace signing keys or merge main without approval.

Next exact step: continue the unimplemented master-spec features, starting with occurrence-safe task recurrence and durable cross-module links, with complete UI, backup remapping, migrations and tests. Hosted debug build verification for this checkpoint is complete; release/device/purchase acceptance is still pending. Do not repeat the already passing suite unless code changes or new failures justify it. Continue remaining modules without replacing working persistence.
