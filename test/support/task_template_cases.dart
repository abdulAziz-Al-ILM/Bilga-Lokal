import 'dart:convert';
import 'dart:io';

import 'package:bilga/features/backup/backup_store.dart';
import 'package:bilga/features/notes/note_database.dart';
import 'package:bilga/features/templates/task_template_store.dart';
import 'package:bilga/features/todo/recurrence_rule.dart';
import 'package:bilga/features/todo/reminders/todo_reminder_store.dart';
import 'package:bilga/features/todo/todo_checklist_store.dart';
import 'package:bilga/features/todo/todo_database.dart';
import 'package:bilga/features/todo/todo_series_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

void registerTaskTemplateTests({
  Future<Directory> Function()? createDirectory,
  bool secure = false,
}) {
  late Directory directory;
  late Database db;
  late TaskTemplateStore store;
  final stamp = DateTime.utc(2030, 1, 31, 9).toIso8601String();
  setUp(() async {
    directory =
        await (createDirectory?.call() ??
            Directory.systemTemp.createTemp('bilga-task-templates-'));
    db = await TodoDatabase.openAt(
      '${directory.path}/tasks.db',
      secure: secure,
    );
    store = TaskTemplateStore(db);
    await db.insert('todos', {
      'id': 'source',
      'title': 'Prepare meeting',
      'description': 'Private description',
      'priority': 2,
      'due_at': stamp,
      'created_at': stamp,
      'updated_at': stamp,
    });
    await db.transaction(
      (txn) => TodoChecklistStore.replace(txn, 'source', [
        const TodoChecklistItem('source-check', 'Read agenda', done: true),
        const TodoChecklistItem('source-check-2', 'Write minutes'),
      ]),
    );
  });
  tearDown(() async {
    await db.close();
    await directory.delete(recursive: true);
  });
  TaskTemplate change(TaskTemplate t, {String? title, String? name}) =>
      TaskTemplate(
        id: t.id,
        name: name ?? t.name,
        title: title ?? t.title,
        description: t.description,
        priority: t.priority,
        checklist: t.checklist,
        revision: t.revision,
      );

  test('Tasks 11 upgrade adds templates without rewriting tasks, checklist or series', () async {
    await db.transaction(
      (txn) => TodoSeriesStore.configure(
        txn,
        'source',
        RecurrenceRule(unit: RecurrenceUnit.month),
      ),
    );
    final tasks = await db.query('todos'),
        items = await db.query('todo_checklist'),
        series = await db.query('todo_series');
    await db.execute('DROP TABLE todo_templates');
    await db.setVersion(11);
    await db.close();
    db = await TodoDatabase.openAt(
      '${directory.path}/tasks.db',
      secure: secure,
    );
    store = TaskTemplateStore(db);
    expect(await db.getVersion(), 12);
    expect(await db.query('todos'), tasks);
    expect(await db.query('todo_checklist'), items);
    expect(await db.query('todo_series'), series);
    expect(await store.all(), isEmpty);
  });
  test('Task snapshot and repeated use preserve source while resetting progress and private bindings', () async {
    await TodoReminderStore.save(db, 'source', DateTime.parse(stamp));
    await db.insert('todo_widget_permissions', {
      'todo_id': 'source',
      'title': 'Prepare meeting',
    });
    await db.transaction(
      (txn) => TodoSeriesStore.configure(
        txn,
        'source',
        RecurrenceRule(unit: RecurrenceUnit.month),
      ),
    );
    final id = await store.save(await store.fromTask('source'));
    final a = await store.instantiate(id), b = await store.instantiate(id);
    expect(a['id'], isNot(b['id']));
    expect(a['description'], 'Private description');
    expect(a['priority'], 2);
    for (final task in [a, b]) {
      expect(task['due_at'], isNull);
      expect(task['is_done'], 0);
      expect(
        (await TodoChecklistStore.load(
          db,
          task['id'] as String,
        )).map((i) => i.done),
        [false, false],
      );
      expect(await TodoSeriesStore.forTask(db, task['id'] as String), isNull);
      for (final table in ['todo_reminders', 'todo_widget_permissions']) {
        expect(
          await db.query(table, where: 'todo_id=?', whereArgs: [task['id']]),
          isEmpty,
        );
      }
    }
    expect((await TodoChecklistStore.load(db, 'source')).first.done, true);
    expect(await db.query('todo_reminders'), hasLength(1));
  });
  test('Editing and deleting templates leaves existing tasks intact and rejects stale editors', () async {
    final id = await store.save(await store.fromTask('source'));
    final original = (await store.all()).single;
    final task = await store.instantiate(id);
    await store.save(change(original, title: 'Updated default'));
    await expectLater(
      store.save(change(original, title: 'Stale edit')),
      throwsStateError,
    );
    await expectLater(store.delete(original), throwsStateError);
    final newer = await store.instantiate(id);
    expect(newer['title'], 'Updated default');
    final current = (await store.all()).single;
    expect(current.revision, 2);
    await store.delete(current);
    expect(await store.all(), isEmpty);
    expect(
      (await db.query(
        'todos',
        where: 'id=?',
        whereArgs: [task['id']],
      )).single['title'],
      'Prepare meeting',
    );
    expect(
      await TodoChecklistStore.load(db, task['id'] as String),
      hasLength(2),
    );
  });
  test('Failed instantiation rolls back all task and checklist writes; invalid folders do not create tasks', () async {
    final id = await store.save(await store.fromTask('source'));
    final before = await db.query('todos');
    await db.execute(
      "CREATE TRIGGER fail_template_check BEFORE INSERT ON todo_checklist WHEN NEW.todo_id!='source' BEGIN SELECT RAISE(ABORT,'synthetic'); END",
    );
    await expectLater(store.instantiate(id), throwsA(anything));
    expect(await db.query('todos'), before);
    expect(await db.query('todo_checklist'), hasLength(2));
    await db.execute('DROP TRIGGER fail_template_check');
    await expectLater(
      store.instantiate(id, folderId: 'missing'),
      throwsStateError,
    );
    await db.insert('todo_folders', {
      'id': 'hidden',
      'name': 'Deleted',
      'is_deleted': 1,
      'created_at': stamp,
      'updated_at': stamp,
    });
    await db.insert('todo_folders', {
      'id': 'child',
      'name': 'Child',
      'parent_id': 'hidden',
      'created_at': stamp,
      'updated_at': stamp,
    });
    await expectLater(
      store.instantiate(id, folderId: 'child'),
      throwsStateError,
    );
    expect(await db.query('todos'), before);
  });
  test(
    'Template validation rejects malformed and future payloads before writes',
    () async {
      final source = await store.fromTask('source');
      await expectLater(
        store.save(change(source, name: ' ')),
        throwsFormatException,
      );
      for (final item in [
        {...source.content, 'version': 2},
        {...source.content, 'priority': 1.5},
        {
          ...source.content,
          'checklist': [''],
        },
        {...source.content, 'reminder': stamp},
      ]) {
        expect(
          () => TaskTemplate.decode(jsonEncode(item)),
          throwsFormatException,
        );
      }
      expect(await store.all(), isEmpty);
    },
  );
  test('Portable backup imports templates independently and repeated imports stay idempotent', () async {
    await store.save(await store.fromTask('source'));
    final notes = await NoteDatabase.openAt(
      '${directory.path}/notes.db',
      secure: secure,
    );
    final targetNotes = await NoteDatabase.openAt(
      '${directory.path}/target-notes.db',
      secure: secure,
    );
    final target = await TodoDatabase.openAt(
      '${directory.path}/target-tasks.db',
      secure: secure,
    );
    try {
      final snapshot = await BackupStore(notesDb: notes, todoDb: db).snapshot();
      expect(snapshot['todoSchema'], 10);
      final backup = BackupStore(notesDb: targetNotes, todoDb: target);
      expect(await backup.restore(snapshot, 'Imported'), true);
      final imported = (await TaskTemplateStore(target).all()).single;
      expect(imported.id, isNot((await store.all()).single.id));
      expect(imported.checklist, ['Read agenda', 'Write minutes']);
      final task = await TaskTemplateStore(target).instantiate(imported.id);
      expect(
        await TodoChecklistStore.load(target, task['id'] as String),
        hasLength(2),
      );
      expect(await backup.restore(snapshot, 'Again'), false);
      final bad = jsonDecode(jsonEncode(snapshot)) as Map<String, dynamic>;
      ((bad['data'] as Map)['todo_templates'] as List).single['payload'] =
          '{"version":999}';
      await expectLater(backup.restore(bad, 'Invalid'), throwsFormatException);
      expect(await TaskTemplateStore(target).all(), hasLength(1));
      final legacy = jsonDecode(jsonEncode(snapshot)) as Map<String, dynamic>;
      legacy['todoSchema'] = 9;
      (legacy['data'] as Map).remove('todo_templates');
      expect(BackupStore.validate(legacy)['todo_templates'], isEmpty);
    } finally {
      await notes.close();
      await targetNotes.close();
      await target.close();
    }
  });
}
