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

## Failures found and corrected

1. System SQLite on this tablet omits JSON1. Android plaintext opens now use the bundled SQLCipher engine with no password, retaining normal plaintext SQLite format and the required SQL feature set.
2. Backup injection was treated as evidence of plaintext storage. The restore attachment now chooses an explicit key from cipher capability and the actual target header, supporting encrypted fixtures and plaintext legacy files.
3. SQLCipher export left the attached FTS virtual-table schema stale on the original connection. Verification now reopens the staged encrypted file and checks integrity/every table count before changing the plaintext file. Failed validation leaves the original untouched.
4. The first-open trial Navigator borrowed the root HeroController. This caused a real blank Notes screen after onboarding. A failing host regression reproduced the exact MaterialApp.builder layout; the gate now uses HeroControllerScope.none and root navigation passes.

The first native run failed 16 scenarios; the second failed one; the third passed its 19 scenarios. The expanded journey then exposed route/theme animation timing assumptions in the test harness; it now waits for settlement and rejects missed touch targets. The final expanded suite passes all 21 scenarios. Failed runs are retained locally and are not reported as successes.

## Remaining acceptance

A separate `am start -W` cold Activity measurement was **5930 ms** for a debug review build. This is not release startup performance or proof of the under-two-second product target. A low-RAM/many-record Android benchmark is still required.

Biometric/device-credential unlock, standalone app PIN (not implemented), full form creation/editing for every module, journal/history/calendar/categories, attachment/media restore/export, second-device/Drive backup, real Play purchases, offline refund/revocation transitions and release-signing compatibility remain unverified or unfinished. Native locale coverage here is Arabic plus the ordinary Uzbek/English flows; 43-language rendering remains host evidence. The full interaction/accessibility audit is incomplete.

The ordinary current review APK will be rebuilt from this source checkpoint after commit and installed through the guarded in-place path. Its final hash belongs in this report when available. This is a development build; the owner review gate remains after completion of all required non-voice features.
