# Feature matrix

Statuses are scoped to the actual feature below. IMPLEMENTED means source exists, not device acceptance.

| Area | Status | Actual implementation / remaining acceptance |
| --- | --- | --- |
| Source recovery | IMPLEMENTED | Four repositories and both primary branches inspected; SOURCE_RECOVERY.md |
| Notes persistence, folders, tags, trash, history, autosave | IMPLEMENTED | Recovered latest WIP; current host regressions pass; Android acceptance pending |
| Competitive rich-text Notes | IN PROGRESS | Rich editor/history/backup implemented and host tested; tablet acceptance and remaining Note import/organization details pending |
| Tasks, dates, priorities, descriptions, filters, folders, trash | IMPLEMENTED | Existing workflows plus recovered reminder integration |
| Recurrence, subtasks, projects and custom task templates | NOT STARTED | Prebuilt checklist templates already exist; recurrence, nested subtasks and custom templates still need complete workflows |
| Android task reminders, snooze and widget actions | IMPLEMENTED | Recovered SQLCipher/native actions; require current branch platform tests |
| Standalone/note/habit reminders | NOT STARTED | Task reminders do not cover the complete reminder module |
| Habits | IMPLEMENTED | Existing schedules, quantitative entries, history, streaks, archive; no habit reminders |
| Private journal | IN PROGRESS | Existing experience entries/categories/attachments/export; history/calendar/custom categories incomplete |
| Daily/weekly planning | IN PROGRESS | Source-linked task/habit views and quick creation added; separate upcoming-reminder panel pending |
| Unified search | TESTED | FTS4 across notes, tasks, habits, journal, books, finance and folders; archive filter and paging |
| Text assistant | IMPLEMENTED | Source-linked offline lookup, no generated answers or automatic modifications |
| Voice | NOT STARTED | Explicitly excluded from this release; no reachable speech/microphone flow |
| Cross-module relationships | NOT STARTED | Note-to-task and journal-to-task durable links still required |
| 40-day trial | IMPLEMENTED | Recovered Keystore/AtomicFile, monotonic/high-water clock protection; device tests pending |
| Read-only access after trial | TESTED | Host reader/history/no-edit regression passes; read/export routes remain under AppLock. Native export acceptance still needs a device |
| Lifetime purchase | BLOCKED | Product ID updated; secure grant flow recovered; real Play/verifier configuration and test purchases unavailable |
| Regional pricing | IN PROGRESS | Runtime localized price remains Play-supplied; owner approval and Console activation pending |
| App lock and local encryption | IMPLEMENTED | Existing device authentication, SQLCipher, Keystore and encrypted attachments retained; standalone app PIN absent |
| Local encrypted backup and merge | IMPLEMENTED | Recovered v1/v2 codecs, transactional cross-DB import and ID remapping; host content/codec regressions pass; media/device acceptance pending |
| Google Drive backup | IN PROGRESS | Existing content-only path; media-bearing backups require local export |
| Localization | IN PROGRESS | All 43 catalogs retained; seven priority-language drafts, remaining new strings use English; native review pending |
| CI and Android artifacts | IN PROGRESS | Current branch validation workflow/build evidence pending |
| Store materials and release acceptance | NOT STARTED | No publication authorized; global release acceptance criteria not met |
