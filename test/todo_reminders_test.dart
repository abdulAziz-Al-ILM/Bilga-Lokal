import 'package:bilga/features/todo/widget/todo_widget_permissions.dart';

import 'dart:io';

import 'package:bilga/core/strings.dart';
import 'package:bilga/features/backup/backup_store.dart';
import 'package:bilga/features/collections/collection_repository.dart';
import 'package:bilga/features/notes/note_database.dart';
import 'package:bilga/features/todo/todo_database.dart';
import 'package:bilga/features/todo/todo_rules.dart';
import 'package:bilga/features/todo/reminders/todo_reminder_store.dart';
import 'package:bilga/features/todo/todo_changes.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'database_safety_test.dart' show initializeTestSqlite;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late Database db;
  final due = DateTime(2030, 3, 15, 10);
  Future<void> add(
    String id, {
    String? folder,
    bool deleted = false,
    bool done = false,
  }) => db
      .insert('todos', {
        'id': id,
        'title': 'Task $id',
        'description': 'kept',
        'priority': 3,
        'due_at': due.toIso8601String(),
        'folder_id': folder,
        'is_done': done ? 1 : 0,
        'is_deleted': deleted ? 1 : 0,
        'created_at': '2020-01-01T08:00:00',
        'updated_at': '2020-01-01T08:00:00',
      })
      .then((_) {});
  Future<void> removeSearchForLegacyFixture() async {
    await db.execute('DROP TRIGGER todo_series_trash');
    await db.execute('DROP TRIGGER todo_series_delete');
    await db.execute('DROP TABLE todo_templates');
    await db.execute('DROP TABLE todo_checklist');
    await db.execute('DROP TABLE todo_occurrences');
    await db.execute('DROP TABLE todo_series');
    for (final row in await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'trigger' AND name LIKE 'search_%'",
    )) {
      await db.execute('DROP TRIGGER ${row['name']}');
    }
    await db.execute('DROP TABLE bilga_search');
    await db.execute('DROP INDEX planner_due');
    await db.execute('DROP INDEX planner_completed');
  }

  setUp(() async {
    databaseFactory = createDatabaseFactoryFfi(ffiInit: initializeTestSqlite);
    directory = await Directory.systemTemp.createTemp('bilga-todo-reminder-');
    db = await TodoDatabase.openAt('${directory.path}/todo.db');
  });
  tearDown(() async {
    await db.close();
    await directory.delete(recursive: true);
  });
  test(
    'v6 migration preserves every task/folder field and grants no reminders',
    () async {
      await add('old');
      await db.insert('todo_folders', {
        'id': 'folder',
        'name': 'Old',
        'created_at': '2020-01-01',
        'updated_at': '2020-01-01',
      });
      final tasks = await db.query('todos'),
          folders = await db.query('todo_folders');
      await db.execute('DROP TRIGGER todo_reminder_cancel');
      await db.execute('DROP TRIGGER todo_reminder_delete');
      await db.execute('DROP TABLE todo_reminders');
      await db.execute('DROP TRIGGER todo_widget_revoke');
      await db.execute('DROP TABLE todo_widget_permissions');
      await removeSearchForLegacyFixture();
      await db.setVersion(6);
      await db.close();
      db = await TodoDatabase.openAt('${directory.path}/todo.db');
      expect(await db.getVersion(), 12);
      expect(await db.query('todos'), tasks);
      expect(await db.query('todo_folders'), folders);
      expect(await db.query('todo_reminders'), isEmpty);
    },
  );
  test('v7 widget migration preserves reminders; per-task consent survives reopen and revokes on rename/trash', () async {
    await add('a');
    await TodoReminderStore.save(db, 'a', due);
    final reminders = await db.query('todo_reminders');
    await db.execute('DROP TRIGGER todo_widget_revoke');
    await db.execute('DROP TABLE todo_widget_permissions');
    await removeSearchForLegacyFixture();
    await db.setVersion(7);
    await db.close();
    db = await TodoDatabase.openAt('${directory.path}/todo.db');
    expect(await db.query('todo_reminders'), reminders);
    expect(await TodoWidgetPermissions.allowed(db), isEmpty);
    await TodoWidgetPermissions.set(db, (await db.query('todos')).single, true);
    await db.close();
    db = await TodoDatabase.openAt('${directory.path}/todo.db');
    expect((await TodoWidgetPermissions.allowed(db))['a'], true);
    await db.update(
      'todos',
      {'title': 'Renamed'},
      where: 'id=?',
      whereArgs: ['a'],
    );
    expect(await TodoWidgetPermissions.allowed(db), isEmpty);
    await TodoWidgetPermissions.set(db, (await db.query('todos')).single, true);
    await db.update(
      'todos',
      {'is_deleted': 1},
      where: 'id=?',
      whereArgs: ['a'],
    );
    await db.update(
      'todos',
      {'is_deleted': 0},
      where: 'id=?',
      whereArgs: ['a'],
    );
    expect(await TodoWidgetPermissions.allowed(db), isEmpty);
  });
  test('Reminder and snooze acknowledgements never change original deadline or timestamps', () async {
    await add('a');
    final before = await db.query('todos');
    await TodoReminderStore.save(db, 'a', due);
    final reminder = (await db.query('todo_reminders')).single;
    final later = due.add(const Duration(minutes: 30));
    await TodoReminderStore(db).applyEvents([
      {
        'id': 'a',
        'revision': reminder['revision'],
        'at': later.toIso8601String(),
        'kind': 'snooze',
      },
    ]);
    expect(
      (await db.query('todo_reminders')).single['remind_at'],
      later.toIso8601String(),
    );
    expect(await db.query('todos'), before);
    await TodoReminderStore(db).applyEvents([
      {
        'id': 'a',
        'revision': 'stale',
        'at': due.toIso8601String(),
        'kind': 'fired',
      },
    ]);
    expect((await db.query('todo_reminders')).single['fired'], 0);
    await TodoReminderStore(db).applyEvents([
      {
        'id': 'a',
        'revision': reminder['revision'],
        'at': later.toIso8601String(),
        'kind': 'fired',
      },
    ]);
    expect((await db.query('todo_reminders')).single['fired'], 1);
  });
  test('Done, trash, due edit and permanent delete invalidate reminders; undo cannot resurrect', () async {
    await add('a');
    final repo = CollectionRepository(CollectionKind.todos, provided: db);
    await TodoReminderStore.save(db, 'a', due);
    await repo.setField('a', 'is_done', 1);
    expect(await db.query('todo_reminders'), isEmpty);
    await repo.setField('a', 'is_done', 0);
    expect(await db.query('todo_reminders'), isEmpty);
    await TodoReminderStore.save(db, 'a', due);
    await repo.trash('a');
    expect(await db.query('todo_reminders'), isEmpty);
    await repo.restore('a');
    expect(await db.query('todo_reminders'), isEmpty);
    await TodoReminderStore.save(db, 'a', due);
    await db.update('todos', {'due_at': null}, where: 'id=?', whereArgs: ['a']);
    expect(await db.query('todo_reminders'), isEmpty);
    await TodoReminderStore.save(db, 'a', due);
    await db.delete('todos', where: 'id=?', whereArgs: ['a']);
    expect(await db.query('todo_reminders'), isEmpty);
  });
  test(
    'Rollback keeps task and reminder, and emits no successful commit signal',
    () async {
      await add('a');
      await TodoReminderStore.save(db, 'a', due);
      int signals = 0;
      final sub = TodoChanges.events.listen((_) => signals++);
      await expectLater(
        TodoChanges.after(
          db.transaction((txn) async {
            await txn.update(
              'todos',
              {'is_deleted': 1},
              where: 'id=?',
              whereArgs: ['a'],
            );
            throw StateError('rollback');
          }),
        ),
        throwsStateError,
      );
      expect((await db.query('todo_reminders')).length, 1);
      expect((await db.query('todos')).single['is_deleted'], 0);
      expect(signals, 0);
      await sub.cancel();
    },
  );
  test(
    'Recursive deleted folders and trash never enter reminder/widget exports',
    () async {
      for (final pair in [('parent', null), ('child', 'parent')]) {
        await db.insert('todo_folders', {
          'id': pair.$1,
          'name': pair.$1,
          'parent_id': pair.$2,
          'is_deleted': pair.$1 == 'parent' ? 1 : 0,
          'created_at': '2020-01-01',
          'updated_at': '2020-01-01',
        });
      }
      await add('a', folder: 'child');
      await add('root');
      await add('trash', deleted: true);
      await add('done', done: true);
      expect((await TodoReminderStore.active(db)).map((t) => t['id']).toSet(), {
        'root',
        'done',
      });
    },
  );
  test(
    'Reminder FK and transaction reject orphans and preserve existing rows',
    () async {
      await expectLater(
        TodoReminderStore.save(db, 'missing', due),
        throwsA(isA<DatabaseException>()),
      );
      expect(await db.query('todo_reminders'), isEmpty);
    },
  );
  test('v7 backup restores reminders under new task IDs; legacy v6 remains importable', () async {
    final notes = await NoteDatabase.openAt('${directory.path}/notes.db');
    final restoredNotes = await NoteDatabase.openAt(
      '${directory.path}/restored-notes.db',
    );
    final restoredTodo = await TodoDatabase.openAt(
      '${directory.path}/restored-todo.db',
    );
    try {
      await add('a');
      await TodoReminderStore.save(db, 'a', due);
      final payload = await BackupStore(notesDb: notes, todoDb: db).snapshot();
      expect(payload['todoSchema'], 10);
      final store = BackupStore(notesDb: restoredNotes, todoDb: restoredTodo);
      expect(await store.restore(payload, 'Restored'), true);
      final r = (await restoredTodo.query('todo_reminders')).single;
      final t = (await restoredTodo.query('todos')).single;
      expect(r['todo_id'], t['id']);
      expect(t['due_at'], due.toIso8601String());
      expect(
        r['revision'],
        isNot((await db.query('todo_reminders')).single['revision']),
      );
      expect(await store.restore(payload, 'Restored'), false);
      final data = Map<String, dynamic>.from(payload['data'] as Map)
        ..remove('todo_reminders');
      expect(
        BackupStore.validate({
          ...payload,
          'todoSchema': 6,
          'data': data,
        })['todo_reminders'],
        isEmpty,
      );
      final bad = Map<String, dynamic>.from(payload['data'] as Map)
        ..['todo_reminders'] = [
          {...r, 'todo_id': 'missing'},
        ];
      expect(
        () => BackupStore.validate({...payload, 'data': bad}),
        throwsFormatException,
      );
    } finally {
      await notes.close();
      await restoredNotes.close();
      await restoredTodo.close();
    }
  });
  test('Calendar midnight transitions and exact time differ from elapsed day buckets', () {
    final now = DateTime(2026, 10, 12, 23, 59, 59);
    expect(
      todoTimeState({'due_at': '2026-10-14T00:00:00'}, now),
      TodoTimeState.yellow,
    );
    expect(
      todoTimeState({'due_at': '2026-10-14T00:00:00'}, DateTime(2026, 10, 13)),
      TodoTimeState.red,
    );
    expect(
      todoTimeState({'due_at': now.toIso8601String()}, now),
      TodoTimeState.overdue,
    );
    expect(todoTimeState({'due_at': 'invalid'}, now), TodoTimeState.neutral);
  });
  test('All 43 locales have reminder controls, disclosure and native label resources', () async {
    for (final file in Directory('assets/i18n').listSync().whereType<File>()) {
      await Strings.load(code: file.uri.pathSegments.last.split('.').first);
      final code = file.uri.pathSegments.last.split('.').first;
      for (final key in [
        'reminder',
        'reminderSnooze',
        'reminderMessage',
        'reminderOverlayInfo',
        'reminderPrivacy',
        'reminderLimits',
        'widgetTodo',
        'reminderFuture',
        'snooze5',
        'snooze10',
        'snooze30',
        'snooze60',
        'tomorrow',
        'snoozeCustom',
      ]) {
        expect(Strings.get(code, key), isNot(key), reason: '$code/$key');
      }
    }
  });
}
