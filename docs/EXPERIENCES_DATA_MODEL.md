# Experiences

Experiences records stay in `private_records(kind='experience')` with existing IDs/revisions. Legacy title/body/feelings/lesson/next/category payloads remain valid and are not rewritten by read operations or the additive database migration.

New optional additions use `experienceVersion:1`: actual local-calendar `date`, reflection/experiment mode, active/completed/paused status, favorite, up to30 exact tags and a category ID. Experiment text fields are hypothesis/method/observations/evidence/result/conclusions. Each text field is capped at100,000 characters; the existing4MiB payload bound remains. Dates are strict real calendar dates. No generated result or personal sample is inserted.

The personal timeline queries thin columns in50-row pages, with Unicode FTS, exact tag/category/status/favorite and date filters. Only opening an entry loads its full payload. The calendar counts actual saved entries by local day. Summary chips count entries, manually completed entries, entries with lessons/conclusions, experiments and recorded days; these counts do not judge quality or fabricate learning progress. The12 practical templates have previews/instructions and open editable drafts, saving nothing until explicit Save.

## History and migration

Notes DB18 adds normalized `module_data`; Tasks remains13. It contains independently revisioned module/category/history/link rows. The upgrade starts history from each entry's actual current revision and leaves its original payload bytes and timestamps intact. Missing earlier edit history is explicitly unavailable.

Every experience write through RecordStore atomically preserves the current database state and appends the new state, with the existing revision compare-and-swap. A stale write rolls back both payload/history. Normalized history is not capped or overwritten. SQLite triggers reject update/deletion while the parent exists. Restoring a version creates a new entry revision and retains subsequent history. History indexes page30 thin rows and fetch only one full selected version. Explicit permanent parent deletion may remove owned history; this continuation did not perform any such operation on user data.

History covers entry content/metadata. Attachments use the existing separate encrypted vault/lifecycle and are not resurrected by restoring an old text snapshot. No original file is changed by history restore.

## Links and follow-up

A confirmed Follow-up task owns one stable action link per entry. A durable pending row contains the original task ID/title/body/due draft. Task insertion in the separate Tasks database is idempotent by that ID; interrupted retries keep the original draft, then acknowledge the link as ready. Reopening the action opens its existing task rather than discarding a new draft or creating a duplicate. Users may also attach existing Note/Book/Habit records after selecting a real matching target. Missing/deleted targets are explicitly unavailable; sources are retained.

Books-to-Experiences creation also records its initial snapshot inside the same transaction. Full-text search/read-only export includes actual experiment fields. Read-only Experiences routes provide content/history/export without mutation controls. UI writes check current trial/purchase access; no test fixture activates a purchase.

## Backup

Portable Notes content becomes16 when normalized module rows exist; otherwise prior13/14/15 selection is retained. Older supported backups remain importable. Validation rejects invalid/future row formats, invalid owners and duplicate history/action identities. Restore prefixes category IDs, entry/history ownership, linked targets and category IDs inside historical snapshots consistently, and retains import fingerprint idempotence. Older restored entries receive a truthful current-state history baseline. Derived FTS remains transactional.

Existing local BILGAB02/BILGAC02 encrypted streaming media framing is unchanged. Managed Experience attachment blobs continue through the existing media manifest. The existing14MiB/100,000-row portable metadata preflight rejects oversized metadata explicitly rather than silently truncating; original media is streamed separately.

## Guidance and evidence

The existing deterministic engine highlights real New experience → title → body → Save → saved results controls. Valid text enables Next; confirmed persistence advances the Save boundary. Cancel/failure/expired access never simulates success or adds a record. Back cannot replay a confirmed Save. Skip/Exit only end help. Guidance is local and non-AI.

Current evidence: six host data cases (`/tmp/bilga-experiences-data3.log`) and four actual host UI cases (`/tmp/bilga-experiences-ui4.log`) pass. Clean analyzer `/tmp/bilga-completion-analyze2.log`. Native `integration_test/experiences_review_test.dart` registers the same six data and three normal-viewport UI cases, guarded to debug Review only. Full current regression301tests PASS in375s (`/tmp/bilga-completion-full-host2.log`); native acceptance/current ordinary APK are still tracked in NON_VOICE_COMPLETION_ACTIVE_CHECKPOINT.md; no unexecuted native result is claimed here.
