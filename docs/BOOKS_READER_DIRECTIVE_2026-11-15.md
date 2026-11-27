# BILGA — COMPLETE BOOKS MODULE TRANSFORMATION
## From Book Catalog to Professional Offline Reading Application

**PROJECT:** Bilga
**COMPANY:** ILM Mizan
**REPOSITORY:** `abdulAziz-Al-ILM/Bilga-Lokal`
**BRANCH:** `development/global-launch`
**PULL REQUEST:** #1

## 1. MAIN OBJECTIVE

The current Books module feels too much like a bibliographic database or a journalist's research notebook.

This is not the intended primary experience.

Bilga's Books module must become a complete, modern, offline-first electronic reading application.

It should combine the practical advantages of:

- Google Play Books.
- Moon+ Reader.
- ReadEra.
- Librera Reader.
- Bookmory.
- Readwise.

Study their publicly documented reading workflows and interface patterns where useful.

Do not copy proprietary designs or assets.

The primary objective is to let ordinary users import books, read them comfortably, remember important passages and continue reading effortlessly.

**A user should not need to understand ISBN, publication metadata, database structures or knowledge-management terminology to read a book.**

Advanced capabilities must remain available without overwhelming ordinary users.

This is a real implementation assignment.

Do not stop after creating designs, plans or documentation.

---

# 2. PRODUCT PHILOSOPHY

Bilga Books must serve two types of users.

### A. Ordinary reader

Wants to:

1. Add a book.
2. Open the book.
3. Read comfortably.
4. Continue where they stopped.
5. Save an occasional bookmark.
6. Finish the book.

These actions must be extremely simple.

### B. Advanced reader

Wants to:

1. Organize a large library.
2. Highlight passages.
3. Create annotations.
4. Save quotations.
5. Create knowledge cards.
6. Review important information.
7. Track reading statistics.
8. Connect knowledge with Notes and Tasks.

Both types of users must use the same application.

Use progressive disclosure: show simple controls by default and advanced controls when requested.

Do not create two separate applications.

---

# 3. FIRST SCREEN — PERSONAL LIBRARY

Redesign the Books home screen.

The primary screen should look and behave like a personal electronic library.

It must prominently display:

### Currently Reading

Books the user has started but not finished.

Each book should display:

- Cover image.
- Title.
- Author, if known.
- Reading progress.
- Last opened time.
- Continue Reading button.

### My Library

All imported or manually created books.

Support:

- Grid view.
- List view.
- Cover thumbnails.
- Search.
- Sorting.
- Filters.
- Custom shelves.

### Quick Actions

Provide prominent actions:

- Add a Book.
- Continue Reading.
- Import from Device.
- Explore Library.
- Reading Statistics.
- Help.

Do not make the entire experience depend on a single floating `+` button.

### First-use state

If the library is empty, show an attractive introductory screen explaining what users can do.

Provide:

**Import a Book**

**Try a Sample**

**How to Read**

Sample content must be legally redistributable, bundled or locally generated, and clearly identified as a sample.

Do not automatically populate the user's real library with fictional records presented as personal books.

---

# 4. IMPORT AND READ ELECTRONIC BOOKS

This is the most important requirement.

Users must be able to select supported book files from their Android device and read them directly inside Bilga.

## Required formats

### Priority 1 — Must be fully supported

**PDF**
- Import local PDF files.
- Display pages accurately.
- Navigate pages.
- Zoom and pan.
- Remember reading position.
- Support bookmarks.
- Support available text selection where technically possible.
- Support search for text-based PDFs.
- Handle scanned/image-based PDFs gracefully.

**EPUB**
- Import EPUB files.
- Render chapters and text.
- Support adjustable font size.
- Support themes.
- Support bookmarks.
- Remember reading position.
- Support table of contents.
- Support selectable text.
- Support highlights and annotations where feasible.

**TXT**
- Import UTF-8 and other safely detectable common text encodings.
- Display long text comfortably.
- Support adjustable typography.
- Remember reading position.
- Search.
- Bookmarks.

### Priority 2 — Additional formats

Evaluate and implement reliable support for:

- FB2.
- HTML.
- DOCX.
- RTF.

Use maintained libraries or carefully implemented parsers.

Do not claim complete support for formats that only work partially.

If a format cannot be rendered reliably in the first implementation, offer an explicit import limitation or a safe external-open option.

Do not create fake support by merely recognizing a file extension.

### Format compatibility

Detect the actual file type where practical.

Handle:

- Incorrect extensions.
- Corrupted files.
- Unsupported encryption.
- DRM-protected books.
- Very large files.
- Missing fonts.
- Unsupported embedded content.

Do not bypass DRM.

Do not promise to open protected books unless legally and technically supported.

---

# 5. ANDROID FILE IMPORT EXPERIENCE

Implement a simple workflow:

1. User taps "Add Book."
2. Android file picker opens.
3. User chooses PDF, EPUB or another supported format.
4. Bilga validates the file.
5. Bilga adds it to the library.
6. The book cover/title are extracted when possible.
7. The book is immediately available to read.

Do not require the user to manually enter metadata before opening a valid book.

Use Android Storage Access Framework.

Avoid unnecessary broad-storage permissions.

Provide a clear choice between safely importing a private app-managed copy and referencing a document through persistent access where supported.

The default should prioritize long-term reliability.

If an external reference becomes unavailable, clearly explain how to relink the file.

Do not silently lose access.

Handle duplicate imports.

Use content hashes or other appropriate identifiers to recognize duplicates without making incorrect assumptions.

Offer:

- Open existing copy.
- Import another copy.
- Cancel.

Do not silently create duplicate library entries.

---

# 6. AUTOMATIC BOOK INFORMATION

Extract metadata when available.

Possible fields:

- Book title.
- Author.
- Cover image.
- Language.
- Number of pages, when meaningful.
- EPUB table of contents.
- Publisher.
- Publication year.
- ISBN.

However:

**ISBN must be optional and hidden in Advanced Details by default.**

Do not require ISBN.

Do not require publication year.

Do not require publisher.

Do not require genre.

Do not require an author.

A user must be able to open and read a PDF even if absolutely no metadata exists.

If metadata is missing, derive a reasonable provisional title from the filename.

Allow the user to edit all automatically populated descriptive fields.

Do not fabricate publication information.

For scanned PDFs, do not pretend that embedded text is available when the document contains only images.

---

# 7. PROFESSIONAL PDF READER

Develop a comfortable integrated PDF-reading experience.

Required:

- Full-screen reading.
- Page navigation.
- Vertical scrolling.
- Optional page-by-page mode.
- Pinch-to-zoom.
- Double-tap zoom where practical.
- Smooth panning.
- Jump to page.
- Page indicator.
- Reading progress.
- Recently opened position.
- Bookmarks.
- Search for embedded text.
- Page thumbnails when practical.
- Orientation changes.
- Tablet optimization.
- Landscape support.
- Dark reader controls.

### Performance

Do not render an entire large PDF into memory.

Use lazy page loading, rendering caches and memory limits.

Support large textbooks with hundreds of pages.

Avoid freezing the application.

Avoid excessive RAM consumption.

### Reading position

If the user closes a PDF on page 154, reopening the same document should return to page 154, preferably preserving the approximate scroll and zoom position where reliable.

Persist position automatically.

Make this resilient to app backgrounding, normal termination and unexpected interruption.

### Scanned PDFs

Image-only PDFs must still be readable.

Text search or highlighting may be unavailable without OCR.

Do not silently pretend otherwise.

OCR is not mandatory for this phase.

---

# 8. PROFESSIONAL EPUB READER

Implement a comfortable reflowable-text reading experience.

Required:

- Adjustable font size.
- Adjustable line spacing.
- Adjustable margins.
- Font-family selection.
- Light theme.
- Dark theme.
- Sepia theme.
- Chapter navigation.
- Table of contents.
- Reading progress.
- Bookmarks.
- Text selection.
- Search.
- Highlighting.
- Personal annotations.

Handle long chapters efficiently.

Preserve reading position using stable document locators rather than fragile pixel offsets.

For example, use appropriate EPUB location identifiers or equivalent persistent references.

Do not assume that fixed page numbers remain valid after changing font size.

Handle valid Unicode text and right-to-left languages correctly.

---

# 9. BOOKMARKS, HIGHLIGHTS AND ANNOTATIONS

Users must be able to save important reading positions.

Implement:

### Bookmarks

- Add bookmark.
- Remove bookmark.
- View bookmarks.
- Jump to bookmark.
- Optional bookmark label.

### Highlights

Where supported by the document renderer:

- Select text.
- Highlight selected text.
- Choose highlight color.
- View all highlights.
- Navigate back to the source.

### Notes

Allow personal notes linked to a book location.

Examples:

- "This idea is important."
- "I disagree with this argument."
- "Use this concept in my project."
- "Review this chapter later."

Each note should retain a link to the relevant page, chapter or supported text location.

For scanned PDFs, support page-linked notes even if text selection is unavailable.

Never corrupt the original book file when saving annotations.

Store annotations separately unless a reliable and explicit document-export feature is implemented.

---

# 10. READING PROGRESS

Track reading progress automatically.

Support:

- Current page or EPUB location.
- Percentage completed.
- Last reading session.
- Last opened time.
- Reading status.
- Finished date.

Statuses:

- Want to Read.
- Currently Reading.
- Completed.
- Paused.
- Abandoned.

If a book has 300 fixed pages and the reader reaches page 150, progress should be approximately halfway.

For EPUB, use an appropriate estimate independent of visual page reflow where possible.

Avoid inaccurate progress calculations.

Let the user manually mark a book as finished.

Do not automatically mark it finished because they briefly opened the last page.

---

# 11. READING SESSIONS AND STATISTICS

Provide practical reading statistics.

Track:

- Reading sessions.
- Session duration.
- Reading days.
- Books completed.
- Reading progress.
- Reading streaks.
- Daily reading activity.
- Weekly activity.
- Monthly activity.

Distinguish active reading time from time spent with the app open in the background.

Pause session tracking when reading is not active.

Do not fabricate reading time.

Provide clean visualizations.

Statistics should be useful rather than decorative.

---

# 12. KNOWLEDGE CARDS

Bilga must help users remember what they read.

However, knowledge cards must be optional.

Do not interrupt ordinary reading.

Provide an action:

**Save as Knowledge Card**

Support these card types:

- Important Idea.
- Quote.
- Definition.
- Personal Explanation.
- Question and Answer.
- Practical Lesson.
- Summary.
- Comparison.
- Critical Observation.
- Actionable Insight.

A knowledge card should contain:

- Card type.
- Title or prompt.
- Main content.
- Optional personal explanation.
- Associated book.
- Page or chapter reference.
- Tags.
- Creation date.

Cards must be editable.

Users must be able to create cards manually or from selected text where supported.

Keep an easy route back to the original reading location.

---

# 13. FLASHCARDS AND REVIEW

Implement a practical flashcard system.

Support:

- Question and answer cards.
- Flip-card interaction.
- Review sessions.
- Due cards.
- Review history.
- Basic spaced repetition.
- Progress indicators.

Use a documented scheduling algorithm.

Persist card scheduling state.

Handle overdue reviews.

Avoid changing historical review information incorrectly.

Users should understand why a card is due for review.

The review system must remain optional.

Ordinary users should be able to read books without ever opening flashcards.

---

# 14. LIBRARY ORGANIZATION

Support advanced organization without overwhelming the default interface.

Features:

- Custom bookshelves.
- Favorites.
- Tags.
- Genres.
- Categories.
- Search.
- Sorting.
- Filters.
- Reading status.
- Recently opened.
- Recently added.
- Completed books.

Suggested default shelves:

- Currently Reading.
- Want to Read.
- Completed.
- Favorites.

Users may add custom shelves.

Do not force organizational fields during import.

---

# 15. BUILT-IN READING TEMPLATES

The user should not encounter an empty, confusing interface.

Provide built-in templates and actionable workflows.

Examples:

### Reading Note

- Main idea.
- Important quote.
- My interpretation.
- Practical application.

### Chapter Summary

- Chapter.
- Key concepts.
- Important examples.
- What I learned.

### Book Review

- Main argument.
- Strengths.
- Weaknesses.
- Personal evaluation.
- Most useful lessons.

### Study Card

- Question.
- Answer.
- Explanation.
- Source location.

### Reading Goal

- Book.
- Target completion date.
- Reading schedule.
- Progress.

Templates must be editable.

Preview the template before creating a record.

Do not create unwanted entries automatically.

---

# 16. BUILT-IN INTERACTIVE HELP

The Books module must include an interactive, deterministic tutorial system.

This is not AI.

Use the existing tutorial architecture where possible.

Provide:

- How to Add a Book.
- How to Read a PDF.
- How to Read an EPUB.
- How to Change Font Size.
- How to Save a Bookmark.
- How to Highlight Text.
- How to Create a Knowledge Card.
- How to Review Flashcards.
- How to Organize Bookshelves.
- How to Continue Reading.

### Example: Import a PDF

1. User taps "Show Me How."
2. Bilga opens the correct screen.
3. The Add Book button is visually highlighted.
4. User taps it.
5. Bilga explains file selection.
6. Android file picker opens.
7. User chooses a file.
8. Bilga validates and imports the file.
9. The library displays the imported book.
10. The tutorial highlights "Read."
11. User opens the book.
12. Bilga explains basic navigation.

Support:

- Back.
- Next.
- Skip.
- Exit.
- Resume where appropriate.

Tutorials must interact with real controls.

Do not simulate completion without the corresponding successful action.

Handle Android file-picker cancellation safely.

Do not require AI or internet access.

---

# 17. INTEGRATION WITH OTHER BILGA MODULES

The Books module must integrate with the rest of Bilga.

Examples:

### Books → Notes

Save selected text or a knowledge card as a Note.

### Books → Tasks

Create a task such as:

"Finish chapter 5 by Friday."

### Books → Habits

Create a reading habit using an existing habit template.

### Books → Experiences

Save a personal learning experience or reflection based on a book.

### Books → Planning

Display relevant reading goals and commitments in the planning system where appropriate.

Use stable links.

Avoid creating inconsistent duplicate records.

Ensure links survive supported backup and restore operations.

---

# 18. BACKUP AND DATA SAFETY

Book files, reading progress, bookmarks, highlights, personal notes and knowledge cards are valuable user data.

Implement appropriate backup behavior.

Support:

- Local encrypted backup.
- Restoration.
- Portable library metadata.
- Reading progress.
- Bookmarks.
- Highlights.
- Annotations.
- Knowledge cards.
- Review history.
- Book file attachments where selected and supported.

Do not silently omit imported book files from a backup that claims to include them.

Make backup options explicit:

- Metadata and reading data only.
- Full backup including supported locally managed book files.

Handle large files efficiently.

Avoid loading entire libraries into memory.

Use streaming when appropriate.

Clearly explain backup size and storage requirements.

Never delete existing reading data during schema migrations.

Test recovery and compatibility.

---

# 19. ANDROID TABLET TESTING

Use the connected Android tablet.

The existing device is expected to be a Blackview Tab16, but verify the actual ADB device.

Use the isolated Bilga Review application.

Do not uninstall, reset or overwrite the production Bilga installation.

Test:

1. Import a PDF.
2. Open and read the PDF.
3. Navigate to another page.
4. Close and reopen at the saved position.
5. Add and reopen a bookmark.
6. Search within a text-based PDF.
7. Import an EPUB.
8. Change EPUB typography.
9. Navigate chapters.
10. Save and reopen a highlight.
11. Import a TXT book.
12. Create a knowledge card.
13. Review a flashcard.
14. Change reading status.
15. Search the library.
16. Add a book to a shelf.
17. Export and restore reading data.
18. Test an invalid document.
19. Test a large document.
20. Rotate the tablet during reading.

Use legally redistributable or locally generated test documents.

Do not claim support for a format that fails its relevant real-device acceptance tests.

Fix crashes, layout problems and persistence defects.

---

# 20. MEMORY AND PERFORMANCE

The development laptop has limited physical RAM and previously experienced an OOM event.

Avoid running multiple expensive build processes simultaneously.

Prefer the connected physical tablet over unnecessary emulators.

Use appropriate build concurrency limits.

For the Android application:

- Lazy-load pages.
- Use bounded caches.
- Dispose rendering resources.
- Avoid memory leaks.
- Avoid excessive background work.
- Handle large PDF files gracefully.
- Handle large EPUB books gracefully.

Optimize for ordinary Android phones and tablets.

---

# 21. VISUAL DESIGN

The reader must look professional and comfortable.

Use Bilga's existing design language.

The default reader should emphasize the book content.

Avoid showing unnecessary controls permanently.

Use contextual controls that can appear and disappear without confusing the reader.

Provide:

- Comfortable margins.
- Readable typography.
- High contrast.
- Accessible controls.
- Tablet layouts.
- Landscape support.
- Dark mode.
- Clear progress indicators.

The interface must not resemble a complex metadata-entry database.

Keep bibliographic fields inside optional Advanced Details.

Do not require users to complete advanced forms before reading.

---

# 22. COPYRIGHT AND PRIVACY

Only import files that the user is authorized to access.

Do not implement DRM circumvention.

Do not automatically download copyrighted books from unauthorized sources.

Do not upload personal books to remote servers without explicit consent.

Keep the reading system offline-first.

Do not add unnecessary trackers.

If an external metadata source is used, make requests optional and disclose them.

---

# 23. PRESERVE EXISTING DEVELOPMENT

Do not rebuild the entire application unnecessarily.

Preserve:

- Notes.
- Tasks.
- Habits.
- Finance.
- Experiences.
- Existing Books records.
- Existing reading history.
- Existing bookmarks.
- Existing databases.
- Existing encryption.
- Existing backups.
- Existing migrations.
- Trial system.
- Purchase architecture.
- Localization.
- Seven themes.

Extend existing structures safely.

Create versioned migrations.

Maintain backward compatibility.

Use the current development branch and draft PR #1.

Do not merge into main.

Do not publish to Google Play.

Do not activate paid services.

---

# 24. COMPLETION REQUIREMENTS

The Books module is not complete until the following user journey works:

**Open Bilga → Books → Add Book → Select PDF/EPUB → Import → Read → Close → Reopen → Continue Reading → Bookmark → Highlight/Annotate where supported → Create Knowledge Card → Review Card → Backup → Restore.**

This entire journey must be implemented and tested.

Do not consider the feature complete merely because a file appears in the library.

Do not stop after implementing import without the reader.

Do not stop after implementing the reader without persistent reading progress.

Do not stop after adding UI controls without real behavior.

Implement complete functionality.

---

# 25. EXECUTION ORDER

Follow this priority order:

**PHASE 1:** Audit the existing Books module.

**PHASE 2:** Implement reliable PDF, EPUB and TXT import and reading.

**PHASE 3:** Implement persistent reading progress, bookmarks and navigation.

**PHASE 4:** Implement highlights, annotations and reader customization.

**PHASE 5:** Implement knowledge cards and flashcards.

**PHASE 6:** Implement reading statistics and library organization.

**PHASE 7:** Implement templates and interactive tutorials.

**PHASE 8:** Complete cross-module integrations.

**PHASE 9:** Verify encrypted backups, migrations and recovery.

**PHASE 10:** Run automated tests and actual-tablet acceptance tests.

**PHASE 11:** Generate a review APK, document results, commit and push the checkpoint.

Do not stop after planning.

Continue implementing the prioritized requirements.

If execution is interrupted, preserve the exact checkpoint in the existing project documentation.

---

# 26. FINAL PRODUCT OWNER REQUIREMENT

I do not want a bibliographic catalog disguised as a reading application.

I want a real electronic library.

A normal user should be able to import a PDF or EPUB and start reading immediately.

A student should be able to read textbooks, save important passages and create study cards.

An advanced reader should be able to organize knowledge and review important ideas.

An ordinary reader should not have to deal with unnecessary metadata.

The Books module must be simple at the surface and powerful underneath.

**Build the reader first. Make it reliable. Then complete the advanced features.**

Voice control remains deferred until the owner approves the completed non-voice application.

**START IMPLEMENTATION NOW.**
