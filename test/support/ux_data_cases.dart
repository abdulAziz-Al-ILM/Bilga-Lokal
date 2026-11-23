import 'dart:convert';
import 'dart:io';

import 'package:bilga/features/backup/backup_store.dart';
import 'package:bilga/features/books/book_library.dart';
import 'package:bilga/features/finance/finance_page.dart';
import 'package:bilga/features/finance/finance_planning.dart';
import 'package:bilga/features/finance/ledger.dart';
import 'package:bilga/features/habits/habit_store.dart';
import 'package:bilga/features/notes/note_database.dart';
import 'package:bilga/features/organization/organization_store.dart';
import 'package:bilga/features/private_space/record_store.dart';
import 'package:bilga/features/reminders/alert_preferences.dart';
import 'package:bilga/features/reminders/attention_repository.dart';
import 'package:bilga/features/todo/todo_database.dart';
import 'package:bilga/features/voice/personal_answers.dart';
import 'package:bilga/features/voice/voice_command.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

void registerUxDataCases({
  Future<Directory> Function()? fixture,
  bool secure = false,
}) {
  late Database notes, tasks;
  late Directory dir;
  late RecordStore records;

  setUp(() async {
    dir =
        await (fixture?.call() ?? Directory.systemTemp.createTemp('bilga-ux-'));
    notes = await NoteDatabase.openAt('${dir.path}/notes.db', secure: secure);
    tasks = await TodoDatabase.openAt('${dir.path}/tasks.db', secure: secure);
    records = RecordStore(database: notes);
  });
  tearDown(() async {
    await tasks.close();
    await notes.close();
    await dir.delete(recursive: true);
  });
  bool allowed() => true;

  Map<String, dynamic> entry(
    String id,
    String type,
    int amount,
    String date, {
    String? parent,
    bool voided = false,
    String category = 'Food',
  }) => {
    'id': id,
    'type': type,
    'amount': amount,
    'date': date,
    'void': voided,
    'category': category,
    'description': id,
    'parent': ?parent,
  };

  test('Nested folders and trash survive portable restore without modifying finance or record identity', () async {
    final ledger = await records.save('finance', {
      'currency': 'USD',
      'title': 'Household',
      'entries': [
        entry('purchase', 'expense', 789, '2026-11-18'),
        entry('loan', 'borrowed', 12345, '2026-11-16'),
        entry('payment', 'repaymentOut', 345, '2026-11-19', parent: 'loan'),
      ],
    });
    final store = OrganizationStore('finance', provided: notes);
    await store.saveFolder('Family', allowed: allowed);
    final parent = (await store.folders()).single;
    await store.saveFolder(
      'Trips',
      parent: parent.id,
      icon: 'work',
      color: 3,
      allowed: allowed,
    );
    final child = (await store.folders()).firstWhere(
      (row) => row.parent == parent.id,
    );
    final items = await store.items(folder: null, query: 'purchase');
    await store.move(items.single, child.id, allowed: allowed);
    await expectLater(
      store.saveFolder(
        'Family',
        id: parent.id,
        parent: child.id,
        allowed: allowed,
      ),
      throwsStateError,
    );
    expect(
      (await store.items(folder: child.id, query: '')).single.entry,
      'purchase',
    );
    expect(
      (await store.folders()).firstWhere((row) => row.id == child.id).count,
      1,
    );
    await store.saveFolder(
      parent.name,
      id: parent.id,
      deleted: true,
      allowed: allowed,
    );
    expect(
      (await store.items(folder: null, query: 'purchase')).single.entry,
      'purchase',
    );
    expect((await records.get(ledger.id)).data, ledger.data);
    expect((await records.get(ledger.id)).revision, ledger.revision);
    final backup = BackupStore(notesDb: notes, todoDb: tasks);
    final snapshot = await backup.snapshot();
    expect(snapshot['notesSchema'], 19);
    expect(
      () => BackupStore.validate({...snapshot, 'notesSchema': 18}),
      throwsFormatException,
    );
    expect(await backup.restore(snapshot, 'Restored organization'), true);
    expect(await backup.restore(snapshot, 'Restored organization'), false);
    final restored = (await store.folders()).singleWhere(
      (row) => row.name == 'Family' && row.id != parent.id,
    );
    expect(restored.deleted, true);
    await store.saveFolder(restored.name, id: restored.id, allowed: allowed);
    final nested = (await store.folders()).singleWhere(
      (row) => row.parent == restored.id,
    );
    final restoredItem = (await store.items(
      folder: nested.id,
      query: '',
    )).single;
    expect(restoredItem.entry, 'purchase');
    expect((await records.get(restoredItem.id)).data, ledger.data);
    expect(
      Ledger.balance((await records.get(restoredItem.id)).data),
      Ledger.balance(ledger.data),
    );
  });

  test('Notes20 migration preserves book payload and converts multiple legacy shelves', () async {
    final book = await records.save(
      'book',
      BookLibrary.update(
        {
          'title': 'Outline',
          'chapters': <Map<String, dynamic>>[],
          'bookmark': 0,
          'characters': '',
        },
        {
          'shelves': ['Science', 'Encyclopedia'],
        },
      ),
    );
    final original = (await notes.query(
      'private_records',
      where: 'id=?',
      whereArgs: [book.id],
    )).single['payload'];
    await notes.setVersion(20);
    await notes.close();
    notes = await NoteDatabase.openAt('${dir.path}/notes.db', secure: secure);
    final folders = OrganizationStore('book', provided: notes);
    expect(await notes.getVersion(), 21);
    final shelves = await folders.folders();
    expect(
      shelves.map((row) => row.name),
      unorderedEquals(['Science', 'Encyclopedia']),
    );
    for (final shelf in shelves) {
      expect(
        (await folders.items(folder: shelf.id, query: '')).single.id,
        book.id,
      );
    }
    expect(
      (await notes.query(
        'private_records',
        where: 'id=?',
        whereArgs: [book.id],
      )).single['payload'],
      original,
    );
  });

  test('Exact check-ins keep over-target values, notes and concurrent incremental intent', () async {
    final habits = HabitStore(provided: notes);
    final today = DateTime.now();
    await habits.create(
      'Push ups',
      id: 'push',
      plan: HabitPlan(target: 12, unit: 'repetitions'),
    );
    await habits.checkIn('push', today, 6, note: 'Actual record');
    await Future.wait(List.generate(7, (_) => habits.adjust('push', today, 1)));
    var row = await habits.get('push');
    expect(row.plan.amount(today, row.days), 13);
    expect(row.plan.done(today, row.days), true);
    expect(row.plan.entries[dayKey(today)]['note'], 'Actual record');
    await habits.adjust('push', today, -2);
    row = await habits.get('push');
    expect(row.plan.amount(today, row.days), 11);
    expect(row.plan.done(today, row.days), false);
  });

  test('Dashboard and voice totals respect exact currency, current date and voided transactions', () async {
    final usd = {
      'currency': 'USD',
      'title': 'US journal',
      'entries': [
        entry('monday', 'expense', 250, '2026-11-16'),
        entry('today', 'expense', 899, '2026-11-19'),
        entry('tomorrow', 'expense', 400, '2026-11-20'),
        entry('voided', 'expense', 1088, '2026-11-19', voided: true),
        entry('received', 'income', 5020, '2026-11-19'),
        entry('last-month', 'expense', 321, '2026-10-31'),
      ],
    };
    await records.save('finance', usd);
    await records.save('finance', {
      'currency': 'JPY',
      'title': 'Japan journal',
      'entries': [entry('rail', 'expense', 123, '2026-11-18')],
    });
    final summary = financeOverview((usd, '2026-11-19'));
    expect(
      (summary.today, summary.income, summary.expense, summary.balance),
      (899, 5020, 1149, 3550),
    );
    expect(
      (await PersonalAnswers(
        notes,
        tasks,
      ).spentThisWeek(DateTime(2026, 11, 19), (s) => s)).single,
      allOf(contains('11.49 USD'), contains('123 JPY')),
    );
    final renamed = FinancePlanning.change(usd, (plan) {
      plan['categories'] = [
        {'name': 'Food', 'parent': '', 'label': 'Meals', 'archived': true},
      ];
    });
    expect((renamed['entries'] as List).first['category'], 'Food');
    expect(
      financeOverview((renamed, '2026-11-19')).categories.single.key,
      'Meals',
    );
    expect(Ledger.balance(renamed), Ledger.balance(usd));
    await records.save('finance', renamed);
    final saved = await BackupStore(notesDb: notes, todoDb: tasks).snapshot();
    expect(saved['notesSchema'], 19);
  });

  test('Reminder preferences omit private text and do not duplicate explicit task reminders', () async {
    final now = DateTime(2026, 11, 19, 12);
    for (final id in ['explicit', 'ordinary']) {
      await tasks.insert('todos', {
        'id': id,
        'title': 'PRIVATE $id',
        'description': '',
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
        'due_at': now.add(const Duration(hours: 2)).toIso8601String(),
      });
    }
    await tasks.insert('todo_reminders', {
      'todo_id': 'explicit',
      'enabled': 1,
      'remind_at': now.add(const Duration(hours: 1)).toIso8601String(),
      'revision': 'current',
      'fired': 0,
    });
    final repository = AttentionRepository(notes: notes, tasks: tasks);
    expect(
      await repository.load(
        now,
        const AlertPreferences({}, 1140),
        scheduledOnly: true,
      ),
      isEmpty,
    );
    final rows = await repository.load(
      now,
      const AlertPreferences({'taskDue': true, 'taskSoon': true}, 1140),
      scheduledOnly: true,
    );
    expect(rows.map((r) => r.id), ['ordinary', 'ordinary']);
    expect(rows.map((r) => r.event), ['taskSoon', 'taskDue']);
    final nativePolicy = rows
        .map((r) => {'target': r.id, 'event': r.event})
        .toList();
    expect(jsonEncode(nativePolicy), isNot(contains('PRIVATE')));
  });

  test('Voice uses local prior Friday, explicit questions and actual saved records', () async {
    expect(
      VoiceCommand.parse('Bugun nima qilishim kerak?').action,
      VoiceAction.today,
    );
    expect(
      VoiceCommand.parse('Read my mathematics folder.').argument,
      'mathematics',
    );
    expect(
      VoiceCommand.parse('How much did I spend this week?').action,
      VoiceAction.weeklySpending,
    );
    final date = PersonalAnswers.previousFriday(DateTime(2026, 11, 20));
    expect(date, DateTime(2026, 11, 13));
    await notes.insert('notes', {
      'id': 'written',
      'title': 'Actual Friday',
      'body': 'Only the saved text.',
      'created_at': date.toIso8601String(),
      'updated_at': date.toIso8601String(),
    });
    final answer = await PersonalAnswers(notes, tasks).written(date, (s) => s);
    expect(answer.single, contains('Actual Friday'));
    expect(answer.single, contains('Only the saved text.'));
    expect(
      (await PersonalAnswers(
        notes,
        tasks,
      ).written(DateTime(2026, 11, 14), (s) => s)).single,
      contains('empty'),
    );
  });

  test('Tomorrow’s spoken plan uses the next calendar day only', () async {
    final now = DateTime(2026, 12, 31, 20);
    for (final entry in {
      'Yesterday’s overdue task': DateTime(2026, 12, 30, 11),
      'Today’s task': DateTime(2026, 12, 31, 23),
      'Tomorrow’s actual task': DateTime(2027, 1, 1, 9),
      'Other planned task': DateTime(2027, 1, 2, 9),
    }.entries) {
      await tasks.insert('todos', {
        'id': entry.key,
        'title': entry.key,
        'description': '',
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
        'due_at': entry.value.toIso8601String(),
      });
    }
    final answer = await PersonalAnswers(
      notes,
      tasks,
    ).plan(now, (s) => s, tomorrow: true);
    expect(answer.first, 'tomorrow · 1\nTomorrow’s actual task');
    expect(answer, hasLength(2));
  });
}
