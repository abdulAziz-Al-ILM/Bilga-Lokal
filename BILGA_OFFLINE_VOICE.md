# Bilga Core offline voice

Updated 2026-10-12. The public model repository is configured, with an Ed25519
public key pinned in the app. No model/language is preinstalled or advertised
as installed before successful verification/download.

## Uzbek STT initialization fix — 2026-10-12

The supplied `~/bilga-voice-error.log` was empty (0 bytes). A live, process-scoped
logcat capture was started on the attached API31/arm64 tablet without clearing
logs or application data. The installed APK matched the previously verified SHA.
`RECORD_AUDIO` was granted; AudioRecord successfully started mono 16kHz PCM.
The optional noise-suppressor effect is unavailable on this tablet, but capture
continued; that message is not the cause. All eight installed model files matched
published size/SHA-256, and both cached catalog and installed signed provenance
were byte-identical to the published envelope. Native Sherpa/ONNX libraries were
present in the APK and matched Gradle's stripped artifacts. These libraries map
straight from the APK on this device, so absence of a named `.so` map alone is
not diagnostic; APK file-offset matching was used after the successful attempt.

The exact code failure was reproduced through **OfflineVoice.listen**, with the
real signed release installed into disposable test storage and a local fake
microphone (no network, user microphone or notes). The inline `Isolate.run`
closure in the recording method captured its surrounding async session context:
`Invalid argument(s): Illegal argument in isolate message ... _AsyncCompleter`.
The decoder was never reached. The page's generic `catch` hid the exception and
showed “Offline ovoz xizmati ishlamadi”. English system STT uses the Android bridge
and avoids this downloaded-model worker path, explaining the different behavior.
Dart documents this closure capture limitation and recommends a separate function:
https://api.dart.dev/dart-isolate/Isolate/run.html

`recognizeModelInBackground` now creates the worker outside the session scope,
passing only the validated model description, directory and PCM samples. The same
boundary is used for local model TTS to avoid capturing playback state. Local
stage/type diagnostics omit raw exceptions, recognized text, microphone data and
notes. All SHA/signature/license/compatibility/private-storage checks are unchanged;
no model release/key/config changes or online fallback are needed.

The reproducer failed before the fix and passed after it (real native decoder,
~5s). Default regression also checks that a native worker error returns correctly
without transferring caller ports/completers. `flutter analyze` passed (4.4s),
full serial Flutter suite passed **163 tests** (57s).

Opt-in local native reproducer (requires the already verified public assets under
`.buildlog/voice-release/publish/assets`, Linux x64 Sherpa package installed):

```sh
LD_LIBRARY_PATH=/home/abdulaziz/.pub-cache/hosted/pub.dev/sherpa_onnx_linux-1.13.8/linux/x64 flutter test tool/voice_models/local_listen_test.dart --dart-define=BILGA_VOICE_LOCAL_TEST=true --reporter expanded
```

Logs and read-only device integrity results: `.buildlog/voice-init-fix/` (ignored).
This fixes initialization, not the preview model's previously disclosed command
accuracy or low-memory limitations. Debug APK build passed (95.9s); ZIP CRC and Android v2 signature passed.
The APK SHA-256 is
`d5dc783fe392d5027f6a1bc5abd5a44030ab4b0fe1655d01fc3750002b5e91d2`
(293634246 bytes). A successful `adb install -r` updated the tablet app without
uninstall/data clear; all eight original model hashes were rechecked and preserved.
Live tablet microphone acceptance **passed**: logcat shows worker start at
12:31:37.792 and decode completion at 12:31:41.711 (Asia/Tashkent); the user
confirmed the error no longer appears. APK offset matching confirmed ONNX Runtime
(6 segments) and Sherpa C API (4 segments) mapped in the actual arm64 app process.
The unused C++ wrapper is not required for Dart's C API. Optional vendor chipname
property/noise-suppression warnings did not prevent decoding. Captures were stopped
after acceptance. This verifies initialization and one real microphone decode,
not universal command accuracy. Full details are in HANDOFF.md. No GitHub push/publication is part of this fix.

## Published Uzbek preview — 2026-10-11

Release: https://github.com/abdulAziz-Al-ILM/Bilga-Language-Models/releases/tag/voice-models-v1

Repository: `abdulAziz-Al-ILM/Bilga-Language-Models`, **public**. CLI authentication
and ADMIN permission were checked. Only this repository received a release; no
application source repository was pushed. The release is explicitly a **prerelease**.

* Catalog: revision **1**, expires **2027-04-01T00:00:00Z**, Ed25519-signed.
* Public key pinned in `model_release_config.dart` and the public config example:
  `ACLVesaFlk6rXZzspz50XGzOPJ06/9tcW8fblcq62dA=`.
* A new, separate private seed was generated at
  `/home/abdulaziz/.local/share/bilga-model-signing/catalog-ed25519-v1.seed`.
  File mode **0600**, directory **0700**, outside the checkout. It was never
  printed, uploaded or supplied to the app build. Make a secure offline backup;
  losing it prevents signing updates trusted by this app key. Existing APK/billing
  keys were not changed or reused.
* Archive: `vosk-uz-small-0.60.zip`, **83919183 bytes**. SHA-256:
  `a3f1ce14f253fc1ccfce62dc5cc55f00545c976f5b2dd0766c87061cb6689bb3`.
* Twelve public assets: eight flat model/notice/review files, ZIP, signed catalog,
  public key and SHA256SUMS. ZIP has exactly the eight declared data/document paths.
  No app source, APK, user data, audio, token or private key was uploaded.
* GitHub's server SHA-256/size matched every uploaded asset. Catalog signs both
  all eight flat file hashes and the archive hash. The app consumes flat assets,
  preserving existing resume and per-file verification; it does not extract ZIPs.

Original publisher's pinned model card/license and source hashes were checked again.
Original ONNX/token files remain unmodified; Apache license, upstream model card,
attribution and `VALIDATION.md` are included. Review is a bounded **Android native
compatibility preview** (API31+, arm64-v8a), not universal accuracy certification.

Additional tablet qualification used only a public Uzbek corpus sample and local
synthetic audio, never user microphone data. Real 9.576s speech, 20 dB SNR noise,
20s repeated speech and silence decoded. Real transcript had an error (“voz” became
“ovoz”); noise added errors. Peak RSS was 183584–185728 KiB. An artificial **512 MiB
virtual-address ceiling FAILED** with native allocation failure; this is not a
physical-RAM measurement and low-memory robustness is not certified. Synthetic
stop/resume/read commands were also misrecognized. All failures are disclosed in
the signed validation document and release notes. `preview:true` displays a visible
warning in Core; no short-command reliability claim is made. Real microphone
commands, accents, in-app playback and download acceptance on the tablet remain
user tests. Android review is now attested for the tested compatibility scope;
license/Android/SHA/signature gates remain enforced.

Tools: `create_voice_catalog_key.py` safely creates a new external key without
overwrite/symlinks/shared permissions; `voice_catalog_public_key.dart` derives
only the public key; `package_voice_release.py` packs an exact verified allowlist;
`sign_voice_catalog.dart` also checks the archive pin; `verify_voice_release.dart`
uses the app's signature/policy parser. Publication used a draft until all server
hashes were checked, then published the preview. Local artifacts/logs:
`.buildlog/voice-release/` (Git ignored).

The app now uses this trusted source by default, retaining Dart-define overrides.
An explicit empty repository/key disables downloads. `voice_models.example.json`
contains **public** values only. Old APKs still require the new trusted app update.

To test on the tablet: install the new debug APK **as an update** (do not uninstall
or clear data), open Bilga Core → Uzbek → **Yuklab olish**, allow ~89.8 MiB of model
downloads, check progress/cancel/resume, restart, then enable airplane mode and try
real microphone commands. STT and TTS remain separate; **no Uzbek TTS asset** is
included. Use typed commands/buttons when recognition is inaccurate. The new APK
was prepared, not automatically installed over user data.

## Why the tablet says “Til modeli yo‘q”

The previous APK had empty `BILGA_VOICE_MODEL_REPOSITORY` and
`BILGA_VOICE_CATALOG_KEY`; selecting Uzbek did not install a model. This bootstrap
problem is now fixed for the published preview. System Uzbek speech still cannot
be assumed. The panel now explains this configuration state rather than
claiming that an unloaded catalog contains no models. With valid configuration,
**Yuklab olish** is visible before the catalog is loaded: explicit consent →
signed catalog verification → compatible missing STT/TTS downloads → size/hash
verification → private installation. Each kind remains independently unavailable
if no reviewed model exists. An unconfigured build shows a disabled download
button and explains the required app update; it cannot safely invent a source/key.

## Real Uzbek STT candidate and prepared release

Selected upstream: [Alpha Cephei Vosk Uzbek 0.60](https://huggingface.co/alphacep/vosk-model-small-streaming-uz),
which explicitly declares **Apache-2.0**. Commit is pinned to
`e0417cabfbbac4efdc34e7aba367501d126ae79c`; model bytes are unmodified.
`tool/voice_models/uzbek_stt.lock.json` records original file names, sizes and
SHA-256 (large-file LFS object hashes plus downloaded small-file hashes).
License text, original model card and provenance notice are included as hashed
release files. The acquisition tool prepares seven original flat assets; the
published preview adds the eighth, signed `VALIDATION.md` review document.

**Important upstream discrepancy:** the model card says non-streaming, but the
actual encoder metadata has `model_type=zipformer2`, `comment=streaming zipformer2`,
`decode_chunk_len=64`, `T=77` and left-context states. It successfully runs with
Sherpa **OnlineRecognizer / OnlineTransducerModelConfig**, not OfflineRecognizer.
Here “online” is Sherpa's streaming API name; all computation is local CPU/FFI.
The app engine name is `streaming_transducer`, with encoder/decoder/joiner/tokens.
One second of local zero padding flushes the final decoding chunk; no audio is
sent anywhere. Language coverage is **Uzbek only**, not all 43 UI languages.

Reproduce acquisition (Python 3.11+ stdlib only, maintainer workstation):

```sh
python3 tool/prepare_uzbek_voice.py .buildlog/voice-models/release --revision 1 --expires 2027-01-01T00:00:00Z
dart run tool/smoke_uzbek_voice.dart .buildlog/voice-models/release
python3 tool/test_prepare_uzbek_voice.py
```

Preparation fetches only pinned public upstream model files, resumes partials,
checks exact size/SHA-256 and writes `assets/` plus `catalog.draft.json`. It does
not publish, sign, create keys or change application/user data. Draft is deliberately
`androidReviewed: false` and cannot pass the release signer/app validation.
Current compatibility target is API 31+, arm64-v8a; do not widen it without testing.
Re-running preparation regenerates the unreviewed draft; retain a separately
reviewed payload for release. Choose an expiry in the future at publication time.

Actual tests on 2026-10-11:

* Linux Sherpa 1.13.8 Dart runtime: verified files, loaded the real model and decoded
  two seconds of silence + one second flush, no hallucinated text; about 1.58 s.
* Attached tablet, Android API 31 / arm64, ~7.4 GiB physical RAM: the same version's
  Android C API loaded the model and decoded three seconds of silence, exit 0,
  CPU time 4.18 s, peak RSS **183228 KiB** (~179 MiB). Public model/test files were
  temporarily placed in `/data/local/tmp/bilga-uz-smoke-20261011` and removed.
  No app DB, microphone, production signing key or user audio was accessed.
* Native probe source: `tool/voice_models/android_smoke.c`; compiled with existing
  NDK 28.2, API26 clang, linked to existing `sherpa_onnx_android_arm64` 1.13.8
  `libsherpa-onnx-c-api.so` and `libonnxruntime.so`, using the official
  [v1.13.8 C API header](https://github.com/k2-fsa/sherpa-onnx/blob/v1.13.8/sherpa-onnx/c-api/c-api.h).

The initial silence probes alone did not approve Android review. The later
real-speech/noise/20s qualification and known failures are recorded in the published
preview section above. Review now covers that bounded native compatibility scope;
real microphone commands and broader device/accuracy acceptance remain pending.

## Uzbek TTS result

No redistribution-ready Uzbek TTS model for the current VITS runtime was verified.
Do not mark Uzbek TTS available based on the STT download.

* [Meta MMS Uzbek Cyrillic](https://huggingface.co/facebook/mms-tts-uzb-script_cyrillic)
  is **CC-BY-NC-4.0**, not suitable for this commercial model release.
* RHVoice Uzbek voices [Sevinch](https://github.com/RHVoice/Sevinch-uzb/blob/main/README.md),
  [Islom](https://github.com/RHVoice/islom-uzb/blob/main/README.md), and
  [Dilnavoz](https://github.com/RHVoice/dilnavoz-uzb/blob/main/README.md) explicitly
  declare **CC-BY-NC-SA-4.0**. Language-rule LGPL licensing does not override voice
  data licensing. No RHVoice APK/voice or NC-licensed MMS asset is bundled/downloaded.
* The tablet's current default engine is `com.google.android.tts`; that package's
  presence alone does not prove an installed Uzbek offline voice.
* A different offline option is **eSpeak NG**, a formant synthesizer rather than
  a VITS neural voice. Its [Uzbek language definition](https://github.com/espeak-ng/espeak-ng/blob/master/espeak-ng-data/lang/trk/uz)
  exists but is marked **testing**. The upstream [Android engine](https://github.com/espeak-ng/espeak-ng/tree/master/android)
  exposes local voices through Android TTS. Its [GPL-3.0-or-later license](https://github.com/espeak-ng/espeak-ng#license-information)
  permits redistribution subject to GPL/source obligations; it is not an NC voice
  license. An independently installed eSpeak NG engine is a candidate for the
  settings route above. It was not installed/tested on this tablet and is not
  advertised as available. Bundling/linking its code or distributing its APK
  requires separate GPL compliance review; it is not a VITS data asset and is
  not silently downloaded through the signed model-data catalog.

The panel offers **Offline ovozni sozlash** to open Android TTS settings. The user
can configure an independently installed, appropriately licensed offline engine
and voice. Returning reinitializes the default TTS engine and checks actual voice
flags again; network-required or uninstalled voices remain rejected. This is
setup guidance, not a promise that Android has an Uzbek voice. Automatic Uzbek
TTS requires a redistribution license and a vetted runtime-compatible model or
a separately reviewed local engine integration. Other 43-language catalog entries
can provide TTS independently when their models pass the existing checks.

## Original bootstrap checklist (completed for the published preview)

The following is the original release workflow, preserved for future maintainers.
Repo/key/signing/publication/configuration are now completed as documented above;
do not create a replacement key or overwrite revision 1. Tablet app acceptance
and secure offline key backup remain owner actions.

1. Supply a dedicated **public** GitHub Releases `owner/repository` and release tag
   (e.g. `voice-models-v1`). The repo/release now exists; only model release assets were published.
2. Complete Uzbek speech/Android acceptance above; keep only tested ABIs/API in
   the reviewed payload. After that review, explicitly attest `androidReviewed`
   in a copy of `catalog.draft.json`. Never flip the flag to skip testing.
3. Create/retain a separate Ed25519 **model-catalog** 32-byte seed offline, outside
   the project (base64 text file with owner-only permissions and secure backup).
   Do not reuse billing/APK signing keys. Never send the seed in chat or upload it.
   The new catalog seed is already created at the external path above. Existing
   APK/billing keys were not accessed or changed; retain the catalog seed securely.
4. Sign on that trusted workstation:

   ```sh
   dart run tool/sign_voice_catalog.dart catalog.reviewed.json .buildlog/voice-models/release/assets /secure/model-catalog-seed catalog.signed.json
   ```

   The signer verifies pinned size/hash rather than overwriting a mismatch,
   validates review/license/path/expiry policy, signs exact payload bytes and
   prints only the base64 public key. Model hashes **do not** replace this signature.
5. Package and upload the exact reviewed allowlist (this preview has twelve assets,
   including eight flat files, archive, signed catalog, public key and checksums).
   Do not upload the seed; an unsigned draft is not a catalog.
6. Build a trusted app update. The current app defaults are already configured;
   for a future deployment, copy `voice_models.example.json` to an optional local
   public configuration and override repository, tag and **public** key:

   ```sh
   flutter build apk --debug --dart-define-from-file=voice_models.local.json
   bash tool/verify_android_apk.sh
   ```

   Install as an update preserving app data, open Core → Uzbek → **Yuklab olish**.
   Validate cancellation/resume/restart, then airplane-mode commands. The current app defaults already contain the published repository and pinned
   public key; explicit Dart defines can override them for a future deployment.

Updates: keep the signing public key pinned in the trusted app; publish a higher
catalog revision and new immutable model version/assets. The client rejects older
revisions and preserves the last working model if an update fails. Do not edit an
existing model version in place. Android/library/model review is per actual model,
not an assertion that every app language has STT and TTS.

## Runtime and actual language availability

* Android system STT uses **only** `createOnDeviceSpeechRecognizer` (Android 12/API
  31+); it never uses the default potentially remote recognizer. API 33+ queries
  `checkRecognitionSupport` for installed languages; API 31–32 and providers that
  do not report support show **unverified**, not available. API 34+ requests local
  language switching, which remains provider-dependent.
* System TTS accepts only matching, installed voices with
  `isNetworkConnectionRequired == false`, excluding `KEY_FEATURE_NOT_INSTALLED`.
  A failed voice selection fails closed. No online STT/TTS fallback exists.
* App-owned downloadable models run with Sherpa ONNX 1.13.8, CPU, two threads,
  in a worker isolate: Whisper, SenseVoice and streaming Zipformer STT, VITS/Piper-compatible TTS.
  Each model must list its **actual** languages. Whisper language coverage,
  SenseVoice coverage and individual VITS voice coverage are different; the app
  does not assume they cover all 43 UI languages.
* The command registry covers all 43 app languages, with aliases for reading,
  pause and resume. The app language is the initial preference; recognized text
  can match commands from any registry language. STT can only recognize languages
  supported by its installed engine/model. New languages extend the registry.
* Text language selection uses conservative script and word hints per sentence,
  falling back to the selected language for ambiguous text. It is **not** universal
  language identification. Same-script mixed languages can require manual language
  selection. Missing voices produce a language-specific error, not an unrelated voice.

Official references checked:
https://developer.android.com/reference/android/speech/SpeechRecognizer
https://developer.android.com/reference/android/speech/RecognitionSupport
https://developer.android.com/reference/android/speech/tts/Voice
https://k2-fsa.github.io/sherpa/onnx/tts/apk.html
https://pub.dev/packages/sherpa_onnx/versions/1.13.8
Sherpa's Apache-2.0 code license does **not** grant licenses to every model.

## Reading and microphone

Notes are passed in full to the reader. Sentence/size chunks preserve every UTF-16
code unit and never split a surrogate pair. System TTS synthesizes a small chunk
to private cache; downloaded TTS produces the same local WAV format. MediaPlayer
pause/resume preserves the audio position inside the chunk, rather than repeating
its text. Completion advances exactly one chunk. A new reading invalidates older
callbacks. Leaving the foreground pauses playback and cancels listening; disposal
releases playback and removes the current temporary audio file. The bookmark is
in memory during the foreground assistant session, not persisted across process death.

Tap the microphone while reading: playback pauses immediately, then speak a stop
or resume command. These two recognized commands execute directly. Other commands
remain editable/reviewable and retain existing mutation confirmations. There is no
passive always-on microphone or claim of hands-free hotword interruption. Buttons
and typed commands work even without STT. Microphone samples for downloaded STT
stay in memory and are discarded after bounded (maximum 20 seconds) recognition.

## Model source configuration

Copy `voice_models.example.json` to a local config file and set:

* `BILGA_VOICE_MODEL_REPOSITORY`: `owner/repository` for a dedicated GitHub Releases repository.
* `BILGA_VOICE_MODEL_RELEASE`: release tag, default `voice-models-v1`.
* `BILGA_VOICE_CATALOG_KEY`: base64 Ed25519 **public** key pinned into the app build.

Build with `flutter build apk --dart-define-from-file=your-config.json`.
The key must be delivered with a trusted app update; never fetch a signing key
from the model server. Empty configuration disables catalog downloads but leaves
system offline speech and manual controls available. No GitHub token is embedded;
release assets must be publicly downloadable. Model updates use monotonically
increasing signed catalog revisions and unexpired catalogs. Offline startup uses
previously verified signed provenance without making network requests.

Selecting a voice language offers explicit model-download consent. After consent,
the app refreshes the trusted catalog and automatically acquires missing STT/TTS
models that pass Android compatibility checks. The panel also supports manual
catalog refresh, per-model download/retry, delete, progress, cancellation and total
storage usage. No compatible model means unavailable, independently for STT/TTS.

## Signed catalog format and publishing

Release asset: `catalog.signed.json`. Envelope fields `payload` and `signature`
are base64; the signature covers the **exact payload bytes**, using Ed25519.
Payload example (metadata must be reviewed before signing):

```json
{
  "schema": 1,
  "revision": 1,
  "expires": "2027-01-01T00:00:00Z",
  "models": [{
    "id": "whisper-example",
    "version": "1",
    "kind": "stt",
    "engine": "whisper",
    "languages": ["en"],
    "license": "Apache-2.0",
    "licenseUrl": "https://your-upstream.example/LICENSE",
    "licenseReviewed": true,
    "androidReviewed": true,
    "androidMinSdk": 26,
    "androidAbis": ["arm64-v8a"],
    "files": [
      {"path": "encoder.onnx", "asset": "whisper-encoder.onnx"},
      {"path": "decoder.onnx", "asset": "whisper-decoder.onnx"},
      {"path": "tokens.txt", "asset": "whisper-tokens.txt"}
    ],
    "config": {"encoder": "encoder.onnx", "decoder": "decoder.onnx", "tokens": "tokens.txt"}
  }]
}
```

`tool/sign_voice_catalog.dart` verifies pinned file/archive size and SHA-256
against release assets, validates review policy and signs the catalog offline:

```
dart run tool/sign_voice_catalog.dart payload.json assets-dir /secure/seed-file catalog.signed.json
```

The seed file contains a base64 32-byte Ed25519 seed. Keep it outside the project
and Git. Publish only the signed catalog and declared assets, never the seed.

Supported configurations:

* STT `whisper`: encoder, decoder, tokens; language detection is automatic.
* STT `sense_voice`: model, tokens; automatic recognition among supported languages.
* STT `streaming_transducer`: encoder, decoder, joiner, tokens; Zipformer2 streaming
  local CPU decoding, with language coverage declared per model.
* TTS `vits`: model, tokens; optional lexicon and `dataDir`. Every phonemizer data
  file must be individually listed and hashed, with its relative nested path.

Models are **data**, not downloaded executable libraries/APKs. No archive extraction
is used. Paths reject traversal; asset names and redirect hosts are restricted.
Permitted reviewed license identifiers: Apache-2.0, MIT, BSD-2-Clause,
BSD-3-Clause, CC0-1.0. Other licenses need deliberate legal/product review and a
code/catalog policy update. The review flags are signed maintainer attestations,
not automated proof of licensing or Android performance. Before marking
`androidReviewed`, test the exact model on listed ABIs and minimum SDK, including
RAM, pronunciation, supported languages and phoneme data requirements. Include
upstream notices among hashed files. Do not mark every UI language as supported.

Files reside under application-support private storage, `offline_voice_models`.
Downloads retain `.part` files, resume using HTTP Range, restart if Range is
ignored, and verify size/SHA-256 before committing installation. Corrupt complete
partials are discarded. Updates preserve the previous signed installed version
until the replacement commits; deletion also removes partial and previous versions.
Network code constructs only GET requests for configured release assets with no
request body, authentication or cookies. It has no API accepting notes or audio.

## Validation limitations

2026-10-11 published-preview checks: `flutter analyze` — no issues;
`flutter test --concurrency=1` — **162 passed**, exit 0, including notes,
backup, billing and all 43 command languages. Python acquisition/security/archive
checks — **7 passed**. Debug APK build exit 0; final ZIP CRC and APK v2 signature
verified. Artifact: `build/app/outputs/flutter-apk/app-debug.apk`, **293634246 bytes**,
SHA-256 `2b290c3ee36f8f78872f2eef570067d0dd6fdcc1b38d0d14671463085f72dca4`.
Logs, reviewed payload and exact public assets: `.buildlog/voice-release/` (Git ignored).
Opt-in live integration: `flutter test tool/voice_models/live_download_test.dart
--dart-define=BILGA_VOICE_LIVE_TEST=true` — **1 passed**, 5m40s. It downloaded all
8 real flat assets through `VoiceModelStore`, verified the pinned signature/hashes,
reopened signed installed provenance without network, found Uzbek STT and correctly
found no Uzbek TTS. Disposable test storage was removed. This is a workstation
app-downloader integration test, not tablet UI/microphone acceptance.

Only the authorized public model release was published. No application-source push
or tablet update installation was performed. Earlier failed test/build attempts
are retained in logs: one native test crash and timing failure preceded the passing
full suite; the first APK had a native-library CRC mismatch. Quarantining only
generated APK/package outputs and rebuilding with CPU affinity produced the verified
APK. This does not establish that the previously documented host instability is fixed.

See HANDOFF.md for current command results. Real-device testing must cover airplane
mode, all installed languages, pause within a word, repeated pause/resume,
foreground microphone interruption, background/lock transitions, model download
cancellation/restart, low storage, app restart and device-specific voice engines.
Native Android speech qualification is documented above. Public-release installation
through the real app downloader is checked separately on the workstation; full
in-app microphone/TTS playback and tablet download acceptance must not be described
as end-to-end device-validated before those user tests.
