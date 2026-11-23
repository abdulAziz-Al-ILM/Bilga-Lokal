## Voice review takes priority — 2026-11-23

The owner put Google Play publication on hold pending the voice review. No bundle was uploaded. The local release packaging attempt remains incomplete. The last attempt stopped at an uncached AndroidX Collection dependency. Future publication still requires purchase verification, Console checks and final listing declarations.

Source `e6106dc` accepts spoken repeat, pause, stop, confirmation and cancellation in Uzbek, English and Russian. A recognized command gets one bounded confirmation turn. The preview remains usable after silence or an unrecognized reply, and actual writes still use the module's normal save or confirmation controls. The assistant remembers the recognizer choice by language. Using system recognition still requires consent for a new conversation. Next-day plan answers use the local calendar date and actual scheduled records. [PR #1](https://github.com/abdulAziz-Al-ILM/Bilga-Lokal/pull/1).

The `f6b0a5e` follow-up verifies the three independent language preferences and uses test-scoped recognizer preferences in the tablet fixture. Full hosted validation passed for `e6106dc`. All 361 Flutter cases passed locally at `5055055`, as did Dart analysis, the 43 catalogs and the foreground voice safeguards. The signed ARM64 owner build is `build/review/bilga-review-voice-controls-keyboard-2026-11-23.apk`, SHA-256 `e76f92654aa49cd98096cdf431ae3ad17eca749b560839d3146ff392375b510f`. [Successful earlier hosted validation](https://github.com/abdulAziz-Al-ILM/Bilga-Lokal/actions/runs/45234754084).

The `f6b0a5e` tablet retry passed ten voice scenarios in 6 minutes 12 seconds, using encrypted fixtures and simulated speech. In `65421ea`, the screen-control panel listens once for confirmation after finding a single target. One later tablet case found a layout overflow when using the keyboard. The compact regression reproduces a 20-pixel overflow at `65421ea` and passes at `5055055`, which sizes the panel from its available height. The manual preview stays usable after the confirmation turn ends.

The `5055055` tablet run passed 11 of 12 scenarios, including spoken confirmation of a real screen control. The repeat-dictation check could not find the confirmation button after the second text entry on Android. A focused rerun exposed an ambiguous test finder for the panel scrollable. The picker was narrowed to the panel's first scrollable. The owner paused work before the next focused run could finish. The saved follow-up gives the panel a stable test key and supports running `integration_test/voice_review_test.dart` with `BILGA_REVIEW_SCREEN_ONLY=true` for the two screen-control cases. [Hosted validation for the tested APK source](https://github.com/abdulAziz-Al-ILM/Bilga-Lokal/actions/runs/45242113923).

The pinned Navoiy and CosyVoice2 components passed their SHA-256 checks. The first assembled tokenizer failed its check. Verified replacement ranges reproduced the publisher's hash. Vox 0.19.5 synthesized the new sentence “Ertaga soat to‘qqizda kutubxonaga borasiz” with the publisher's reference setup. The first chunk took 18.573 seconds on the host with ten flow steps and 11.237 seconds with six. The prepared mobile model occupies 932.7 MiB. The Tab 16 produced a valid 3.20-second, 24 kHz waveform on CPU with a first chunk at 100.708 seconds. Its Mali-G57 Vulkan run produced no waveform during the configured timeout. The ARM FP16 and dot-product build reached the first chunk in 94.038 seconds with ten steps and 64.114 seconds with six. The recorded six-step output is `build/review/navoiy-tablet-fast-6-23nov.wav`. The temporary models and executables were removed from the tablet after verification. Live playback in Review uses the existing synthesizer while Navoiy response time is addressed. [Navoiy publisher source](https://huggingface.co/aisha-org/navoiy-tts/tree/9445f41).

---

## Play preparation — 2026-11-23

Bilga's app dashboard is present in the signed-in Play Console. The existing upload keystore and Google Drive client configuration were recovered locally. The Play Console's upload certificate, highest version code, production eligibility and listing declarations still need verification. The owner authorized release preparation and submission when the build is ready.

The `14876c3` Review build adds spoken text entry phrasing for English and Russian and common screen-navigation phrases. The signed ARM64 artifact is `build/review/bilga-review-voice-2026-11-23.apk` with SHA-256 `388b1e86fbd02c18f23e50f8904b0380f5d2935960a953df277c6f0341681802`. It installed in place on the review package and launched cold in 1.740 seconds on the Tab 16. Native checks passed 13 Notes widget cases, 46 Tasks cases and discovery of the Android speech providers. Nine voice integration scenarios passed in 5 minutes 47 seconds on isolated encrypted fixtures with simulated speech input. The ordinary Review APK was restored with the same verified digest. Production package installation metadata matched across both suites.

Local validation passed 18 scoped Flutter cases, the updated spoken dictation case, analysis of changed Dart files, 13 manifest checks, 43 language catalogs, 17 verifier tests and eight billing preflight fixtures. Hosted run `45228120446` reached 355 passes and one EPUB test failure. The corrected fixture verifies a real change to reader appearance, waits for it to be saved, and checks the persisted revision. The focused test passed locally at `bef8968`. The Play build preflight checks for the public Play licensing key and the public configuration for the HTTPS verifier. The current environment has no production billing configuration. An actual new purchase, restore and expiry recovery remain unverified. The updated privacy policy and store description are drafts. [PR #1](https://github.com/abdulAziz-Al-ILM/Bilga-Lokal/pull/1) · [Hosted validation](https://github.com/abdulAziz-Al-ILM/Bilga-Lokal/actions/runs/45228120446).

The owner approved the Navoiy publisher sample in Review. Live Uzbek replies still use the existing synthesizer. The pinned Navoiy and CosyVoice2 components are being downloaded for conversion and measurement on the tablet. Model quality, latency and the delivery size for end users remain open. [Navoiy source](https://huggingface.co/aisha-org/navoiy-tts/tree/9445f41).

---

## Active non-voice completion — 2026-11-16

**Whole product remains IN PROGRESS.** Latest pushed/owner-installed source2cb48a6 adds professional Experiences (timeline/calendar/12templates/structured experiments/history/custom categories/tags/favorites/links/actual summaries/real guide). Its physical9actual/11withhooks suite passes172s; ordinary APK `build/review/bilga-experiences-review-app.apk` SHA25636c02559f9f4d53a06704986cb43c7a86dc70cb7a52581e0afc4e5b326033a0c is installed in-place. Hosted CI43863555340 succeeds with301 Flutter+17backend+9manifest tests, clean analyzer and verified Android build. Production package metadata is unchanged; its data was not read or changed.

Current subsequent working tree extends Habits with advanced dated schedules/pauses/history/goals/search/categories/statistics/calendar, real-control guides and encrypted generic native reminders. **311 host tests pass412s**, plus1later real time-picker/opt-in/save/disable UI case passes12s; analyzer8 is clean and43×886 catalogs/non-voice/9manifest guards pass. Notes capability19/portable advanced-Habit17; previous Experiences18/content16 are historical. Native Habit/alarm acceptance and ordinary19 APK are pending; **ADB currently has no connected device** and reconnection is requested. No current native result is invented. Detailed exact state: [NON_VOICE_COMPLETION_ACTIVE_CHECKPOINT.md](NON_VOICE_COMPLETION_ACTIVE_CHECKPOINT.md), [HABITS_ADVANCED_AND_REMINDERS.md](HABITS_ADVANCED_AND_REMINDERS.md).

Finance planning expansion, universal searchable Help Hub/remaining module guides and final integration/accessibility/localization/release/purchase acceptance remain outstanding. No voice/microphone, main merge, publication or paid activation. Older entries below describe earlier checkpoints and artifacts.

---

## Offline Books reader acceptance — 2026-11-15

Books now imports and reads PDF/EPUB/TXT inside Bilga, with encrypted managed files or explicit persistent references, covers, continue/progress, bookmarks/highlights/notes, typography, native PDF controls, knowledge cards/Leitner review, active-reading statistics, shelves, deterministic help, templates, durable cross-module links and full local encrypted recovery. Optional bibliographic details remain advanced. Notes DB **17**, Tasks **13**, portable reading content **15**. Format bounds and limitations: [BOOKS_OFFLINE_READER.md](BOOKS_OFFLINE_READER.md).

Final runtime **ff59d5b** CI **43708926430 succeeds with287 tests**, analyzer, DST/backend, Android build/verification. Physical Tab16 passes the expanded20-scenario suite, final6-case current UI suite, actual SAF12-case suite and real-process-restart12-case suite (overlapping scopes, not a summed suite). The latter prove PDF154/bookmark and persisted external TXT survive Review process death. [Acceptance/artifact checkpoint](BOOKS_READER_ACTIVE_CHECKPOINT.md) links exact evidence and failed-attempt history.

Ordinary **`build/review/bilga-reader-review-app.apk`** is signer-checked, installed in place and launched; real home → Kitoblar opens the new library. SHA256 **`400d37d158e2615698afe6400e908ccb5f51ec35671dc258d8969092d3740bae`**. Test runners are absent. Production package metadata is identical before/after; production data was not read or modified. Generated tablet documents were hash-verified and removed. Owner ZIP is preserved.

**The wider six-module product remains IN PROGRESS.** No manual TalkBack/native-keyboard, release performance, second-device recovery or full translation acceptance is claimed. No main merge, publication, paid activation or voice work. Earlier checkpoints below describe older artifacts/schemas and are historical.

---

# Release readiness

**IN PROGRESS — DO NOT SUBMIT TO GOOGLE PLAY.**

The source recovery and initial integrated development checkpoint are not a complete commercial release. Consult FEATURE_MATRIX.md, TEST_REPORT.md and KNOWN_LIMITATIONS.md for precise gaps.

Package: `com.ilmmizan.bilga` (preserved). Database files: `bilga.db`, `bilga_todo.db`. Current upgrade targets: Notes 17 / Tasks 13. Portable backup content versions are Notes 15 with reading data (older Notes13/14 remain importable) / Tasks 11 with backward-compatible import; search indexes and device-local widget consent are excluded and reconstructed.

Business: 40-day application-managed trial, then one non-consumable lifetime product `bilga_lifetime_unlock`. No subscription or automatic billing. Price must come from Play ProductDetails; $9.99 is a planning reference only. Existing data is not removed at expiry; protected read/export/backup routes remain.

Latest November 11 project checkpoint: **208 full Flutter tests PASS**, analyzer/formatting clean, **43 × 396** catalogs and nine manifest guards PASS. Review-only Tab16/API31 tests pass **43 scenarios**, 49 including hooks, in 274 seconds after keyboard correction. Projects include nested progress, safe conversion, search/reader/export, additive migration and backup. Template CI 43034401498 failed during apt DNS resolution before application tests; bounded setup retries are added and new hosted CI is pending. All six-module completion and owner acceptance gates still apply.

Required before release:

- Finish every required feature and full interaction/localization/accessibility audit.
- Pass full unit/widget/repository/legacy migration/encrypted-media restore/security/performance tests.
- Verify reminders/reboot/timezone/background behavior on real Android devices.
- Configure and license-test Play purchase, pending/cancel, acknowledgement retry, restore, revoked/refunded and offline-cached entitlements.
- Validate optional Drive restore, including media, on clean second device.
- Build reproducible debug APK and existing-key signed release APK/AAB; verify package, manifest, ZIP/signature and hashes.
- Finalize privacy policy, Data Safety, content rating, store listing, screenshots and feature graphic from the actual finished product.
- Recheck current official Play target API, Billing Library deadlines, testing-track/account/country rules at submission time.
- Obtain owner approval for actual publication and final country prices. No prices have been activated.

Prerequisite review: [PLAY_POLICY_REVIEW.md](PLAY_POLICY_REVIEW.md), including target API 36, updated Billing 9.1.0, conditional account testing and country availability.

Policy reference consulted: https://developer.android.com/google/play/billing/integrate (2026-11-09). Purchases must be verified and acknowledged only after completion; pending purchases do not unlock. This reference does not replace final policy review.

Historical November 9 host verification: **158 Flutter tests PASS**, analyzer no issues, formatting and all 43 locale structures PASS. Details and earlier failures are in TEST_REPORT.md. Hosted CI **42668103911 SUCCESS**, validated source `f2bb128ed4d4d6adef20fc28a7595de5d00fee2a`: analyzer no issues, **158 tests PASS**, debug APK build PASS, ZIP integrity PASS, APK v2 signature PASS, merged manifest PASS (package unchanged, target API 36, Billing 9.1.0, no microphone permission).

[Download private debug APK artifact](https://github.com/abdulAziz-Al-ILM/Bilga-Lokal/actions/runs/42668103911/artifacts/13698162381) — archive 211,606,874 bytes; expires **2026-11-16 22:58 Asia/Tashkent**. APK path within the CI artifact: `app-debug.apk`; runner build path: `build/app/outputs/flutter-apk/app-debug.apk`. APK SHA-256: `3ceb34222fc421cd2d9dde65642c63e7f33a8a2f542624fc1151b25c3e7ce4cc`.

This is a disposable-signer debug build, not a signed production release or an upgrade-signing acceptance result. That November 9 CI artifact did not establish release-signing or device acceptance. The newer tablet results are recorded separately above.

No release signing credentials were supplied to this work. Do not generate replacement keys or silently substitute debug artifacts.

## Current continuation — 2026-11-15

The combined Books-library/Habit-guidance source passes **268 full host tests**, clean analyzer/format, 43 × 568 catalogs, nine manifest guards and the non-voice guard. Current schema remains **Notes 16 / Tasks 13**; portable Notes content is **13 normally, 14 for Finance accounts**, Tasks **11**. This corrects the older schema summary above. Finance report CI 43064321644 succeeded at e520971, separately from this uncommitted/new checkpoint; current hosted verification is pending until push.

Book metadata/search/filter/editor/reader/backup and the first deterministic Habit guide/22-template gallery are incremental product work. All four professional-module scopes, remaining five module tours, full accessibility/localization/device/security/performance acceptance and real release setup remain required. No release readiness, main merge, voice approval, Google Play publication or paid activation is asserted or authorized by these test results.

Ordinary owner-usable Review APK at **9528234** is built, signer-checked, installed in place and launched successfully (COLD, 5295 ms debug Activity; not a release benchmark). Artifact: `build/review/bilga-books-guidance-review-app.apk`, SHA-256 `d524a0bb28fb60561fbb38cd67c055ed679a1c44901a8572788187c27025737d`. Its kernel contains Books/guidance/Finance reports and excludes integration runners and research images. Metadata: `docs/evidence/books-guidance-review-apk-2026-11-15.json`. Production is preserved. Current hosted CI remains pending until push.

## Hosted verification and artifact storage — 2026-11-15

Run **43687503754** at **4ac793c** passes **268 Flutter tests in 196s**, backend, analyzer, format, catalogs, non-voice/manifest guards, DST, Android debug build and APK verification. Hosted debug APK SHA-256 is `e9bd6caae23e32939142569e7bebf40c503c9ab0271c15147e32c90fdeec55ff`. Its final **upload fails because GitHub artifact storage quota is full**, so the overall run is failure and no hosted artifact/download is claimed. The separately built ordinary Review APK is already installed and available locally at source 9528234. Evidence: `evidence/books-guidance-ci-2026-11-15.json`.

CI now keeps every automatic test/build/verification step, writes a verified digest to the job summary, and offers cloud APK upload only through the explicit manual `upload_debug_artifact` boolean (default false, one-day retention). An opted-in upload remains strict and can fail if storage is unavailable. No existing artifact was deleted and no paid service was activated. Local YAML/conditional checks and an executed summary-digest fixture pass; hosted verification of this workflow-only correction is pending its push. Do not describe a skipped optional upload as a successful upload.
