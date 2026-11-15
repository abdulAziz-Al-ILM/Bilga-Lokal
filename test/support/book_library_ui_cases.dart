import 'dart:io';
import 'dart:async';

import 'package:bilga/core/strings.dart';
import 'package:bilga/features/agent/agent_access.dart';
import 'package:bilga/features/books/book_details_editor.dart';
import 'package:bilga/features/books/book_library.dart';
import 'package:bilga/features/books/book_library_store.dart';
import 'package:bilga/features/books/book_library_page.dart';
import 'package:bilga/features/notes/note_database.dart';
import 'package:bilga/features/private_space/record_store.dart';
import 'package:bilga/features/private_space/space_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

void registerBookLibraryUiTests({
  Future<Directory> Function()? createDirectory,
  bool secure = false,
  bool includeCompact = true,
  VoidCallback? onUiVerified,
}) {
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 25; i++) {
      await tester.pump(const Duration(milliseconds: 20));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
    }
    await tester.pumpAndSettle();
  }

  Future<void> show(WidgetTester tester, Finder finder) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await settle(tester);
    if (finder.evaluate().isEmpty) {
      tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .jumpTo(0);
      await settle(tester);
      await tester.scrollUntilVisible(
        finder,
        250,
        scrollable: find.byType(Scrollable).first,
      );
    }
    await tester.ensureVisible(finder);
    await settle(tester);
  }

  Future<void> fill(WidgetTester tester, String key, String text) async {
    final finder = find.byKey(ValueKey('book-detail-$key'));
    await show(tester, finder);
    // The live binding retains focusedEditable after native unfocus. Reusing
    // showKeyboard for the same field can therefore skip requestKeyboard and
    // inject into a closed client. A real tap reopens the correct field.
    await tester.tap(
      find.descendant(of: finder, matching: find.byType(EditableText)),
    );
    await settle(tester);
    await tester.enterText(finder, text);
    await settle(tester);
    expect(tester.widget<TextFormField>(finder).controller!.text, text);
    FocusManager.instance.primaryFocus?.unfocus();
    await settle(tester);
    expect(tester.widget<TextFormField>(finder).controller!.text, text);
  }

  Future<void> press(WidgetTester tester, Key key) async {
    final finder = find.byKey(key);
    await show(tester, finder);
    await tester.tap(finder);
    await settle(tester);
  }

  Future<(Directory, Database, RecordStore, PrivateRecord?)> fixture(
    WidgetTester tester, {
    bool empty = false,
  }) async => (await tester.runAsync(() async {
    await Strings.load(code: 'en');
    final dir =
        await (createDirectory?.call() ??
            Directory.systemTemp.createTemp('bilga-books-ui-'));
    final db = await NoteDatabase.openAt(
      '${dir.path}/notes.db',
      secure: secure,
    );
    final store = RecordStore(database: db);
    final record = empty
        ? null
        : await store.save('book', {
            'title': 'Legacy reading',
            'characters': 'Original characters',
            'bookmark': 1,
            'chapters': [
              {
                'title': 'One',
                'body': 'Original complete content',
                'versions': [
                  {
                    'title': 'Earlier',
                    'body': 'Earlier content',
                    'date': '2020-01-01',
                  },
                ],
              },
              {
                'title': 'Two',
                'body': 'Second chapter',
                'versions': <dynamic>[],
              },
            ],
          });
    return (dir, db, store, record);
  }))!;
  Future<List<PrivateRecord>> read(
    WidgetTester tester,
    RecordStore store,
  ) async => (await tester.runAsync(() => store.all('book')))!;
  testWidgets(
    'Book library creates validated metadata, filters reading/favorites and searches author without losing details',
    (tester) async {
      final (dir, db, store, _) = await fixture(tester, empty: true);
      final access = AgentAccess()..owned.add(AgentAccess.core);
      try {
        await tester.pumpWidget(
          MaterialApp(
            home: BookLibraryPage(records: store, access: access),
          ),
        );
        await settle(tester);
        await press(tester, const Key('book-library-add'));
        await fill(tester, 'title', 'Personal library book');
        await fill(tester, 'author', 'Saved author');
        await fill(
          tester,
          'description',
          '  Saved annotation\nwith formatting  ',
        );
        await press(tester, const Key('book-detail-status'));
        await tester.tap(find.text('Reading').last);
        await settle(tester);
        await fill(tester, 'pages', '250');
        await fill(tester, 'currentPage', '42');
        await fill(tester, 'isbn', '9780306406158');
        await press(tester, const Key('book-details-save'));
        expect(
          find.text('Enter a valid ISBN-10 or ISBN-13, or leave it empty.'),
          findsOneWidget,
        );
        expect(await read(tester, store), isEmpty);
        await fill(tester, 'isbn', '978-0-306-40615-7');
        await fill(tester, 'tags', 'Study, personal');
        await fill(tester, 'shelves', 'Home');
        await press(tester, const Key('book-detail-favorite'));
        for (final item in {
          'title': 'Personal library book',
          'pages': '250',
          'currentPage': '42',
          'isbn': '978-0-306-40615-7',
        }.entries) {
          expect(
            tester
                .widget<TextFormField>(
                  find.byKey(ValueKey('book-detail-${item.key}')),
                )
                .controller!
                .text,
            item.value,
          );
        }
        await press(tester, const Key('book-details-save'));
        for (
          var i = 0;
          i < 40 && find.byType(RecordPage).evaluate().isEmpty;
          i++
        ) {
          await tester.pump(const Duration(milliseconds: 100));
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 50)),
          );
        }
        if (find.byType(RecordPage).evaluate().isEmpty) {
          // Only the synthetic test fixture is mounted. Keep diagnostics scoped
          // to validation/status; do not log owner databases or real content.
          final errors = tester
              .widgetList<InputDecorator>(find.byType(InputDecorator))
              .map((w) => w.decoration.errorText)
              .whereType<String>()
              .toList();
          debugPrint(
            'Synthetic Book save diagnostic: errors=$errors, '
            'savedRows=${(await read(tester, store)).length}, '
            'saveErrorVisible=${find.text(Strings.get('en', 'saveError')).evaluate().isNotEmpty}',
          );
        }
        expect(find.byType(RecordPage), findsOneWidget);
        var saved = (await read(tester, store)).single;
        final meta = BookLibrary.metadata(saved.data);
        expect(meta['author'], 'Saved author');
        expect(meta['description'], '  Saved annotation\nwith formatting  ');
        expect(meta['status'], 'reading');
        expect(meta['isbn'], '9780306406157');
        expect(meta['pages'], 250);
        expect(meta['currentPage'], 42);
        expect(meta['favorite'], true);
        expect(meta['tags'], ['Study', 'personal']);
        expect(meta['shelves'], ['Home']);
        await tester.pageBack();
        await settle(tester);
        await press(tester, const Key('book-filter-status-all'));
        await tester.tap(find.text('Want to read').last);
        await settle(tester);
        expect(
          find.byKey(ValueKey('book-library-row-${saved.id}')),
          findsNothing,
        );
        await press(tester, const Key('book-filter-status-planned'));
        await tester.tap(find.text('Reading').last);
        await settle(tester);
        await press(tester, const Key('book-library-favorites'));
        await show(
          tester,
          find.byKey(ValueKey('book-library-row-${saved.id}')),
        );
        expect(find.text('Personal library book'), findsOneWidget);
        await show(tester, find.byKey(const Key('book-library-search')));
        await tester.enterText(
          find.byKey(const Key('book-library-search')),
          'Saved author',
        );
        await settle(tester);
        await show(
          tester,
          find.byKey(ValueKey('book-library-row-${saved.id}')),
        );
        expect(find.text('Personal library book'), findsOneWidget);
        saved = (await read(tester, store)).single;
        expect(saved.revision, 1);
        expect(tester.takeException(), isNull);
        onUiVerified?.call();
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(() async {
          await db.close();
          await dir.delete(recursive: true);
        });
        access.dispose();
      }
    },
  );
  testWidgets(
    'Book metadata editor retains draft after failed storage and preserves legacy chapters/history/bookmark',
    (tester) async {
      final (dir, db, store, original) = await fixture(tester);
      final access = AgentAccess()..owned.add(AgentAccess.core);
      try {
        await tester.pumpWidget(
          MaterialApp(
            home: RecordPage(original!, store: store, access: access),
          ),
        );
        await settle(tester);
        await press(tester, const Key('book-details-open'));
        await fill(tester, 'author', 'Corrected author');
        await tester.runAsync(
          () => db.execute(
            "CREATE TRIGGER fail_book_ui BEFORE UPDATE ON private_records BEGIN SELECT RAISE(ABORT,'synthetic storage failure'); END",
          ),
        );
        await press(tester, const Key('book-details-save'));
        expect(find.byType(BookDetailsEditor), findsOneWidget);
        expect(
          tester
              .widget<TextFormField>(
                find.byKey(const Key('book-detail-author')),
              )
              .controller!
              .text,
          'Corrected author',
        );
        expect((await read(tester, store)).single.revision, original.revision);
        await tester.runAsync(() => db.execute('DROP TRIGGER fail_book_ui'));
        await press(tester, const Key('book-details-save'));
        final saved = (await read(tester, store)).single;
        expect(saved.data['chapters'], original.data['chapters']);
        expect(saved.data['bookmark'], 1);
        expect(saved.data['characters'], 'Original characters');
        expect(BookLibrary.metadata(saved.data)['author'], 'Corrected author');
        expect(find.byType(RecordPage), findsOneWidget);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(() async {
          await db.close();
          await dir.delete(recursive: true);
        });
        access.dispose();
      }
    },
  );
  testWidgets(
    'Typing during a delayed initial book load retains the metadata filter choices and current results',
    (tester) async {
      final (dir, db, records, original) = await fixture(tester);
      final access = AgentAccess()..owned.add(AgentAccess.core);
      final gate = Completer<void>();
      try {
        final saved = (await tester.runAsync(
          () => records.save(
            'book',
            BookLibrary.update(original!.data, {
              'author': 'Saved author',
              'shelves': ['Kept shelf'],
              'tags': ['Kept tag'],
            }),
            previous: original,
          ),
        ))!;
        final library = _DelayedBookLibrary(records, gate.future);
        await tester.pumpWidget(
          MaterialApp(
            home: BookLibraryPage(library: library, access: access),
          ),
        );
        await tester.pump();
        await tester.enterText(
          find.byKey(const Key('book-library-search')),
          'Saved author',
        );
        await tester.pump(const Duration(milliseconds: 350));
        await settle(tester);
        expect((await read(tester, records)).single.revision, saved.revision);
        gate.complete();
        await settle(tester);
        await show(tester, find.byKey(const Key('book-filter-shelves-')));
        expect(find.byKey(const Key('book-filter-shelves-')), findsOneWidget);
        expect(find.byKey(const Key('book-filter-tags-')), findsOneWidget);
        await show(
          tester,
          find.byKey(ValueKey('book-library-row-${saved.id}')),
        );
        expect(find.text('Legacy reading'), findsOneWidget);
        expect(tester.takeException(), isNull);
      } finally {
        if (!gate.isCompleted) gate.complete();
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(() async {
          await db.close();
          await dir.delete(recursive: true);
        });
        access.dispose();
      }
    },
  );
  if (includeCompact) {
    testWidgets(
      'Compact RTL book editor closes unchanged legacy data and retains edits when access expires',
      (tester) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final (dir, db, store, original) = await fixture(tester);
        final access = AgentAccess()..owned.add(AgentAccess.core);
        try {
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(brightness: Brightness.dark),
              builder: (c, child) => MediaQuery(
                data: MediaQuery.of(c)
                    .copyWith(textScaler: const TextScaler.linear(2)),
                child: Directionality(
                  textDirection: TextDirection.rtl,
                  child: child!,
                ),
              ),
              home: RecordPage(original!, store: store, access: access),
            ),
          );
          await settle(tester);
          await press(tester, const Key('book-details-open'));
          await tester.pageBack();
          await settle(tester);
          expect((await read(tester, store)).single.data, original.data);
          expect(
            (await read(tester, store)).single.revision,
            original.revision,
          );
          await press(tester, const Key('book-details-open'));
          await fill(tester, 'author', 'Retained private author');
          await fill(tester, 'pages', '۲۵۰');
          await fill(tester, 'currentPage', '۴۲');
          final input = tester.widget<TextField>(
            find.descendant(
              of: find.byKey(const Key('book-detail-currentPage')),
              matching: find.byType(TextField),
            ),
          );
          expect(input.enableIMEPersonalizedLearning, false);
          access.owned.clear();
          await press(tester, const Key('book-details-save'));
          expect(find.byType(BookDetailsEditor), findsOneWidget);
          expect(
            (await read(tester, store)).single.revision,
            original.revision,
          );
          expect(
            tester
                .widget<TextFormField>(
                  find.byKey(const Key('book-detail-author')),
                )
                .controller!
                .text,
            'Retained private author',
          );
          access.owned.add(AgentAccess.core);
          await press(tester, const Key('book-details-save'));
          final saved = (await read(tester, store)).single;
          expect(saved.revision, original.revision + 1);
          expect(BookLibrary.metadata(saved.data)['pages'], 250);
          expect(BookLibrary.metadata(saved.data)['currentPage'], 42);
          expect(saved.data['chapters'], original.data['chapters']);
          expect(tester.takeException(), isNull);
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.runAsync(() async {
            await db.close();
            await dir.delete(recursive: true);
          });
          access.dispose();
        }
      },
    );
  }
}

class _DelayedBookLibrary extends BookLibraryStore {
  final Future<void> gate;
  _DelayedBookLibrary(RecordStore records, this.gate) : super(records: records);
  @override
  Future<Map<String, List<String>>> filters() async {
    await gate;
    return super.filters();
  }
}
