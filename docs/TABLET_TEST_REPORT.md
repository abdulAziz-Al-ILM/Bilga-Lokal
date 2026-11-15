## Book library and deterministic Habit guidance — 2026-11-15

**The full six-module product remains IN PROGRESS.** The owner's new professional-completion directive and ZIP references were inspected. The ZIP contained four text files and seven externally linked images; all seven images were downloaded and visually reviewed. Research attribution and useful patterns are preserved in `references/README.md`; third-party images remain local/ignored and are not shipped in Bilga.

Book library now has optional versioned author/publication/ISBN/status/dates/pages/rating/favorite metadata, custom shelves/tags/categories, bounded thin pagination, FTS search/filter/sort, guarded editing, complete source reading/export and compatible idempotent backup. Legacy reads do not rewrite or invent metadata and metadata edits preserve chapters/history/bookmark. See `BOOK_LIBRARY_DATA_MODEL.md`.

Habits now has a searchable 22-template category gallery with preview/cancel and a prefilled real editor. Only explicit Save creates a habit; the catalogue contains no completions or personal records. A reusable local deterministic tutorial engine highlights actual keyed widgets, allows real target interactions, gates actions on success, supports Back/Next/Skip/Exit and stores only version/step/active state. The first six-step Habit journey opens the real form and explains the actual dashboard after successful persistence. Text entry stays highlighted until the user confirms Next. Failed/expired saves retain drafts and remain at the save step; Back never replays a confirmed save. Missing anchors fall back to unobstructed help. See `GUIDANCE_SYSTEM.md` and `INTERACTION_MATRIX.md`.

**268 full Flutter tests PASS in 127 seconds**, analyzer clean, format clean (201 files), **43 × 568** catalog keys, nine manifest guards and non-voice guard PASS. Supplemental Book UI verification passes all four cases after adding actual-field refocusing, exact synthetic field checks and bounded navigation waiting. Host coverage includes route-wide 360px/2× RTL/dark guidance, real spotlight hit tests/rotation/fallback, explicit resume/version errors, preview no-write, safe save retry, Book validation/legacy preservation/search/filter race/rollback/backup and read-only content. `docs/evidence/books-guidance-host-2026-11-15.json` records the scope.

The focused Book-editor suite now passes **3 physical scenarios / 5 including hooks in 160 seconds**, including invalid ISBN → correction → real save/reopen/filter/search and both other UI regressions. An earlier combined run passed **13 of 14 scenarios** (16 runner cases including hooks, 251 seconds): real startup/all ten routes/14 palettes/Arabic RTL, six encrypted Book database/backup fixtures, three Habit template/guide/retry/skip journeys and four actual synthetic screenshots. Its one failed Book case was a retained-focus-cache problem in the live test helper; explicitly tapping the real EditableText before injected input fixes it. Four supplemental host UI cases pass too. Product validation was not weakened. The runtime app source did not change between those scoped runs. **The combined target was not rerun as an all-pass suite after this fixture fix**; evidence preserves that distinction in `docs/evidence/books-guidance-tablet-2026-11-15.json` and dated failed attempts. Manual native-keyboard and native rotation acceptance are not asserted by this focused work.

Schema remains Notes **16**, Tasks **13**; portable Notes content remains 13 normally/14 with Finance accounts and Tasks content 11. No new dependency or backup framing is introduced. Finance report CI **43064321644 succeeded** at e520971, and its ordinary APK was installed/started before this continuation; newly saved evidence files describe that earlier artifact precisely. Current checkpoint's CI and ordinary APK are separate.

Remaining scope is substantial: other five modules' tours/shared searchable Help Hub; advanced Habits schedules/categories/reminders/statistics; Finance categories/budgets/goals/recurrence/debt deadlines/reminders; Experiences templates/timeline/calendar/history/tags/favorites/follow-up; Books covers/sessions/statistics/cards/review scheduling; durable cross-module links and full localization/accessibility/performance acceptance. English/Uzbek/Russian new copy is draft, other catalogs currently use English fallback. No main merge, publication, paid activation or voice work occurred. Original production installation/data/signing remain preserved.

Earlier checkpoint evidence follows.

---

# USB tablet verification — November 10, 2026

**Stage A remains IN PROGRESS.** These are real Android development tests with synthetic data, not final owner approval or a production-signing upgrade test.

## Environment and preservation

Blackview Tab16 (Tab_16 / Tab16_NEU), Android 12/API31, arm64, display 1200×2000. USB authorization was explicitly approved by the owner. The hardware serial is intentionally kept in local command history rather than this report.

Existing production package: `com.ilmmizan.bilga`, version 1.4.0+9, min API26, target API36. Its APK and signing metadata were inspected read-only; no installed database or user document was read. Signer SHA-256: `38ecfe0234e465924812ba3ee84ef838557a1d03d53713bd7a6d76478663bd6d`. No update, downgrade, uninstall, clear-data, factory reset, production key replacement or production fixture execution occurred.

Tests used `com.ilmmizan.bilga.review`, label **Bilga Review**, with separate Android UID/private storage/Keystore. Review certificate SHA-256: `c3e5f6408f14cc0281d46f74f057fd31c548b4b6d3b80e18011d872306aeadd0`. This local debug-only key does not replace any production key. The production identity and signing configuration remain defaults. The review build is blocked from release tasks and checked for a debug flag, explicit label and absence of microphone permission. Target API36 / Billing9.1 were verified from its merged binary manifest.

The review installer cryptographically verifies the APK, rejects production identity and compares any installed review certificate before an in-place upgrade. A negative test with an invalid device serial rejected a production APK before attempting ADB. The first two Flutter driver runs automatically removed only their synthetic review installation during cleanup; the runner now uses `--keep-app-running` and preserves subsequent review data. Temporary fixture databases are confined to unique review-cache directories. The notification fixture removes only its own unique task ID and restores reminder settings.

## Results

The final device suite passed **21 scenario cases**, reported as **27 including six setup/teardown hooks**, in **101 seconds**. Sanitized machine evidence: [tablet-2026-11-10.json](evidence/tablet-2026-11-10.json). The local full console log is `/tmp/bilga-tablet-tests-7.log`; it contains only synthetic review test diagnostics, not owner content. The integration APK hash is recorded in the JSON evidence. It runs tests on launch and must not be handed off as the ordinary application.

| Scope | Actual device result |
| --- | --- |
| Trial/startup | Production Dart entry point launched in review; trial introduction and acknowledgment exercised; active trial enables modules |
| Notes migrations | Synthetic Notes v1–v10 row-preserving upgrades on Android; current plaintext database including FTS converts to encrypted storage and reopens |
| Tasks migration | Synthetic Tasks v1 upgrade, folders and cycle/deletion checks |
| SQLCipher/Keystore | Encrypted quantitative habit persists across close/reopen; secure-delete enabled; encrypted files lack plaintext SQLite header |
| Atomicity/recovery | Failed edit rolls back history/content; folder/trash batches preserve independent deletions; cross-database restore rolls back and repeated imports do not duplicate |
| Rich editor | Real editor title input, body/controller editing, toolbar bold, autosave/save, encrypted reopen, plain-text search projection, encrypted backup and merge retain style/text |
| Rotation | Android Activity requested landscape then portrait while editing; real physical viewport dimensions changed; text/style remained intact without overflow |
| Tasks/habits/search | Synthetic task creation/completion and habit entries persist; native FTS finds note/task/habit sources |
| Navigation | Notes, Tasks, Habits, text assistant, Finance, Journal, Books, Today, Search and Settings open and return through the app Navigator |
| Themes/locales | All seven palettes in light and dark (14 variants) render; Arabic changes layout direction to RTL; original review settings restored |
| Notifications | Actual quiet notification posted by Android; snooze cancels it, updates SQL and delivers again; notification-owned immutable PendingIntent completes encrypted SQL task and removes reminder/notification |

The notification test ran with exact-alarm access granted, notifications enabled, device unlocked/awake and app foreground. It temporarily disabled sound, overlay and title disclosure only for review. A probe requires both the exact review package and Android's debug flag; it can inspect/dispatch only a uniquely tagged synthetic notification belonging to that app. The completion action was sent through the real OS PendingIntent, not by directly writing `is_done`. A manual drawer tap, sound audibility, locked-device actions, permission-denied cases, Doze, reboot/update and timezone changes remain unverified. No exact-delivery guarantee follows from this result.

## Recurrence extension and native instrumentation

The later recurrence suite passes **22 scenario cases**, **28 runner cases including hooks**, in **147 seconds** (`/tmp/bilga-recurrence-tablet-tests-2.log`). Its first new build failed at compilation because the test omitted the sqflite extension import; no installation occurred in that failed build. After the import fix, all scenarios pass. Test APK SHA-256: `9be8d0536e3cb392507d69a695acbb6d3415d86f929d6cd345d6229a69863b96`. Sanitized evidence: [recurrence-tablet-2026-11-10.json](evidence/recurrence-tablet-2026-11-10.json).

The new scenario starts a synthetic daily series and completes the first real notification PendingIntent. It verifies the completed row, one successor/head, sequence history, privacy metadata and absent inherited widget consent. Without publishing through Dart after completion, the successor's Android reminder arrives. Fixture cleanup removes only that test's series/tasks and restores quiet/title settings. This runs with the app foreground; process death, Doze and reboot remain separate acceptance work.

Separate review-only native instrumentation passes **13 Notes widget checks** (encrypted cache, readback, tamper/ID binding, intents, metadata, permission epoch, clearing) and **46 task checks** (calendar/reminder claims, native SQLCipher transactions, stale actions, privacy/lease gates, intents and widget metadata). Fixture files use reserved unbound IDs or unique cache directories. Merged test-manifest targets and installed signatures are checked before installation; original production is never an instrumentation target. Initial harness checks rejected Android's absent-package exit code and then its non-raw result formatting; adding `-r` exposes the checked RESULT_OK code. Final raw logs: `/tmp/bilga-native-review-tests-3.log`; both suites return `INSTRUMENTATION_CODE: -1`.

## Subtask extension

The latest run passes **29 scenario cases**, **35 including hooks**, in **173 seconds** (`/tmp/bilga-checklist-tablet-tests-2.log`). Six new encrypted SQLCipher fixture cases verify Tasks 10→11 upgrade without task/series rewrites; failed-edit rollback and cross-task isolation; transactional search/trash behavior; old-progress retention and future-default reset; independent duplication/privacy; and backup ordering/progress/idempotence plus invalid-reference rejection. A real UI journey creates two subtasks, marks one complete, reorders, saves, reads 1/2 progress, then duplicates through the task menu and sees an independent unchecked 0/2 copy. Native notification completion also creates unchecked successor subtasks while preserving the completed checklist. Sanitized proof and APK hash: [checklist-tablet-2026-11-10.json](evidence/checklist-tablet-2026-11-10.json).

Native instrumentation was rerun against this checklist-capable review app: **13 Notes widget checks and 46 task checks PASS**, both return raw RESULT_OK (`/tmp/bilga-checklist-native-tests.log`).

The first expanded run passed the previous 22 scenarios but the seven new cases failed before fixture writes: Directory.createTemp was called on a nonexistent parent. The corrected helper creates unique directories directly inside the guarded review cache. Only that corrected run is counted as a 29-case pass. Subtasks use one-level titles/completion; independent subtask dates/reminders are not implemented.

## November 11 custom-template extension

USB device was reidentified as the authorized Blackview Tab16/API31; both original production and isolated review packages were present. Only the signed review package was upgraded. The suite passes **36 scenario cases**, **42 including hooks**, in **222 seconds** (`/tmp/bilga-templates-tablet-tests-1.log`). Six encrypted SQLCipher cases verify Tasks 11→12 preservation, independent repeated use, stale edit/delete rejection, atomic failure/invalid ancestry, payload validation and idempotent portable backup. The UI journey creates a template, cancels preview without writing tasks, applies it, saves the created task, snapshots it, edits future defaults and deletes a template while preserving existing tasks. Evidence/hash: [task-templates-tablet-2026-11-11.json](evidence/task-templates-tablet-2026-11-11.json).

Native instrumentation was rerun against the template-capable review app: **13 Notes widget and 46 task checks PASS**, both raw RESULT_OK (`/tmp/bilga-templates-native-tests.log`).

The first host UI harness attempted pumpAndSettle while real FFI loading still needed event-loop time and timed out; its settling helper now pumps real I/O before waiting for route animations. The corrected host tests and physical journey pass. A separate host test covers small viewport, 2× text, RTL and explicit draft discard; this does not certify a physical phone. Resource monitoring used one expensive process at a time, a build lock, capped Gradle workers and no persistent Gradle daemon.

## Failures found and corrected

1. System SQLite on this tablet omits JSON1. Android plaintext opens now use the bundled SQLCipher engine with no password, retaining normal plaintext SQLite format and the required SQL feature set.
2. Backup injection was treated as evidence of plaintext storage. The restore attachment now chooses an explicit key from cipher capability and the actual target header, supporting encrypted fixtures and plaintext legacy files.
3. SQLCipher export left the attached FTS virtual-table schema stale on the original connection. Verification now reopens the staged encrypted file and checks integrity/every table count before changing the plaintext file. Failed validation leaves the original untouched.
4. The first-open trial Navigator borrowed the root HeroController. This caused a real blank Notes screen after onboarding. A failing host regression reproduced the exact MaterialApp.builder layout; the gate now uses HeroControllerScope.none and root navigation passes.

The first native run failed 16 scenarios; the second failed one; the third passed its 19 scenarios. The expanded journey then exposed route/theme animation timing assumptions in the test harness; it now waits for settlement and rejects missed touch targets. The final expanded suite passes all 21 scenarios. Failed runs are retained locally and are not reported as successes.

## Remaining acceptance

A separate `am start -W` cold Activity measurement was **5930 ms** for a debug review build. This is not release startup performance or proof of the under-two-second product target. A low-RAM/many-record Android benchmark is still required.

Biometric/device-credential unlock, standalone app PIN (not implemented), full form creation/editing for every module, journal/history/calendar/categories, attachment/media restore/export, second-device/Drive backup, real Play purchases, offline refund/revocation transitions and release-signing compatibility remain unverified or unfinished. Native locale coverage here is Arabic plus the ordinary Uzbek/English flows; 43-language rendering remains host evidence. The full interaction/accessibility audit is incomplete.

Ordinary review APK: `build/review/bilga-review-app.apk`, source `a0d7463010e416eb8f5f171fac5b83ed39355592`, 217,901,916 bytes. SHA-256: `c28efded33e933f94cc1c2961ef7e8c267b80637e12584576b753c28b76a29b6`. It was installed as a signature-compatible in-place review upgrade. Machine metadata: [review-apk-2026-11-10.json](evidence/review-apk-2026-11-10.json).

Additional ordinary-app checks used only a synthetic note named “Review native keyboard”: created through the Notes menu, entered title/body using Android input events without the clipboard, applied bold from the toolbar, verified autosave, sent the app to background with Android Home and brought the same task back, saved, searched for “keyboard” and reopened the complete source. Text remained intact. The fixture remains only in the isolated review app. This verifies native input and a real foreground/background cycle; it does not certify process-kill recovery or every keyboard/OEM. This is a development build; the owner review gate remains after completion of all required non-voice features.

## November 11 project attempt — failed UI acceptance

The project integration APK built and passed identity/signature/no-microphone gates. On Tab16/API31, 41 of 43 scenario cases passed, 47 passed / two failed including hooks, in 213 seconds. All six encrypted project cases pass: schema preservation, nested progress/hidden data, stale edits/conversion, rollback/validation, search/trash and backup ownership. The custom-template and project UI journeys failed when controls disappeared after typing and programmatic scrolling with an active IME. Source now unfocuses before test scrolling, uses a stable status key and dismisses editor keyboards on drag/save. Analyzer is clean, but the repeat is pending; default sandbox testing failed at loopback binding before tests started. Evidence: [projects-tablet-attempt-2026-11-11.json](evidence/projects-tablet-attempt-2026-11-11.json). Automatic approval review hit a usage limit, blocking further escalated commands; this is not an unsafe-action determination.

## Corrected November 11 project suite — PASS

After the approval service resumed, the four corrected template/project host UI tests passed, then all 208 full Flutter tests and analysis passed. The rebuilt isolated review APK passes **43 scenarios**, **49 including hooks**, in **274 seconds** (`/tmp/bilga-projects-tablet-tests-2.log`). Both earlier IME failures are absent: focus is cleared before test scrolling, status uses a stable control key, and editor keyboards dismiss on drag/save. All six encrypted project fixture cases and the complete real nested-project UI journey pass. Evidence/hash: [projects-tablet-2026-11-11.json](evidence/projects-tablet-2026-11-11.json). The failed attempt above remains historical evidence, not an active blocker.

The template CI job's exact setup error was also retrieved: apt DNS resolution of azure.archive.ubuntu.com failed, exit 100, before application tests. Bounded apt retries and explicit index-refresh failure are added for the next CI run. No production data was read or modified by these tests.

## November 11 Finance account extension

The signed, isolated review suite passes **48 scenario cases**, **54 including hooks**, in **354 seconds** (`/tmp/bilga-finance-tablet-tests-1.log`). Test APK SHA-256: `8a5d6b271ada3e98795164f50f7d2ab69cd99ed8602100f8e4611328dc7a5db6`. Evidence: [finance-accounts-tablet-2026-11-11.json](evidence/finance-accounts-tablet-2026-11-11.json).

Four new SQLCipher fixture cases verify unchanged Notes 15→16 legacy rows, all-or-nothing transfer saves under stale revisions and simulated SQL failure, currency/account/reconciliation backup preservation with invalid-import rejection/idempotence, and explicit downgrade rejection without row loss. The new form journey enters Finance through its main page, creates a bank record/opening balance, transfers from the legacy cash account, reconciles with a reason, reads observation history, renames, archives/restores, then records an expense against the chosen account. It asserts exact integer balances and report exclusions. All operations are synthetic local records, not bank transactions. Form tests inject a synthetic entitlement; live purchase acceptance is not implied.

All earlier navigation/theme/RTL, rich editor/rotation, notification/recurrence, checklist/template/project cases pass in the same run. Original production Bilga is not updated or used for fixtures. Notes is now version **16** and Tasks remains **13**; do not install older unguarded review APKs over this data. Compact 2× text/RTL and failed-save recovery are host evidence, not physical-phone acceptance. CSV bytes/escaping are host tested; real SAF export gestures and complete Finance/Books acceptance remain required.

Native instrumentation against the Finance-capable review app also passes **13 Notes widget and 46 task checks**, both raw `INSTRUMENTATION_CODE: -1` (`/tmp/bilga-finance-native-tests.log`).

## November 11 transaction history extension

The review suite passes **50 scenario cases**, **56 including hooks**, in **391 seconds** (`/tmp/bilga-finance-history-tablet-tests-1.log`). APK SHA-256: `3a6de680d4951fa47933257441bd12068a004244fc3ac37f0cd58f73798a3d5e`. Evidence: [finance-history-tablet-2026-11-11.json](evidence/finance-history-tablet-2026-11-11.json).

The new SQLCipher fixture proves a simulated failed update and a stale revision cannot write the new amount or its history separately; a later restore retains both previous states. Portable backup now explicitly checks transaction snapshots and rejects unsupported history versions before merge writes. The real main Finance → transaction → edit/account selector journey changes an expense, opens its complete prior state, restores only that transaction, voids it and restores it, asserting exact balances and unchanged unrelated income. Existing 48 scenarios pass in the same run. Synthetic entitlements remain confined to form tests, not real billing acceptance.

Compact 2× text/RTL access-expiry draft recovery, malformed/recursive history rejection and read-only history are host evidence. Native Android source is unchanged in this extension; the separately recorded 13 widget/46 task instrumentation result belongs to account source 6270268, while native notification completion/recurrence are exercised again by this full physical suite. No new standalone native-instrumentation run is claimed here. Production Bilga is preserved.

## November 11 financial-report extension

The complete review suite passes **51 scenario cases**, **57 including hooks**, in **429 seconds** (`/tmp/bilga-finance-reports-tablet-tests-1.log`). Test APK SHA-256: `abc6aac59cbb67353a9a9f592e012cf63b0655c22f4830e743f182db489cd12d`. Evidence: [finance-reports-tablet-2026-11-11.json](evidence/finance-reports-tablet-2026-11-11.json).

The real Finance route opens reports from an encrypted synthetic ledger, excludes future/voided expenses from the selected period, switches to twelve months, changes grouping, selects a chart point and refreshes after an explicitly simulated external fixture edit. The refresh itself does not change the record revision or payload. All prior 50 scenarios pass in the same run. Compact 2× text/RTL/dark large-money rendering, exact large arithmetic/calendar edges and expired-trial library report access are host evidence. No new standalone native-instrumentation result is claimed; native Android source is unchanged. No schema or dependency change was introduced. Production remains untouched.

Ordinary owner-usable Review APK at **9528234** is built, signer-checked, installed in place and launched successfully (COLD, 5295 ms debug Activity; not a release benchmark). Artifact: `build/review/bilga-books-guidance-review-app.apk`, SHA-256 `d524a0bb28fb60561fbb38cd67c055ed679a1c44901a8572788187c27025737d`. Its kernel contains Books/guidance/Finance reports and excludes integration runners and research images. Metadata: `docs/evidence/books-guidance-review-apk-2026-11-15.json`. Production is preserved. Current hosted CI remains pending until push.
