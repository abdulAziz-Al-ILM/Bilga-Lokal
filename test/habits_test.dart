import 'dart:io';

import 'package:bilga/features/habits/habit_store.dart';
import 'package:bilga/features/notes/note_database.dart';
import 'package:bilga/features/todo/todo_database.dart';
import 'package:bilga/features/backup/backup_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'database_safety_test.dart' show initializeTestSqlite;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  databaseFactory = createDatabaseFactoryFfi(ffiInit: initializeTestSqlite);
  test('Streak uses calendar days across month boundaries and yesterday', () {
    expect(habitStreak({'2026-08-31', '2026-09-01'}, DateTime(2026, 9, 2)), 2);
    expect(habitStreak({'2026-08-31', '2026-09-01'}, DateTime(2026, 9, 3)), 0);
  });
  test('Habit check-in is idempotent and survives backup/restore', () async {
    final directory = await Directory.systemTemp.createTemp(
      'bilga-habits-test-',
    );
    final db = await NoteDatabase.openAt('${directory.path}/notes.db');
    final todo = await TodoDatabase.openAt('${directory.path}/todo.db');
    final db2 = await NoteDatabase.openAt('${directory.path}/notes2.db');
    final todo2 = await TodoDatabase.openAt('${directory.path}/todo2.db');
    try {
      final store = HabitStore(provided: db);
      await store.create(
        'Read',
        plan: HabitPlan(target: 10, unit: 'pages', cue: 'After tea'),
      );
      final habit = (await store.all()).single;
      await store.mark(habit.id, DateTime(2026, 8, 1), true);
      await store.mark(habit.id, DateTime(2026, 8, 1), true);
      expect((await store.all()).single.days.length, 1);
      await store.checkIn(
        habit.id,
        DateTime(2026, 8, 2),
        3,
        note: 'Small step',
      );
      final backup = await BackupStore(notesDb: db, todoDb: todo).snapshot();
      final target = BackupStore(notesDb: db2, todoDb: todo2);
      expect(await target.restore(backup, 'Imported'), true);
      expect(await target.restore(backup, 'Imported'), false);
      expect((await HabitStore(provided: db2).all()).single.days, {
        '2026-08-01',
      });
      final restored = (await HabitStore(provided: db2).all()).single;
      expect(restored.plan.target, 10);
      expect(restored.plan.entries['2026-08-02']['note'], 'Small step');
      expect(restored.plan.amount(DateTime(2026, 8, 2), restored.days), 3);
      await store.mark(habit.id, DateTime(2026, 8, 1), false);
      expect((await store.all()).single.days, isEmpty);
      await store.archive(habit.id, true);
      expect(await store.all(), isEmpty);
      expect((await store.all(includeArchived: true)).length, 1);
      final oldBackup = Map<String, dynamic>.from(backup)..['notesSchema'] = 8;
      oldBackup['data'] = Map<String, dynamic>.from(backup['data'] as Map)
        ..remove('habits');
      expect(BackupStore.validate(oldBackup)['habits'], isEmpty);
    } finally {
      await db.close();
      await todo.close();
      await db2.close();
      await todo2.close();
      await directory.delete(recursive: true);
    }
  });
}
