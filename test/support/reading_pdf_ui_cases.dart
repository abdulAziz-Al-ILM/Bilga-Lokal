import 'dart:io';

import 'package:bilga/core/strings.dart';
import 'package:bilga/features/agent/agent_access.dart';
import 'package:bilga/features/books/reading/book_importer.dart';
import 'package:bilga/features/books/reading/book_reading_page.dart';
import 'package:bilga/features/books/reading/reading_store.dart';
import 'package:bilga/features/notes/note_database.dart';
import 'package:bilga/features/private_space/record_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart';

import 'reading_fixtures.dart';

void registerReadingPdfUiCases({
  Future<Directory> Function()? createDirectory,
  bool secure = false,
}) {
  Future<void> settle(WidgetTester t) async {
    var quiet = 0;
    for (var i = 0; i < 250; i++) {
      await t.pump(const Duration(milliseconds: 40));
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      if (find.byType(CircularProgressIndicator).evaluate().isEmpty &&
          !t.binding.hasScheduledFrame) {
        if (++quiet >= 3) return;
      } else {
        quiet = 0;
      }
    }
    throw StateError('PDF fixture reader did not settle');
  }

  Future<void> tap(WidgetTester t, Finder f) async {
    await t.ensureVisible(f);
    await t.tap(f);
    await settle(t);
  }

  testWidgets(
    'PDF 500 pages: real renderer, page 154, bookmark, embedded search, landscape and reopen',
    (t) async {
      final fixture = (await t.runAsync(() async {
        await Strings.load();
        final dir =
            await (createDirectory?.call() ??
                Directory.systemTemp.createTemp('bilga-pdf-ui-'));
        final db = await NoteDatabase.openAt(
          '${dir.path}/notes.db',
          secure: secure,
        );
        Pdfrx.cacheDirectoryPath = dir.path;
        final store = ReadingStore(
          records: RecordStore(database: db),
          vault: FixtureBookVault(Directory('${dir.path}/vault')),
          previewRoot: dir,
        );
        final importer = BookImporter(store),
            c = await BookImporter(store).prepare(
              Stream.value(fixturePdf(pages: 500)),
              'Original textbook.pdf',
            );
        final b = await importer.commit(c, allowed: () => true);
        await c.close();
        return (dir, store, b);
      }))!;
      final (dir, store, book) = fixture;
      final access = AgentAccess()..owned.add(AgentAccess.core);
      Future<void> open() async {
        await t.pumpWidget(
          MaterialApp(
            home: BookReadingPage(book: book, store: store, access: access),
          ),
        );
        await settle(t);
      }

      try {
        await open();
        await tap(t, find.byKey(const Key('reader-location')));
        await t.enterText(find.byType(TextField).first, '154');
        await tap(
          t,
          find.widgetWithText(TextButton, Strings.get('en', 'save')),
        );
        expect(find.text('154 / 500'), findsOneWidget);
        await tap(t, find.byKey(const Key('reader-bookmark')));
        await t.enterText(find.byType(TextField).first, 'Page 154 bookmark');
        await tap(
          t,
          find.widgetWithText(TextButton, Strings.get('en', 'save')),
        );
        expect(
          (await t.runAsync(() => store.one(book.id, 'bookmark')))!
              .data['location']['page'],
          154,
        );
        await tap(t, find.byKey(const Key('reader-search')));
        await t.enterText(find.byType(TextField).first, 'original page 154');
        await tap(
          t,
          find.widgetWithText(TextButton, Strings.get('en', 'save')),
        );
        for (
          var i = 0;
          i < 500 &&
              t
                      .widget<IconButton>(
                        find.byKey(const Key('reader-search-next')),
                      )
                      .onPressed ==
                  null;
          i++
        ) {
          await t.pump(const Duration(milliseconds: 100));
          await t.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 50)),
          );
        }
        await tap(t, find.byKey(const Key('reader-search-next')));
        expect(find.text('1/1'), findsOneWidget);
        if (secure) {
          await SystemChrome.setPreferredOrientations([
            DeviceOrientation.landscapeLeft,
          ]);
          await t.runAsync(
            () => Future<void>.delayed(const Duration(seconds: 2)),
          );
          await settle(t);
          final size = MediaQuery.sizeOf(
            t.element(find.byType(BookReadingPage)),
          );
          expect(size.width, greaterThan(size.height));
        } else {
          t.view.physicalSize = const Size(1200, 800);
          await settle(t);
        }
        expect(find.text('154 / 500'), findsOneWidget);
        await t.pumpWidget(const SizedBox.shrink());
        await settle(t);
        final saved = (await t.runAsync(() => store.one(book.id, 'progress')))!;
        expect(saved.data['location']['page'], 154);
        await open();
        expect(find.text('154 / 500'), findsOneWidget);
        expect(t.takeException(), isNull);
      } finally {
        await t.pumpWidget(const SizedBox.shrink());
        await settle(t);
        if (secure) {
          await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
        } else {
          t.view.resetPhysicalSize();
        }
        await t.runAsync(() async {
          await (await store.db).close();
          await dir.delete(recursive: true);
        });
        access.dispose();
      }
    },
  );
}
