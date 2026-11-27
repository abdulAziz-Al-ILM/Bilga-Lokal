import 'dart:convert';
import 'dart:io';

import 'package:bilga/features/backup/backup_store.dart';
import 'package:bilga/features/collections/collection_repository.dart';
import 'package:bilga/features/notes/note_database.dart';
import 'package:bilga/features/todo/recurrence_rule.dart';
import 'package:bilga/features/todo/reminders/todo_reminder_store.dart';
import 'package:bilga/features/todo/todo_checklist_store.dart';
import 'package:bilga/features/todo/todo_database.dart';
import 'package:bilga/features/todo/todo_series_store.dart';
import 'package:bilga/features/todo/widget/todo_widget_permissions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

void registerTodoChecklistTests({
  Future<Directory> Function()? createDirectory,
  bool secure = false,
}) {
  late Directory directory;
  late Database db;
  final clock = DateTime.utc(2030, 1, 31, 9);
  setUp(() async {
    directory =
        await (createDirectory?.call() ??
            Directory.systemTemp.createTemp('bilga-checklist-'));
    db = await TodoDatabase.openAt(
      '${directory.path}/tasks.db',
      secure: secure,
    );
    for (final id in ['a', 'b']) {
      await db.insert('todos', {
        'id': id,
        'title': 'Task $id',
        'due_at': clock.toIso8601String(),
        'created_at': clock.toIso8601String(),
        'updated_at': clock.toIso8601String(),
      });
    }
  });
  tearDown(() async {
    await db.close();
    await directory.delete(recursive: true);
  });
  Future<void> save(String id, List<TodoChecklistItem> items) =>
      db.transaction((txn) => TodoChecklistStore.replace(txn, id, items));

  test(
    'Upgrade from Tasks 10 adds checklist without changing tasks or series',
    () async {
      await db.transaction(
        (txn) => TodoSeriesStore.configure(
          txn,
          'a',
          RecurrenceRule(unit: RecurrenceUnit.month),
        ),
      );
      final before = await db.query('todos'),
          series = await db.query('todo_series');
      await db.execute('DROP TABLE todo_projects');
      await db.execute('DROP TABLE todo_templates');
      await db.execute('DROP TABLE todo_checklist');
      await db.setVersion(10);
      await db.close();
      db = await TodoDatabase.openAt(
        '${directory.path}/tasks.db',
        secure: secure,
      );
      expect(await db.getVersion(), 13);
      expect(await db.query('todos'), before);
      expect(await db.query('todo_series'), series);
      expect(await db.query('todo_checklist'), isEmpty);
    },
  );

  test(
    'Invalid/failed checklist edits roll back and never touch another task',
    () async {
      await save('a', [const TodoChecklistItem('first', 'First', done: true)]);
      await save('b', [const TodoChecklistItem('other', 'Other task')]);
      await expectLater(
        save('a', [const TodoChecklistItem('first', '')]),
        throwsFormatException,
      );
      await expectLater(
        save('a', [const TodoChecklistItem('other', 'Steal ID')]),
        throwsA(anything),
      );
      expect((await TodoChecklistStore.load(db, 'a')).single.title, 'First');
      expect((await TodoChecklistStore.load(db, 'a')).single.done, true);
      expect(
        (await TodoChecklistStore.load(db, 'b')).single.title,
        'Other task',
      );
      await db.execute(
        "CREATE TRIGGER fail_check BEFORE INSERT ON todo_checklist WHEN NEW.title='fail' BEGIN SELECT RAISE(ABORT,'synthetic'); END",
      );
      await expectLater(
        save('a', [const TodoChecklistItem('new', 'fail')]),
        throwsA(anything),
      );
      expect((await TodoChecklistStore.load(db, 'a')).single.id, 'first');
      final repo = CollectionRepository(CollectionKind.todos, provided: db);
      await repo.trash('a');
      expect((await TodoChecklistStore.load(db, 'a')).single.done, true);
      await repo.restore('a');
      expect((await TodoChecklistStore.load(db, 'a')).single.done, true);
      await db.delete('todos', where: 'id=?', whereArgs: ['a']);
      expect(await TodoChecklistStore.load(db, 'a'), isEmpty);
      expect(await TodoChecklistStore.load(db, 'b'), hasLength(1));
    },
  );

  test('Subtask search follows updates, rollback, trash and delete without duplicates', () async {
    Future<List<Map<String, Object?>>> search(String term) => db.rawQuery(
      "SELECT id FROM bilga_search WHERE bilga_search MATCH ? AND kind='todo'",
      [term],
    );
    await save('a', [const TodoChecklistItem('first', 'Uniqueword')]);
    expect(await search('Uniqueword'), hasLength(1));
    final repo = CollectionRepository(CollectionKind.todos, provided: db);
    expect((await repo.load(query: 'Uniqueword')).items.single['id'], 'a');
    await db.update(
      'todos',
      {'description': 'Edited body'},
      where: 'id=?',
      whereArgs: ['a'],
    );
    expect(await search('Uniqueword'), hasLength(1));
    try {
      await db.transaction((txn) async {
        await TodoChecklistStore.replace(txn, 'a', [
          const TodoChecklistItem('first', 'Changedword'),
        ]);
        throw StateError('synthetic rollback');
      });
    } catch (_) {}
    expect(await search('Uniqueword'), hasLength(1));
    expect(await search('Changedword'), isEmpty);
    await repo.trash('a');
    expect(await search('Uniqueword'), isEmpty);
    await repo.restore('a');
    expect(await search('Uniqueword'), hasLength(1));
    await save('a', []);
    expect(await search('Uniqueword'), isEmpty);
  });

  test('Recurrence keeps old progress, resets new progress and respects edit scope', () async {
    await save('a', [const TodoChecklistItem('first', 'Original', done: true)]);
    await db.transaction(
      (txn) => TodoSeriesStore.configure(
        txn,
        'a',
        RecurrenceRule(unit: RecurrenceUnit.month),
      ),
    );
    await save('a', [
      const TodoChecklistItem('first', 'Only this occurrence', done: true),
    ]);
    final store = TodoSeriesStore(db);
    final next = (await store.setCompleted('a', true, at: clock))!;
    expect(
      (await TodoChecklistStore.load(db, 'a')).single.title,
      'Only this occurrence',
    );
    final copied = (await TodoChecklistStore.load(db, next)).single;
    expect(copied.title, 'Original');
    expect(copied.done, false);
    expect(copied.id, isNot('first'));
    await save(next, [copied.copyWith(title: 'Future default', done: true)]);
    await db.transaction(
      (txn) => TodoSeriesStore.configure(
        txn,
        next,
        RecurrenceRule(unit: RecurrenceUnit.month),
      ),
    );
    final march = (await store.setCompleted(
      next,
      true,
      at: DateTime.utc(2030, 2, 28, 9),
    ))!;
    expect(
      (await TodoChecklistStore.load(db, march)).single.title,
      'Future default',
    );
    expect((await TodoChecklistStore.load(db, march)).single.done, false);
    expect((await TodoChecklistStore.load(db, next)).single.done, true);
  });

  test(
    'Duplicate is independent and excludes reminder, series and widget consent',
    () async {
      await save('a', [
        const TodoChecklistItem('first', 'Prepare', done: true),
      ]);
      await TodoReminderStore.save(db, 'a', clock);
      await db.insert('todo_widget_permissions', {
        'todo_id': 'a',
        'title': 'Task a',
      });
      await db.transaction(
        (txn) => TodoSeriesStore.configure(
          txn,
          'a',
          RecurrenceRule(unit: RecurrenceUnit.month),
        ),
      );
      final id = await CollectionRepository(
        CollectionKind.todos,
        provided: db,
      ).duplicateTask('a');
      expect((await TodoChecklistStore.load(db, id)).single.done, false);
      expect(await TodoSeriesStore.forTask(db, id), isNull);
      expect(
        await db.query('todo_reminders', where: 'todo_id=?', whereArgs: [id]),
        isEmpty,
      );
      expect((await TodoWidgetPermissions.allowed(db)).containsKey(id), false);
      await save(id, [const TodoChecklistItem('copy-edit', 'Independent')]);
      expect((await TodoChecklistStore.load(db, 'a')).single.title, 'Prepare');
    },
  );

  test('Backup preserves ordering/progress and rejects orphan/duplicate positions before writing', () async {
    final notes = await NoteDatabase.openAt(
      '${directory.path}/notes.db',
      secure: secure,
    );
    final targetNotes = await NoteDatabase.openAt(
      '${directory.path}/target-notes.db',
      secure: secure,
    );
    final target = await TodoDatabase.openAt(
      '${directory.path}/target.db',
      secure: secure,
    );
    try {
      await save('a', [
        const TodoChecklistItem('second', 'Second'),
        const TodoChecklistItem('first', 'First', done: true),
      ]);
      final snapshot = await BackupStore(notesDb: notes, todoDb: db).snapshot();
      final store = BackupStore(notesDb: targetNotes, todoDb: target);
      expect(snapshot['todoSchema'], 11);
      expect(await store.restore(snapshot, 'Restored'), true);
      final row = (await target.query(
        'todos',
        where: 'title=?',
        whereArgs: ['Task a'],
      )).single;
      final items = await TodoChecklistStore.load(target, row['id'] as String);
      expect(items.map((item) => item.title), ['Second', 'First']);
      expect(items.map((item) => item.done), [false, true]);
      expect(items.map((item) => item.id), isNot(contains('first')));
      expect(await store.restore(snapshot, 'Again'), false);
      for (final field in ['todo_id', 'position', 'title']) {
        final bad = jsonDecode(jsonEncode(snapshot)) as Map<String, dynamic>;
        final rows = (bad['data'] as Map)['todo_checklist'] as List;
        (rows.last as Map)[field] = switch (field) {
          'todo_id' => 'missing',
          'position' => 0,
          _ => '',
        };
        await expectLater(store.restore(bad, 'Invalid'), throwsFormatException);
      }
      expect(await target.query('todo_checklist'), hasLength(2));
      final legacy = jsonDecode(jsonEncode(snapshot)) as Map<String, dynamic>;
      legacy['todoSchema'] = 8;
      (legacy['data'] as Map).remove('todo_checklist');
      expect(BackupStore.validate(legacy)['todo_checklist'], isEmpty);
    } finally {
      await notes.close();
      await targetNotes.close();
      await target.close();
    }
  });
}
