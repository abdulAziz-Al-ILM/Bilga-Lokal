import 'dart:io';

import 'package:bilga/core/strings.dart';
import 'package:bilga/features/agent/agent_access.dart';
import 'package:bilga/features/books/book_library_page.dart';
import 'package:bilga/features/books/reading/book_reading_page.dart';
import 'package:bilga/features/books/reading/reading_store.dart';
import 'package:bilga/features/notes/note_database.dart';
import 'package:bilga/features/private_space/record_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

import '../test/support/reading_fixtures.dart';
import 'review_guard.dart';

/// The driver selects only original fixture documents in Android DocumentsUI.
/// No picker/URI/permission mock: the actual FilesBridge and SAF are exercised.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(requireReviewPackage);
  testWidgets(
    'Real Android SAF: cancel, PDF, EPUB, persistent TXT reference, duplicate and corrupt file',
    (t) async {
      await requireReviewPackage();
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
      Future<void> settle() async {
        for (var i = 0; i < 30; i++) {
          await t.pump(const Duration(milliseconds: 50));
          await t.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 30)),
          );
        }
      }

      Future<void> choose(String name, {bool reference = false}) async {
        if (reference) {
          await t.ensureVisible(find.byKey(const Key('book-library-organize')));
          await t.tap(find.byKey(const Key('book-library-organize')));
          await settle();
          await t.ensureVisible(find.byKey(const Key('book-library-link')));
        }
        final button = find.byKey(
          Key(reference ? 'book-library-link' : 'book-library-add'),
        );
        await t.ensureVisible(button);
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
        binding.reportData = {
          'realSaf': {
            'cancel': true,
            'pdf': true,
            'epub': true,
            'txtPersistentReference': true,
            'duplicateCancel': true,
            'corruptRejected': true,
            'productionTouched': false,
          },
        };
        expect(t.takeException(), isNull);
      } finally {
        await t.pumpWidget(const SizedBox.shrink());
        await settle();
        await notes.close();
        await dir.delete(recursive: true);
        access.dispose();
      }
    },
    timeout: const Timeout(Duration(minutes: 8)),
  );
}
