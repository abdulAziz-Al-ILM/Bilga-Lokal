import 'package:sqflite/sqflite.dart';

import '../habits/habit_store.dart';
import '../notes/note_database.dart';
import '../todo/todo_database.dart';

class DailyPlan {
  final List<Map<String, Object?>> overdue, today, upcoming, completed;
  final List<Habit> habits;
  DailyPlan(this.overdue, this.today, this.upcoming, this.completed, this.habits);
}

class PlannerRepository {
  final Database? notesDb, todoDb;
  PlannerRepository({this.notesDb, this.todoDb});

  /// Civil dates rather than 24-hour durations: DST may shorten/lengthen a day.
  static DateTime day(DateTime d) => DateTime(d.year, d.month, d.day);

  Future<DailyPlan> load(DateTime now) async {
    final db = todoDb ?? await TodoDatabase.database;
    final notes = notesDb ?? await NoteDatabase.database;
    final local = now.toLocal();
    final today = day(local), end = DateTime(local.year, local.month, local.day + 8);
    final tasks = await db.query('todos', where: 'is_deleted = 0 AND (due_at IS NOT NULL OR completed_at IS NOT NULL)',
      orderBy: 'priority DESC, due_at, id');
    final overdue = <Map<String, Object?>>[], due = <Map<String, Object?>>[],
        upcoming = <Map<String, Object?>>[], completed = <Map<String, Object?>>[];
    for (final task in tasks) {
      if (task['is_done'] == 1) {
        final at = DateTime.tryParse(task['completed_at'] as String? ?? '')?.toLocal();
        if (at != null && day(at) == today) completed.add(task);
        continue;
      }
      final at = DateTime.tryParse(task['due_at'] as String? ?? '')?.toLocal();
      if (at == null) continue;
      if (at.isBefore(local)) { overdue.add(task); }
      else if (day(at) == today) { due.add(task); }
      else if (at.isBefore(end)) { upcoming.add(task); }
    }
    final habits = (await HabitStore(provided: notes).all())
        .where((h) => !day(h.created.toLocal()).isAfter(today) && h.plan.scheduled(today)).toList();
    return DailyPlan(overdue, due, upcoming, completed, habits);
  }
}
