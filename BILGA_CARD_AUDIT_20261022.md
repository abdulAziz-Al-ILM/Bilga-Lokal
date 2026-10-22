# Bilga cards — preliminary code audit, 2026-10-22

This inventory was read before the host JVM crash stopped work. It records code
coverage and gaps; it does not certify every flow as fully working. The current
source has not passed native build/device verification. No other card was changed.

## Inventory and existing capabilities

`lib/app/home_page.dart` defines seven main cards. Core contains Start and the
deferred Turbo entry; they are not extra top-level cards.

| Card | Implemented in code | Partial or unverified | Missing / not found in inspected paths |
| --- | --- | --- | --- |
| Notes | Create/edit/autosave, folders, normalized tag library and links, title/body/tag search, favorites/archive/trash, version history, consent-gated Android widget | Cold/cached-engine refresh fix needs current device regression; search uses LIKE; large datasets and Unicode matching need dedicated evidence | FTS index, links/backlinks, shared editing |
| To-Do | CRUD, folders/trash, priority/deadline, calendar urgency borders/grid, filters, separate reminders, native Done/preset Snooze, widget and optional overlay | New native widget custom-time picker is WIP; native build failed; new selected-time/SQL/alarm/device assertions have not run | Opt-in persistent task-summary notification (requested, not started); recurring task/subtask/project model |
| Habits | Create/configure/rename/archive, weekday schedule history, amount/target/unit/cue/reason/minimum, idempotent check-in/undo/skip, streak, 28-day calendar/progress, older-date history | Editor/usability, archive filtering, schedule changes and preserved historical targets need stronger tests; weekly schedule is weekday-based | Per-habit reminders, Android widget, habit search, explicit completion percentage and flexible reporting |
| Finance | Local currency ledgers, exact integer minor units, income/expense/lending/borrowing, repayments/overpayment checks, categories, monthly budgets/reports, search, CSV export, voided records | Broad UI smoke tests, scale, correction/reconciliation and finance-specific restore flows need more evidence | Recurring transactions, bank integration, native widget, separate multi-account transfer model |
| Experience | Searchable local records, feelings/lesson/next-step fields, edit/export, private-record storage | Generic record UI; permanent delete needs a stronger recovery flow | Dedicated mood calendar/statistics, scheduled prompts, Android widget |
| Books | Books/chapters, chapter versions/trash restoration, characters, reader/bookmark, text/EPUB export | Generated EPUB/large manuscript/reader accessibility need current-device validation; whole-record removal is permanent | Library import workflow, richer annotations, reading schedule/widget |
| Bilga Core | Start command parser, offline voice/model catalog/runtime controls, reading pause/resume, guarded access, themed Core widget | Actual STT/TTS coverage depends on installed compatible models/voices; Turbo is deferred; command breadth needs a later separate audit | Universal offline support must not be claimed; advanced Turbo is not implemented |

## Cross-cutting dimensions

- **Database/privacy:** Notes, Habits and private records use the existing encrypted
  NoteDatabase; To-Do uses its separate encrypted database. Native Todo writes use
  existing SQLCipher/key/transaction guards. No reset/key change is authorized.
  AppLock/secure-window controls exist. Notes and Todo widget disclosure is explicit;
  launcher-retained snapshots remain an external privacy limitation.
- **Search:** Notes searches title/body/tag with escaped LIKE and tag links;
  Todo searches title/description with local filters. Finance and book/experience
  pages have their own search. Habits has no search control in the inspected page.
  No single indexed cross-card search was found.
- **UI/theme:** shared Material theme covers seven palettes and light/dark/system;
  existing surfaces use it. Native widget/picker theme follows WidgetTheme. Current
  scale/font/RTL/tablet/device regressions are still required, especially new UI.
- **Offline:** CRUD/schedules/ledger/reading storage are local. Optional Drive backup
  and model download require network. Offline voice capability is language/device-
  dependent. Core command changes are deferred by user instruction.
- **Backup/restore:** BackupStore includes Notes/Todo/Habits/private records with
  validation and additive restore; HabitPlan details/history survive its existing
  backup test. Device-local widget consent is not restored as implicit permission.
  New fields must remain compatible with old payloads and metadata preservation.
- **Widgets:** Android manifest has Notes, Todo and Core providers. No Habits,
  Finance, Experience or Books provider was present at this audit checkpoint.
  Existing widgets expose explicit entry/actions, not an excuse to bypass locks.
- **Usability:** all new settings must use the43-locale catalog. Existing Habits
  has large action buttons, a constrained-width layout, retry/empty messages and
  Material calendar; polish should extend these rather than replace the data model.

Evidence paths: `lib/features/collections/collection_repository.dart`,
`lib/features/notes/*`, `lib/features/todo/*`, `lib/features/habits/*`,
`lib/features/finance/{ledger,finance_page}.dart`,
`lib/features/private_space/{record_store,space_page,book_reader}.dart`,
`lib/features/agent/{agent_hub,agent_command}.dart`,
`lib/features/backup/{backup_store,backup_codec}.dart`,
`lib/core/{private_database,app_lock,settings}.dart`,
`android/app/src/main/AndroidManifest.xml` and corresponding tests.

## Prioritized backlog (proposed, not completed)

1. **Gate: host stability and data safety.** Resolve unexplained runtime GC crashes
   before heavy validation; retain WIP, verify existing migrations/restore and
   compare encrypted DB hashes before/after each install-r.
2. **Finish To-Do basics:** verify custom timestamp through native picker → guarded
   SQLCipher reminder transaction → one replacement alarm → real firing, including
   cancel/past time/stale token/lock. Reuse the prepared ready-handshake fix.
3. **Optional Todo summary:** default OFF, meaningful overdue/today/important counts,
   red notification accent/overdue indicator, generic lock-screen version and easy
   disable. Refresh on committed data/settings and relevant day/deadline boundaries;
   no infinite FGS or minute polling. Android controls status-bar small-icon color:
   [Android notification design](https://developer.android.com/design/ui/mobile/guides/home-screen/notifications).
4. **Habits first product upgrade:** structured daily/weekly/custom weekday editor,
   maintain historical schedules/targets, calendar/streak/percentage, accessible
   one-tap progress, search/archive/empty states, per-habit opt-in reminders and
   a private-default Android widget. Keep encrypted JSON/legacy days and portable
   backup compatibility; add migration/restore/UI/RTL/theme/date-boundary tests.
5. **Next card order:** To-Do advanced recurrence/subtasks → Notes indexed search
   and editor/recovery polish → Finance account/reconciliation/reporting quality →
   Experience mood/history/recovery → Books reader/import/export/accessibility.
   Use reviewable migrations and tests; never bulk-rewrite all cards together.
6. **Core voice later:** extend offline command coverage only after card workflows
   and permissions are stable. Preserve real per-language STT/TTS availability.

Runtime audit, market comparison and the Habits upgrade are not completed. This
backlog is based on repository evidence and the user's product priorities.
