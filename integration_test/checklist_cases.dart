import 'dart:io';

import 'package:bilga/features/collections/collection_page.dart';
import 'package:bilga/features/collections/collection_repository.dart';
import 'package:bilga/features/todo/todo_database.dart';
import 'package:bilga/features/todo/todo_checklist_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

import '../test/support/todo_checklist_cases.dart';
import 'review_guard.dart';

Future<Directory> _directory() async {
  await requireReviewPackage();
  return (await getTemporaryDirectory()).createTemp('review-checklist-');
}

void registerChecklistCases(IntegrationTestWidgetsFlutterBinding binding) {
  group('Encrypted subtask fixtures', () {
    registerTodoChecklistTests(createDirectory: _directory, secure: true);
  });
  testWidgets(
    'Task editor creates, reorders and checks subtasks; list duplicates them independently',
    (tester) async {
      final directory = await _directory();
      final db = await TodoDatabase.openAt(
        '${directory.path}/tasks.db',
        secure: true,
      );
      Future<void> settle() async {
        await tester.pumpAndSettle();
        await Future<void>.delayed(const Duration(milliseconds: 250));
        await tester.pumpAndSettle();
      }

      try {
        final stamp = DateTime.now().toIso8601String();
        await db.insert('todos', {
          'id': 'fixture',
          'title': 'Checklist tablet fixture',
          'created_at': stamp,
          'updated_at': stamp,
        });
        await tester.pumpWidget(
          MaterialApp(
            home: CollectionPage(
              kind: CollectionKind.todos,
              repository: CollectionRepository(
                CollectionKind.todos,
                provided: db,
              ),
            ),
          ),
        );
        await settle();
        await tester.tap(find.text('Checklist tablet fixture'));
        await settle();
        final add = find.byKey(const Key('task-checklist-add'));
        await tester.ensureVisible(add);
        await settle();
        await tester.tap(add);
        await settle();
        await tester.enterText(
          find.byType(TextFormField).first,
          'Prepare material',
        );
        await settle();
        await tester.ensureVisible(add);
        await settle();
        await tester.tap(add);
        await settle();
        await tester.enterText(
          find.byType(TextFormField).last,
          'Review result',
        );
        await settle();
        await tester.ensureVisible(find.byType(Checkbox).first);
        await settle();
        await tester.tap(find.byType(Checkbox).first);
        await settle();
        await tester.tap(find.byTooltip('Subtask actions').first);
        await settle();
        await tester.tap(find.text('Move down'));
        await settle();
        await tester.tap(find.byTooltip('Save'));
        await settle();
        final items = await TodoChecklistStore.load(db, 'fixture');
        expect(items.map((item) => item.title), [
          'Review result',
          'Prepare material',
        ]);
        expect(items.map((item) => item.done), [false, true]);
        expect(find.text('Subtasks: 1 / 2'), findsOneWidget);
        final tile = find
            .ancestor(
              of: find.text('Checklist tablet fixture'),
              matching: find.byType(ListTile),
            )
            .first;
        await tester.ensureVisible(tile);
        await settle();
        await tester.tap(
          find.descendant(
            of: tile,
            matching: find.byType(PopupMenuButton<String>),
          ),
        );
        await settle();
        await tester.tap(find.text('Duplicate task'));
        await settle();
        final tasks = await db.query('todos');
        expect(tasks, hasLength(2));
        final copy = tasks.singleWhere((row) => row['id'] != 'fixture');
        final fresh = await TodoChecklistStore.load(db, copy['id'] as String);
        expect(fresh.map((item) => item.title), [
          'Review result',
          'Prepare material',
        ]);
        expect(fresh.every((item) => !item.done), true);
        expect(find.text('Subtasks: 0 / 2'), findsOneWidget);
        binding.reportData = {
          ...?binding.reportData,
          'checklist': {
            'encryptedFixtures': true,
            'realEditorReorderAndCompletion': true,
            'listProgress': true,
            'independentDuplication': true,
          },
        };
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await db.close();
        await directory.delete(recursive: true);
      }
    },
  );
}
