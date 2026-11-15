> Historical pause: the owner resumed work with the professional-completion directive on 2026-11-15. See `CONTINUATION_CHECKPOINT_2026-11-15.md` for current state.

# Resume checkpoint — owner paused work on 2026-11-11

The owner explicitly said to stop here and continue tomorrow. Do not start further development or testing until the owner resumes. No automatic schedule was created.

## Published development checkpoint

Branch: `development/global-launch`. Latest committed/pushed source: `e5209713743253a368eb9088462c6c5571716f61`. Draft PR #1 remains open and unmerged. Finance accounts, transfers/reconciliation, transaction corrections/history, and reports are committed. History CI 43059176688 succeeded at 121d876; report CI 43064321644 succeeded at e520971, with actual test/build/manifest/artifact steps verified.

Latest ordinary, usable Review APK: `build/review/bilga-finance-reports-review-app.apk`. SHA-256: `2cd17f7ad849d5e6f2cc36a073f93ad0e2e3d1af6ea9b7a6053873e502650432`. Installed in place and launched on the authorized Blackview Tab16/API31 in the separate `com.ilmmizan.bilga.review` package. Original production `com.ilmmizan.bilga` was not updated, cleared, uninstalled or used for fixtures. Debug cold Activity launch: 5273 ms; not a release benchmark. Metadata: `docs/evidence/finance-reports-review-apk-2026-11-11.json` (currently uncommitted).

Finance reports checkpoint evidence: 241 full host tests, 51 physical scenarios / 57 runner cases in 429 seconds. Standalone native 13 Notes widget + 46 task instrumentation results belong to earlier account source 6270268; Android native source has not changed since.

## Current uncommitted Books work

All changes remain saved in the working tree; Books is NOT committed or pushed yet. Preserve this working tree.

New `lib/features/books/` files: `book_library.dart`, `book_library_store.dart`, `book_details_editor.dart`, `book_library_page.dart`. Implements optional `libraryVersion: 1` metadata, author/description/genre/publication/ISBN/language, reading status/dates/pages, ratings/favorites/categories/tags/shelves, thin 50-row pagination, FTS search, filters/sorting and guarded editor writes. Legacy metadata reads preserve existing chapters/history/bookmark and retain unknown status/dates. ISBN-10/13 checksum/prefix rules use official ISBN agency references; no catalogue lookup or book-content download occurs. Fullwidth numbers/ISBN, Unicode dashes, Arabic/Chinese label delimiters and description whitespace are supported.

Existing source changes: optional RecordStore/AgentAccess injection in SpacePage/RecordPage, fresh Core write checks, Books wrapper route, metadata readable export, Book source validation/preview in search, owner-filtered attachment queries and optional attachment RecordStore forwarding. Metadata is a compatible JSON extension; Notes DB remains 16, Tasks DB 13, backup content versions unchanged. Do not install an older review APK over current data.

Tests added: `test/book_library_model_test.dart`, `test/book_library_data_test.dart`, `test/book_library_ui_test.dart`, reusable cases under `test/support/book_library_*`, plus a read-only Book source test. Six model + six database cases pass; four UI cases pass (create/ISBN/filter/search, failed-save retry, delayed-initial-load search/filter race, compact 2x RTL/dark + expired-access draft retry). The FINAL full suite passes **258 tests** in **117 seconds**: `/tmp/bilga-books-full-tests-1.log`. Analyzer clean: `/tmp/bilga-books-analyze-final.log`; 43 catalogs × 488 keys, nine manifest guards and no-voice checks pass. Current additions have English and Uzbek/Russian drafts; other catalogs use English fallback.

Books integration setup is prepared but NOT YET BUILT OR RUN on the tablet: `integration_test/book_library_cases.dart`, `integration_test/books_review_test.dart`. The focused target registers the real app startup/navigation/theme/RTL journey plus six encrypted data cases and three non-compact UI cases (expected 10 scenarios; confirm actual runner count after execution). The full `tablet_review_test.dart` also registers Book cases.

`tool/test_tablet_review.sh` now accepts an optional third target argument, defaulting to the existing full tablet target. It still enforces Review package/signature/prebuilt binary and --keep-app-running. Syntax check passes; a traversal target was rejected before device access (`/tmp/bilga-review-target-negative.log`). Positive custom-target execution still needs verification. Do not edit a running Bash build/test script.

## First work after explicit resume

1. Reinspect working tree and any running processes; preserve current changes. Full host suite already passed; avoid rerunning unchanged tests unnecessarily.
2. Build focused Book test APK with `bash tool/build_tablet_review.sh --target-platform android-arm64 --target integration_test/books_review_test.dart`, then copy the verified APK to a clearly named test artifact.
3. Run `bash tool/test_tablet_review.sh Tab16NEU0045423 <test-apk> integration_test/books_review_test.dart` using existing authorization. This serial is local-only; keep it out of public evidence. Fix any real issues and record exact scope/results.
4. Complete current Book evidence/status docs, commit/push tested Books, update draft PR, and build/install an ordinary owner-usable Review APK. Keep test runners separate from ordinary APKs.
5. Continue the remaining product work. Books still needs cover images, typed knowledge cards, stable chapter/bookmark references, reading sessions/statistics, flashcard scheduling and knowledge links/conversions. Finance still needs category trees/budgets/goals/recurrence/debt deadlines/reminders/savings progress. Other six-module and shared acceptance gaps remain in FEATURE_MATRIX.md and KNOWN_LIMITATIONS.md. Do not claim the full product complete.

One expensive Flutter/Gradle/device test at a time using `.bilga-tools/build.lock`. SDKs/cache/keystore remain ignored under `.bilga-tools`. Use existing review signing key; never replace production signing. No main merge, publication, paid activation, real bank actions or voice work is authorized by this checkpoint. Voice stays gated by explicit owner approval after non-voice completion.

Official ISBN references checked during this work: https://www.isbn-international.org/index.php/node/10 (ISBN-13 prefix and alternating weights); https://www.isbn.org/faqs_general_questions (legacy ISBN-10 weighted modulus-11 and X). The validator checks format/checksum, not assignment or title ownership.
