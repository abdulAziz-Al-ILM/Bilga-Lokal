import 'package:sqflite/sqflite.dart';

import '../habits/habit_store.dart';
import '../notes/note_database.dart';
import '../todo/todo_database.dart';

class DailyPlan {
  final List<Map<String, Object?>> overdue, today, upcoming, completed;
  final List<Habit> habits;
  DailyPlan(
    this.overdue,
    this.today,
    this.upcoming,
    this.completed,
    this.habits,
  );
}

class PlannerRepository {
  final Database? notesDb, todoDb;
  PlannerRepository({this.notesDb, this.todoDb});

  /// Civil dates rather than 24-hour durations: DST may shorten/lengthen a day.
  static DateTime day(DateTime d) => DateTime(d.year, d.month, d.day);

  Future<List<({Map<String, Object?> row, DateTime at})>> scheduledReminders(
    DateTime now,
  ) async {
    final db = todoDb ?? await TodoDatabase.database;
    final rows = await db.rawQuery("""
      WITH RECURSIVE hidden(id) AS (
        SELECT id FROM todo_folders WHERE is_deleted=1 UNION
        SELECT f.id FROM todo_folders f JOIN hidden h ON f.parent_id=h.id
      )
      SELECT t.id,t.title,r.remind_at AS reminder_at,r.fired
      FROM todo_reminders r JOIN todos t ON t.id=r.todo_id
      WHERE r.enabled=1 AND t.is_deleted=0 AND t.is_done=0
        AND (t.folder_id IS NULL OR t.folder_id NOT IN (SELECT id FROM hidden))
      ORDER BY r.remind_at,t.id
    """);
    return [
      for (final row in rows)
        if (DateTime.tryParse(row['reminder_at'] as String? ?? '')
            case final DateTime at)
          (row: row, at: at.toLocal()),
    ];
  }

  Future<DailyPlan> load(DateTime now) async {
    final db = todoDb ?? await TodoDatabase.database;
    final notes = notesDb ?? await NoteDatabase.database;
    final local = now.toLocal();
    final today = day(local),
        end = DateTime(local.year, local.month, local.day + 8);
    final tasks = await db.rawQuery(
      """
      WITH RECURSIVE hidden(id) AS (
        SELECT id FROM todo_folders WHERE is_deleted=1 UNION
        SELECT f.id FROM todo_folders f JOIN hidden h ON f.parent_id=h.id
      )
      SELECT id,title,due_at,completed_at,is_done,priority
      FROM todos WHERE is_deleted=0 AND
        (folder_id IS NULL OR folder_id NOT IN (SELECT id FROM hidden)) AND
        ((is_done=0 AND due_at IS NOT NULL) OR (is_done=1 AND substr(completed_at,1,10) BETWEEN ? AND ?))
      ORDER BY priority DESC,due_at,id
    """,
      [
        DateTime(
          today.year,
          today.month,
          today.day - 1,
        ).toIso8601String().substring(0, 10),
        DateTime(
          today.year,
          today.month,
          today.day + 1,
        ).toIso8601String().substring(0, 10),
      ],
    );
    final overdue = <Map<String, Object?>>[],
        due = <Map<String, Object?>>[],
        upcoming = <Map<String, Object?>>[],
        completed = <Map<String, Object?>>[];
    for (final task in tasks) {
      if (task['is_done'] == 1) {
        final at = DateTime.tryParse(task['completed_at'] as String? ?? '')
            ?.toLocal();
        if (at != null && day(at) == today) completed.add(task);
        continue;
      }
      final at = DateTime.tryParse(task['due_at'] as String? ?? '')?.toLocal();
      if (at == null) continue;
      if (at.isBefore(local)) {
        overdue.add(task);
      } else if (day(at) == today) {
        due.add(task);
      } else if (at.isBefore(end)) {
        upcoming.add(task);
      }
    }
    final habits = (await HabitStore(provided: notes).all())
        .where(
          (h) =>
              !day(h.created.toLocal()).isAfter(today) &&
              h.plan.due(today, h.days, created: h.created),
        )
        .toList();
    return DailyPlan(overdue, due, upcoming, completed, habits);
  }
}
