# Books reader acceptance checkpoint — 2026-11-15

The scoped [reader directive](BOOKS_READER_DIRECTIVE_2026-11-15.md) is implemented and its engineering acceptance passes. The wider six-module Bilga product remains **IN PROGRESS**. Continue on `development/global-launch`, draft PR #1; no main merge, Google Play publication, paid activation or voice work occurred. No goal tool or subagents were used.

## Owner-usable artifact

- Ordinary default `lib/main.dart` APK: **`build/review/bilga-reader-review-app.apk`**, 217,902,184 bytes.
- SHA256 **`400d37d158e2615698afe6400e908ccb5f51ec35671dc258d8969092d3740bae`**.
- Source **8ff1d3afd1f1309ad16427a712edca2742b398cb**; application runtime matches **ff59d5bf12a9f080e2270fdb5f2e3f06b4a62c77**, subsequent changes are acceptance harness/evidence only.
- Package **`com.ilmmizan.bilga.review`**, label **Bilga Review**, debug only, no microphone permission. Existing Review signer preserved: `c3e5f6408f14cc0281d46f74f057fd31c548b4b6d3b80e18011d872306aeadd0`.
- Installed in place, launched successfully (**WARM 4663ms debug Activity**, not a release benchmark). Actual ordinary home → Kitoblar tap opens library with import/help/statistics/sample controls. No record was imported or changed during this ordinary-app smoke check.
- Kernel includes BookReadingPage/ReadingStore/library/guidance/Finance reports and excludes integration runners and reference images. The tablet is left running the ordinary Books library, not a test binary.
- Full identity/install/launch/preservation record: [ordinary APK evidence](evidence/books-reader-review-apk-2026-11-15.json).

## Verification

| Scope | Passing result | Evidence |
| --- | --- | --- |
| Final runtime hosted CI | **287 tests / 274s**, analyzer/format, backend, DST, 43 × 740 catalogs, non-voice/manifest guards, Android multi-ABI build and artifact verification | [CI43708926430](https://github.com/abdulAziz-Al-ILM/Bilga-Lokal/actions/runs/43708926430), [JSON](evidence/books-reader-final-ci-2026-11-15.json) |
| Expanded physical reader/data/library suite at c0d18e2 | **20 actual / 22 with hooks**, 369s | [JSON](evidence/books-reader-tablet-pass-2026-11-15.json) |
| Final current physical reader controls/UI | **6 actual / 8 with hooks**, 140s | [JSON](evidence/books-reader-final-ui-tablet-2026-11-15.json) |
| Actual Android SAF + rich encrypted recovery | **12 actual / 14 with hooks**, 285s | [JSON](evidence/books-reader-saf-pass-2026-11-15.json) |
| Real Review process restart + rich recovery | **12 actual / 14 with hooks**, 77s | [JSON](evidence/books-reader-process-restart-2026-11-15.json) |

Native counts overlap; these are separate suites, not one summed all-feature run. Latest final6UI covers text highlight/card/review, EPUB font/chapter/read-only behavior, duplicate decisions, real guides and 500-page native PDF page mode/search/page154/bookmark/landscape/reopen. Actual DocumentsUI sequence completes without operator intervention: cancel, managed PDF, managed EPUB, persistent external TXT, duplicate cancel, corrupt EPUB rejection. New PID9098, after explicitly stopping PID9097 and confirming no Review PID, reopens PDF154/bookmark and retains external TXT URI access. Only the test's scoped encrypted cache fixture/checkpoint was removed.

Earlier failed harness/parser/UI synchronization attempts remain documented in dated `evidence/books-reader-*attempt*.json`, SAF navigation evidence and Git history. They are not accepted as passing runs. No assertions were weakened. The last helper fix performs real scrolling to instantiate recycled slivers and confirms DocumentsUI dismissal instead of assuming a two-second delay. Review build/test locking uses `flock --close` so detached ADB processes cannot retain the build lock.

## Preservation and limits

Production **`com.ilmmizan.bilga`** was not installed, cleared, stopped, uninstalled or opened for data access. Its before/after package metadata is identical: UID11022, version1.4.0+9, first install2026-10-06 07:57:29, last update2026-10-23 20:00:52. No production databases were read. Four exact SHA-verified synthetic r2 Downloads documents, their empty folder and our temporary UI hierarchy were removed. Owner **`Bilga_references_qayta.zip`** remains untracked and preserved.

Current schema: Notes **17**, Tasks **13**, portable reading Notes content **15**. Preserve additive migrations/encryption and use current compatible APKs. PDF is fixed-layout (no OCR/DRM); image page mode requires scrolling mode for text search/selection. EPUB simplifies publisher CSS/fonts/multimedia; TXT supports strict UTF8 or BOM UTF16; HTML/FB2 are explicitly simplified, DOCX/RTF unsupported. Exact bounds/privacy/backup semantics: [BOOKS_OFFLINE_READER.md](BOOKS_OFFLINE_READER.md).

New reader copy has English/Uzbek/Russian drafts, English fallback elsewhere in 43 catalogs. Manual native-keyboard/TalkBack, release-mode performance, second-device recovery and native-speaker translation acceptance remain outside this scoped pass. Flutter logged a slider semantics transform warning during the passing final native UI run; manual accessibility is not certified. Ordinary secure-window privacy stayed enabled, so no ordinary screenshot is claimed. Optional cloud artifact upload was skipped; the verified APK is local, no hosted artifact download is claimed.

## Subsequent work

Review the ordinary APK with the owner. Continue the broader professional-product requirements recorded in [KNOWN_LIMITATIONS.md](KNOWN_LIMITATIONS.md) and [FEATURE_MATRIX.md](FEATURE_MATRIX.md): remaining advanced Habits/Finance/Experiences/Notes/Tasks workflows, shared help, localization/accessibility/release acceptance. This reader pass does not authorize publishing, purchases/hosting activation, voice or a main merge.

Pinned local environment: Flutter3.47.8/Dart3.13.7 under `.bilga-tools/flutter`, JDK21, AndroidSDK36/build-tools36 and NDK28.2.13676358. Run one expensive job at a time. `tool/test_host.sh` reuses NDK Clang; Review scripts guard package/signer and use `.bilga-tools/build.lock`. Authorized physical tablet: **Tab16NEU0045423**, Blackview Tab16, Android12/API31, arm64. USB already authorized; do not request it again unless actual connection evidence requires action.
