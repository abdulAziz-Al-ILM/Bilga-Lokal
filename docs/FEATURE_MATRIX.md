# Feature matrix

Statuses are scoped to the actual feature below. IMPLEMENTED means source exists, not device acceptance.

| Area | Status | Actual implementation / remaining acceptance |
| --- | --- | --- |
| Source recovery | IMPLEMENTED | Four repositories and both primary branches inspected; SOURCE_RECOVERY.md |
| Notes persistence, folders, tags, trash, history, autosave | IMPLEMENTED | Host regressions pass; selected encrypted editor/migration/rollback scenarios pass on Tab16; complete interaction audit pending |
| Competitive rich-text Notes | IN PROGRESS | Rich editor/history/backup implemented; editor/save/reopen/backup/rotation pass on Tab16; remaining Note import/organization details and full audit pending |
| Tasks, dates, priorities, descriptions, filters, folders, trash | IMPLEMENTED | Existing workflows plus recovered reminder integration |
| Recurring tasks | TESTED | Editor, additive Tasks 10 migration, single/future edits, atomic occurrence generation, history, backup remapping and native notification completion; 22-scenario tablet suite plus DST/calendar tests pass |
| Subtasks, projects and custom task templates | IN PROGRESS | Prebuilt checklist templates exist; complete subtasks/projects/custom templates remain required |
| Android task reminders, snooze and widget actions | IMPLEMENTED | Recovered SQLCipher/native actions; Tab16/API31 delivery, snooze and native completion pass; reboot/Doze/timezone and permission failure acceptance remain |
| Standalone/note/habit reminders | NOT STARTED | Task reminders do not cover the complete reminder module |
| Habits | IMPLEMENTED | Existing schedules, quantitative entries, history, streaks, archive; encrypted habit persistence/completion tested on Tab16; no habit reminders |
| Private journal | IN PROGRESS | Existing experience entries/categories/attachments/export; history/calendar/custom categories incomplete |
| Daily/weekly planning | IN PROGRESS | Source-linked task/habit views and quick creation added; separate upcoming-reminder panel pending |
| Unified search | TESTED | FTS4 across notes, tasks, habits, journal, books, finance and folders; archive filter and paging |
| Text assistant | IMPLEMENTED | Source-linked offline lookup, no generated answers or automatic modifications |
| Voice | NOT STARTED | Explicitly excluded from this release; no reachable speech/microphone flow |
| Cross-module relationships | NOT STARTED | Note-to-task and journal-to-task durable links still required |
| 40-day trial | IMPLEMENTED | Keystore/AtomicFile trial start and acknowledgment run on Tab16; monotonic/high-water clock protections pass host tests; native clock/reboot acceptance pending |
| Read-only access after trial | TESTED | Host reader/history/no-edit regression passes; read/export routes remain under AppLock. Native export acceptance still needs a device |
| Lifetime purchase | IN PROGRESS | Secure client grant protocol plus Python verifier, Google API adapter, acknowledgement and hashed token ledger implemented; real Play configuration/test purchases and deployment pending |
| Purchase verification backend | HOST TESTED | 17 Python security/failure tests and Python-to-Dart grant fixture pass; not deployed, no real Play credential validation |
| Regional pricing | IN PROGRESS | Runtime localized price remains Play-supplied; owner approval and Console activation pending |
| App lock and local encryption | IMPLEMENTED | Existing device authentication, SQLCipher, Keystore and encrypted attachments retained; standalone app PIN absent |
| Local encrypted backup and merge | IMPLEMENTED | Recovered v1/v2 codecs, transactional cross-DB import and ID remapping; host content/codec regressions and Tab16 encrypted text merge/rollback/idempotence pass; real media/second-device acceptance pending |
| Google Drive backup | IN PROGRESS | Existing content-only path; media-bearing backups require local export |
| Localization | IN PROGRESS | All 43 catalogs retained; seven priority-language drafts, remaining new strings use English; native review pending |
| CI and Android artifacts | IN PROGRESS | Host and current local review build verified; recurrence source push/CI pending |
| Store materials and release acceptance | NOT STARTED | No publication authorized; global release acceptance criteria not met |
