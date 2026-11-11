import 'dart:io';

import 'package:bilga/core/strings.dart';
import 'package:bilga/features/finance/account_ledger.dart';
import 'package:bilga/features/finance/ledger.dart';
import 'package:bilga/features/finance/transaction_edits.dart';
import 'package:bilga/features/private_space/record_store.dart';
import 'package:bilga/features/notes/note_database.dart';
import 'package:bilga/features/notes/note_model.dart';
import 'package:bilga/features/notes/note_service.dart';
import 'package:bilga/features/search/library_page.dart';
import 'package:bilga/features/search/search_repository.dart';
import 'package:bilga/features/todo/todo_database.dart';
import 'package:bilga/features/todo/todo_checklist_store.dart';
import 'package:bilga/features/todo/todo_project_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'database_safety_test.dart' show initializeTestSqlite;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  databaseFactory = createDatabaseFactoryFfi(ffiInit: initializeTestSqlite);
  setUpAll(Strings.load);

  testWidgets(
    'Expired-trial reader opens complete source and history without editing or changing records',
    (tester) async {
      late Directory dir;
      late Database n, t;
      final time = DateTime(2026, 11, 9);
      await tester.runAsync(() async {
        dir = await Directory.systemTemp.createTemp('bilga-reader-');
        n = await NoteDatabase.openAt('${dir.path}/notes.db');
        t = await TodoDatabase.openAt('${dir.path}/todos.db');
        final service = NoteService(database: n);
        final note = Note(
          id: 'n',
          title: 'Private title',
          body: 'Original body',
          createdAt: time,
          updatedAt: time,
        );
        await service.addNote(note);
        await service.updateNote(note.copyWith(body: 'Complete saved body'));
      });
      try {
        final repository = SearchRepository(notesDb: n, todoDb: t);
        await tester.runAsync(() async {
          await tester.pumpWidget(
            MaterialApp(
              home: LibraryPage(readOnly: true, repository: repository),
            ),
          );
          await Future<void>.delayed(const Duration(milliseconds: 100));
        });
        await tester.pumpAndSettle();
        expect(find.text('Private title'), findsOneWidget);
        await tester.runAsync(() async {
          await tester.tap(find.text('Private title'));
          await tester.pump();
          await Future<void>.delayed(const Duration(milliseconds: 100));
        });
        await tester.pumpAndSettle();
        expect(find.text('Complete saved body'), findsOneWidget);
        expect(find.byIcon(Icons.edit_outlined), findsNothing);
        expect(find.byType(TextField), findsNothing);
        expect(find.byIcon(Icons.ios_share), findsOneWidget);
        expect(find.text('Version history'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.runAsync(() async {
          expect(
            (await n.query('notes')).single['body'],
            'Complete saved body',
          );
          expect(
            (await n.query('note_versions')).single['body'],
            'Original body',
          );
        });
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(() async {
          await n.close();
          await t.close();
          await dir.delete(recursive: true);
        });
      }
    },
  );
  testWidgets(
    'Read-only task source includes complete subtasks without modifying progress',
    (tester) async {
      late Directory dir;
      late Database notes, todos;
      late SearchRepository repo;
      late SearchHit hit;
      await tester.runAsync(() async {
        dir = await Directory.systemTemp.createTemp('bilga-reader-checklist-');
        notes = await NoteDatabase.openAt('${dir.path}/notes.db');
        todos = await TodoDatabase.openAt('${dir.path}/tasks.db');
        final stamp = DateTime.now().toIso8601String();
        await todos.insert('todos', {
          'id': 'a',
          'title': 'Reader task',
          'description': 'Full description',
          'created_at': stamp,
          'updated_at': stamp,
        });
        await todos.transaction(
          (txn) => TodoChecklistStore.replace(txn, 'a', [
            const TodoChecklistItem('first', 'Prepare', done: true),
            const TodoChecklistItem('second', 'Review'),
          ]),
        );
        repo = SearchRepository(notesDb: notes, todoDb: todos);
        hit = (await repo.search('Prepare')).single;
      });
      try {
        await tester.runAsync(() async {
          await tester.pumpWidget(
            MaterialApp(
              home: DocumentPage(hit: hit, repository: repo),
            ),
          );
          await Future<void>.delayed(const Duration(milliseconds: 100));
        });
        await tester.pumpAndSettle();
        final text = tester
            .widget<SelectableText>(find.byType(SelectableText))
            .data!;
        expect(text, contains('☑ Prepare'));
        expect(text, contains('☐ Review'));
        expect(find.byIcon(Icons.edit_outlined), findsNothing);
        expect(find.byType(Checkbox), findsNothing);
        expect(find.byIcon(Icons.ios_share), findsOneWidget);
        await tester.runAsync(() async {
          expect(
            (await TodoChecklistStore.load(
              todos,
              'a',
            )).map((item) => item.done),
            [true, false],
          );
        });
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(() async {
          await notes.close();
          await todos.close();
          await dir.delete(recursive: true);
        });
      }
    },
  );
  testWidgets(
    'Read-only project source exposes full details and due date without editing',
    (tester) async {
      late Directory directory;
      late Database notes, todos;
      late SearchRepository repo;
      late SearchHit hit;
      await tester.runAsync(() async {
        directory = await Directory.systemTemp.createTemp(
          'bilga-project-reader-',
        );
        notes = await NoteDatabase.openAt('${directory.path}/notes.db');
        todos = await TodoDatabase.openAt('${directory.path}/tasks.db');
        await TodoProjectStore(todos).save(
          name: 'Project source',
          description: 'Detailedproject content',
          status: 'paused',
          dueDate: '2030-02-15',
        );
        repo = SearchRepository(notesDb: notes, todoDb: todos);
        hit = (await repo.search('Detailedproject')).single;
      });
      try {
        await tester.runAsync(() async {
          await tester.pumpWidget(
            MaterialApp(
              home: DocumentPage(hit: hit, repository: repo),
            ),
          );
          await Future<void>.delayed(const Duration(milliseconds: 100));
        });
        await tester.pumpAndSettle();
        final text = tester
            .widget<SelectableText>(find.byType(SelectableText))
            .data!;
        expect(text, contains('Detailedproject content'));
        expect(text, contains('Paused'));
        expect(text, contains('2030'));
        expect(find.byIcon(Icons.edit_outlined), findsNothing);
        expect(find.byIcon(Icons.ios_share), findsOneWidget);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(() async {
          await notes.close();
          await todos.close();
          await directory.delete(recursive: true);
        });
      }
    },
  );
  testWidgets(
    'Read-only finance exposes account directions and reconciliation audit including voided adjustments',
    (tester) async {
      late Directory directory;
      late Database notes, todos;
      late SearchRepository repo;
      late SearchHit hit;
      late List<Map<String, Object?>> before;
      await tester.runAsync(() async {
        directory = await Directory.systemTemp.createTemp(
          'bilga-finance-reader-',
        );
        notes = await NoteDatabase.openAt('${directory.path}/notes.db');
        todos = await TodoDatabase.openAt('${directory.path}/tasks.db');
        var data = AccountLedger.addAccount(
          {
            'title': 'Finance source',
            'currency': 'USD',
            'entries': <dynamic>[],
          },
          id: 'bank',
          name: 'Statement account',
          type: 'bank',
          opening: 10000,
          openedOn: '2020-01-01',
        );
        data = AccountLedger.transfer(
          data,
          id: 'move',
          from: 'bank',
          to: AccountLedger.legacyId,
          amount: 1500,
          date: '2020-01-02',
        );
        data = AccountLedger.reconcile(
          data,
          id: 'audit',
          account: 'bank',
          observed: 8000,
          date: '2020-01-03',
          description: 'Fullaudit statement reason',
          maxMoney: maxMoney,
        );
        data = TransactionEdits.setVoided(data, id: 'audit', voided: true);
        await RecordStore(database: notes).save('finance', data);
        before = await notes.query('private_records');
        repo = SearchRepository(notesDb: notes, todoDb: todos);
        hit = (await repo.search('Fullaudit')).single;
      });
      try {
        await tester.runAsync(() async {
          await tester.pumpWidget(
            MaterialApp(
              home: DocumentPage(hit: hit, repository: repo),
            ),
          );
          await Future<void>.delayed(const Duration(milliseconds: 100));
        });
        await tester.pumpAndSettle();
        final text = tester
            .widget<SelectableText>(find.byType(SelectableText))
            .data!;
        expect(text, contains('Statement account → Finance source'));
        expect(text, contains('100.00 USD'));
        expect(text, contains('Reconciliation history'));
        expect(text, contains('Transaction history'));
        expect(text, contains('Before void'));
        expect(text, contains('Fullaudit statement reason'));
        expect(text, contains('80.00 USD'));
        expect(text, contains('Voided'));
        expect(find.byType(TextField), findsNothing);
        expect(find.byIcon(Icons.edit_outlined), findsNothing);
        await tester.runAsync(
          () async => expect(await notes.query('private_records'), before),
        );
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(() async {
          await notes.close();
          await todos.close();
          await directory.delete(recursive: true);
        });
      }
    },
  );
}
