import 'habit_changes.dart';

import 'dart:convert';
import 'dart:math';

import 'package:sqflite/sqflite.dart';

import '../notes/note_database.dart';
import 'habit_rules.dart';
import 'habit_plan.dart';
export 'habit_plan.dart';
export 'habit_rules.dart';

String newLocalId() =>
    '${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}';

class Habit {
  final String id, title;
  final Set<String> days;
  final bool archived;
  final HabitPlan plan;
  final DateTime created;
  Habit(
    this.id,
    this.title,
    this.days,
    this.archived, {
    HabitPlan? plan,
    DateTime? created,
  }) : plan = plan ?? HabitPlan(),
       created = created ?? DateTime.now();
  factory Habit.fromMap(Map<String, Object?> row) => Habit(
    row['id'] as String,
    row['title'] as String,
    Set<String>.from(jsonDecode(row['days'] as String) as List),
    row['is_archived'] == 1,
    plan: HabitPlan.decode(row['details'] as String? ?? '{}'),
    created: DateTime.parse(row['created_at'] as String).toLocal(),
  );
}

class HabitStore {
  final Database? provided;
  HabitStore({this.provided});
  Future<Database> get db async => provided ?? await NoteDatabase.database;
  Future<List<Habit>> all({bool includeArchived = false}) async =>
      (await (await db).query(
        'habits',
        where: includeArchived ? null : 'is_archived = 0',
        orderBy: 'created_at ASC',
      )).map(Habit.fromMap).toList();
  Future<Habit> get(String id) async {
    final rows = await (await db).query(
      'habits',
      where: 'id=?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) throw StateError('habit_missing');
    return Habit.fromMap(rows.single);
  }

  Future<void> create(String title, {String? id, HabitPlan? plan}) async {
    if (title.trim().isEmpty || title.length > 200) {
      throw ArgumentError('habit_title');
    }
    HabitPlan.decode((plan ?? HabitPlan()).encode());
    final now = DateTime.now().toIso8601String();
    await (await db).insert('habits', {
      'id': id ?? newLocalId(),
      'title': title.trim(),
      'days': '[]',
      'details': (plan ?? HabitPlan()).encode(),
      'is_archived': 0,
      'created_at': now,
      'updated_at': now,
    });
    HabitChanges.committed();
  }

  Future<void> rename(String id, String title) async {
    if (title.trim().isEmpty || title.length > 200) {
      throw ArgumentError('habit_title');
    }
    await (await db).update(
      'habits',
      {'title': title.trim(), 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
    HabitChanges.committed();
  }

  Future<void> archive(String id, bool value) async {
    await (await db).update(
      'habits',
      {
        'is_archived': value ? 1 : 0,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    HabitChanges.committed();
  }

  Future<void> configure(String id, String title, HabitPlan plan) async {
    if (title.trim().isEmpty || title.length > 200) {
      throw ArgumentError('habit_title');
    }
    HabitPlan.decode(plan.encode());
    await (await db).transaction((txn) async {
      final rows = await txn.query('habits', where: 'id = ?', whereArgs: [id]);
      if (rows.isEmpty) throw StateError('habit_missing');
      final old = Habit.fromMap(rows.single).plan;
      final data = jsonDecode(plan.encode()) as Map<String, dynamic>;
      data['v'] = 2;
      if (old.schedules.values.any((v) => v is List)) {
        data['legacyTarget'] = old.legacyTarget ?? old.target;
      }
      data['entries'] = old.entries;
      data['schedules'] = {
        dayKey(DateTime.parse(rows.single['created_at'] as String).toLocal()):
            old.currentSchedule.encode(),
        ...old.schedules,
        dayKey(DateTime.now()): plan.currentSchedule.encode(),
      };
      await txn.update(
        'habits',
        {
          'title': title.trim(),
          'details': HabitPlan.decode(jsonEncode(data)).encode(),
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    });
    HabitChanges.committed();
  }

  Future<void> mark(String id, DateTime date, bool done) async {
    final rows = await (await db).query(
      'habits',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (rows.isEmpty) throw StateError('habit_missing');
    await checkIn(
      id,
      date,
      done ? Habit.fromMap(rows.single).plan.targetAt(date) : 0,
    );
  }

  Future<void> checkIn(
    String id,
    DateTime date,
    int amount, {
    String? note,
    bool skipped = false,
  }) => _writeEntry(id, date, (_) => amount, note: note, skipped: skipped);

  Future<void> adjust(String id, DateTime date, int delta) =>
      _writeEntry(id, date, (current) => (current + delta).clamp(0, 1000000));

  Future<void> _writeEntry(
    String id,
    DateTime date,
    int Function(int) update, {
    String? note,
    bool skipped = false,
  }) async {
    if (dayKey(date).compareTo(dayKey(DateTime.now())) > 0 ||
        (note?.length ?? 0) > 2000) {
      throw ArgumentError('habit_entry');
    }
    await (await db).transaction((txn) async {
      final rows = await txn.query('habits', where: 'id = ?', whereArgs: [id]);
      if (rows.isEmpty) throw StateError('habit_missing');
      final habit = Habit.fromMap(rows.single), key = dayKey(date);
      if (habit.archived) throw StateError('habit_archived');
      final target = habit.plan.targetAt(date);
      final amount = update(habit.plan.amount(date, habit.days));
      if (amount < 0 || amount > 1000000) throw ArgumentError('habit_entry');
      habit.plan.entries[key] = {
        'amount': amount,
        'target': target,
        'skipped': skipped,
        'note': note ?? habit.plan.entries[key]?['note'] ?? '',
      };
      HabitPlan.decode(habit.plan.encode());
      final days = habit.days;
      if (!skipped && amount >= target) {
        days.add(key);
      } else {
        days.remove(key);
      }
      await txn.update(
        'habits',
        {
          'days': jsonEncode(days.toList()..sort()),
          'details': habit.plan.encode(),
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    });
    HabitChanges.committed();
  }
}
