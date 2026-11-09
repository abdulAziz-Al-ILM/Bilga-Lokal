import 'dart:io';

import 'package:bilga/core/strings.dart';
import 'package:bilga/features/collections/collection_repository.dart';
import 'package:bilga/features/notes/note_database.dart';
import 'package:bilga/features/todo/todo_database.dart';
import 'package:bilga/features/templates/template_catalog.dart';
import 'package:bilga/features/templates/template_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'database_safety_test.dart' show initializeTestSqlite;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    databaseFactory = createDatabaseFactoryFfi(ffiInit: initializeTestSqlite);
    for (final code in languages.keys) {
      await Strings.load(code: code);
    }
  });

  test('All ten templates have explicit translations in all 43 languages', () {
    expect(entryTemplates.where((t) => t.todo).length, 5);
    expect(entryTemplates.where((t) => !t.todo).length, 5);
    for (final code in languages.keys) {
      for (final t in entryTemplates) {
        for (final key in ['tpl_${t.id}', ...t.sections.map((s) => 'tpl_$s')]) {
          expect(
            Strings.catalogs[code]!.containsKey(key),
            isTrue,
            reason: '$code/$key',
          );
          expect(Strings.catalogs[code]![key]!.trim(), isNotEmpty);
        }
      }
    }
  });

  test('Notes remain independent of locale and template changes; folders preserved', () async {
    final dir = await Directory.systemTemp.createTemp('bilga-template-notes-');
    final db = await NoteDatabase.openAt('${dir.path}/notes.db');
    try {
      final repo = CollectionRepository(CollectionKind.notes, provided: db);
      await repo.createFolder('Parent', null);
      final parent = (await repo.activeFolders()).single['id'] as String;
      final template = entryTemplates.first;
      final a = await repo.createFromTemplate(template, 'uz', parent);
      final b = await repo.createFromTemplate(template, 'ky', parent);
      expect(a['id'], isNot(b['id']));
      expect(a['folder_id'], parent);
      await db.update(
        'notes',
        {'body': 'My own edits'},
        where: 'id = ?',
        whereArgs: [a['id']],
      );
      await repo.createFromTemplate(template, 'en', parent);
      final saved = await db.query(
        'notes',
        where: 'id = ?',
        whereArgs: [a['id']],
      );
      expect(saved.single['body'], 'My own edits');
      expect(saved.single['title'], template.title('uz'));
      expect(await db.getVersion(), 14);
    } finally {
      await db.close();
      await dir.delete(recursive: true);
    }
  });

  test('Checklist creation is atomic, repeatable, nested and has no invented deadlines', () async {
    final dir = await Directory.systemTemp.createTemp('bilga-template-todo-');
    final db = await TodoDatabase.openAt('${dir.path}/todos.db');
    try {
      final repo = CollectionRepository(CollectionKind.todos, provided: db);
      final t = entryTemplates.firstWhere((t) => t.todo);
      await repo.createFolder('Parent', null);
      final parent = (await repo.activeFolders()).single['id'] as String;
      final a = await repo.createFromTemplate(t, 'uz', parent);
      final b = await repo.createFromTemplate(t, 'uz', parent);
      expect(a['id'], isNot(b['id']));
      expect(a['parent_id'], parent);
      final tasks = await db.query(
        'todos',
        where: 'folder_id = ?',
        whereArgs: [a['id']],
        orderBy: 'created_at DESC',
      );
      expect(tasks.map((r) => r['title']).toList(), t.lines('uz'));
      expect(
        tasks.every((r) => r['due_at'] == null && r['is_done'] == 0),
        isTrue,
      );
      await db.execute(
        "CREATE TRIGGER fail_template BEFORE INSERT ON todos BEGIN SELECT RAISE(ABORT, 'test failure'); END",
      );
      final before = await db.query('todo_folders');
      await expectLater(
        repo.createFromTemplate(t, 'uz', parent),
        throwsA(isA<Exception>()),
      );
      expect(await db.query('todo_folders'), before);
      await db.execute('DROP TRIGGER fail_template');
      await expectLater(
        repo.createFromTemplate(t, 'uz', 'missing'),
        throwsStateError,
      );
      expect(await db.query('todo_folders'), before);
      expect(await db.getVersion(), 9);
    } finally {
      await db.close();
      await dir.delete(recursive: true);
    }
  });

  testWidgets(
    'Preview cancel leaves picker open; confirm returns the selected template',
    (tester) async {
      EntryTemplate? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  selected = await Navigator.push<EntryTemplate>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const TemplatePage(todos: false),
                    ),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Daily journal'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(selected, isNull);
      expect(find.byType(TemplatePage), findsOneWidget);
      await tester.tap(find.text('Daily journal'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create from template'));
      await tester.pumpAndSettle();
      expect(selected?.id, 'journal');
      expect(find.byType(TemplatePage), findsNothing);
    },
  );
}
