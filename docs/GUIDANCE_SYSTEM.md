# Offline guidance — first implementation, 2026-11-15

The owner supplied `PROFESSIONAL_PRODUCT_COMPLETION_2026-11-15.md` and a reference ZIP. The reusable engine and Habit creation journey are implemented. **The universal six-module help requirement is still in progress.** No AI, remote instructions, microphone, analytics, fabricated record or automatic save is used.

## Engine and safety

`GuideController` defines a stable tour ID/version and ordered steps with stable IDs, target names, localized explanation keys, optional required success events and an irreversible-action boundary. Required steps reject Next until their action has succeeded. Text readiness makes Next available without moving the highlight while the user types. Back can revisit an already completed field; it never replays a save. A confirmed save is a boundary and cannot be replayed through Back. Skip and Exit only close guidance; they neither save nor discard the form.

Progress is serialized in order to SharedPreferences as version/step/active only. No title, draft, personal record ID or contents are stored in preferences. Resume is explicit. A newly opened editor without a durable draft starts at the name again. Only a caller with an actually restored draft may request step resumption. Invalid/mismatched state falls back to the first step. Preference failure does not prevent local help or change record persistence. The existing editor discard confirmation handles Android Back.

`GuideHost` resolves GlobalKeys on the current route, scrolls their actual render objects into view and periodically refreshes rectangles while a tour is active. It highlights the live control with a painted spotlight and leaves a hit-test hole for that control. Independent barriers block unrelated pointer actions. The guide panel provides large Material controls, wrapping actions, scrollable explanations, a semantics live region and RTL/dark/theme inheritance. Missing targets fall back to help without a blocking mask. Keyboard insets and viewport changes affect panel placement. The engine does not send a synthetic tap to a product control.

The shared private-field editor now exposes optional anchor keys, a save key, field-change callbacks and a route wrapper. The seven-field Habit form is laid out eagerly inside its scroll view, keeping all anchor contexts available when scrolling or returning to an earlier step. Existing required-field validation, save mutex, fresh write authorization, failure draft retention, discard confirmation and private IME flags remain in use.

## Habit journey

Persistent entry points: Help in the app bar, Explore habit templates, and Create my first habit. Help explains the module, yes/no versus quantity, schedule/streak/pause semantics and actual save behavior.

1. Help → Show me how opens the real Habit editor.
2. Name remains highlighted while typing; Next becomes available for a nonempty name.
3. Weekdays explains actual selected-day chips and waits for Next.
4. Quantity explains the actual target field and waits for Next.
5. Unit explains the optional unit field and waits for Next.
6. Save highlights the real editor save control and waits for a successful repository write.
7. The guide returns to the actual dashboard and explains progress/check-in/history. This is the sixth numbered tour step (the first bullet above is navigation).

Failed writes and trial expiry retain the draft and the Save step. Authorization is checked immediately before every Habit mutation. The form's Save remains the only operation that creates a record; choosing a template, opening Help, Next, Back, Skip, Exit and missing-target fallback never create one.

The immutable catalog contains 22 suggestions in Health, Learning, Productivity, Home, Personal development, Reflection, Finance and Wellbeing. Search/category filtering and preview always remain available. Customize opens a prefilled real creation form; each draft gets independent schedule/entry collections and starts with no completions. The catalog is not inserted into databases, searches, statistics or backups. Only explicitly saved habits enter existing encrypted persistence/search/backup.

## Scope still required

Other Notes/Tasks/Finance/Experiences/Books tours and a searchable shared Help Hub are not wired yet. Habit advanced schedules, categories, reminders, consolidated statistics/export and the remaining four-module work still need implementation. Existing pause means a day-level deliberate skip, not a fully featured date-range pause. UI descriptions describe current functionality only. No full TalkBack/manual accessibility audit, multi-device/layout acceptance or release performance claim is made. English/Uzbek/Russian new copy is a draft; other catalogs currently use English fallback.

Verification evidence is recorded separately in `TEST_REPORT.md`, `TABLET_TEST_REPORT.md` and dated evidence files. Do not infer a tablet pass from host tests.

Current Habit quantities are integer counts (1–1,000,000 for targets, 0–1,000,000 for check-ins). Choose a suitable unit; fractional quantities are not implemented by this checkpoint.
