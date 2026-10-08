# Bilga Core — Offline Interaction & Widget Specification

Status: **approved product requirements; not yet implemented**. Date: 2026-10-08.
Owner decision: Bilga Core local-only AI; no cloud AI, no remote speech transcription, no internet search. Google Account + Drive solely optional backup/restore. A separate future application named Bilga Agent will handle external cross-app AI/automation.

## Naming
- In-app/offline assistant: **Bilga Core**.
- Future cross-app product: **Bilga Agent**.
- Existing home-screen widget currently says "Bilga Agent"; rename visible launcher/title to **Bilga Core** while it targets in-app assistant. Reserve "Bilga Agent" for the separate product; avoid broken external-app link.

## Voice and in-app actions
- User taps the Bilga Core widget; a compact on-screen status/activity panel shows state.
- Spoken request example (Uzbek, English or app-localized aliases): "Notes/Yozuvlar > Ish > Qurshop; read content added in the last 7 days".
- Resolver uses typed domain operations and localized aliases, folder hierarchy, title match, metadata/date filtering and ambiguity prompts. No hard-coded phrase list required for every utterance. Never query the web as fallback.
- Show structured step-by-step progress in compact UI: section opened; folder found; note selected; reading/writing; completed/error. Do not expose private note contents on lock screen or outside unlocked application.
- Read entire selected long note, not just first 3500 characters, in chunks; TTS playback supports immediate voice/button **stop, pause, resume**, remembers current chunk and offset where possible. Spoken commands can interrupt TTS, with explicit microphone activation while foreground; do not promise always-on passive hotword listening.
- Offline STT availability differs by device and language. Require locally installed speech pack/engine or bundled model, never silently call cloud. If unavailable, show manual controls or guided installation with explicit network consent (for acquiring model, not transmitting speech). Offline TTS similarly depends on voice availability; enable voice selection and fallback/error messaging.
- Security: read/write operations scoped to unlocked user's local database; destructive edits require confirmation; no silent remote transfer.

## Home-screen widgets
1. **Bilga Core** voice launch + compact activity/status surface (Android AppWidget has platform limitations; foreground activity/sheet for live microphone, visual updates synchronized to widget).
2. **Today's tasks** with next deadline, completed count and quick open/mark actions; notification content private when locked.
3. **Finance overview** with day/week/month/all-time selectable range; income, expenses, balance and optional debt overview; conceal sensitive sums on lock screen.
4. **Ambience/music** based on existing tranquil image/sound scenes; current theme, play/pause, next, sleep timer and audio service media notification.
5. Optional later: reminders or notes shortcuts; no overloading v1.

## Receiving from other apps
- Android ACTION_SEND and ACTION_SEND_MULTIPLE for shared text, links, images and videos (content URI when granted), allowing "save to note", "add comment", choose folder and save attachment.
- Instagram sharing may provide **only a URL**, not full video bytes. Accept shared URL and metadata, not unauthorized automated downloading or bypassing service restrictions; show user what was actually saved.
- Persist grant or import file safely using scoped storage, check MIME/size, revoke temporary access, handle failure, redact log; never upload private attachments.

## Reminders and alarms
- Local reminders with date/time, recurrence, snooze, dismissal, timezone changes, boot recovery and Doze considerations.
- Android notification channels, runtime POST_NOTIFICATIONS on relevant Android versions; exact-alarm permission/API where appropriate and permitted; fallback scheduling if exact not granted. Do not promise infallible alarm firing when permissions/battery restrictions block it.
- Per reminder configurable notification: chime, tone, voice/TTS phrase such as "Janob/Xonim, ...", vibration, silent. TTS over locked screen and background subject to Android OS restrictions; notification + audio only with explicit permissions/settings.
- Avoid always-on microphone. No sensitive note text spoken on a locked device unless expressly enabled.

## Startup logo animation (last polishing stage)
- User images: primary geometric white-symbol logo on black and green scroll app mark. Animate *logo elements* flying from edges and assembling into primary emblem; scroll seal displays embossed/emblazoned primary mark. Smooth easing and ~short duration, minimize startup blocking; obey reduced-motion configuration.
- For longer real loading, two bars/symbols glide left to right with eased loop; do not fake indefinite wait, stop immediately upon ready.
- Prefer vector/motion reconstruction from approved logo shapes; do not use static raster rotations that look like unrelated objects.
- User supplied artwork is the reference. Asset rights and exact color/shape consistency preserved.

## Engineering order and acceptance
1. Import complete source safely to private repo (scan for secrets, user DBs, signing keys, private backups); preserve rollback.
2. Rename existing Core widget visible text and assistant UI **Bilga Core**, reserve Agent label.
3. Fix chunked TTS and stop/pause/resume, offline-only STT policy, status panel.
4. Domain intent router; notes folder/time lookup; multilingual synonyms; safety permission boundaries.
5. Local reminder scheduler + notifications/voice-alert settings.
6. Today tasks widget, finance widget, music widget.
7. Share-to-Bilga flows with URL/file distinction.
8. Startup motion.
9. Unit/widget/integration tests, real-device validation, privacy and backup/restore regression, cold-start performance checks.

No claim that these are complete until tested on device. Product constraint: Bilga Core offline-first, optional Google Drive backup/restore only.
