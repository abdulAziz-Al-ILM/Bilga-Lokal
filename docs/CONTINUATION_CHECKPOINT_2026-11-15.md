# Continuation checkpoint — 2026-11-15

The owner resumed through `PROFESSIONAL_PRODUCT_COMPLETION_2026-11-15.md` and asked to inspect `Bilga_references_qayta.zip`. This supersedes the historical Nov 11 pause. No automatic schedule or active Codex goal was created. Work remains on `development/global-launch`, draft PR #1; no merge, publication, paid activation or voice authorization.

## References and implemented increment

ZIP contained four text files. They are extracted into `references/`; all seven linked images were downloaded and visually inspected. Local gallery works offline. Attribution/official pattern verification is in `references/README.md`; raw third-party images are ignored by Git and not shipped. Preserve the original owner ZIP, which remains untracked.

Books metadata/status/shelves/search/filter/paging/editor/reader/export/backup foundation is now wired and verified. Preserve all earlier uncommitted Book work in this checkpoint. Data model is `BOOK_LIBRARY_DATA_MODEL.md`. No new schema or dependency: Notes 16, Tasks 13; portable Notes 13 normally/14 for Finance accounts, Tasks 11. Legacy chapters/history/bookmark remain intact; stable chapter/bookmark IDs are still required.

Habits has 22 independent editable template drafts, searchable category gallery, preview/cancel/customize and explicit Save. The reusable deterministic engine under `lib/features/guidance/` now powers the real six-step Habit creation journey with live anchors, real route navigation, text readiness/Next, Save success event, irreversible-save boundary, Back/Skip/Exit, safe local versioned progress/resume, responsive/dark/RTL and missing-target fallback. Shared form hooks and eager field anchors preserve draft/validation/private IME behavior. Fresh Core authorization is checked before Habit writes. Other module tours/shared searchable Help Hub are not implemented yet. See `GUIDANCE_SYSTEM.md` and `INTERACTION_MATRIX.md`.

## Verification

Full host suite: **268 PASS**, 127s, `/tmp/bilga-guidance-full-tests-2.log`. Final app runtime source has not changed since that pass; later changes are test helpers/report metadata only. Four supplementary Book UI cases pass in 46s (`/tmp/bilga-books-ui-refocus-tests.log`). Analyzer/format clean, 43×568 catalogs, nine manifest guards and no-voice guard pass. Current native/API31 results and failed attempts are preserved in `docs/evidence/books-guidance-*` and `book-editor-*`.

Focused Book-editor target passes **3 scenarios / 5 with hooks in 160s**, `/tmp/bilga-book-editor-tablet-tests-2.log`; APK `build/review/bilga-book-editor-tests-v2.apk`, SHA256 `25bb843596ac36068ed223ea1817b62dfc600c3585f3499c5c3127bbf321917a`. This includes correcting an invalid ISBN, save/open/filter/search, failed-save legacy preservation and delayed-filter/query race.

Earlier combined target passed **13/14 scenarios**, 16 runner cases with hooks, 251s; its single Book failure is fixed by the focused run, not by weakening validation. Its passing cases include startup/all ten routes/14 themes/Arabic RTL, six encrypted Book data/backup fixtures, three Habit creation/template/retry/skip UI cases and screenshots. **No new single all-pass combined run or native rotation/manual keyboard acceptance is asserted.** Runtime product source is identical across those runs; only fixture input/reporting changed.

Important test helper correction: Flutter's live binding retains `focusedEditable` after native unfocus, so `showKeyboard`/`enterText` on the identical field can skip reopening its client. Host input clear resets that cache. `book_library_ui_cases.dart` now taps the actual EditableText before fixture input, and asserts text before/after blur. Waiting alone and direct platform-state synchronization did not fix it; these failed attempts remain documented. Do not reintroduce the focus-cache problem or claim manual native keyboard acceptance from injected test text.

Four actual native screenshots (only encrypted temporary DEMO fixtures, no owner data) are under `docs/evidence/screenshots/2026-11-15/`; capture briefly clears only the synthetic Review window's secure flag and restores it in finally, without changing persistent settings. Raw reference screenshots are different and not committed.

## Artifact and source handoff

The ordinary owner-usable Books/guidance Review APK is the next handoff action after preserving the tested source commit. Build default `lib/main.dart` with `tool/build_tablet_review.sh --target-platform android-arm64`, verify kernel includes BookLibraryStore/GuideController but no integration runners, then use `tool/check_tablet_review_install.py <authorized-device> <apk> --install` and launch Review only. Record actual source commit/hash/install/launch evidence; never hand off a test APK as the ordinary app. Artifact evidence appended below takes precedence once produced.

Stable local Review signer remains `c3e5f6408f14cc0281d46f74f057fd31c548b4b6d3b80e18011d872306aeadd0`; use existing ignored `.bilga-tools/review-signing/debug.keystore`. Production `com.ilmmizan.bilga` is preserved. USB was already approved. Use one expensive Flutter/Gradle/device test at a time with `.bilga-tools/build.lock`; never edit a running Bash build/test script. No emulator is needed.

Finance reports source e520971 has green CI 43064321644 and the previously installed ordinary Finance report APK; its pending evidence files are included now. Standalone 13 Notes widget/46 task native checks belong to source 6270268, not a new run. Current checkpoint CI must be verified separately after push.

## Next product work

Continue Habits professional dashboard/search/custom categories, correct advanced schedules and historical target/statistics semantics, reminders/export/backup, and extend the reusable help system. Then Finance categories/hierarchies/budgets/goals/recurrence/debt deadlines/reminders/onboarding, Experiences template-driven timeline/calendar/history/tags/favorites/follow-up, Books covers/reading sessions/statistics/typed knowledge cards/flashcards/review scheduling. Complete other five module tours/shared Help Hub, durable cross-module links and full interaction/localization/accessibility/performance acceptance. New en/uz/ru text is draft; other catalogs use English fallback. No complete-product or release-ready claim is justified.
