# Source recovery — 2026-11-09

The master spec is `FINAL_PRODUCT_SPEC.md`. Its business and voice decisions supersede older handoffs.

| Source | Examined revision | Findings |
| --- | --- | --- |
| Bilga-Lokal main | 8871b3ac007ab05402949b3eacd4327340c6913c | Clean initial checkout; four imported backup implementations missing; Notes DB 11 / Tasks DB 6 |
| Bilga-Lokal wip/todo-widget-recovery | f4d5c8a1dc84cb732b2215f9051bc1ce352799ac | Notes DB 13 / Tasks DB 8, tags, widget consent, reminder actions, encrypted trial, signed purchase grants and backup fixes |
| Bilga-Backup main | 9754f3be36 (full SHA in GitHub history) | Original Flutter source; four missing backup files recovered, then upgraded to WIP revisions |
| Bilga main | 60b14e6021 (full SHA in GitHub history) | Kotlin foundation; inspected actual local backup, rule-based assistant and reminder scheduler source |
| Bilga-Language-Models main | 3cff3d2c12 (full SHA in GitHub history) | One-file source tree; voice-models-v1 tag exists; no text inference implementation recovered |

All four repositories were accessible through authenticated GitHub access. Branches, tags, recent commits and PRs were inspected. No PRs or release tags exist in the Flutter primary repository; its WIP branch contains substantially newer code. The model repository's voice tag is outside the current voice-free release scope. Remote inventories were non-truncated.

Recovered selected source from WIP rather than merging it into main. Excluded speech models, STT/TTS acquisition and voice implementation. Its AGENTS.md was read for history, but not installed: the current master spec authorizes a dedicated development branch and supersedes the former requirement to work only on the old WIP branch.

Existing recorded CI run 40100139344 succeeded for an earlier WIP source revision. That is historical evidence, not validation of this development branch. Old tablet reports likewise do not certify current code or this computer.

Kotlin findings: the assistant explicitly uses keyword overlap with source IDs; it is not a generative model. Its scheduler calls exact alarms unconditionally, so that implementation was not ported. The newer Flutter/native reminder integration handles modern permissions and has dedicated native tests.

No claim is made to recover files existing only on the former computer. No private personal content, signing material, model binaries or databases were copied. The four backup source files were the only missing production Dart imports detected before recovery.
