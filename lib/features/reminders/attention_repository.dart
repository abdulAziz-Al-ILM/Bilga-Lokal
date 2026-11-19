import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../finance/finance_planning.dart';
import '../finance/finance_page.dart' show financeOverview;
import '../habits/habit_store.dart';
import '../notes/note_database.dart';
import '../planning/planner_repository.dart';
import 'alert_preferences.dart';

typedef AttentionRow = ({
  String id,
  String kind,
  String event,
  String key,
  String title,
  DateTime at,
  bool completed,
  bool notify,
  bool immediate,
});

class AttentionRepository {
  final Database? notes, tasks;
  AttentionRepository({this.notes, this.tasks});

  Future<List<AttentionRow>> load(
    DateTime now,
    AlertPreferences prefs, {
    bool scheduledOnly = false,
  }) async {
    final planner = PlannerRepository(notesDb: notes, todoDb: tasks);
    final day = dayKey(now);
    final noteDb = notes ?? await NoteDatabase.database;
    final rows = <AttentionRow>[];
    void add(
      String id,
      String kind,
      String event,
      String title,
      DateTime at, {
      bool completed = false,
      bool notify = false,
      bool immediate = false,
      String? dedup,
    }) {
      if (scheduledOnly && !notify) return;
      rows.add((
        id: id,
        kind: kind,
        event: event,
        key: dedup ?? at.toIso8601String(),
        title: title,
        at: at,
        completed: completed,
        notify: notify,
        immediate: immediate,
      ));
    }

    DateTime evening(DateTime date) => DateTime(
      date.year,
      date.month,
      date.day,
      prefs.eveningMinute ~/ 60,
      prefs.eveningMinute % 60,
    );
    if (!scheduledOnly ||
        prefs.has('taskDue') ||
        prefs.has('taskSoon') ||
        prefs.has('habitEvening')) {
      final plan = await planner.load(now);
      final reminders = await planner.scheduledReminders(now);
      final explicit = {for (final reminder in reminders) reminder.row['id']};
      for (final reminder in reminders) {
        add(
          reminder.row['id'] as String,
          'task',
          'taskReminder',
          reminder.row['title'] as String,
          reminder.at,
          completed: reminder.row['fired'] == 1,
        );
      }
      for (final row in [...plan.overdue, ...plan.today, ...plan.upcoming]) {
        final at = DateTime.parse(row['due_at'] as String).toLocal(),
            id = row['id'] as String;
        add(
          id,
          'task',
          'taskDue',
          row['title'] as String,
          at,
          notify: prefs.has('taskDue') && !explicit.contains(id),
        );
        final soon = at.subtract(const Duration(hours: 1));
        if (prefs.has('taskSoon') &&
            !explicit.contains(id) &&
            at.isAfter(now) &&
            soon.isAfter(now)) {
          add(
            id,
            'task',
            'taskSoon',
            row['title'] as String,
            soon,
            notify: true,
          );
        }
      }
      for (final row in plan.completed) {
        final at = DateTime.tryParse(row['completed_at'] as String? ?? '')
            ?.toLocal();
        if (at != null) {
          add(
            row['id'] as String,
            'task',
            'taskDue',
            row['title'] as String,
            at,
            completed: true,
          );
        }
      }
      final pending = plan.habits
          .where((h) => !h.plan.done(now, h.days))
          .toList();
      for (final habit in pending) {
        final minute = habit.plan.reminderMinute;
        if (minute != null) {
          add(
            habit.id,
            'habit',
            'habitScheduled',
            habit.title,
            DateTime(now.year, now.month, now.day, minute ~/ 60, minute % 60),
          );
        }
      }
      if (prefs.has('habitEvening') && pending.isNotEmpty) {
        add('habits', 'center', 'habitEvening', '', evening(now), notify: true);
      }
    }
    if (!scheduledOnly ||
        prefs.has('financeRecurring') ||
        prefs.has('financeBudget')) {
      final ledgers = await noteDb.query(
        'private_records',
        columns: ['id', 'payload'],
        where: "kind='finance' AND json_type(payload,'\$.planning')='object' OR kind='finance' AND (json_type(payload,'\$.budgets')='object' OR json_extract(payload,'\$.budget')>0)",
      );
      for (final ledger in ledgers) {
        final data =
            jsonDecode(ledger['payload'] as String) as Map<String, dynamic>;
        final id = ledger['id'] as String, title = data['title'] as String;
        final p = FinancePlanning.plan(data);
        if (!scheduledOnly) {
          for (final debt in financeOverview((
            data,
            day,
          )).upcoming.where((row) => row.section == 'debts')) {
            add(
              id,
              'finance',
              'financeDebt',
              debt.label,
              evening(DateTime.parse(debt.day)),
            );
          }
        }
        for (final rule in p['recurring']) {
          if (rule['active'] != true || rule['type'] != 'expense') continue;
          final due = FinancePlanning.occurrence(rule);
          if (due != null) {
            add(
              id,
              'finance',
              'financeRecurring',
              rule['name'] as String,
              evening(DateTime.parse(due)),
              notify: prefs.has('financeRecurring'),
              immediate: due.compareTo(day) <= 0,
              dedup: '${rule['id']}/$due',
            );
          }
        }
        for (final budget in FinancePlanning.budgets(
          data,
          day.substring(0, 7),
        )) {
          final spent = FinancePlanning.spent(
            data,
            day.substring(0, 7),
            budget['category'],
            day,
          );
          final percent = FinancePlanning.percent(spent, budget['amount']);
          if (percent >= 80) {
            final event = percent >= 100 ? 'budgetExceeded' : 'budgetNear';
            add(
              id,
              'finance',
              event,
              title,
              evening(now),
              notify: prefs.has('financeBudget'),
              immediate: true,
              dedup: '${budget['month']}/${budget['category']}',
            );
          }
        }
      }
    }
    if (prefs.has('experienceReview')) {
      final next = DateTime(
        now.year,
        now.month,
        now.day + (7 - now.weekday) % 7,
      );
      final nextDay = evening(next).isBefore(now)
          ? DateTime(next.year, next.month, next.day + 7)
          : next;
      add(
        'experiences',
        'experience',
        'experienceReview',
        '',
        evening(nextDay),
        notify: true,
        dedup: 'weekly',
      );
    }
    if (prefs.has('bookReading')) {
      final at = evening(now);
      add(
        'books',
        'book',
        'bookReading',
        '',
        at.isBefore(now)
            ? evening(DateTime(now.year, now.month, now.day + 1))
            : at,
        notify: true,
        dedup: 'daily',
      );
    }
    if (!scheduledOnly || prefs.has('bookCards')) {
      final cards = await noteDb.rawQuery("""
        SELECT book_id, min(json_extract(payload,'\$.due')) due
        FROM book_reading WHERE kind='card' AND json_type(payload,'\$.due')='text'
        GROUP BY book_id
      """);
      for (final row in cards) {
        final at = DateTime.tryParse(row['due'] as String)?.toLocal();
        if (at != null) {
          add(
            row['book_id'] as String,
            'book',
            'bookCards',
            '',
            at,
            notify: prefs.has('bookCards'),
            immediate: !at.isAfter(now),
          );
        }
      }
    }
    rows.sort((a, b) => a.at.compareTo(b.at));
    return rows;
  }
}
