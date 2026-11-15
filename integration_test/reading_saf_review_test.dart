import 'dart:io';
import 'dart:convert';

import 'package:path/path.dart' as path;

import 'package:bilga/core/strings.dart';
import 'package:bilga/features/agent/agent_access.dart';
import 'package:bilga/features/books/book_library_page.dart';
import 'package:bilga/features/books/reading/book_reading_page.dart';
import 'package:bilga/features/books/reading/book_importer.dart';
import 'package:bilga/features/books/reading/reading_store.dart';
import 'package:bilga/features/notes/note_database.dart';
import 'package:bilga/features/private_space/record_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

import '../test/support/reading_fixtures.dart';
import '../test/support/reading_data_cases.dart';
import 'review_guard.dart';

Future<void> verifyRestart(
  WidgetTester t,
  Directory cache,
  File checkpoint,
  IntegrationTestWidgetsFlutterBinding binding,
) async {
  await requireReviewPackage();
  await Strings.load();
  final saved = Map<String, dynamic>.from(
    jsonDecode(await checkpoint.readAsString()),
  );
  final fixture = Directory(saved['directory']);
  if (saved['v'] != 1 ||
      !path.isWithin(cache.path, fixture.path) ||
      !path.basename(fixture.path).startsWith('review-saf-reader-') ||
      await FileSystemEntity.isLink(fixture.path)) {
    throw StateError('fixture_scope');
  }
  final db = await NoteDatabase.openAt(
    '${fixture.path}/notes.db',
    secure: true,
  );
  final store = ReadingStore(
    records: RecordStore(database: db),
    vault: FixtureBookVault(Directory('${fixture.path}/vault')),
    previewRoot: fixture,
  );
  final access = AgentAccess()..owned.add(AgentAccess.core);
  try {
    final book = await store.records.get(saved['book']);
    expect(
      (await store.one(book.id, 'progress'))!.data['location']['page'],
      154,
    );
    expect(
      (await store.rows(
        book.id,
        'bookmark',
      )).any((r) => r.data['note'] == 'Restart bookmark'),
      isTrue,
    );
    await t.pumpWidget(
      MaterialApp(
        home: BookReadingPage(book: book, store: store, access: access),
      ),
    );
    for (var i = 0; i < 120 && find.text('154 / 500').evaluate().isEmpty; i++) {
      await t.pump(const Duration(milliseconds: 50));
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
    }
    expect(find.text('154 / 500'), findsOneWidget);
    expect(t.takeException(), isNull);
    final reference = ReadingRow(
      (await db.rawQuery(
        "SELECT * FROM book_reading WHERE kind='source' AND json_extract(payload,'\$.format')='txt'",
      )).single,
    );
    expect(reference.data['mode'], 'reference');
    final linked = await BookImporter(store).materialize(reference);
    expect(await linked.readAsString(), contains('Original Bilga SAF text.'));
    await linked.parent.delete(recursive: true);
    debugPrint('BILGA_RESTART_VERIFIED:154');
    binding.reportData = {
      'realProcessRestart': {
        'page154': true,
        'bookmark': true,
        'persistedExternalTxtReference': true,
        'originalManagedFileReopened': true,
        'productionTouched': false,
      },
    };
  } finally {
    await t.pumpWidget(const SizedBox.shrink());
    for (var i = 0; i < 20; i++) {
      await t.pump(const Duration(milliseconds: 50));
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
    }
    await db.close();
    await fixture.delete(recursive: true);
    await checkpoint.delete();
    access.dispose();
  }
}

/// Tests register synchronously; device I/O belongs inside fixtures/callbacks.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(requireReviewPackage);
  registerReadingDataCases(
    createDirectory: () async {
      await requireReviewPackage();
      return (await getTemporaryDirectory()).createTemp(
        'review-reader-recovery-',
      );
    },
    secure: true,
  );
  testWidgets(
    'Real Android SAF: cancel, PDF, EPUB, persistent TXT reference, duplicate and corrupt file',
    (t) async {
      await requireReviewPackage();
      final cache = await getTemporaryDirectory();
      final checkpoint = File(
        '${cache.path}/review-reader-reopen-20261115-r1.json',
      );
      if (await checkpoint.exists()) {
        await verifyRestart(t, cache, checkpoint, binding);
        return;
      }
      await Strings.load();
      final dir = await (await getTemporaryDirectory()).createTemp(
        'review-saf-reader-',
      );
      final notes = await NoteDatabase.openAt(
        '${dir.path}/notes.db',
        secure: true,
      );
      final store = ReadingStore(
        records: RecordStore(database: notes),
        vault: FixtureBookVault(Directory('${dir.path}/vault')),
        previewRoot: dir,
      );
      final access = AgentAccess()..owned.add(AgentAccess.core);
      var preserveForRestart = false;
      Future<void> settle() async {
        for (var i = 0; i < 30; i++) {
          await t.pump(const Duration(milliseconds: 50));
          await t.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 30)),
          );
        }
      }

      Future<void> choose(String name, {bool reference = false}) async {
        expect(find.byType(BookLibraryPage), findsOneWidget);
        final scrollable = find
            .descendant(
              of: find.byType(CustomScrollView),
              matching: find.byType(Scrollable),
            )
            .first;
        if (reference) {
          await t.scrollUntilVisible(
            find.byKey(const Key('book-library-organize')),
            300,
            scrollable: scrollable,
            maxScrolls: 40,
          );
          await settle();
          await t.tap(find.byKey(const Key('book-library-organize')));
          await settle();
          await t.ensureVisible(find.byKey(const Key('book-library-link')));
          await settle();
        }
        final button = find.byKey(
          Key(reference ? 'book-library-link' : 'book-library-add'),
        );
        await t.scrollUntilVisible(
          button,
          reference ? 300 : -300,
          scrollable: scrollable,
          maxScrolls: 40,
        );
        await settle();
        debugPrint('BILGA_SAF_READY:$name');
        await t.tap(button);
        // Native DocumentsUI is operated by the paired host acceptance driver.
        await t.runAsync(
          () => Future<void>.delayed(const Duration(seconds: 20)),
        );
        await settle();
      }

      try {
        await t.pumpWidget(
          MaterialApp(
            home: BookLibraryPage(
              records: store.records,
              reading: store,
              access: access,
            ),
          ),
        );
        await settle();
        await choose('CANCEL');
        expect(await store.records.all('book'), isEmpty);
        for (final format in ['PDF', 'EPUB', 'TXT']) {
          await choose(format, reference: format == 'TXT');
          expect(find.byType(BookReadingPage), findsOneWidget);
          final books = await store.records.all('book');
          expect(
            books.length,
            format == 'PDF'
                ? 1
                : format == 'EPUB'
                ? 2
                : 3,
          );
          final source = (await notes.rawQuery(
            "SELECT * FROM book_reading WHERE kind='source' AND json_extract(payload,'\$.format')=?",
            [format.toLowerCase()],
          )).single;
          expect(
            ReadingRow(source).data['mode'],
            format == 'TXT' ? 'reference' : 'managed',
          );
          expect(find.byKey(const Key('reader-location')), findsOneWidget);
          if (format == 'EPUB') {
            expect(find.text('Original first chapter'), findsWidgets);
          }
          if (format == 'TXT') {
            expect(find.text('Original Bilga SAF text.'), findsWidgets);
          }
          await t.pageBack();
          await settle();
        }
        await choose('PDF');
        expect(find.text(Strings.get('en', 'rDuplicate')), findsOneWidget);
        expect(await store.records.all('book'), hasLength(3));
        await t.tap(
          find.widgetWithText(TextButton, Strings.get('en', 'cancel')),
        );
        await settle();
        await choose('Invalid');
        expect(await store.records.all('book'), hasLength(3));
        expect(
          find.textContaining(Strings.get('en', 'rImportFailed')),
          findsOneWidget,
        );
        // Finish with a real page jump and bookmark, then leave only this
        // synthetic encrypted fixture for the next process to reopen.
        final source = ReadingRow(
          (await notes.rawQuery(
            "SELECT * FROM book_reading WHERE kind='source' AND json_extract(payload,'\$.format')='pdf'",
          )).single,
        );
        final book = await store.records.get(source.book);
        await t.pumpWidget(
          MaterialApp(
            home: BookReadingPage(book: book, store: store, access: access),
          ),
        );
        await settle();
        await t.tap(find.byKey(const Key('reader-location')));
        await settle();
        await t.enterText(find.byType(TextField).first, '154');
        await t.tap(find.widgetWithText(TextButton, Strings.get('en', 'save')));
        await settle();
        expect(find.text('154 / 500'), findsOneWidget);
        await t.tap(find.byKey(const Key('reader-bookmark')));
        await settle();
        await t.enterText(find.byType(TextField).first, 'Restart bookmark');
        await t.tap(find.widgetWithText(TextButton, Strings.get('en', 'save')));
        await settle();
        await t.pumpWidget(const SizedBox.shrink());
        await settle();
        expect(
          (await store.one(book.id, 'progress'))!.data['location']['page'],
          154,
        );
        await checkpoint.writeAsString(
          jsonEncode({'v': 1, 'directory': dir.path, 'book': book.id}),
          flush: true,
        );
        preserveForRestart = true;
        binding.reportData = {
          'realSaf': {
            'cancel': true,
            'pdf': true,
            'epub': true,
            'txtPersistentReference': true,
            'duplicateCancel': true,
            'corruptRejected': true,
            'restartPrepared': true,
            'productionTouched': false,
          },
        };
        expect(t.takeException(), isNull);
      } finally {
        await t.pumpWidget(const SizedBox.shrink());
        await settle();
        await notes.close();
        if (!preserveForRestart) await dir.delete(recursive: true);
        access.dispose();
      }
    },
    timeout: const Timeout(Duration(minutes: 8)),
  );
}
