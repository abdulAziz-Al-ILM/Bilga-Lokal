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
