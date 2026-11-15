import 'dart:convert';
import 'dart:io';

import 'package:bilga/core/strings.dart';
import 'package:bilga/features/agent/agent_access.dart';
import 'package:bilga/features/books/book_library_page.dart';
import 'package:bilga/features/books/reading/book_importer.dart';
import 'package:bilga/features/books/reading/book_reading_page.dart';
import 'package:bilga/features/books/reading/reading_hub.dart';
import 'package:bilga/features/books/reading/reading_store.dart';
import 'package:bilga/features/notes/note_database.dart';
import 'package:bilga/features/private_space/record_store.dart';
import 'package:flutter/material.dart';
import 'package:bilga/features/guidance/guide_host.dart';
import 'package:flutter_test/flutter_test.dart';

import 'reading_fixtures.dart';

void registerReadingUiCases({
  Future<Directory> Function()? createDirectory,
  bool secure = false,
}) {
  Future<void> settle(WidgetTester t) async {
    var quiet = 0;
    for (var i = 0; i < 150; i++) {
      await t.pump(const Duration(milliseconds: 40));
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      final dialogs = find.byType(AlertDialog);
      final modalReady =
          dialogs.evaluate().isNotEmpty &&
          ModalRoute.of(t.element(dialogs.first))?.animation?.status ==
              AnimationStatus.completed;
      if (secure && i < 10) continue;
      if (find.byType(CircularProgressIndicator).evaluate().isEmpty &&
          (modalReady || !t.binding.hasScheduledFrame)) {
        if (++quiet >= 3) return;
      } else {
        quiet = 0;
      }
    }
    debugDumpApp();
    throw StateError(
      'Reader UI did not settle after waiting for actual fixture I/O',
    );
  }

  Future<void> tap(WidgetTester t, Finder finder) async {
    await t.ensureVisible(finder);
    await t.tap(finder);
    await settle(t);
  }

  Future<void> save(WidgetTester t) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await settle(t);
    await tap(t, find.widgetWithText(TextButton, Strings.get('en', 'save')));
  }

  Future<(Directory, ReadingStore, AgentAccess)> fixture(
    WidgetTester t,
  ) async => (await t.runAsync(() async {
    await Strings.load();
    final dir =
        await (createDirectory?.call() ??
            Directory.systemTemp.createTemp('bilga-reading-ui-'));
    final db = await NoteDatabase.openAt(
      '${dir.path}/notes.db',
      secure: secure,
    );
    return (
      dir,
      ReadingStore(
        records: RecordStore(database: db),
        vault: FixtureBookVault(Directory('${dir.path}/vault')),
        previewRoot: dir,
      ),
      AgentAccess()..owned.add(AgentAccess.core),
    );
  }))!;
  Future<void> dispose(
    WidgetTester t,
    Directory dir,
    ReadingStore store,
    AgentAccess access,
  ) async {
    await t.pumpWidget(const SizedBox.shrink());
    await settle(t);
    await t.runAsync(() async {
      await (await store.db).close();
      await dir.delete(recursive: true);
    });
    access.dispose();
  }

  testWidgets(
    'Actual TXT import opens reader, persists bookmark and location, creates/reviews a real question card',
    (t) async {
      final (dir, store, access) = await fixture(t);
      try {
        final importer = BookImporter(store);
        await t.pumpWidget(
          MaterialApp(
            home: BookLibraryPage(
              reading: store,
              records: store.records,
              access: access,
              picker: () async => [
                {'uri': 'fixture', 'name': 'Original.txt'},
              ],
              prepareImport: (choice) => importer.prepare(
                Stream.value(
                  utf8.encode(
                    List.generate(
                      60,
                      (i) =>
                          'Original paragraph $i. Read and remember this idea.',
                    ).join('\n\n'),
                  ),
                ),
                choice['name'],
              ),
            ),
          ),
        );
        await settle(t);
        await tap(t, find.byKey(const Key('book-library-add')));
        expect(find.byType(BookReadingPage), findsOneWidget);
        expect(find.byType(SelectableText), findsWidgets);
        await tap(t, find.byKey(const Key('reader-bookmark')));

        await t.enterText(find.byType(TextField).first, 'Remember this page');
        await save(t);
        final book = (await t.runAsync(() => store.records.all('book')))!
            .single;
        expect(
          await t.runAsync(() => store.rows(book.id, 'bookmark')),
          hasLength(1),
        );
        await t.drag(find.byType(Scrollable).first, const Offset(0, -600));
        await settle(t);
        await t.pump(const Duration(seconds: 1));
        await settle(t);
        final progress = (await t.runAsync(
          () => store.one(book.id, 'progress'),
        ))!;
        expect(progress.data['location']['block'], greaterThan(0));
        await t.pageBack();
        await settle(t);
        await tap(t, find.byKey(ValueKey('book-current-read-${book.id}')));
        expect(find.byType(BookReadingPage), findsOneWidget);
        await t.longPress(find.byType(SelectableText).hitTestable().first);
        await settle(t);
        final highlight = find.text(Strings.get('en', 'rKind_highlight'));
        if (highlight.evaluate().isEmpty) {
          final overflow = find.descendant(
            of: find.byType(AdaptiveTextSelectionToolbar),
            matching: find.byIcon(Icons.more_vert),
          );
          if (overflow.evaluate().isNotEmpty) await tap(t, overflow.first);
        }
        await tap(t, highlight);
        await tap(t, find.text('Yellow'));
        await save(t);
        expect(
          await t.runAsync(() => store.rows(book.id, 'highlight')),
          hasLength(1),
        );
        await tap(t, find.byIcon(Icons.more_vert));
        await tap(t, find.text(Strings.get('en', 'rReadingNotes')));
        expect(find.byType(ReadingHub), findsOneWidget);
        await tap(t, find.byKey(const Key('reading-kind-card')));
        await tap(t, find.byKey(const Key('reading-add-card')));
        await tap(t, find.text(Strings.get('en', 'rCard_question')));
        await t.enterText(find.byType(TextField).at(0), 'What helps memory?');
        await t.enterText(find.byType(TextField).at(1), 'Explain and review.');
        await save(t);
        expect(
          await t.runAsync(() => store.rows(book.id, 'card')),
          hasLength(1),
        );
        await tap(t, find.byKey(const Key('reading-review-due')));
        expect(find.text('What helps memory?'), findsOneWidget);
        expect(await t.runAsync(() => store.rows(book.id, 'review')), isEmpty);
        await tap(t, find.byIcon(Icons.help_outline));
        await tap(t, find.byKey(const Key('flashcard-flip')));
        await tap(t, find.byKey(const Key('guide-back')));
        expect(find.byKey(const Key('flashcard-flip')), findsOneWidget);
        await tap(t, find.byKey(const Key('flashcard-flip')));
        expect(find.text('Explain and review.'), findsOneWidget);
        await tap(t, find.byKey(const Key('flashcard-rate-2')));
        expect(
          await t.runAsync(() => store.rows(book.id, 'review')),
          hasLength(1),
        );
        expect(t.takeException(), isNull);
      } finally {
        await dispose(t, dir, store, access);
      }
    },
  );
  testWidgets(
    'EPUB reader changes typography, navigates chapters and read-only reading never mutates saved data',
    (t) async {
      final (dir, store, access) = await fixture(t);
      try {
        final c = (await t.runAsync(
          () =>
              BookImporter(store)
                  .prepare(Stream.value(fixtureEpub()), 'Original.epub'),
        ))!;
        final book = (await t.runAsync(
          () => BookImporter(store).commit(c, allowed: () => true),
        ))!;
        await t.pumpWidget(
          MaterialApp(
            home: BookReadingPage(book: book, store: store, access: access),
          ),
        );
        await settle(t);
        expect(find.text('First chapter'), findsWidgets);
        await tap(t, find.byKey(const Key('reader-appearance')));
        await tap(t, find.text('Sepia'));
        await tap(t, find.text(Strings.get('en', 'gFinish')));
        final settings = (await t.runAsync(
          () => store.one(book.id, 'settings'),
        ))!;
        expect(settings.data['theme'], 'sepia');
        await tap(t, find.byIcon(Icons.chevron_right).last);
        expect(find.text('فصل دوم'), findsWidgets);
        await t.pumpWidget(const SizedBox.shrink());
        await settle(t);
        final before = await t.runAsync(
          () => (store.db).then((db) => db.query('book_reading')),
        );
        await t.pumpWidget(
          MaterialApp(
            home: BookReadingPage(
              book: book,
              store: store,
              access: access,
              readOnly: true,
            ),
          ),
        );
        await settle(t);
        expect(find.text('فصل دوم'), findsWidgets);
        final mark = t.widget<IconButton>(
          find.ancestor(
            of: find.byKey(const Key('reader-bookmark')),
            matching: find.byType(IconButton),
          ),
        );
        expect(mark.onPressed, isNull);
        await t.pumpWidget(const SizedBox.shrink());
        await settle(t);
        expect(
          await t.runAsync(
            () => (store.db).then((db) => db.query('book_reading')),
          ),
          before,
        );
        await t.runAsync(c.close);
        expect(t.takeException(), isNull);
      } finally {
        await dispose(t, dir, store, access);
      }
    },
  );
  testWidgets(
    'Picker cancellation and duplicate decisions never silently add another book',
    (t) async {
      final (dir, store, access) = await fixture(t);
      var picks = 0;
      try {
        await t.pumpWidget(
          MaterialApp(
            home: BookLibraryPage(
              records: store.records,
              reading: store,
              access: access,
              picker: () async => ++picks == 1
                  ? []
                  : [
                      {'name': 'Original.txt'},
                    ],
              prepareImport: (_) => BookImporter(store).prepare(
                Stream.value(utf8.encode('A duplicate original passage.')),
                'Original.txt',
              ),
            ),
          ),
        );
        await settle(t);
        await tap(t, find.byKey(const Key('book-library-add')));
        expect(await t.runAsync(() => store.records.all('book')), isEmpty);
        await tap(t, find.byKey(const Key('book-library-add')));
        await t.pageBack();
        await settle(t);
        await tap(t, find.byKey(const Key('book-library-add')));
        expect(find.text(Strings.get('en', 'rDuplicate')), findsOneWidget);
        await tap(
          t,
          find.widgetWithText(TextButton, Strings.get('en', 'cancel')),
        );
        expect(await t.runAsync(() => store.records.all('book')), hasLength(1));
        await tap(t, find.byKey(const Key('book-library-add')));
        await tap(t, find.text(Strings.get('en', 'rOpenExisting')));
        expect(find.byType(BookReadingPage), findsOneWidget);
        await t.pageBack();
        await settle(t);
        await tap(t, find.byKey(const Key('book-library-add')));
        await tap(t, find.text(Strings.get('en', 'rAnotherCopy')));
        expect(find.byType(BookReadingPage), findsOneWidget);
        expect(await t.runAsync(() => store.records.all('book')), hasLength(2));
        expect(t.takeException(), isNull);
      } finally {
        await dispose(t, dir, store, access);
      }
    },
  );
  testWidgets(
    'Bookmark help advances only after actual Save and survives editor cancellation',
    (t) async {
      final (dir, store, access) = await fixture(t);
      try {
        final c = (await t.runAsync(
          () => BookImporter(store).prepare(
            Stream.value(utf8.encode('Original guided reading passage.')),
            'Guided.txt',
          ),
        ))!;
        final book = (await t.runAsync(
          () => BookImporter(store).commit(c, allowed: () => true),
        ))!;
        await t.pumpWidget(
          MaterialApp(
            home: BookReadingPage(book: book, store: store, access: access),
          ),
        );
        await settle(t);
        await tap(t, find.byIcon(Icons.more_vert));
        await tap(t, find.text(Strings.get('en', 'rHelp')));
        await tap(t, find.text(Strings.get('en', 'rKind_bookmark')));
        var controller = t.widget<GuideHost>(find.byType(GuideHost)).controller;
        expect(controller.index, 0);
        expect(controller.canNext, isFalse);
        await tap(t, find.byKey(const Key('reader-bookmark')));
        await t.pageBack();
        await settle(t);
        expect(controller.index, 0);
        expect(
          await t.runAsync(() => store.rows(book.id, 'bookmark')),
          isEmpty,
        );
        await tap(t, find.byKey(const Key('reader-bookmark')));
        await save(t);
        expect(controller.index, 1);
        expect(controller.canBack, isFalse);
        expect(
          await t.runAsync(() => store.rows(book.id, 'bookmark')),
          hasLength(1),
        );
        await tap(t, find.byKey(const Key('guide-next')));
        expect(controller.active, isFalse);
        await t.runAsync(c.close);
        expect(t.takeException(), isNull);
      } finally {
        await dispose(t, dir, store, access);
      }
    },
  );
  testWidgets(
    'Reading navigation guide highlights working chapter controls and saves the new location',
    (t) async {
      final (dir, store, access) = await fixture(t);
      try {
        final c = (await t.runAsync(
          () =>
              BookImporter(store)
                  .prepare(Stream.value(fixtureEpub()), 'Guided.epub'),
        ))!;
        final book = (await t.runAsync(
          () => BookImporter(store).commit(c, allowed: () => true),
        ))!;
        await t.pumpWidget(
          MaterialApp(
            home: BookReadingPage(book: book, store: store, access: access),
          ),
        );
        await settle(t);
        await tap(t, find.byIcon(Icons.more_vert));
        await tap(t, find.text(Strings.get('en', 'rHelp')));
        await tap(t, find.text('EPUB / TXT'));
        final controller = t
            .widget<GuideHost>(find.byType(GuideHost))
            .controller;
        expect(controller.canNext, isFalse);
        await tap(t, find.byIcon(Icons.chevron_right).last);
        expect(controller.index, 1);
        expect(controller.canBack, isFalse);
        expect(
          (await t.runAsync(() => store.one(book.id, 'progress')))!
              .data['location']['section'],
          'OEBPS/text/two.xhtml',
        );
        await tap(t, find.byKey(const Key('guide-next')));
        await t.runAsync(c.close);
        expect(t.takeException(), isNull);
      } finally {
        await dispose(t, dir, store, access);
      }
    },
  );
}
