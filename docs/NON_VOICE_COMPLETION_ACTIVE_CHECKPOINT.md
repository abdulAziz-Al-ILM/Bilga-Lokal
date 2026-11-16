# Active non-voice completion checkpoint — 2026-11-16

Implementation remains active; the requested whole-product completion is NOT achieved. Branch development/global-launch, draft PR1, starting a8a353c. No main merge, Play publication, voice/microphone, paid deployment, original-production data operations or subagents. User ZIP `Bilga_references_qayta.zip` is preserved untracked.

## Last pushed and owner-installed source

`2cb48a627df02d47774a67e2e68e380111369909`, after6d04577. Experiences timeline/calendar/12templates/structured experiments/custom categories/tags/favorites/history/restore/attachments/follow-up Tasks/links/search/actual summaries/real guided create are implemented. Original Notes/Tasks/Books remain. Notes capability18, Tasks13, portable Experience content16. See EXPERIENCES_DATA_MODEL.md.

Host301 PASS375s at6d; final whitespace-only change has4UI PASS41s, then final2cb native9actual/11withhooks PASS172s (`/tmp/bilga-experiences-tablet2.log`). GitHub CI43863555340 at2cb SUCCESS:301 Flutter,17 backend and9 manifest tests, clean analyzer,43×826 catalogs, both DST runtimes and Android debug build/manifest verification. Raw CI `/tmp/bilga-experiences-ci-43863555340.log`; evidence `evidence/experiences-ci-2026-11-16.json`.

Ordinary default-main owner APK `build/review/bilga-experiences-review-app.apk`, SHA256 `36c02559f9f4d53a06704986cb43c7a86dc70cb7a52581e0afc4e5b326033a0c`,217902184bytes, is signer-compatible and installed in-place. Actual home carousel→Tajribalar smoke passed; production package metadata unchanged. Evidence `evidence/experiences-review-apk-2026-11-16.json`. This APK contains NO subsequent advanced Habits work.

## Current working implementation: advanced Habits

HabitPlan v2 supports weekday/interval/weekly/monthly schedules, start/end/pauses, dated historical targets plus legacy fallback, categories/tags/favorites, completed-day goals/date and opt-in reminder minute. Configuration retains actual check-ins and prior schedule rules transactionally. Basic editing preserves advanced metadata. Main tracker search/filters and quota-aware due/streak/progress displays; Planner uses shared due policy. Existing22 templates retained. Advanced settings and real statistics/calendar/history editor have actual-control guides; no future-day editing or invented progress.

Notes capability19 (non-destructive version protection); advanced-Habit portable content17 with strict downgrade-header rejection and exact metadata/history restore. Never reinstall an18-capable APK after owner Notes19 database opens. SQLCipher/streaming encrypted media framing remains unchanged.

Android module reminders: separately encrypted atomic no-backup mirror; opted-in live Habit schedule policy and up to400 valid recent completion dates only, no personal text/amount/database keys. Real AlarmManager/non-exported receiver/generic private notifications, boot/unlock/timezone/time/exact-permission rescheduling, quota/pause suppression and persisted delivery claims. Visible permissions/restrictions/retry; navigation stays behind AppLock/access and validates actual existing source. Confirmed Habit changes/restores refresh cached policy. Pure Java leap/interval/20-year-pause/partial-period/quota/DST policy passes.

Native synthetic instrumentation snapshots/restores only Review's encrypted module mirror and a reserved synthetic Habit policy, with no personal records. `tool/test_module_reminders_review.py` validates manifest/signers, proves absent Review process before the real alarm time, uses `am kill` (never production/force-stop), and restores the original mirror in finally.

## Latest verification

- `/tmp/bilga-completion-full-host3.log`: **311/311 PASS412s**. New advanced data4, UI3 and reminder policy3 included. Whole runtime source was stable. The subsequently added extra reminder opt-in UI case was NOT included in that discovery/run.
- `/tmp/bilga-habit-reminder-ui7.log`: additional real time-picker→explicit Save→disable1/1 PASS12s. The test is now included in the current shared native target.
- `/tmp/bilga-habit-reminder-focused6.log`:16 focused PASS32s.
- `/tmp/bilga-completion-analyze8.log`: No issues found3.9s.
-43×886 catalogs, non-voice and9 manifest guards PASS. EN/UZ/RU additions; remaining languages have English fallback, no native-speaker acceptance claim.
- `integration_test/habits_advanced_review_test.dart`:4secure data+3existing normal Habit guide cases+3new normal advanced UI cases (10actual), Review-only guard. Native build1 failed a Kotlin multi-variable declaration; corrected. Build2 PASS38.5s (`/tmp/bilga-habits-native-build2.log`). Preserved `build/review/bilga-habits-advanced-tests.apk`, SHA2560afab7a394df31c0ada10dc71274f9ec93d1b0c591f492b743ff520a1e720a3d. Companion instrumentation build PASS32s, manifest/Review signer verified, preserved `build/review/bilga-habits-native-companion.apk` (evidence has SHA). First request timed out in automatic approval before process creation; explicit Review-only retry approved.254 Dart files format-clean; no current native Habit/real alarm/ordinary19 execution acceptance yet.
- **ADB currently has no device** despite persistent prior authorization. Async request sent to reconnect/unlock; continue host work, do not ask for USB permission again.

## Exact next work

1. Finish current native-target build; fix any real Kotlin/Java/compiler defect. Preserve the testAPK under a unique filename/hash. Build Review instrumentation companion under the same build lock/JDK/SDK/review signer.
2. When Tab16NEU0045423 returns, run10actual secure Habit/native UI cases, real process-death alarm test, restore original mirror, fix defects. Production package `com.ilmmizan.bilga` must never be installed/cleared/stopped/read for data. Only Review/test packages may be changed.
3. Build ordinary default-main Notes19 Review APK, validate manifest/signer/kernel, install in place, smoke, compare production metadata. Do not leave a test binary as owner deliverable. Commit/push coherent tested progress and update existing draft PR1 and engineering status/known-limits.
4. Continue Finance hierarchy/budgets/goals/recurring/debt deadlines/reminders/planning/templates/real guide. Draft ONLY `/tmp/bilga_finance_planning.dart` and `/tmp/bilga_finance_planning_page.dart` (not in repo/imported/analyzed/tested; review carefully before applying). Preserve verified accounts/transfers/history/reports; exact integer money; recurring intentions require explicit actual posting; goals should reflect real selected account balances. Future Finance metadata needs a new capability/portable schema guard.
5. Implement searchable Help Hub and ensure all6 module purpose/templates/start/real-control guide/progress. Finish cross-links/shared search/backup/reminders/offline/localization/accessibility/responsiveness/trial40days/lifetime architecture/migrations/action audit. Run appropriate host/native regressions, final ordinary Review APK, evidence and PR updates. Do not claim whole product complete early.

## Environment and limits

Pinned Flutter3.47.8/Dart3.13.7, JDK21.0.13+9/SDK36/NDK28.2 under `.bilga-tools`; one expensive task at a time via `.bilga-tools/build.lock`. Host `bash tool/test_host.sh`; build/test `tool/build_tablet_review.sh`/`test_tablet_review.sh`; all preserve original production identity. Native widget/task tests use `tool/test_native_review.py`. Physical Blackview Tab16/API31 serialTab16NEU0045423 previously authorized. Existing signer SHA256 `c3e5f6408f14cc0281d46f74f057fd31c548b4b6d3b80e18011d872306aeadd0`. SQLite host cases use existing `initializeTestSqlite`, no machine installation.

Manual TalkBack/keyboard, release performance, reboot/Doze/second-device delivery and final payment-service/live Play acceptance remain unverified; no fabricated results. Current owner APK cold debug launch5831ms is a launch observation, not release performance.
