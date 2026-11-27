# Feature matrix

Statuses are scoped to the actual feature below. IMPLEMENTED means source exists, not device acceptance.

| Area | Status | Actual implementation / remaining acceptance |
| --- | --- | --- |
| Source recovery | IMPLEMENTED | Four repositories and both primary branches inspected; SOURCE_RECOVERY.md |
| Notes persistence, folders, tags, trash, history, autosave | IMPLEMENTED | Host regressions pass; selected encrypted editor/migration/rollback scenarios pass on Tab16; complete interaction audit pending |
| Competitive rich-text Notes | IN PROGRESS | Rich editor/history/backup implemented; editor/save/reopen/backup/rotation pass on Tab16; remaining Note import/organization details and full audit pending |
| Tasks, dates, priorities, descriptions, filters, folders, trash | IMPLEMENTED | Existing workflows plus recovered reminder integration |
| Recurring tasks | TESTED | Editor, additive Tasks 10 migration, single/future edits, atomic occurrence generation, history, backup remapping and native notification completion; 22-scenario tablet suite plus DST/calendar tests pass |
| Subtasks/checklists, progress and duplication | TESTED | Ordered one-level subtasks, edit/save/reorder/complete, list progress, independent copies, recurrence resets, search, reader/export, additive migration and backup; host and Tab16 journeys pass |
| Custom task templates | TESTED | Create/preview/apply/edit/delete, task snapshots, unchecked copies, stale-edit protection, Tasks 12 migration and content 10 backup; host 199 and tablet 36-scenario suites pass |
| Projects | TESTED | Metadata/status/deadline, nested progress/overdue counts, safe list conversion, source reader/export, search/trash and backup; 208 host tests and 43-scenario tablet suite pass after keyboard correction |
| Task tags/calendar/sorting/bulk/history audit | IN PROGRESS | Existing due-date smart folders, planner and occurrence history do not complete every required organization workflow |
| Android task reminders, snooze and widget actions | IMPLEMENTED | Recovered SQLCipher/native actions; Tab16/API31 delivery, snooze and native completion pass; reboot/Doze/timezone and permission failure acceptance remain |
| Standalone/note/habit reminders | NOT STARTED | Task reminders do not cover the complete reminder module |
| Habits | IN PROGRESS | Existing schedules/quantities/history/streaks/archive plus 22-template gallery and first deterministic creation guide; 268 combined host tests pass. Advanced schedules, reminders, custom categories and complete statistics remain required. Current native scope is recorded separately. |
| Experiences | IN PROGRESS | Private entries, basic categories, reflection fields, attachments/export exist; custom categories, calendar, durable history, tags, favorites and linked follow-up tasks remain required |
| Finance | IN PROGRESS | Local cash/bank/card/savings accounts, exact opening/current balances, atomic transfers, dated reconciliation/audit, archival, CSV, read-only export and portable backup pass host tests. Transaction corrections/history/restore and reversible voids pass host tests; recurring transactions, category budgets/goals, debt deadlines/reminders and savings progress remain required; date-range reports pass host and tablet tests |
| Finance accounts integrity and UI | TESTED | 225 full host tests and 48-scenario Tab16 suite pass, including encrypted rollback/stale/backup fixtures and main Finance → accounts → transfer/reconcile/history/archive/restore → selected-account expense journey; synthetic entitlements only |
| Finance transaction edits/history | TESTED | 234 full host tests and 50-scenario Tab16 suite; amount/account edits, isolated history restoration, reversible voids, failed/stale rollback and portable/read-only history pass; access-expiry draft retry is compact/RTL host evidence |
| Finance reports | TESTED | 241 full host tests and 51-scenario Tab16 suite; exact daily/weekly/monthly income/expense/cash-flow reports, category breakdown and chart/filter/refresh pass; read-only access and compact RTL/dark large amounts are host tested |
| Books offline reader | TESTED (SCOPED) | Native PDF, reflowable EPUB/TXT, encrypted import, covers, progress, marks/annotations, cards/review, sessions/statistics, shelves, deterministic help, cross-module links and full local encrypted backup. 287-test CI, expanded20-scenario Tab16 suite, final6-case UI, real SAF and real process-restart acceptance pass; overlapping counts are separate suites. Format and accessibility/performance limits: BOOKS_OFFLINE_READER.md. Ordinary APK: BOOKS_READER_ACTIVE_CHECKPOINT.md. |
| Daily/weekly planning | IN PROGRESS | Source-linked task/habit views and quick creation added; separate upcoming-reminder panel pending |
| Unified search | TESTED | FTS4 across notes, tasks, habits, journal, books, finance and folders; archive filter and paging |
| Text assistant | IMPLEMENTED | Source-linked offline lookup, no generated answers or automatic modifications |
| Voice | NOT STARTED | Explicitly excluded from this release; no reachable speech/microphone flow |
| Cross-module relationships | IN PROGRESS | Books creates stable Notes/Tasks/planning/Habit/Experience links with idempotent retries and restore remapping. General Note-to-task and journal-to-task workflows remain required. |
| 40-day trial | IMPLEMENTED | Keystore/AtomicFile trial start and acknowledgment run on Tab16; monotonic/high-water clock protections pass host tests; native clock/reboot acceptance pending |
| Read-only access after trial | TESTED | Host reader/history/no-edit regression passes; read/export routes remain under AppLock. Native export acceptance still needs a device |
| Lifetime purchase | IN PROGRESS | Secure client grant protocol plus Python verifier, Google API adapter, acknowledgement and hashed token ledger implemented; real Play configuration/test purchases and deployment pending |
| Purchase verification backend | HOST TESTED | 17 Python security/failure tests and Python-to-Dart grant fixture pass; not deployed, no real Play credential validation |
| Regional pricing | IN PROGRESS | Runtime localized price remains Play-supplied; owner approval and Console activation pending |
| App lock and local encryption | IMPLEMENTED | Existing device authentication, SQLCipher, Keystore and encrypted attachments retained; standalone app PIN absent |
| Local encrypted backup and merge | IMPLEMENTED | Recovered v1/v2 codecs, transactional cross-DB import and ID remapping; host content/codec regressions and Tab16 encrypted text merge/rollback/idempotence pass; real media/second-device acceptance pending |
| Google Drive backup | IN PROGRESS | Existing content-only path; media-bearing backups require local export |
| Localization | IN PROGRESS | All 43 catalogs retained; seven priority-language drafts, remaining new strings use English; native review pending |
| CI and Android artifacts | TESTED (DEVELOPMENT) | Reader runtime ff59d5b CI43708926430 passes287 tests and Android build/verification. Ordinary default-main Review APK is signer-verified, installed and launched; BOOKS_READER_ACTIVE_CHECKPOINT.md. Cloud upload skipped, no signed production release or release performance certification. |
| Store materials and release acceptance | NOT STARTED | No publication authorized; global release acceptance criteria not met |

## 2026-11-15 reference-driven continuation

The owner's professional-completion directive is preserved in `PROFESSIONAL_PRODUCT_COMPLETION_2026-11-15.md`. All seven supplied linked reference images were downloaded and visually reviewed locally; source attribution, current official product/help links and observed patterns are in `../references/README.md`. Images are research-only, ignored by Git and excluded from app assets.

- **Book library foundation — HOST + SCOPED TABLET TESTED:** metadata/status/author/publication/ISBN/dates/pages/rating/favorites, custom shelves/tags/categories, thin paging, search/filter/sort, guarded editor, legacy chapter/history/bookmark preservation, reader/export and compatible backup. This historical foundation is superseded by the offline reader, covers, sessions/statistics, cards/review and stable locators in `BOOKS_OFFLINE_READER.md`.
- **Habit templates and first-use help — HOST + SCOPED TABLET TESTED:** 22 editable suggestions, searchable category gallery, preview/cancel/customize, explicit save, persistent Help and first-habit action. Existing tracking/history/archive remains. No catalogue entries become user records until Save.
- **Shared deterministic guidance — IN PROGRESS / HOST TESTED FIRST JOURNEY:** actual keyed controls, spotlight hit-test hole, real editor navigation, action gating, Back/Next/Skip/Exit, local versioned progress, explicit safe resume, layout/keyboard fallback and fresh authorization. The six-step Habit creation journey is wired. The Habit journey also passes in the scoped tablet run. Books reader/library tours are now wired; Notes/Tasks/Finance/Experiences tours and a searchable Help Hub remain required. See `GUIDANCE_SYSTEM.md`.
- **Current combined host scope:** 268 tests, clean analyzer/format, 43 × 568 catalogs and nine manifest guards pass. Native evidence is in `evidence/books-guidance-tablet-2026-11-15.json`: three Book-editor scenarios pass after the fixture refocus fix; the earlier combined run has thirteen other/overlapping passes and one now-fixed failure. No single all-pass combined rerun is asserted. The ordinary new Review artifact is separate.

This section supersedes older rows that said Book metadata was absent or implied Habits were a complete professional module. Full four-module product maturity and universal help remain **IN PROGRESS**.
