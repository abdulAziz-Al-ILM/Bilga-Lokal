## Finance accounts — 2026-11-11

**The six-module product remains IN PROGRESS.** Finance now supports local cash/bank/card/savings records, signed opening balances/dates, current date-aware balances, one-row atomic transfers, reconciliation observations/adjustments, rename, archive/restore, account selection for ordinary entries, account/audit CSV and complete read-only export. Transfers conserve total funds; transfers and adjustments are excluded from income/expense reports. A matched reconciliation still records its observation/reason. No bank operation, currency conversion or exchange rate is invented.

Legacy Finance reads do not rewrite records. Account operations materialize explicit account/currency ownership with preserved transaction IDs/amounts. Notes DB **16** adds a capability boundary without changing Notes rows; Tasks stays **13**. The shared opener now explicitly refuses a lower configured database version. Older unguarded APKs are still unsafe to install over this data: a schema increment cannot retroactively fix an old binary. Portable Notes content **14** is emitted only for account-bearing finance; other snapshots stay **13**, Tasks content stays **11**. Validated merges retain idempotence. See `FINANCE_DATA_MODEL.md`.

**225 full Flutter tests PASS** (80 seconds), analyzer no issues, formatting clean, **43 × 426** catalog keys, nine manifest guards and non-voice guard PASS. New coverage includes exact/localized money, conservation/voiding, dated balances, historical reconciliation, currency/references/limits/future versions, partial debts, stale revisions and simulated SQL failure rollback, backup, account forms through the main Finance route, failed-save draft recovery in compact 2× text/RTL, and complete read-only audit without mutation. Evidence: `docs/evidence/finance-host-2026-11-11.json`.

Blackview Tab16/API31 passes **48 physical scenario cases**, **54 including hooks**, in **354 seconds**. Four encrypted Finance fixtures verify legacy preservation, atomic/stale/failed transfers, account/audit backup and guarded downgrade rejection. The real UI creates an account, transfers, reconciles, inspects history, renames, archives/restores and posts an expense to the selected account. This uses synthetic test entitlement only, not real purchase acceptance. Evidence: `docs/evidence/finance-accounts-tablet-2026-11-11.json`. Native review instrumentation also passes **13 Notes widget and 46 task checks**, both raw RESULT_OK (`/tmp/bilga-finance-native-tests.log`). The prior project APK was separately built, signer-checked and installed in place, with a 5213 ms debug cold Activity launch (`docs/evidence/projects-review-apk-2026-11-11.json`); that is neither a release benchmark nor the new Finance artifact.

Project hosted CI **43047300447** failed before app tests because apt could not resolve azure.archive.ubuntu.com despite retries. Setup now checks installed dependencies and only installs missing packages; missing-dependency errors remain fatal. This change is not yet hosted-verified. Evidence: `docs/evidence/projects-ci-setup-failure-2026-11-11.json`.

Finance transaction editing/history, categories/budgets/goals/recurrence/debt deadlines/analytics, complete Books/Experiences/Habits, remaining Notes/Tasks organization, durable links, broader reminders, app PIN, Drive media and full device/accessibility/performance acceptance remain required. Production Bilga is preserved; no main merge, publication, paid activation or voice implementation occurred.

Earlier checkpoints follow.

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

# Continuation checkpoint — 2026-11-10

**Overall remains IN PROGRESS; Stage A is not complete.** Rich-text Notes now includes headings, lists/checklists, links, undo/redo, private keyboard input, formatting history and backup support. Notes migrates additively to schema 15; portable Notes content schema is 13 and old imports remain supported. All 166 Flutter regressions pass; analyzer has no issues; 43 catalogs contain 336 keys. New strings remain draft/fallback translations, without native-speaker certification.

The Python purchase verifier is implemented with 17 passing security/failure tests and a Python-to-Dart grant fixture. It checks receipt signatures, performs Google API lookup and acknowledgment, records hashed token metadata and signs device/receipt-bound grants. It is not deployed or tested against real Play credentials. Its README documents configuration and anonymous receipt-replay limits. No private signing key or paid service was activated.

The owner authorized USB debugging for Blackview Tab16, Android 12/API31. Existing production Bilga 1.4.0+9 and its certificate were inspected read-only. Its signing certificate differs from the isolated review key, so no production update, uninstall, data clear or database read was attempted. The separate debug-only `com.ilmmizan.bilga.review` package now passes 21 real-tablet scenario cases (27 including hooks) in 101 seconds. Scope includes storage/migration/backup, rich editing/rotation, all ten main routes, 14 theme variants, Arabic RTL, and real quiet notification delivery, snooze/re-delivery and native PendingIntent completion. Exact evidence and limitations are in TABLET_TEST_REPORT.md. The original application ID and production signing settings remain defaults. Legacy spoken-reminder controls and native TTS were discovered during the audit and removed; a source CI guard now prevents reintroduction. Earlier claims that all reachable TTS was already removed were incomplete.

Device testing additionally fixed vendor SQLite JSON1 differences, encrypted fixture attachment, SQLCipher export verification and the trial overlay sharing the root HeroController. The earlier blanket no-TTS claim was corrected during this audit. Prior source checkpoint 382c437 passed hosted CI 42778229175; the new device milestone needs its own CI. Historical evidence below applies to its named source revisions. Current continuation and precise remaining work are in IMPLEMENTATION_STATUS.md and FEATURE_MATRIX.md.

---

# Engineering checkpoint — 2026-11-09

**Overall: IN PROGRESS. Bilga is not release ready.** This is an implemented and tested development checkpoint against the owner's complete master specification, not a claim that every required module is finished.

## Implemented source

Recovered four missing backup files and the newer maintained Notes/tag, encrypted-trial, Android task-reminder/widget and backup implementations from the existing recovery branch. The earlier Kotlin assistant/reminder/backup source was inspected, and the language-model repository was inventoried. SOURCE_RECOVERY.md records revisions and findings.

Added unified offline FTS4 search across Notes, Tasks, Habits, journals, books, finance and folders; type/archive filtering; paged previews; original-record reading and supported editor navigation; attachment export; and read-only note-history viewing. The text assistant explicitly performs source-linked lookup without generating personal facts or changing records.

Added Today/next-seven-days task/habit views and quick creation using original record IDs. Added trial activation/remaining-day information and early purchase access in settings. Trial expiry keeps a protected read/export/backup path. Removed reachable voice/TTS functionality and microphone permission. All new UI strings use catalogs; seven priority-language drafts are supplied, with English fallback for new strings in other catalogs.

New sales use one product, `bilga_lifetime_unlock`, and Play-supplied localized prices. Verified legacy receipts remain compatible. Upgraded the official Flutter billing packages to declare Play Billing 9.1.0 and added a binary-manifest CI gate. No backend, regional prices or store publication was activated.

## Validation and data safety

Flutter 3.47.8 / Dart 3.13.7 on Ubuntu x64: clean analyzer, **158 full Flutter tests passing**, formatting and **43 × 324** catalog structure checks passing. Four Python manifest-gate tests pass. The subsequent privacy-control readiness fix passes all 26 Notes-widget checks locally; hosted validation now passes the full 158-test suite for that fix, including the debug APK build and artifact checks.

Retained application ID, database filenames, signing configuration and local encryption. Search uses additive Notes 14 / Tasks 9 migrations. Existing v1–v13 Notes upgrade coverage and selected Tasks upgrade cases preserve records/history/folders; the static historical SQL checker additionally covers Tasks v1–v5. No installed data was deleted or downgraded. Backup content formats remain compatible; search and device-local widget consent are derived/excluded. Restoration automatically rebuilds search in the source transaction. Host tests verify rollback, repeated imports and privacy-consent isolation. Real Android SQLCipher/media/device restore remains unverified.

The synthetic host-FFI benchmark uses 3000 Notes + 3000 Tasks: latest run inserted them with FTS triggers in 654 ms and executed two paged searches in 14 ms. This is not Android performance evidence.

TEST_REPORT.md records commands, earlier failures, fixes and the final host results. Hosted run 42667262437 passed analysis and setup but failed one timing-sensitive pre-existing widget test (157 passed / 1 failed); APK stages were skipped. Its deterministic readiness fix is source commit f2bb128. Final retry **SUCCESS**: https://github.com/abdulAziz-Al-ILM/Bilga-Lokal/actions/runs/42668103911 . Analyzer no issues, **158 tests PASS**, debug APK, ZIP/v2 signature and manifest checks passed.

## Artifacts and GitHub

Branch: `development/global-launch`. Verified pushed source checkpoints: `61035a2` (host-verified integration), `600ebb7` (Billing 9.1 and manifest checks), `f2bb128` (privacy-test readiness). Draft PR: https://github.com/abdulAziz-Al-ILM/Bilga-Lokal/pull/1 . Main is unmerged.

No signed release APK/AAB exists from this work. Local APK/AAB setup was interrupted after doctor confirmed no Android SDK/Java or Android device; no local build success is claimed. Hosted source `f2bb128ed4d4d6adef20fc28a7595de5d00fee2a` produced the verified [private debug APK artifact](https://github.com/abdulAziz-Al-ILM/Bilga-Lokal/actions/runs/42668103911/artifacts/13698162381), expiring 2026-11-16 22:58 Asia/Tashkent. APK SHA-256: `3ceb34222fc421cd2d9dde65642c63e7f33a8a2f542624fc1151b25c3e7ce4cc`. Its merged manifest has the preserved package ID, target API 36, Billing 9.1.0 and no microphone permission. The APK uses a disposable CI debug signer; production signing compatibility is unverified.

## Remaining product work and external acceptance

FEATURE_MATRIX.md and KNOWN_LIMITATIONS.md identify unfinished implementation: rich-text notes, recurrence/subtasks/projects, cross-module durable links, broader reminder workflows, journal history/calendar/custom categories, media-bearing Drive backups and a complete interaction/accessibility/performance audit. A standalone app PIN is also missing. These are engineering tasks, not credential blockers.

External requirements: actual Play product/license/verifier configuration and licensed test accounts; existing release-signing credentials; optional Drive OAuth configuration/accounts; real Android devices for alarms, lifecycle, encryption, migration and purchase acceptance; applicable Play closed testing and merchant requirements; owner review of legal/store materials and final regional prices. No signing key was replaced, no paid infrastructure was deployed and no store publication occurred.

New purchases retain the secure verifier-grant requirement. The client is implemented, but its backend is not implemented/deployed in this repository; this remains engineering work before external setup and live certification. An entirely offline device cannot learn a new refund, and privacy-preserving offline trial enforcement cannot perfectly survive reinstall/clear-data. No anti-piracy or native-speaker verification guarantee is claimed.

Next exact work: continue the remaining feature implementation, starting with occurrence-safe recurrence and durable cross-module links, without discarding working persistence. This checkpoint’s hosted Android debug build and artifact verification are complete. The master brief is saved as FINAL_PRODUCT_SPEC.md so subsequent work does not require the owner to repeat it.
