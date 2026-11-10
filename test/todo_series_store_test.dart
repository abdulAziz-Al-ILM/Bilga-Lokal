import 'dart:io';
import 'dart:convert';

import 'package:bilga/features/backup/backup_store.dart';
import 'package:bilga/features/notes/note_database.dart';

import 'package:bilga/features/todo/recurrence_rule.dart';
import 'package:bilga/features/todo/reminders/todo_reminder_store.dart';
import 'package:bilga/features/todo/todo_database.dart';
import 'package:bilga/features/todo/todo_series_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'database_safety_test.dart' show initializeTestSqlite;

void main() {
  databaseFactory = createDatabaseFactoryFfi(ffiInit: initializeTestSqlite);
  late Directory dir;
  late Database db;
  final due = DateTime.utc(2026, 1, 31, 9);
  final monthly = RecurrenceRule(unit: RecurrenceUnit.month);
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('bilga-series-');
    db = await TodoDatabase.openAt('${dir.path}/tasks.db');
    await db.insert('todos', {
      'id': 'task',
      'title': 'Original',
      'description': 'Series description',
      'priority': 2,
      'is_done': 0,
      'due_at': due.toIso8601String(),
      'created_at': due.toIso8601String(),
      'updated_at': due.toIso8601String(),
    });
  });
  tearDown(() async {
    await db.close();
    await dir.delete(recursive: true);
  });
  Future<void> configure(
    String id,
    RecurrenceRule rule, {
    bool reset = false,
  }) => db.transaction(
    (txn) => TodoSeriesStore.configure(txn, id, rule, resetAnchor: reset),
  );
  Future<Map<String, Object?>> row(String id) async =>
      (await db.query('todos', where: 'id=?', whereArgs: [id])).single;

  test('Completion retains old occurrence and creates one pending successor atomically', () async {
    await configure('task', monthly);
    final store = TodoSeriesStore(db);
    final next = await store.setCompleted(
      'task',
      true,
      at: due.add(const Duration(hours: 1)),
    );
    expect(next, isNotNull);
    expect((await row('task'))['is_done'], 1);
    expect(
      (await row(next!))['due_at'],
      DateTime.utc(2026, 2, 28, 9).toIso8601String(),
    );
    expect((await row(next))['description'], 'Series description');
    expect((await row(next))['priority'], 2);
    expect((await TodoSeriesStore.forTask(db, next))!['current_sequence'], 1);
    expect(await db.query('todo_occurrences'), hasLength(2));
  });

  test('Repeated completion and reopening a past occurrence never duplicate the current head', () async {
    await configure('task', monthly);
    final store = TodoSeriesStore(db), at = due.add(const Duration(hours: 1));
    final next = await store.setCompleted('task', true, at: at);
    expect(await store.setCompleted('task', true, at: at), isNull);
    await store.setCompleted('task', false, at: at);
    expect(await store.setCompleted('task', true, at: at), isNull);
    expect(await db.query('todos'), hasLength(2));
    expect((await TodoSeriesStore.forTask(db, 'task'))!['head_task_id'], next);
  });

  test('Generation failure rolls completion, reminder cancellation and series state back', () async {
    await TodoReminderStore.save(
      db,
      'task',
      due.subtract(const Duration(hours: 1)),
    );
    await configure('task', monthly);
    await db.execute(
      "CREATE TRIGGER refuse_generated BEFORE INSERT ON todos WHEN NEW.id LIKE 'occurrence:%' BEGIN SELECT RAISE(ABORT,'simulated disk error'); END",
    );
    await expectLater(
      TodoSeriesStore(db).setCompleted('task', true, at: due),
      throwsA(anything),
    );
    expect((await row('task'))['is_done'], 0);
    expect((await TodoSeriesStore.forTask(db, 'task'))!['current_sequence'], 0);
    expect(await db.query('todo_reminders'), hasLength(1));
    expect(await db.query('todos'), hasLength(1));
  });

  test('Occurrence edits preserve series defaults; future edits retain original month-end anchor', () async {
    await configure('task', monthly);
    await db.update(
      'todos',
      {
        'title': 'One occurrence',
        'due_at': DateTime.utc(2026, 2, 2, 9).toIso8601String(),
      },
      where: 'id=?',
      whereArgs: ['task'],
    );
    final store = TodoSeriesStore(db);
    final feb = (await store.setCompleted(
      'task',
      true,
      at: DateTime.utc(2026, 2, 2, 10),
    ))!;
    expect((await row(feb))['title'], 'Original');
    expect(
      (await row(feb))['due_at'],
      DateTime.utc(2026, 2, 28, 9).toIso8601String(),
    );
    await db.update(
      'todos',
      {'title': 'Future default'},
      where: 'id=?',
      whereArgs: [feb],
    );
    await configure(feb, monthly);
    expect(
      (await TodoSeriesStore.forTask(db, feb))!['anchor_at'],
      due.toIso8601String(),
    );
    final march = (await store.setCompleted(
      feb,
      true,
      at: DateTime.utc(2026, 2, 28, 10),
    ))!;
    expect(
      (await row(march))['due_at'],
      DateTime.utc(2026, 3, 31, 9).toIso8601String(),
    );
    expect((await row(march))['title'], 'Future default');
    await expectLater(configure('task', monthly), throwsStateError);
  });

  test('Calendar reminder pattern persists; missed reminders do not replay; end date stops generation', () async {
    final daily = RecurrenceRule(
      unit: RecurrenceUnit.day,
      until: DateTime.utc(2026, 2, 1),
    );
    await TodoReminderStore.save(db, 'task', DateTime.utc(2026, 1, 30, 8));
    await configure('task', daily);
    final store = TodoSeriesStore(db);
    final next = (await store.setCompleted(
      'task',
      true,
      at: due.add(const Duration(hours: 1)),
    ))!;
    final reminder = (await db.query(
      'todo_reminders',
      where: 'todo_id=?',
      whereArgs: [next],
    )).single;
    expect(
      reminder['remind_at'],
      DateTime.utc(2026, 1, 31, 8).toIso8601String(),
    );
    expect(reminder['fired'], 1);
    expect(
      await store.setCompleted(next, true, at: DateTime.utc(2026, 2, 1, 10)),
      isNull,
    );
    expect((await TodoSeriesStore.forTask(db, next))!['active'], 0);
    expect(await db.query('todos'), hasLength(2));
  });

  test('Backup merge remaps series/head/template references and still advances once', () async {
    final notes = await NoteDatabase.openAt('${dir.path}/notes.db');
    final targetNotes = await NoteDatabase.openAt(
      '${dir.path}/target-notes.db',
    );
    final target = await TodoDatabase.openAt('${dir.path}/target.db');
    try {
      await configure('task', monthly);
      final snapshot = await BackupStore(notesDb: notes, todoDb: db).snapshot();
      expect(snapshot['todoSchema'], 9);
      final imported = BackupStore(notesDb: targetNotes, todoDb: target);
      expect(await imported.restore(snapshot, 'Imported'), isTrue);
      final head = (await target.query('todos')).single;
      final state = (await TodoSeriesStore.forTask(
        target,
        head['id'] as String,
      ))!;
      expect(state['head_task_id'], head['id']);
      expect(
        (jsonDecode(state['template'] as String) as Map)['folder_id'],
        head['folder_id'],
      );
      final next = await TodoSeriesStore(target)
          .setCompleted(head['id'] as String, true, at: due);
      expect(next, isNotNull);
      expect(
        (await target.query(
          'todos',
          where: 'id=?',
          whereArgs: [next],
        )).single['due_at'],
        DateTime.utc(2026, 2, 28, 9).toIso8601String(),
      );
      expect(await imported.restore(snapshot, 'Again'), isFalse);
      final bad = jsonDecode(jsonEncode(snapshot)) as Map<String, dynamic>;
      ((bad['data'] as Map)['todo_series'] as List).single['head_task_id'] =
          'missing';
      await expectLater(
        imported.restore(bad, 'Invalid'),
        throwsFormatException,
      );
      expect(await target.query('todos'), hasLength(2));
    } finally {
      await notes.close();
      await targetNotes.close();
      await target.close();
    }
  });

  test('Trashing stops a series; restoring needs explicit resume; hard deletion is safe', () async {
    await configure('task', monthly);
    await db.update(
      'todos',
      {'is_deleted': 1},
      where: 'id=?',
      whereArgs: ['task'],
    );
    expect((await TodoSeriesStore.forTask(db, 'task'))!['active'], 0);
    await db.update(
      'todos',
      {'is_deleted': 0},
      where: 'id=?',
      whereArgs: ['task'],
    );
    expect((await TodoSeriesStore.forTask(db, 'task'))!['active'], 0);
    await configure('task', monthly);
    await db.delete('todos', where: 'id=?', whereArgs: ['task']);
    final series = (await db.query('todo_series')).single;
    expect(series['active'], 0);
    expect(series['head_task_id'], isNull);
    expect(await db.query('todo_occurrences'), isEmpty);
  });
}
