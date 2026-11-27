# Bilga UX references (private research)

These are third-party interface references for the owner's private research. Do not copy source imagery, exact branded layouts, logos or assets into Bilga or redistribute them in the released application.

Open `gallery.html` in a browser with an internet connection to inspect the screenshots; images are hosted on their original sites. Run `bash fetch_screenshots.sh` from this folder to save local screenshots into category folders (`habits`, `finance`, `experiences`, `books`). Download failures can happen if a site changes its URL or blocks scripted fetches.

Sources:
- Habitify popular habits/template-gallery screenshot: https://www.habitify.me/de/blog/how-to-track-habits-like-an-expert-with-habitify
- Loop Habit Tracker (statistics/calendar): https://play.google.com/store/apps/details?id=org.isoron.uhabits
- Realbyte Money Manager (budget/report): https://help.realbyteapps.com/hc/en-us/articles/360042743774-How-to-set-up-modify-delete-a-budget
- Day One templates: https://dayoneapp.com/guides/tips-and-tutorials/templates/
- Day One prompt packs: https://dayoneapp.com/guides/tips-and-tutorials/templates/
- Daylio chart/mood UI: https://web.uri.edu/counseling/apps/
- Bookmory product overview: https://apps.apple.com/us/app/bookmory-reading-tracker/id1515533482
- Readwise daily highlight review: https://docs.readwise.io/highlights/docs/faqs/reviewing-highlights

Official research and patterns (not exhaustive app audits):
- Habitify: curated templates and routines.
- Loop: clear schedule/streak charts and calendar.
- Money Manager: calendar/ledger, budget summaries and chart insights.
- YNAB: on-screen setup checklist and category target education.
- Day One: template gallery, structured prompts and easy quick-start.
- Bookmory: reading shelves, reading sessions, journal notes, progress and stats.
- Readwise: actionable review cards and user-controlled repetition.

## Reviewed on 2026-11-15

The owner's `Bilga_references_qayta.zip` contained four text files, not embedded screenshots. All seven gallery images were downloaded successfully and visually inspected. `gallery.html` now uses the local files for offline viewing; its links still open the original images. Image hashes and source URLs are in [downloads-2026-11-15.json](downloads-2026-11-15.json). Raw third-party images are ignored by Git and are not application assets.

The supplied screenshots are mixed historical references, not proof of every current competitor feature. Official product/help pages were separately checked. Useful patterns to adapt in original Bilga UI:

| Product | Verified source | Observed pattern and Bilga use |
| --- | --- | --- |
| Habitify | [Official article](https://habitify.me/de/blog/how-to-track-habits-like-an-expert-with-habitify) | Supplied image shows a Today list beside selectable popular habits. Use an always-available template catalog, preview and editable form. |
| Loop | [Official site](https://loophabits.org/) | Official site describes charts, reminders and statistics. Supplied historical image shows streaks, calendar and separate history. Keep daily tracking simple and provide exact data beside charts. |
| Money Manager | [Official budget guide](https://help.realbyteapps.com/hc/en-us/articles/360042743774-How-to-set-up-modify-delete-a-budget) | Guide shows category/amount/save, then budget progress on the Total screen. Make budgets reachable from Finance and distinguish spending from transfers. |
| YNAB | [Official setup guide](https://www.ynab.com/guide/the-ultimate-get-started-guide) | Sequence categories, account balances and a plan. Adapt to an optional checklist with explicit real-user input; no invented transactions. No YNAB screenshot was supplied or downloaded. |
| Day One | [Official templates guide](https://dayoneapp.com/guides/tips-and-tutorials/templates/) | Curated and custom templates, editable sections. Supplied historical screenshot illustrates template preview and editing; build optional reflection prompts, not compulsory forms. |
| Daylio | [Official product site](https://daylio.net/) | Quick check-in, calendar/list, entry-derived charts and customization. Supplied image is hosted by University of Rhode Island; use fast entry and actual-record statistics. |
| Bookmory | [Developer App Store listing](https://apps.apple.com/us/app/bookmory-reading-tracker/id1515533482) | Listing describes progress, reading timer, calendar and statistics. Supplied third-party image illustrates notes and rated covers; retain user-owned metadata and offer useful reading actions. |
| Readwise | [Official review documentation](https://docs.readwise.io/highlights/docs/faqs/reviewing-highlights) | Configurable highlight review; supplied third-party screenshot shows a single review card with a completion action. Use an explicit review queue and transparent local scheduling. |

The source downloads include secondary hosts (blogs.es, Medium, URI, itsallwidgets, Catherine Pope); they are visual references, not normative documentation or reusable licensed assets. Copy no wording, passages, branding, artwork or layout into shipped UI. Research is complete for this initial reference set; implementation and acceptance are separate work.
