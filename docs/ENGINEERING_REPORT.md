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
