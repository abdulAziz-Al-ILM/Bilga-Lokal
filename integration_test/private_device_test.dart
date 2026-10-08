import 'package:sqflite/sqflite.dart';

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:bilga/features/notes/note_database.dart';
import 'package:bilga/features/habits/habit_store.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Encrypted habit survives closing and reopening the database', (
    tester,
  ) async {
    final dir = await Directory(
      '${(await getTemporaryDirectory()).path}/habit-${DateTime.now().microsecondsSinceEpoch}',
    ).create();
    final path = '${dir.path}/habits.db';
    Database? opened;
    try {
      var db = await NoteDatabase.openAt(path, secure: true);
      opened = db;
      expect(
        (await db.rawQuery('PRAGMA secure_delete')).single.values.single,
        1,
      );
      var store = HabitStore(provided: db);
      await store.create(
        'Kitob o‘qish 📚',
        id: 'persisted-habit',
        plan: HabitPlan(target: 20, unit: 'minutes', cue: 'After breakfast'),
      );
      final today = DateTime.now();
      await store.mark('persisted-habit', today, true);
      await db.close();
      opened = null;

      db = await NoteDatabase.openAt(path, secure: true);
      opened = db;
      store = HabitStore(provided: db);
      final habit = (await store.all()).single;
      expect(habit.id, 'persisted-habit');
      expect(habit.title, 'Kitob o‘qish 📚');
      expect(habit.days, {dayKey(today)});
      expect(habit.plan.target, 20);
      expect(habit.plan.cue, 'After breakfast');
      expect(habit.plan.amount(today, habit.days), 20);
      expect(
        String.fromCharCodes(await File(path).openRead(0, 16).first),
        isNot('SQLite format 3\x00'),
      );
    } finally {
      await opened?.close();
      await dir.delete(recursive: true);
    }
  });
  testWidgets('Existing Unicode notes migrate to encrypted database', (
    tester,
  ) async {
    final dir = await Directory(
      '${(await getTemporaryDirectory()).path}/migration-${DateTime.now().microsecondsSinceEpoch}',
    ).create();
    final path = '${dir.path}/fixture.db';
    try {
      var db = await NoteDatabase.openAt(path);
      await db.insert('notes', {
        'id': 'test',
        'title': 'Salom 🌿',
        'body': 'Привет — مرحبا',
        'created_at': '2026-10-01',
        'updated_at': '2026-10-01',
      });
      await db.close();
      expect(
        String.fromCharCodes(await File(path).openRead(0, 16).first),
        'SQLite format 3\x00',
      );
      db = await NoteDatabase.openAt(path, secure: true);
      expect((await db.query('notes')).single['body'], 'Привет — مرحبا');
      expect(await db.getVersion(), 11);
      await db.close();
      expect(
        String.fromCharCodes(await File(path).openRead(0, 16).first),
        isNot('SQLite format 3\x00'),
      );
      expect(await File('$path.plain-migration').exists(), false);
    } finally {
      await dir.delete(recursive: true);
    }
  });
}
