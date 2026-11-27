import 'dart:io';

import 'package:bilga/core/strings.dart';
import 'package:bilga/features/todo/recurrence_rule.dart';
import 'package:bilga/features/todo/reminders/todo_bridge.dart';
import 'package:bilga/features/todo/todo_checklist_store.dart';
import 'package:bilga/features/todo/todo_database.dart';
import 'package:bilga/features/todo/todo_editor_page.dart';
import 'package:bilga/features/todo/todo_editor_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'database_safety_test.dart' show initializeTestSqlite;

void main() {
  databaseFactory = createDatabaseFactoryFfi(ffiInit: initializeTestSqlite);

  for (final platformError in [false, true]) {
    testWidgets(
      platformError
          ? 'Notification platform failure leaves the task draft and explains the failure'
          : 'Denied notification permission leaves the reminder set and explains Android blocking',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(800, 1000));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final messenger = tester.binding.defaultBinaryMessenger;
        final calls = <String>[];
        messenger.setMockMethodCallHandler(TodoBridge.channel, (call) async {
          calls.add(call.method);
          if (platformError) throw PlatformException(code: 'not_available');
          return false;
        });
        addTearDown(
          () => messenger.setMockMethodCallHandler(TodoBridge.channel, null),
        );
        await tester.pumpWidget(
          const MaterialApp(home: TodoEditorPage(initialTitle: 'Draft task')),
        );

        final reminder = find.byType(SwitchListTile).first;
        await tester.ensureVisible(reminder);
        await tester.tap(reminder);
        await tester.pumpAndSettle();

        expect(calls, ['requestNotificationPermission']);
        expect(tester.widget<SwitchListTile>(reminder).value, isTrue);
        expect(
          find.text(
            Strings.get(
              'en',
              platformError
                  ? 'moduleReminderUnavailable'
                  : 'moduleReminderBlocked',
            ),
          ),
          findsOneWidget,
        );
        expect(find.text('Draft task'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  test(
    'Task editor saves related rows atomically and retries a rejected save',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'bilga-task-edit-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final database = await TodoDatabase.openAt(
        '${directory.path}/tasks.db',
        secure: false,
      );
      addTearDown(database.close);
      final store = TodoEditorStore(database: database);
      final due = DateTime(2030, 6, 6, 18);

      TodoEditorDraft draft(String checklistTitle) => TodoEditorDraft(
        taskId: null,
        folderId: null,
        title: '  Review release  ',
        description: 'Keep my formatting\n',
        priority: 2,
        due: due,
        originalDue: null,
        reminder: (enabled: true, time: due.subtract(const Duration(hours: 1))),
        originalReminder: (enabled: false, time: null),
        checklist: [TodoChecklistItem('editor-item', checklistTitle)],
        checklistChanged: true,
        recurrence: RecurrenceRule(unit: RecurrenceUnit.day),
        recurrenceChanged: true,
        recurrenceReadOnly: false,
        applyToFuture: false,
        hasSeries: false,
      );

      await expectLater(store.save(draft('')), throwsFormatException);
      for (final table in [
        'todos',
        'todo_reminders',
        'todo_checklist',
        'todo_series',
      ]) {
        expect(await database.query(table), isEmpty, reason: table);
      }

      await store.save(draft('Check package'));
      final task = (await database.query('todos')).single;
      final id = task['id'] as String;
      expect(task['title'], 'Review release');
      expect(task['description'], 'Keep my formatting\n');
      expect(task['due_at'], due.toIso8601String());
      expect((await store.reminderFor(id))?.enabled, isTrue);
      expect((await store.checklistFor(id)).single.title, 'Check package');
      expect((await store.seriesFor(id))?['head_task_id'], id);
    },
  );
}
