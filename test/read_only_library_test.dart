import 'dart:io';

import 'package:bilga/core/strings.dart';
import 'package:bilga/features/notes/note_database.dart';
import 'package:bilga/features/notes/note_model.dart';
import 'package:bilga/features/notes/note_service.dart';
import 'package:bilga/features/search/library_page.dart';
import 'package:bilga/features/search/search_repository.dart';
import 'package:bilga/features/todo/todo_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'database_safety_test.dart' show initializeTestSqlite;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  databaseFactory = createDatabaseFactoryFfi(ffiInit: initializeTestSqlite);
  setUpAll(Strings.load);

  testWidgets('Expired-trial reader opens complete source and history without editing or changing records', (tester) async {
    late Directory dir;
    late Database n, t;
    final time = DateTime(2026, 11, 9);
    await tester.runAsync(() async {
      dir = await Directory.systemTemp.createTemp('bilga-reader-');
      n = await NoteDatabase.openAt('${dir.path}/notes.db');
      t = await TodoDatabase.openAt('${dir.path}/todos.db');
      final service = NoteService(database: n);
      final note = Note(id: 'n', title: 'Private title', body: 'Original body', createdAt: time, updatedAt: time);
      await service.addNote(note);
      await service.updateNote(note.copyWith(body: 'Complete saved body'));
    });
    try {
      final repository = SearchRepository(notesDb: n, todoDb: t);
      await tester.pumpWidget(MaterialApp(home: LibraryPage(readOnly: true, repository: repository)));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pumpAndSettle();
      expect(find.text('Private title'), findsOneWidget);
      await tester.tap(find.text('Private title'));
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pumpAndSettle();
      expect(find.text('Complete saved body'), findsOneWidget);
      expect(find.byIcon(Icons.edit_outlined), findsNothing);
      expect(find.byType(TextField), findsNothing);
      expect(find.byIcon(Icons.ios_share), findsOneWidget);
      expect(find.text('Version history'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        expect((await n.query('notes')).single['body'], 'Complete saved body');
        expect((await n.query('note_versions')).single['body'], 'Original body');
      });
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(() async { await n.close(); await t.close(); await dir.delete(recursive: true); });
    }
  });
}
