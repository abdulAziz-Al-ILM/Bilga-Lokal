## Release preflight 1.4.0+20 — 2026-11-27

The loading and retry screen now suppresses Flutter's DEBUG banner. The signed ARM64 tablet APK is `build/review/bilga-review-no-banner-v20-2026-11-27.apk`, SHA-256 `ed50465067ff5e2c1ae2e60925597b0c1ca1013a3e9a1fb9323ba887e12936ca`. Its manifest passed the isolated Review checks. The tablet was absent from ADB when the update was ready.

The signed technical preflight AAB is `build/play-preflight/2026-11-27/all-abis/bilga-1.4.0-20-build-only.aab`, SHA-256 `8635031a68a1c1e38319dd1c1cf9817582f6ee922830deb0ba0f54ca85b4c613`. It includes the three supported ABIs `armeabi-v7a`, `arm64-v8a` and `x86_64`. Bundletool validated the package and reported `PAGE_ALIGNMENT_16K`. All 16 64-bit native libraries passed ELF alignment checks. The manifest declares target API 36 and Billing 9.1.0. It passed the non-debuggable release check without test-only or instrumentation flags. `jarsigner` verified the bundle with the same certificate as the earlier local preflight. Compare the upload certificate and highest version code against Play Console before producing the upload build. [Google Play target SDK](https://support.google.com/googleplay/android-developer/answer/11926878) · [Android 16 KB compatibility](https://developer.android.com/guide/practices/page-sizes).

The store copy and privacy draft now describe read-aloud, books, finance and the latest reminder behavior. The upload build command still stops because `billing_config.json` is missing. Real purchase and restore verification require the configured HTTPS verifier and a Play test track. No bundle was uploaded.

All 369 Flutter tests passed in 18 minutes 11 seconds. The 14 manifest tests, 17 purchase verifier tests, catalog validation, startup file analysis and Android `lintVitalRelease` also passed. The release DEX excludes the integration-test plug-in, and the bundle includes the three task reminder tones and the embedded offline speech license and source archive.

The owner's Play Console screenshot confirms that `com.ilmmizan.bilga` is a draft and Production is inactive. The dashboard says that closed testing is required before applying for production access. It also shows a trader status declaration banner. The dashboard does not show the tester count, the current closed-track progress, the highest version code or the upload certificate. Google's requirement for affected personal accounts is at least 12 testers continuously opted in for 14 days before applying for production access. [Play Console testing requirements](https://support.google.com/googleplay/android-developer/answer/14151465).

---

## Read aloud, rounded widgets and reminder tones — 2026-11-27

The Read aloud button is available on unlocked Bilga screens. In Uzbek, English and Russian, voice commands can read the current screen or open a named module and read its displayed text. Notes, task editors, experiences and search result documents supply their full text. The book reader supplies the current EPUB or TXT section or the text layer of the current PDF page. Image-only PDF pages require OCR. Speech preserves long text in consecutive chunks with pause, resume and stop. Playback clears on navigation, app lock or backgrounding. Screen reading excludes hidden and obscured controls. The screen voice panel presents alternative transcripts for correction.

The Notes, Tasks and Core widgets use a shared rounded card with the active theme. Normal task reminders use Android's standard notification sound. Important, very important and critical tasks use two notes, three notes and two spaced pairs respectively. Task due and upcoming alerts use the same priority. The channels follow Android ringer settings and Bilga's sound preference.

The signed ARM64 Review APK is `build/review/bilga-review-read-aloud-v19-2026-11-27.apk` (1.4.0+19), SHA-256 `d6b47c748dfe364721052b258334e3dbedd1a7f97bcf1b0d5b1bd811d5fe59a3`. The final APK was restored and launched on Tab 16, and its installed digest matched. All 46 final focused Flutter tests, 13 manifest checks and 43 string catalogs passed. The device passed 58 native Tasks and shared widget checks, 13 native Notes widget checks and six read-aloud integration scenarios. The Android audio subsystem played the synthetic Uzbek excerpt to completion. The synthetic scheduled task posted to `bilga.todo.priority.3.v1`, and its test cache was restored. Uzbek recognition and speech quality still depend on the installed language services and pronunciation quality of the bundled fallback.

---

## Reminder sound and task widget privacy — 2026-11-25

Non-task reminders now follow the in-app reminder sound setting. The new Android channel uses the default notification tone. The existing silent channel preserves quiet delivery and any explicit Android block on upgrade. Turning off a task's widget permission removes its row, deadline, controls and contribution to progress. Cached widget actions check the current permission before changing a task.

The signed ARM64 Review APK is `build/review/bilga-review-reminder-widget-v18-2026-11-25.apk` (1.4.0+18), SHA-256 `14688f87d78dc15d9d86a2714b15089f431ad7d4bc6a4dae519833704bc3c39d`. All 45 focused Flutter checks, 13 manifest checks and the JVM calendar reminder check passed. The APK installed in place on the Tab 16, and the installed digest matched. Production package metadata matched before and after the upgrade.

On the locked Tab 16, all 51 targeted Android checks passed, including the widget exclusion and both notification channel configurations. A scheduled synthetic habit reminder posted to `bilga.modules.sound.v1`. The fixture restored the original reminder cache and schedule. Android's ringer mode was SILENT and its notification stream was muted, so the delivery confirms the channel while audible playback still needs a listening check with the tablet in sound mode. The broad native sweep stopped at the encrypted Notes widget check because the tablet was locked. Launcher layout inspection also requires an unlocked screen.

---

## Play release preparation resumed — 2026-11-25

The owner authorized proceeding with Google Play release preparation. The local upload-key configuration and Google OAuth client configuration are present. The build-time billing configuration is absent, and the purchase verifier has no confirmed production deployment. All 17 verifier tests and 13 manifest tests passed. These results cover synthetic purchases and declaration checks. A real Play purchase and restore still require the configured backend and a Play test track. Without that configuration the app cannot grant a new purchase after the 40-day trial.

The signed build-only AAB is `build/play-preflight/2026-11-25/bilga-1.4.0-18-build-only.aab`, SHA-256 `f271596a1fb9c7c95ac3f7ba1e886d082ad1a7cf6da2b649e9216e5043022788`. Bundletool validated the archive, and `jarsigner` verified its signature. The base manifest declares `com.ilmmizan.bilga`, target API 36, Billing 9.1.0 and foreground-only voice. ARM64 and x86-64 are the only bundled architectures, and all 16 native libraries for those architectures passed the 16 KB ELF check. Bundletool requests 16 KB alignment. The AAB excludes the Review voice sample and the debug Dart kernel. Version code 18 is provisional until compared with Play Console. [Google Play target SDK](https://support.google.com/googleplay/android-developer/answer/11926878) · [Android 16 KB compatibility](https://developer.android.com/guide/practices/page-sizes).

The offline local build temporarily removed the stale dev-only `integration_test` entry from the generated Android registrant and restored the generated file afterward. The supported Flutter CLI regenerates that file in release mode when Pub preparation is enabled. The missing AndroidX Collection and DataStore artifacts were retrieved with checksum verification. `:app:lintVitalRelease` passed separately with the same source, build flags and ABI selection. The build-only package contains no production billing settings.

The existing Firefox profile did not accept a second automated session. Desktop accessibility could not read the Play Console page. The owner was asked to check whether the Bilga Production page offers **Create new release** or **Apply for production**. Upload certificate matching, the highest uploaded version code, listing declarations, and track eligibility remain pending. No release was submitted.

---

## Transcript alternatives and Navoiy performance — 2026-11-25

Voice control now shows up to two alternatives returned by the Android recognizer. Selecting one replaces the editable transcript and clears its previous command preview. The normal review and confirmation flow still applies. The focused tests cover duplicate and malformed results, selection of “Bilga” when the initial transcript contains “belgi”, and typing a separate correction.

All 364 Flutter cases passed, along with analysis of the changed Dart files, the 43 language catalogs, 13 manifest tests and the checks for foreground-only recognition. All 13 voice integration scenarios passed on the Tab 16 in 6 minutes 50 seconds with simulated speech and encrypted fixture records. The signed ARM64 Review APK is `build/review/bilga-review-voice-alternatives-v17-2026-11-25.apk` (1.4.0+17), SHA-256 `800082b4ed863d2f450b4be5e7cde94128b03b28f66e9a286b0d5b3014ab34ac`. The restored Review installation matched that digest and launched cold in 2.442 seconds. The production package metadata matched before and after the device suite.

Navoiy's two-step model synthesized the same 3.20-second sentence on the Tab 16 in 25.702 seconds with a one-second reference window and the original speaker embedding. An eight-thread run took 26.137 seconds. Moving the flow stage to the Mali GPU took 50.185 seconds in strict Vulkan mode. Using the shorter reference, the ARM NEON matrix experiment reached the first audio in 22.777 seconds against 24.476 seconds for its same-session CPU baseline. The generated waveforms in that pair had sample cosine similarity of 0.999975. The experiment also synthesized two other full sentences in 18.715 and 12.385 seconds.

Quantizing selected batched matrix operations to eight bits reduced the same 3.20-second sentence from 22.108 to 18.846 seconds in the second controlled pass. Its speech-token, flow and vocoder stages took 8.151, 6.308 and 4.382 seconds. The shorter full sentence took 10.157 seconds. The 28-token prefix probe generated 1.12 seconds of audio in 8.863 seconds and stopped before completing the sentence. The existing Vox integration still generates a whole sentence group before it emits audio. The full comparison clips are `build/review/navoiy-neon-gemm-25nov.wav` and `build/review/navoiy-q8-quantized-25nov.wav`. [Navoiy source](https://huggingface.co/aisha-org/navoiy-tts/tree/9445f41) · [Vox runtime](https://github.com/dariumi/Vox/tree/v0.19.5).

The Uzbek Vosk 0.22 model with Android Vosk 0.3.75 loaded in 1.523 seconds and decoded three pre-generated clips in 0.978 to 1.557 seconds. Two transcripts matched their source sentences. The clock sentence produced “ertagi” and “to'qqizta” where the expected words were “ertaga” and “to'qqizda”. The Linux recognizer returned the same transcript for the quantized and floating-point matrix variants of that sentence. This is a small synthetic check. Live recognition and listening quality need separate evaluation. [Vosk model catalog](https://alphacephei.com/vosk/models) · [Android reference project](https://github.com/alphacep/vosk-android-demo/blob/master/app/build.gradle).

The offline benchmark scripts and experimental runtime are under `.bilga-tools/uzbek-speech`. The temporary device copies were removed. The measured Navoiy delay remains too long for live conversation, and the Review APK continues to use its existing synthesis and recognition providers. Google Play publication remains paused.

---

## Voice controls and keyboard — 2026-11-24

On the Tab 16, entering an Uzbek dictation and then an English dictation could leave the second command without a confirmation button. The keyboard timing correction passed both focused landscape scenarios. The full tablet run then exposed the problem in portrait during the first dictation. Bilga now accounts for the keyboard inset once and resolves the submitted command after the keyboard closes and the route's visible controls update. The target and its current value are still checked before applying a confirmed edit. The tablet scenarios use synthetic text and simulated speech.

The signed ARM64 Review APK is `build/review/bilga-review-voice-dictation-v16-2026-11-24.apk` (1.4.0+16), SHA-256 `a8e46c7e82d11375b1266aafd7d516c31c705485dcad14550fbd253f4a351bba`. The manifest passed the Review package and foreground microphone checks. The APK contains the compiled app and publisher's Navoiy sample. Google Play publication remains paused. The preceding `5055055` GitHub validation finished successfully. [GitHub Actions](https://github.com/abdulAziz-Al-ILM/Bilga-Lokal/actions/runs/45242113923).

The updated source passed all 362 Flutter cases, analysis of the voice code and fixtures, all 43 localization catalogs and 13 manifest tests. The compact keyboard regression verifies that the command waits for the visible screen to return before offering confirmation. All 12 voice integration scenarios passed on the Tab 16 in portrait, including consecutive Uzbek and English dictation, spoken confirmation, and cancellation when a confirmed control becomes unavailable. After the suite, the signed Review APK was installed in place and launched cold in 2.527 seconds. The installed APK digest matched and production package metadata was identical before and after.

The same Navoiy sentence produced 3.20 seconds of audio on the Tab 16 in 31.335 seconds with two flow steps and 47.924 seconds with four. At two steps, the speech-token model took 7.941 seconds, the flow stage 15.931 seconds, and the vocoder 7.459 seconds. Both model copies passed their digests and the temporary directory was removed. The samples are `build/review/navoiy-flow2-tablet-24nov.wav` and `build/review/navoiy-flow4-tablet-24nov.wav`. The result leaves a delay of over 30 seconds before speech, so live replies still use Bilga's existing synthesizer. The owner approved the publisher's demo previously. The lower-step output has yet to receive a listening evaluation. [Navoiy publisher source](https://huggingface.co/aisha-org/navoiy-tts/tree/9445f41).

---

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
