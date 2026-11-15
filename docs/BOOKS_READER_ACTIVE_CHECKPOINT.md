> **CI confirmed:** runtime source c0d18e2 passes the complete GitHub validation run **43703600208** (host tests, backend, analyzer, DST, Android multi-ABI debug build and APK verification). Cloud artifact upload is intentionally optional/skipped; no hosted APK is claimed. Current extra changes are test/recovery evidence only.

> **Updated acceptance:** at runtime source **c0d18e2**, the entire expanded physical-tablet target passes **20/20 actual scenarios, 22/22 including hooks, in 369s**. Artifact `build/review/bilga-reader-acceptance-tests-v2.apk`, SHA256 `113e59dece931ba41321835e0ae458d27a8c93ac6cadf0050ff3bee7a67b68a4`. Log `/tmp/bilga-reader-tablet-acceptance2.log`; JSON `evidence/books-reader-tablet-pass-2026-11-15.json`. This supersedes the failed first attempt below. Actual SAF and ordinary APK remain pending.
>
> Test follow-up now expands encrypted recovery to settings, bookmarks, highlights, annotations, question cards and immutable review snapshots together; host **11/11 PASS**, `/tmp/bilga-reader-rich-backup-host2.log`. The SAF target has two phases: first actual picker tests and real page154/bookmark preparation, then a second launch recognizes only its scoped checkpoint, reruns encrypted recovery and reopens page154 after a real process restart. Use folder **BilgaReviewReader-20261115-r2**, already pushed to Downloads; r1 is older generated data. `tool/run_reading_saf_review.py` runs the same target for both phases. After phase A passes, explicitly stop only `com.ilmmizan.bilga.review`, verify its PID is gone, then run the same target again. Phase B deletes only its verified temporary fixture/checkpoint. Preserve test APKs separately and finish by installing the ordinary default-main Review APK.

# Active Books reader acceptance checkpoint

This is continuing work, **not a pause or a completion claim**. Follow the owner's [reader directive](BOOKS_READER_DIRECTIVE_2026-11-15.md). No goal tool was created. Remain on `development/global-launch`, draft PR #1. Do not touch production `com.ilmmizan.bilga`, merge, publish, enable paid services or voice.

## Preserved source and verification

- Reader implementation commit **eeeb9670fa71fc12533fb267053b9c9741398a61** is pushed. PR title/body now describe the actual reader and explicitly pending tablet/ordinary APK work.
- Full serial host suite **285 PASS in 307s**, `/tmp/bilga-reader-full-host2.log`. Analyzer `/tmp/bilga-reader-analyze-final2.log` clean. Format 225 files, 43 × 737 catalog keys, nine manifest guards and no-voice guard pass. Only braces followed that full run before eeeb967.
- New follow-up (after eeeb967): real navigation guidance spotlights working chapter/page controls instead of an indicator; waits for actual navigation and a committed location; confirmed-write tutorial boundaries prevent replay; flashcard Back restores its real flip button. Added bookmark-cancel/save and navigation guidance tests. Text UI fixture selects a hit-testable paragraph, handles actual toolbar overflow and waits for native keyboard/viewport settling.
- Focused current follow-up host run **6 PASS in 55s**, `/tmp/bilga-reader-guided-ui2.log` (five text/guidance cases plus native PDF viewer). A braces-only fix followed. Current analyzer rerun is `/tmp/bilga-reader-analyze-followup2.log`.
- Device is connected/approved: **Tab16NEU0045423**, Blackview Tab16, Android 12/API31, arm64. User reconnected it and replied `ulandi`; do not ask USB approval again.
- Production metadata baseline only: `build/review/evidence/production-before-reader.json`: UID11022, v1.4.0+9, last update `2026-10-23 20:00:52`. Production databases/files were not read or changed. Verify identical metadata after all tests.

## First actual tablet run

Build at eeeb967 took **58.3s**. Test APK `build/review/bilga-reader-acceptance-tests.apk`, SHA256 **8a398b527d6b8695efdfa2df04f6a62e4a78245a04180d003c46e9f39555469a**. This is an integration-test binary, **not the ordinary owner APK**.

`/tmp/bilga-reader-tablet-acceptance1.log`: **14/15 actual scenarios pass**, 16 pass / 1 fail including hooks, 127s. All 11 encrypted temporary parser/data/backup/link/migration cases pass. EPUB typography/chapter/read-only UI and duplicate decisions pass. The real PDF viewer/page154/bookmark/search/reopen and real landscape activity orientation pass. TXT UI stops at a missing Highlights toolbar finder after selecting the first cached paragraph. No native success is claimed for the later card/review steps in that failed case. Evidence JSON: `evidence/books-reader-tablet-attempt1-2026-11-15.json`.

Repeat the actual tablet run with the follow-up; do not weaken persistence assertions. The updated native target also registers the three existing shared Book metadata UI cases, to exercise status/shelf/search with this reader source.

## Next actions

1. Confirm clean analyzer; commit/push the follow-up source so its APK identity is exact.
2. Build `bash tool/build_tablet_review.sh --target-platform android-arm64 --target integration_test/reading_review_test.dart`; copy output to a distinct `build/review/bilga-reader-acceptance-tests-v2.apk` before the next build overwrites it. Run `bash tool/test_tablet_review.sh Tab16NEU0045423 APK integration_test/reading_review_test.dart`. One expensive process at a time via `.bilga-tools/build.lock`. Preserve the existing Review signer.
3. Build/run **actual SAF** target `integration_test/reading_saf_review_test.dart`, paired with `python3 tool/run_reading_saf_review.py Tab16NEU0045423 APK BilgaReviewReader-20261115-r1`. It selects only generated test files in DocumentsUI, no picker/permission mock. Fixtures already exist in `/tmp/BilgaReviewReader-20261115-r1` and were pushed to `/sdcard/Download/BilgaReviewReader-20261115-r1`. Contents: original PDF, EPUB, TXT and corrupt EPUB. Do not delete any other Downloads content. Host automation may need adjustment for actual DocumentsUI navigation. Test covers picker cancel, PDF/EPUB, persistent TXT reference, duplicate cancel, corrupt rejection.
4. Fix actual failures, rerun affected checks, then build the **ordinary default `lib/main.dart`** Review APK (no `--target integration_test/...`). Verify package/label/debug/no microphone, signer and kernel includes reader but excludes test runners. Install in place with `python3 tool/check_tablet_review_install.py Tab16NEU0045423 APK --install`, launch Review only, verify actual identity/launch. Never leave the owner with only a test APK.
5. Record native evidence, ordinary APK source/SHA/size/identity, production before/after equality and honest limitations. Update handoff, commit/push evidence and final draft PR description. Remove only exact synthetic Downloads fixture folder after tests.
6. CI for eeeb967 is **43702367274**, last seen in progress. Earlier correction CI **43688930874** at91408f0 is successful but does not verify the reader. Keep cloud APK upload optional due artifact quota; do not delete owner artifacts or change billing.

## Environment

Pinned Flutter `.bilga-tools/flutter/bin/flutter` 3.47.8; Dart3.13.7; `PUB_CACHE=$PWD/.bilga-tools/pub-cache`; JDK21 under `.bilga-tools/java/jdk-*`; Android SDK `.bilga-tools/android`, NDK28.2.13676358. `bash tool/test_host.sh` provides serial locking and existing NDK Clang for native PDF assets. Host tests need sandbox escalation for the local test service. Review signer SHA256 **c3e5f6408f14cc0281d46f74f057fd31c548b4b6d3b80e18011d872306aeadd0**. No production key replacement, app clear or uninstall.

Notes device schema **17**, Tasks **13**, portable reading schema **15**. Never install an older database-16 binary after database17 opens. Source files, bookmarks, settings, cards, history and reading links are normalized; original managed files/cover/index use existing encrypted vault. Full vs metadata-only backups are explicit. See `BOOKS_OFFLINE_READER.md` for exact format/performance limitations.

Original owner ZIP `Bilga_references_qayta.zip` remains untracked and must be preserved. All other current changes belong to this reader work. No subagents were used or authorized. Keep concise Uzbek updates during ongoing work.
