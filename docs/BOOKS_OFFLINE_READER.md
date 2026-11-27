# Offline Books reader

The current owner request is [the reader transformation directive](BOOKS_READER_DIRECTIVE_2026-11-15.md). It supersedes the earlier catalog-first implementation order. Development remains on `development/global-launch`, draft PR #1. No production package, release signing key, Play publication, paid service or deferred voice feature is authorized by this work.

## User experience

Books opens with Import, an explicitly offered original sample, currently reading, covers, progress and Continue. Import validates a device file and opens the integrated reader without a metadata form. Grid/list, search, status/favorites, recently opened/added and optional shelves/tags/categories remain available. Manual records and bibliographic fields live under advanced organization/details. Legacy chapters, versions and the old chapter bookmark are preserved.

Android import uses `ACTION_OPEN_DOCUMENT`, without broad-storage permissions. A managed encrypted copy is the default. Advanced organization also offers a persistent external reference. A SHA-256 duplicate dialog explicitly offers existing/another/cancel. Unavailable files can be relinked only with matching original content; progress and annotations stay attached to the original book. Read-only access can temporarily open a verified original without changing saved data or retaining a new grant.

## Compatibility and limits

| Format | Implemented behavior | Limits |
| --- | --- | --- |
| PDF | Native PDFium pages, lazy bounded rendering, scroll and page mode, pinch/pan, page jump, thumbnails, embedded-text search/selection, bookmarks, page notes, permitted text highlights | Unencrypted documents only, at most 1 GiB and 1,000,000 pages. Scanned/textless pages render; no OCR. Page mode uses an image viewport; return to scrolling for text search and selection. |
| EPUB | Spine chapters, EPUB 3 navigation / NCX when available, local images, selectable reflowed text, typography, themes, search, highlights and paragraph locators | No DRM, scripts, remote resources, publisher CSS, embedded fonts or audio/video. Complex publisher layouts are simplified. Archives compressed/expanded at most 256 MiB, 5,000 entries, 16 MiB per entry; index at most 2 MiB. |
| TXT | Strict UTF-8, UTF-8 BOM or UTF-16 LE/BE BOM, selectable text, search, typography, paragraph locations | At most 16 MiB. Unknown encodings are rejected instead of guessing. |
| HTML / FB2 | Explicitly disclosed simplified text import | Text only; original layout/interactive content/images are not preserved. |
| DOCX / RTF | Explicit unsupported-format message | No extension-only or fabricated support. |

EPUB filenames, actual signatures, encryption metadata, archive paths, entry counts/sizes, symlinks and CRC are checked. Central headers are bounded before the archive decoder can decompress symlinks. PDF copy restrictions are respected. No copyrighted book downloads, metadata requests, trackers or DRM circumvention were added.

## Data and privacy

- Device Notes database **17**, Tasks **13**. Additive migration introduces `book_reading`; existing Notes, Finance, Habits, Books and chapter history are not rewritten.
- Each source, location, settings, mark, card, review, session and cross-module link is a small independently revisioned row. Source/progress/settings and source/action links have unique indexes. Stale writes fail instead of overwriting newer data.
- Original managed files, covers and chapter indexes use the existing authenticated streaming attachment vault, `BILGAC02`; no new production key or encryption scheme. Internal derivatives are hidden from ordinary attachment lists and cannot be independently removed.
- Native rendering needs a temporary plaintext file inside private app cache. Reader close deletes it; the existing startup cleanup clears stale private previews after interruption. Permanent managed originals stay encrypted. No book content is uploaded.
- Frequent progress writes use a short debounce and flush on background/close. PDF stores page plus approximate scroll/zoom. Text stores section path, paragraph block and offset; reopening places the paragraph in view. Font changes do not reinterpret visual page numbers. File hashes prevent relinking a different edition onto old locations.
- Reading time is a foreground estimate. A monotonic clock excludes paused/background/other-screen activity, two-minute inactivity and long blocked-event-loop intervals. Local-midnight buckets retain the reading day's date, rather than grouping UTC timestamps as local days. Completion is explicit.

## Learning tools

Bookmarks, colored highlights and location notes are separate from originals. Cards support idea, quote, definition, explanation, question/answer, lesson, summary, comparison, observation and actionable insight; card editing preserves scheduling. Required question answers prevent empty flashcards.

Reviews use bounded Leitner intervals of 1, 2, 4, 7, 14, 30 and 60 calendar days. Again resets, Hard retains the box, Good advances one and Easy advances two. Each confirmed rating atomically updates the card and appends an immutable question/answer/history snapshot. Overdue cards remain due; queues load up to 100 at a time. Reading notes/cards use paged Unicode-aware local full-text search. JSON export streams rows without a 5,000-row truncation.

Reading Note, Chapter Summary, Book Review, Study Card and Reading Goal templates are previewed before opening editable drafts. Nothing is created until Save. Deterministic help highlights actual import/read, appearance, bookmark, selection, card and review controls and advances write-dependent steps only after success. Library guidance also covers continuing and shelves. Help uses the existing offline guide architecture, not AI.

Cards/highlights/notes can explicitly create Notes, Tasks/planning commitments, the existing 15-minute reading Habit template or an Experience. Each source/action has one stable link. Same-database writes are atomic; Tasks uses a durable pending link with a stable target ID so retry after interruption cannot create a second task. Supported backup restore prefixes targets and source IDs consistently.

## Backup

Portable Notes content schema **15** includes normalized reading rows; older compatible backups remain readable. Restore validates ownership, row versions, singleton duplication and managed-media manifests before writing. Derived search indexes rebuild through transactional triggers. Snapshot preflight bounds metadata before loading large tables.

Local export offers **metadata and reading data only**, or **full encrypted backup with managed files**. Full `BILGAB02` backup streams source/cover/index blobs through the existing encrypted format. Metadata-only restore needs original files relinked. External references always require their original provider/file; the choice dialog explains this and estimated managed-file size. Original files are never silently omitted from an option claiming to include managed files.

## Verification and continuation

Tests use original generated PDF/EPUB/TXT documents and separate encrypted fixture vaults. They do not read or reset owner databases. The guarded device runners refuse to start outside debug `com.ilmmizan.bilga.review`.

- `bash tool/test_host.sh`: pinned Flutter and serial execution; reuses the installed NDK Clang when host Clang is absent.
- `integration_test/reading_review_test.dart`: shared import/parser/backup/migration/link tests, actual text UI journey, native PDF and real activity orientation request.
- `integration_test/reading_saf_review_test.dart`: actual Android picker cancellation, PDF/EPUB import, persistent TXT reference, duplicate cancellation and corrupt rejection. The paired `tool/run_reading_saf_review.py` selects only generated documents in a uniquely named Downloads fixture folder.
- `tool/prepare_reading_review_fixtures.py`: creates only original synthetic files; never reads owner content.

The current runtime source **ff59d5b** passes GitHub validation **43708926430**: **287 host tests in 274 seconds**, clean analyzer/format, backend protocol and DST checks, **43 × 740** catalogs, non-voice/manifest guards, Android multi-ABI build and artifact verification. Optional cloud artifact upload was skipped; no hosted download is claimed. [CI evidence](evidence/books-reader-final-ci-2026-11-15.json).

Physical Blackview Tab16/API31, isolated Review only:

| Acceptance | Result | Evidence |
| --- | --- | --- |
| Expanded reader/data/library suite at c0d18e2 | 20 actual scenarios / 22 including hooks PASS, 369s | [Expanded tablet suite](evidence/books-reader-tablet-pass-2026-11-15.json) |
| Final runtime controls, real text selection/card/review, EPUB typography, guides, PDF page mode/search/500 pages/rotation/reopen | 6 actual / 8 including hooks PASS, 140s | [Final UI](evidence/books-reader-final-ui-tablet-2026-11-15.json) |
| Real Android SAF cancel, managed PDF/EPUB, persistent external TXT, duplicate cancel, corrupt rejection, page154/bookmark preparation, rich encrypted recovery | 12 actual / 14 including hooks PASS, 285s; no operator intervention | [Actual SAF](evidence/books-reader-saf-pass-2026-11-15.json) |
| Explicit Review process death, new PID, managed PDF page154/bookmark and persisted external TXT access | 12 actual / 14 including hooks PASS, 77s | [Process restart](evidence/books-reader-process-restart-2026-11-15.json) |

The latter native runs use test source **8ff1d3a**; application runtime is unchanged from ff59d5b. Counts overlap and must not be added into a claimed single all-feature suite. Fixtures use Flutter input injection with actual controls; manual native-keyboard/TalkBack acceptance, release-mode performance and second-device restore are not certified. Android logged a Flutter slider semantics transform warning during an otherwise passing UI run; full manual accessibility remains a separate acceptance item. Earlier failed harness attempts are preserved in the dated evidence and superseded only by the complete passes above.

The ordinary default-main Review APK and production preservation record are recorded in [the active checkpoint](BOOKS_READER_ACTIVE_CHECKPOINT.md). The broader six-module product remains in progress; these results complete the scoped reader engineering acceptance, not global commercial-release acceptance.

## Primary references

Public reading workflows: [ReadEra](https://readera.org/), [Moon+ Reader FAQ](https://www.moondownload.com/faq.html), [Librera](https://librera.mobi/), [Play Books file import](https://support.google.com/googleplay/answer/11012086?hl=en). These informed progressive disclosure and reading workflows; no proprietary design or assets were copied.

Implementation APIs: [pdfrx](https://pub.dev/packages/pdfrx), [pdfrx repository](https://github.com/espresso3389/pdfrx), [archive](https://pub.dev/packages/archive), [xml](https://pub.dev/packages/xml), [html](https://pub.dev/packages/html), [scrollable_positioned_list](https://pub.dev/packages/scrollable_positioned_list). Versions are locked. Archive 4.5.2 was selected after native compilation exposed image 4.11.0's incompatible use of an API absent in archive 4.3.0; no unrelated dependency sweep was performed.
