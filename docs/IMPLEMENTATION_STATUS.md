## Purchase verifier implementation — 2026-11-10

Added `backend/purchase_verifier`: receipt RSA verification, fixed-host authenticated Google Play lookup/acknowledgment, cancellation-only signed revocations, exact Ed25519 client grants, bounded WSGI endpoint, persistent hashed token ledger and explicit non-overwriting key-generation tooling. No credentials were read, no production key was generated and no service was deployed. The README distinguishes anonymous restore/replay limitations, cached offline grants and required external setup.

Validation: 17 Python tests PASS in an isolated environment; dependency integrity check PASS. All 15 focused Dart verifier tests PASS, including a public fixture issued by the actual Python verifier. Static analysis has no issues. Combined full Flutter suite: **165 PASS** in 46 seconds, including the added fixture test. All seven production/review manifest gates PASS. A later audit found legacy reminder TTS still reachable; its settings and native speech path are now removed, with a first-party no-voice CI gate. Native recompilation/acceptance is pending; the earlier blanket no-TTS statement was too broad. Native tablet test harness is prepared with review-package storage guards; actual test execution is still pending the cold Android build.

# 2026-11-10 continuation checkpoint

Branch remains `development/global-launch`; draft PR #1 remains the review target. The new owner instruction is saved in NON_VOICE_OWNER_REVIEW_BRIEF.md. Stage A (complete non-voice implementation and verification) precedes Stage B (owner review). Voice and Play publication still require separate explicit approval.

Rich-text Notes are implemented with headings, bold/italic/underline/strikethrough, lists/checklists, links, undo/redo, existing autosave/attachments/tags/history and a read-only rich reader. Notes schema 15 adds nullable rich_body to notes/history; plain body remains searchable and compatible. Portable backup content schema 13 preserves formatting; old backup formats are still accepted. A narrowly patched MIT-licensed flutter_quill 11.6.0 is vendored to preserve disabled keyboard suggestions/autocorrect/IME learning. See vendor/flutter_quill/BILGA_PATCH.md.

Current host evidence: **164 full Flutter tests PASS**, analyzer no issues; all 43 catalogs have 336 keys. New cases cover formatting-only history, restoration and backup, invalid deltas/unsafe links, Notes 14 migration, no-op legacy opening, actual TextInput privacy flags, and large-font editing above the keyboard. Review APK compilation is running locally; no new APK/device feature pass is claimed yet.

The connected Blackview Tab 16 is USB-authorized, Android 12/API 31, arm64, 1200×2000. Existing production Bilga is version 1.4.0+9, target 36, debuggable, with certificate SHA-256 38ecfe0234e465924812ba3ee84ef838557a1d03d53713bd7a6d76478663bd6d (confirmed by apksigner). It has not been installed over, uninstalled, reset, launched for automation or had databases read. Test key differs. An explicitly opted-in debug-only `com.ilmmizan.bilga.review` build is being prepared, labeled Bilga Review, with a separate UID/storage/Keystore and stable local test key. The normal production ID is unchanged. No review installation existed when inspected.

Local toolchains now live in ignored `.bilga-tools/` so reboot no longer loses them: pinned Flutter 3.47.8/Dart 3.13.7, Temurin 21.0.13+9, Android SDK 36/build-tools 36.0.0/NDK 28.2. The USB tool must run with host/loopback access. The review build command is `bash tool/build_tablet_review.sh`; it verifies debug label, package isolation, signature and absence of microphone permission before any separate install action.

Next exact step: finish the current review APK build, verify its actual manifest and signer, install only the isolated review package after checking it remains absent or signature-compatible, then execute synthetic-data UI/integration journeys on the actual tablet. Continue other required modules and verifier backend while native builds run. The overall product remains IN PROGRESS; the historical checkpoint below is not a completion claim.

---

# Implementation status

Checkpoint date: 2026-11-09 (Asia/Tashkent)
Branch: `development/global-launch`
Starting commit: `8871b3ac007ab05402949b3eacd4327340c6913c`
Overall: **IN PROGRESS**, not release ready.

The owner supplied `FINAL_PRODUCT_SPEC.md`. Do not resume the superseded voice/per-feature-sales strategy from old root documents.

Completed source work in this checkpoint:

- Inspected all four GitHub repositories and primary branches/history; recovered missing backup source and newer WIP functionality (see SOURCE_RECOVERY.md).
- Retained package ID, DB filenames, existing encrypted storage and signing configuration. Recovered Notes DB 13 and Tasks DB 8; added non-destructive search migrations to Notes 14 / Tasks 9.
- Preserved 43 locales and seven palettes; added draft translations for new UI in seven priority languages, with English fallback text in the other 36 catalogs.
- Removed reachable voice/STT/TTS functionality and microphone permission; assistant is explicitly local, read-only text lookup.
- Added unified local FTS4 search with transactional source triggers, pagination, archive and type filters, source details, attachment export and note-history viewing.
- Added an explicit read/export route after trial expiry; existing editing routes remain covered by the access gate and AppLock.
- Added Today and next-seven-days views from original task/habit records, quick creation, and trial/purchase status in settings.
- Upgraded official billing packages to Play Billing 9.1.0 because the recovered Billing 7.1.1 is past its submission deadline; added a merged-manifest CI gate.
- Standardized the new sale product to `bilga_lifetime_unlock`, retaining legacy verified purchase compatibility. New purchases still require the recovered secure-verifier configuration.

Current verification: Flutter analyze PASS (no issues), full Flutter suite 158 PASS (64s), formatting PASS (125 files), 43 × 324 catalog structure PASS. Test failures and fixes are recorded in TEST_REPORT.md. Source checkpoint `61035a238141a89e478d0190e08f71939f3d6c6e` was pushed and its remote SHA verified. Draft PR: https://github.com/abdulAziz-Al-ILM/Bilga-Lokal/pull/1 . Validated/pushed source `f2bb128ed4d4d6adef20fc28a7595de5d00fee2a`. Hosted CI **42668103911 SUCCESS**: 158 tests, analyzer, debug APK, ZIP/v2 signature and merged-manifest checks pass. Artifact link and hash are in RELEASE_READINESS.md. Final documentation commits do not change application source. Local Android builds are blocked by absent Android SDK/Java; a hosted debug APK is available; no signed release APK/AAB is claimed.

Remaining required implementation includes rich-text editing, task recurrence/subtasks/projects/custom templates, standalone and habit/note reminder workflows, richer journal history/calendar/categories, cross-module relationships, backup media streaming to Drive and the complete interaction/accessibility/performance audit. See FEATURE_MATRIX.md and KNOWN_LIMITATIONS.md.

External configuration: Play product/license key/verification service credentials, OAuth client setup, existing release signing credentials, Android SDK/device access and store acceptance. Never publish, activate regional prices, replace signing keys or merge main without approval.

Next exact step: continue the unimplemented master-spec features, starting with occurrence-safe task recurrence and durable cross-module links, with complete UI, backup remapping, migrations and tests. Hosted debug build verification for this checkpoint is complete; release/device/purchase acceptance is still pending. Do not repeat the already passing suite unless code changes or new failures justify it. Continue remaining modules without replacing working persistence.
