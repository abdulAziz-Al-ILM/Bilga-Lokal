import 'dart:convert';
import 'dart:io';

import 'package:bilga/core/private_database.dart';
import 'package:bilga/features/habits/habit_store.dart';
import 'package:bilga/features/habits/habit_schedule.dart';
import 'package:bilga/features/notes/note_database.dart';
import 'package:bilga/features/todo/todo_database.dart';
import 'package:bilga/features/backup/backup_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

void registerAdvancedHabitDataCases({
  Future<Directory> Function()? createDirectory,
  bool secure = false,
}) {
  late Directory dir;
  late Database notes, tasks;
  late HabitStore store;
  setUp(() async {
    dir =
        await (createDirectory?.call() ??
            Directory.systemTemp.createTemp('bilga-advanced-habits-'));
    notes = await NoteDatabase.openAt('${dir.path}/notes.db', secure: secure);
    tasks = await TodoDatabase.openAt('${dir.path}/tasks.db', secure: secure);
    store = HabitStore(provided: notes);
  });
  tearDown(() async {
    if (notes.isOpen) await notes.close();
    await tasks.close();
    await dir.delete(recursive: true);
  });
  test('Changing a daily target preserves recorded amounts and the legacy fallback for historical editing', () async {
    final today = DateTime.now(),
        first = DateTime(today.year, today.month, today.day - 10),
        yesterday = DateTime(today.year, today.month, today.day - 1);
    await store.create(
      'Read',
      id: 'read',
      plan: HabitPlan(
        target: 10,
        unit: 'pages',
        schedules: {
          dayKey(first): [1, 2, 3, 4, 5, 6, 7],
        },
      ),
    );
    await notes.update(
      'habits',
      {'created_at': first.toIso8601String()},
      where: 'id=?',
      whereArgs: ['read'],
    );
    await store.checkIn(
      'read',
      DateTime(today.year, today.month, today.day - 2),
      10,
    );
    await store.configure('read', 'Read', HabitPlan(target: 20, unit: 'pages'));
    var habit = await store.get('read');
    expect(habit.plan.targetAt(yesterday), 10);
    expect(habit.plan.targetAt(today), 20);
    await store.mark('read', yesterday, true);
    habit = await store.get('read');
    expect(habit.plan.amount(yesterday, habit.days), 10);
    expect(habit.plan.entries[dayKey(yesterday)]['target'], 10);
    expect(
      habit.plan.done(
        DateTime(today.year, today.month, today.day - 2),
        habit.days,
      ),
      isTrue,
    );
  });
  test('Weekly/monthly quotas earn period streaks from actual completions, with partial-period and pause rules', () {
    final weekly = HabitPlan(
      schedule: HabitSchedule.decode({
        'type': 'weekly',
        'quota': 3,
        'start': '2026-11-02',
      }),
    );
    expect(
      weekly.streak(
        {'2026-11-02', '2026-11-03', '2026-11-04'},
        DateTime(2026, 11, 9),
        created: DateTime(2026, 11, 2),
      ),
      1,
    );
    expect(
      weekly.streak(
        {'2026-11-02', '2026-11-03'},
        DateTime(2026, 11, 9),
        created: DateTime(2026, 11, 2),
      ),
      0,
    );
    final monthly = HabitPlan(
      schedule: HabitSchedule.decode({
        'type': 'monthly',
        'quota': 3,
        'start': '2024-02-27',
      }),
    );
    expect(
      monthly.streak(
        {'2024-02-27', '2024-02-28', '2024-02-29'},
        DateTime(2024, 3, 1),
        created: DateTime(2024, 2, 27),
      ),
      1,
    );
    expect(
      monthly.completedDays({'2024-02-27', '2024-03-02'}, DateTime(2024, 3, 1)),
      1,
    );
  });
  test('Basic edits retain categories, tags, goals and advanced schedule; portable17 restore retains all history', () async {
    final plan = HabitPlan(
      schedule: HabitSchedule.decode({
        'type': 'weekly',
        'quota': 3,
        'start': '2026-01-01',
      }),
      category: 'Learning',
      tags: {'study'},
      favorite: true,
      goalTarget: 40,
      goalDate: '2026-12-31',
      reminderMinute: 540,
    );
    await store.create('Study', id: 'study', plan: plan);
    await store.checkIn('study', DateTime(2026, 1, 1), 1, note: 'Actual work');
    final edited = (await store.get('study')).plan
        .copyWith(target: 5, unit: 'pages');
    await store.configure('study', 'Study edited', edited);
    final h = await store.get('study');
    expect(h.plan.category, 'Learning');
    expect(h.plan.schedule!.type, 'weekly');
    expect(h.plan.tags, {'study'});
    expect(h.plan.favorite, isTrue);
    expect(h.plan.reminderMinute, 540);
    expect(h.plan.goalTarget, 40);
    expect(h.plan.entries['2026-01-01']['note'], 'Actual work');
    final backup = BackupStore(notesDb: notes, todoDb: tasks),
        snapshot = await BackupStore(notesDb: notes, todoDb: tasks).snapshot();
    expect(snapshot['notesSchema'], 17);
    final bad = jsonDecode(jsonEncode(snapshot)) as Map<String, dynamic>;
    bad['notesSchema'] = 16;
    expect(() => BackupStore.validate(bad), throwsFormatException);
    expect(await backup.restore(snapshot, 'Imported'), isTrue);
    expect(await backup.restore(snapshot, 'Imported'), isFalse);
    final restored = (await store.all()).singleWhere((h) => h.id != 'study');
    expect(restored.plan.encode(), h.plan.encode());
  });
  test('Notes19 capability prevents older Notes18 executables from rewriting advanced plans', () async {
    await store.create(
      'Keep',
      id: 'keep',
      plan: HabitPlan(
        schedule: HabitSchedule.decode({
          'type': 'monthly',
          'quota': 5,
          'start': '2026-01-01',
        }),
      ),
    );
    final before = await notes.query('habits'), path = notes.path;
    await notes.close();
    await expectLater(
      PrivateDatabase.open(
        path,
        secure: secure,
        version: 18,
        onCreate: (d, v) async {},
        onUpgrade: (d, a, b) async {},
      ),
      throwsStateError,
    );
    notes = await NoteDatabase.openAt(path, secure: secure);
    expect(await notes.getVersion(), 20);
    expect(await notes.query('habits'), before);
  });
}
