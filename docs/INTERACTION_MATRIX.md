# Interaction matrix — 2026-11-15 incremental checkpoint

This matrix covers the newly implemented Book library and Habit templates/first guide. It is not a complete six-module audit. Host evidence: `evidence/books-guidance-host-2026-11-15.json`. Native evidence is separate and must be marked PASS only after an actual run.

| Flow/control | Expected behavior | Automated evidence |
| --- | --- | --- |
| Habit `habit-templates` / template app-bar icon | Open reusable catalog without writing a habit | Habit guidance UI template journey |
| `habit-template-search` / category chips | Filter bundled suggestions, not personal data | UI search plus all-22 catalog/model validity; every category chip is not individually device audited |
| `habit-template-{id}` | Preview purpose, schedule, quantity; Cancel writes nothing | Template preview/cancel journey |
| `habit-template-customize` | Open a fresh editable form; no entry/completion until Save | Template customize/create journey and independent-plan model test |
| `habit-help`, `habit-get-started`, `habit-guide-start` | Explain value and open actual editor only on request | Guide UI create/skip journeys |
| `editor-field-title`, named `title` anchor | Keep name highlighted while typing; require nonempty text before Next | Full guide journey; model event gate |
| Named `weekdays`, `target`, `unit` anchors | Scroll real controls into view, allow edits, confirm with Next | Full guide and 360px/2× RTL/dark route-wide tests |
| Named Save anchor | Wait for successful authorized save, prevent parallel saves | Failure/expiry/no-write/retry UI journey; existing editor save mutex |
| `guide-back` / `guide-next` | Revisit fields with draft intact; never replay confirmed save | Model state machine and failed-save field revisit |
| `guide-skip` / `guide-exit` | Close hints, preserve real draft and normal editing | Skip/Android Back UI journey and fallback/Exit host test |
| Android Back | Existing discard confirmation; no implicit write | Skip/discard UI journey |
| Missing/changed target, rotation | Visible scrollable fallback or relocated spotlight; exit remains available | Dedicated guide-host widget tests; native rotation not asserted by this checkpoint |
| Guide pointer hole | Target receives actual taps, unrelated controls do not | Dedicated guide-host hit-testing test; manual TalkBack audit remains outstanding |
| `book-library-add` / `book-details-save` | Validate full metadata and write once after explicit authorization | Book UI metadata/create/invalid-ISBN journey |
| Book detail fields/status/rating/favorite | Preserve chapters, history and bookmark; keep failed-save draft | Model/data/failed-save/compact expired-access UI cases |
| `book-library-search`, status/favorite/shelf/tag/category/sort | Query thin summaries; retain correct filters if earlier loads finish late | Data filter/pagination tests and delayed-initial-load UI race |
| `book-library-row-{id}` | Load validated full record on open; no metadata write on read | Legacy/reopen/no-op UI and data cases |
| `book-library-more` | Load next bounded page with no duplicate IDs | 122-book thin paging database test; every UI paging gesture not manually audited |
| Book readable export / read-only source | Full metadata and chapter content, no edit controls/writes after expiry | Read-only Book source regression |
| Book backup/import | Preserve metadata/history, remap IDs, reject future versions and remain idempotent | Shared Book portable backup data test, including encrypted native fixture when verified |
| Attachment owner query | Retrieve only requested kind/owner; stale removal does not delete referenced blob | Book injected attachment data case |

Remaining acceptance: all other module tutorials, shared Help Hub, guided budget/session/card workflows, historical advanced Habit semantics, full permission/accessibility/layout/device matrix and release performance. Reference images under `references/` are research, not test screenshots; genuine Bilga screenshots must be identified separately and use only synthetic Review fixtures.
