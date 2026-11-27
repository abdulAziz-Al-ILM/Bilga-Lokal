# BILGA — FOUR MODULES PRODUCT-MATURITY SPRINT + GUIDED UX

You are Codex operating inside `/home/abdulaziz/StudioProjects/Bilga-Lokal` (verify actual root). This is an EXECUTION task, not a brainstorming exercise. The product owner reports that Notes and To-Do are reasonably strong, but HABITS, FINANCE, EXPERIENCES, and BOOKS still feel like children's demos. Correct that imbalance. Deliver four cohesive, sophisticated, genuinely useful offline-first products within Bilga. Do not rewrite working Notes/Tasks or regress them. Preserve existing application ID, encrypted databases, migrations, backups, 40-day trial, lifetime entitlement, locale catalogs, and existing user data.

## Source of truth and safeguarding

1. Inspect `git status`, current branch and latest commits, including `development/global-launch` and draft PR #1. Treat the currently present working tree as potentially newer than GitHub's last checkpoint. Do not overwrite uncommitted work. Read `docs/FINAL_PRODUCT_SPEC.md`, `docs/FEATURE_MATRIX.md`, `docs/IMPLEMENTATION_STATUS.md`, `docs/KNOWN_LIMITATIONS.md`, and other recent checkpoints. Inspect the *implementation*, not just the reports.
2. Inspect `references/` (the owner may place a screenshot/reference ZIP there). Review the reference gallery and the supplied source URLs. These are UX research references ONLY: do not copy screenshots, proprietary assets, logos, or exact layouts into shipped product; design original Bilga UI.
3. Use the connected Blackview Tab16 via `adb devices -l` only when authorized. Preserve the original production Bilga app. Test on an isolated review package/app and synthetic fixtures, never uninstall, clear, downgrade, or overwrite the original app. Confirm signature and package identity before installation.
4. PC has limited memory and has experienced Linux OOM: no overlapping Flutter/Gradle builds or unnecessary emulators; use conservative workers, inspect RAM, and checkpoint frequently.
5. Keep voice/STT/TTS and microphone permission OUT. Voice is a separate phase after the owner's personal acceptance of the non-voice product.

## Core product-quality principle

A blank screen plus '+' is NOT a finished product. Each of these four modules MUST open on an immediately comprehensible, information-rich, interactive home screen with: a short value proposition; genuinely useful starter choices (curated TEMPLATE CATALOG, not invented personal records); an optional 30–60-second guided first action; context-sensitive actions; actionable empty states; meaningful trend/progress visuals once data exists; and a persistent Help / Learn entry. First-run onboarding must not require an account or internet. A novice must achieve a first real result in under 90 seconds.

**Do not silently seed fake user habits, expenses, loans, journal entries, books, or reading completions.** Preset cards are discoverable examples/catalog entries. Actual data records are created ONLY when the user explicitly chooses a template and confirms input. Previews must say SAMPLE/DEMO and never be included in user financial totals, statistics, searches or backups. Allow user to skip onboarding, dismiss suggestions, and customize templates. Templates must remain available at all times, not vanish after first launch.

## SHARED FIRST-RUN AND HELP SYSTEM (NO AI)

Create a reusable, accessible, localized, offline, rule-driven guided-tour system used throughout Bilga, especially these four modules and optionally Notes/Tasks. No external LLM, model download, remote instruction service, voice, or invasive analytics.

- Entry points: `? Yordam`, `Qanday ishlaydi?`, `Boshlash`, `Namuna ko‘rish`, `Yangi ... yaratish`, `Qo‘llanma` on each module. Dedicated searchable Help Hub accessible anytime from modules and Settings.
- In-context walkthrough with spotlight overlay anchored to ACTUAL widget keys/rectangles, tooltip explanation and optional arrow. Keep underlying screen visible. Buttons: **Keyingi**, **Orqaga**, **O‘tkazib yuborish**, **Qo‘llanmani tugatish**, **Amalni bajarish** where appropriate. Large tap targets, TalkBack descriptions, keyboard/focus management, scrolling, safe areas, tablets, text scaling, RTL, screen rotation, Android back. Do not trap users under overlays.
- Step state machine: `tourId`, `version`, `stepId`, `targetKey`, precondition, intended user action, optional validation, next step, cancel/resume semantics. A walkthrough can open the proper screen, highlight the specific control and wait for the user to do it; advance ONLY when action succeeds (e.g. persisted record exists). Handle async load, missing targets and changed layouts by retry/fallback to inline explanation. Back/cancel never create or commit records; no duplicate writes when resumed.
- Guided actions launch real existing editor/repository operations (no simulated onPressed). Safe to resume after app process death when practical. Help copy must match the screen's actual implementation; documentation and UI stay synchronized.
- User-selectable tutorials: Create habit; set weekly habit; interpret streaks; create expense; set starting balance; create budget; record partial loan repayment; interpret cashflow; create structured experience; link lesson to task; add book; log reading session; create an insight card; review flashcards. Include end-of-flow confirmation and return-to-relevant-page.
- Built-in beginner help content with plain-language definitions, a 1-minute example, mistakes to avoid, and actionable buttons; users should not have to ask someone else how to operate Bilga. Keep this deterministic, local, low-overhead.
- UI tours and help must be testable: unit tests for state machine, widget/integration tests for target discovery, focus, skip/back/resume, small screens/large text, success triggering and no accidental data creation.

## MODULE 1 — HABITS: professionally competitive

Benchmark Loop Habit Tracker (calendar/streak/statistics), Habitify (curated popular habit gallery, daily routine), Daylio (quick check-in and trend). Implement/reconcile with existing models, migrations and backup:

- A polished Today tab with morning/day/evening groups, exact due habits, quick check-off or quantity entry, progress summary, missed/paused semantics, and clearly empty day behavior.
- Explore/Template Library with categories: Health, Learning, Productivity, Wellbeing, Finance, Spiritual/Reflection, Housekeeping, Custom. At least 20 *meaningful*, editable starter templates such as: drink water (quantity), read 15 minutes, 10-minute walk, sleep by desired time, stretch 5 minutes, record expenses, study 25 minutes, language practice, reflect 3 minutes, journal, exercise, tidy desk. Never create records until explicitly selected/saved. Include icon, suggested frequency, unit, intent and customize action. Avoid ungrounded medical promises.
- Flexible schedules: daily, selected weekdays, n times/week, interval, pause, start/end dates; yes/no and quantity goals; correct day-boundary and streak behavior in user's local timezone and when schedule changes.
- Calendar/heatmap, trend charts, completion rates with correct denominators, streaks, best streak and missed-day handling; accessible exact data alternative to graphs; export CSV and backup.
- Optional reminders using Android's permitted notification scheduling; avoid permissions by default. Habit edit/archive/delete and historical corrections must preserve data integrity. No streak manipulation through seeding.
- Guided experiences: `Boshlash uchun odat tanlash`, `Birinchi belgilash`, `Haftalik maqsad`, `Natijani tushunish`.

## MODULE 2 — FINANCE: genuinely trustworthy money manager

Benchmark Money Manager (daily/calendar/monthly ledger, category statistics, receipts), YNAB (category funding/targets, onboarding checklist). PRESERVE existing precise integer minor-unit accounting, accounts, transfers, reconciliation, date-range reports, void/history, read-only access and backup. Never use floating point for money. No real banking actions and no invented live FX rates.

- Home dashboard shows current account balances, this month's income/spending, spendable vs budgeted amounts with correct logic, active debt/loan summary, upcoming obligations, and sensible empty states. Clearly distinguish transfers from income, opening balances from income, debt principal from spending, and pending vs cleared where relevant.
- A coherent tab set: Overview, Transactions, Budgets, Debts, Reports. Daily/calendar/monthly navigation; account filter, category hierarchy, search, recurring entries, optional receipt attachment, transaction details/history, CSV exports.
- On first entry: **setup checklist**: (1) Select currency, (2) Add cash/card account and starting balance, (3) Record first expense or income, (4) Create first monthly spending budget, (5) View report. Each button opens and highlights the actual input. Users can skip; do not fabricate actual balances or transactions.
- Built-in category catalog with editable starter categories: food, transport, rent/housing, utilities, education, health, shopping, family, entertainment, gifts, other; income: salary, freelance, business, gifts, other. Preset budget examples can offer values for user review, but must never set amounts automatically without confirmation.
- Budgets by category/month, custom intervals when feasible, carryover behavior explicitly chosen, used/remaining/over-budget computation, goals and savings progress. Recurring expense/income with edit/skip series occurrences and failure-safe scheduling.
- Debts: lent/borrowed, principal, disbursement, partial repayment, remaining amount, due date, optional reminders, currency, contacts as optional free-text (not mandatory access to contacts), immutable history and safe corrections.
- Multi-currency separate balances, explicit rate/date/source for any conversion. No silently merged currencies or deceptive aggregate dashboard.
- Helpful example previews using synthetic demo data visibly labeled “Namuna”, entirely isolated from persisted records and never mixed into reports. Offline-first, secure, large-number accessibility, sound charts, tests verifying accounting invariants and reversals.
- Guided help: `Birinchi hisob`, `Birinchi xarajat`, `Budjet`, `Qarz`, `Hisobotni o‘qish`.

## MODULE 3 — EXPERIENCES: structured learning/decision journal

Benchmark Day One (prompt packs, guided templates, calendar, media and entry timeline), Daylio (fast structured check-ins and trends). Distinguish Bilga's EXPERIENCES from ordinary Notes: capture event → observation → decision/lesson → next action → later outcome. Focus on user-controlled reflection, never AI-generated personal narratives.

- Main hub shows Today prompt, recently saved experiences, calendar/timeline, category quick filters, and optional reflection reminders. Work, Study, Life, Soul/Reflection and fully custom categories.
- Template Gallery with at least 12 meaningful starting structures, e.g. daily reflection, learning from a mistake, project retrospective, experiment log, tough conversation, decision journal, gratitude, lesson learned, first attempt, weekly review, meeting reflection, achievement, personal challenge. Template preview explains when to use and what result the user gets; NEVER invent user's past experiences.
- Structured editor supports title/date, event, context, expectations, what happened, results/evidence, feelings optional, lesson, next step, follow-up date, tags, attachments, photos and explicit save/draft handling. Optional short-form one-line check-in mode for low effort.
- Durable history and corrections, timeline/calendar, search, favorites, private categories, filter, export/backup and safe local privacy. Optional progress summaries only based on actual entries; never claim insights based on empty data.
- Cross-link an experience to note/task/book/habit via stable IDs and safe backup remapping; `Create follow-up task` is explicit and idempotent.
- Guided help: `Tajribani qayd etish`, `Shablondan boshlash`, `Xulosa → Vazifa`, `Haftalik tahlil`.

## MODULE 4 — BOOKS: full reading and knowledge system

Benchmark Bookmory (shelves, reading sessions/progress, calendar/stats, quotes and reading journal), Readwise (highlight review and spaced repetition). Reuse current book/chapter/reader/bookmark implementations and retain existing metadata.

- Home: Currently reading with progress / continue, To Read shelf, Finished shelf, book count and reading insights, recommended *actions* not recommendations of fake books. Curated onboarding examples like “Add the book you're reading”, “Save a favorite quote” and “Start a 10-minute reading session”. Sample book cards use generic fictional/sample titles or public-domain metadata with clear demo labeling; never silently add to library.
- Library metadata: author, title, cover (optional), ISBN, format, total pages or time/chapters, publication info, language, tags, series, custom shelves, status (to-read/reading/finished/paused/abandoned), ratings and dates.
- Reading: session timer that safely pauses/backgrounds, page/minute logging, daily/weekly goals, progress, calendar, reading trends, re-reading sessions and correctly aggregated stats. Allow use without downloading or storing copyrighted books.
- Knowledge cards: Quote, Idea, Summary, Question, Definition, Action, Personal Reflection; source book + chapter/page/time; editing, tagging, attachments where supported, search and export. Highlight own notes / public-domain material; do not download copyrighted text or store long book passages without user input/authorization.
- Review mode with flashcards: front/back, simple transparent scheduling (e.g. SM-2-based or carefully documented bounded algorithm), due review, rating, history, local reminders when permitted, transparent statistic and reset controls. No fabricated completion.
- Strong book → Notes/Tasks/Experiences links with durable IDs and backup support.
- Guided tutorials: `Birinchi kitob`, `O‘qishni qayd etish`, `Bilim kartochkasi`, `Kartochkani takrorlash`, `Statistikani tushunish`.

## Visual implementation and onboarding acceptance

- Use original Bilga design language; benchmark interaction *principles* from reference images, not branded pixels/assets. Consistent design tokens, thoughtful iconography, typography and card density, accessible colors/dark mode, 7 palettes, compact phones/tablets, 2x text, RTL.
- Modules must be understandable WITHOUT data. Show helpful catalog, preview, contextual setup checklist, explanatory text and interactive actions; not empty graphs with 0 everywhere and only a lonely '+'.
- Fully local bundled content; user can re-open tutorials and template galleries at any time. First launch may show 2–3 optional value cards but never block the user; no forced sign-in, voice or cloud.
- No AI requirement. Guided overlay is deterministic code with view keys/state machines, not conversational promises.
- 43 locale catalog structure retained; Uzbek/English/Russian + Central Asian priority first; fallback honestly noted, no invisible or overflowed text.

## Non-negotiable verification

For each of the 4 modules complete one end-to-end journey: discover template -> preview -> customize -> persist -> revisit/edit -> search -> report/statistic -> export -> backup/restore -> read-only after trial. Additional cases for trial expiration mid-form, invalid input, rapid double taps, interrupted writes, timezone/DST, cross-record links, migration from prior schemas. Make tours work with 2x font, keyboard open, screen rotated, screen scrolled, RTL, and Android back; no click-through onto destructive controls.

Use isolated Review on connected tablet, capture genuine screen recordings/screenshots of the new Bilga screens for owner review, ideally save `docs/evidence/screenshots/` or an artifact (do not commit private user data). No fabricated screenshots or claims of physical verification. Maintain an interaction matrix with buttons, expected behaviors and tests. Run Dart format, analyze, relevant tests, full test suite, Android debug build/CI and selected tablet acceptance. Record exact PASS/FAIL and any blocked tests.

## Execution order — don't stop at planning

1. Inspect working tree, references and current implementations.
2. Build reusable onboarding/template catalog + deterministic guided tours framework (start with habit creation). Verify the framework end-to-end.
3. Complete Habits, Finance, Experiences and Books in coherent increments, ensuring UI+schema+tests+backup each time. Prioritize end-to-end user value over piles of isolated helper classes.
4. Cross-module links and unified search, then full data safety/accessibility/localization validation.
5. Tablet-run all four first-use workflows and produce real screenshots + owner-review APK without damaging original app.
6. Commit/push checkpoints to `development/global-launch`, update draft PR #1, and update `FEATURE_MATRIX.md`, `IMPLEMENTATION_STATUS.md`, `TEST_REPORT.md`, `KNOWN_LIMITATIONS.md`, `RELEASE_READINESS.md` with verified evidence. Preserve incomplete work on interruption, never claim release readiness prematurely.

Do not start voice work. Do not merge main. Do not publish or activate paid services. Do not ask the owner about individual button decisions; make safe, professional defaults. If one external credential blocks a feature, continue all independent functionality. **Build, test, demonstrate, and show the actual result; not another implementation-only report.**
