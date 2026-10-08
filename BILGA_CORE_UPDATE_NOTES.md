# Bilga Core — initial integration patch (2026-10-08)

This is a **source snapshot**, not an APK or tested release.

Changes:
- Existing in-app Agent's visible title / widget rename to **Bilga Core**.
- Remove the online speech-recognition toggle; Android listen method is always called with `online: false`.
- Long TTS messages are split into 2800-character chunks; stop button increments a cancellation epoch to avoid continuing after cancellation.
- Existing source, all domain features and assets otherwise preserved.

Open blockers:
- Offline voice recognition must be tested on target device/language; Android offline flag alone does not guarantee availability.
- Long TTS now supports stop, but resumable position, selecting notes by folder/date, status mini-window, and spoken stop/resume **are not implemented yet**.
- Audit any remaining online/web actions within the old embedded Agent before Play release.
- No Flutter analyze, unit or real-device test was run in the artifact environment.
- Review sensitive configuration files before pushing even a private GitHub repo.
