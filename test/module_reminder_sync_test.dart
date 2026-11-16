import 'dart:convert';
import 'dart:io';

import 'package:bilga/features/habits/habit_store.dart';
import 'package:bilga/features/habits/habit_schedule.dart';
import 'package:bilga/features/notes/note_database.dart';
import 'package:bilga/features/reminders/module_reminder_sync.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'database_safety_test.dart' show initializeTestSqlite;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  databaseFactory = createDatabaseFactoryFfi(ffiInit: initializeTestSqlite);
  late Directory dir;
  late Database db;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('bilga-reminder-policy-');
    db = await NoteDatabase.openAt('${dir.path}/notes.db');
  });
  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ModuleReminderBridge.channel, null);
    await db.close();
    await dir.delete(recursive: true);
  });
  test('Native mirror contains opted-in live policy only, with valid recent completed dates and no personal text', () async {
    final store = HabitStore(provided: db), now = DateTime(2026, 11, 16);
    await store.create(
      'PRIVATE TITLE',
      id: 'enabled',
      plan: HabitPlan(
        reminderMinute: 540,
        cue: 'PRIVATE CUE',
        category: 'PRIVATE CATEGORY',
        schedule: HabitSchedule.decode({'type': 'weekly', 'quota': 3}),
        schedules: {
          '2026-12-01': HabitSchedule.decode({'type': 'monthly', 'quota': 5})
              .encode(),
        },
      ),
    );
    await store.create('Off', id: 'off');
    await store.create(
      'Archived',
      id: 'archived',
      plan: HabitPlan(reminderMinute: 100),
    );
    await store.archive('archived', true);
    await store.checkIn('enabled', now, 1, note: 'PRIVATE NOTE');
    await store.checkIn('enabled', DateTime(2026, 11, 15), 1, skipped: true);
    await db.update(
      'habits',
      {
        'days': jsonEncode(['2025-01-01', '2026-02-30', '2026-11-17']),
      },
      where: 'id=?',
      whereArgs: ['enabled'],
    );
    final rows = await ModuleReminderSync.habitRows(db, now);
    expect(rows, hasLength(1));
    expect(rows.single['id'], 'habit:enabled');
    expect(rows.single['completed'], ['2026-11-16']);
    final windows = rows.single['windows'] as List;
    expect(windows, hasLength(2));
    expect(windows.last['from'], '2026-12-01');
    expect(windows.last['schedule']['type'], 'monthly');
    expect(jsonEncode(rows), isNot(contains('PRIVATE')));
  });
  test('Locked sources never publish and a later refresh replaces reminders after archive', () async {
    final store = HabitStore(provided: db);
    await store.create(
      'Private title',
      id: 'h',
      plan: HabitPlan(reminderMinute: 600),
    );
    var allowed = false;
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ModuleReminderBridge.channel, (call) async {
          calls.add(call);
          if (call.method == 'state') {
            return {'notifications': true, 'exact': true};
          }
          return null;
        });
    final sync = ModuleReminderSync(canRead: () => allowed, provided: db);
    await sync.refresh();
    expect(calls, isEmpty);
    allowed = true;
    await sync.refresh();
    expect((calls.last.arguments['rows'] as List).single['target'], 'h');
    await store.archive('h', true);
    await sync.refresh();
    expect(calls.last.arguments['rows'], isEmpty);
    expect(sync.failed, isFalse);
    sync.dispose();
  });
  test('Period quotas stop planner requirements without hiding a completed day that can be corrected', () {
    final p = HabitPlan(
      schedule: HabitSchedule.decode({
        'type': 'weekly',
        'quota': 3,
        'start': '2026-11-02',
      }),
    );
    final days = {'2026-11-02', '2026-11-03', '2026-11-04'};
    expect(
      p.due(DateTime(2026, 11, 5), days, created: DateTime(2026, 11, 2)),
      isFalse,
    );
    expect(
      p.due(DateTime(2026, 11, 4), days, created: DateTime(2026, 11, 2)),
      isTrue,
    );
    expect(
      p.due(DateTime(2026, 11, 9), days, created: DateTime(2026, 11, 2)),
      isTrue,
    );
  });
}
