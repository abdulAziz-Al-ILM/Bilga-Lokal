import 'package:sqflite/sqflite.dart';

import '../finance/ledger.dart';
import '../finance/finance_planning.dart';
import '../notes/note_database.dart';
import '../planning/planner_repository.dart';

class PersonalAnswers {
  final Database? notesDb, tasksDb;
  PersonalAnswers(this.notesDb, this.tasksDb);
  Future<Database> get notes async => notesDb ?? await NoteDatabase.database;

  static String day(DateTime time) => time.toIso8601String().substring(0, 10);

  /// "Last Friday" always means the preceding Friday, even on Friday itself.
  static DateTime previousFriday(DateTime now) {
    final local = now.toLocal();
    final elapsed = (local.weekday - DateTime.friday + 7) % 7;
    return DateTime(
      local.year,
      local.month,
      local.day - (elapsed == 0 ? 7 : elapsed),
    );
  }

  Future<List<String>> plan(
    DateTime now,
    String Function(String) tr, {
    bool onlyHabits = false,
  }) async {
    final plan = await PlannerRepository(
      notesDb: notesDb,
      todoDb: tasksDb,
    ).load(now);
    final habits = plan.habits.where((h) => !h.plan.done(now, h.days)).toList();
    final result = <String>[];
    if (!onlyHabits) {
      final reminders = await PlannerRepository(
        notesDb: notesDb,
        todoDb: tasksDb,
      ).scheduledReminders(now);
      final todaysReminders = reminders
          .where((r) => day(r.at) == day(now))
          .toList();
      result.add(
        "${tr('todayPlan')} · ${plan.today.length}\n${plan.today.take(5).map((t) => t['title']).join('\n')}",
      );
      if (plan.overdue.isNotEmpty) {
        result.add(
          "${tr('todoOverdue')} · ${plan.overdue.length}\n${plan.overdue.take(5).map((t) => t['title']).join('\n')}",
        );
      }
      if (todaysReminders.isNotEmpty) {
        result.add(
          "${tr('vaReminders')} · ${todaysReminders.length}\n${todaysReminders.take(5).map((r) => r.row['title']).join('\n')}",
        );
      }
    }
    result.add(
      "${tr('vaHabits')} · ${habits.length}\n${habits.take(8).map((h) => '${h.title}, ${h.plan.amount(now, h.days)} / ${h.plan.targetAt(now)} ${h.plan.unit}'.trimRight()).join('\n')}",
    );
    return result;
  }

  Future<List<String>> written(
    DateTime date,
    String Function(String) tr,
  ) async {
    final db = await notes;
    final key = day(date);
    const localCreation = """CASE
      WHEN substr(created_at,-1)='Z' OR substr(created_at,-6,1) IN ('+','-')
      THEN date(created_at,'localtime') ELSE substr(created_at,1,10) END""";
    final rows = await db.rawQuery(
      '''
      WITH RECURSIVE hidden(id) AS (
        SELECT id FROM folders WHERE is_deleted=1 UNION
        SELECT f.id FROM folders f JOIN hidden h ON f.parent_id=h.id
      )
      SELECT 'note' kind,title,substr(body,1,200) excerpt
      FROM notes WHERE is_deleted=0 AND is_archived=0
        AND (folder_id IS NULL OR folder_id NOT IN (SELECT id FROM hidden))
        AND $localCreation=?
      UNION ALL
      SELECT 'experience',json_extract(payload,'\$.title'),
        substr(coalesce(json_extract(payload,'\$.lesson'),json_extract(payload,'\$.body'),''),1,200)
      FROM private_records WHERE kind='experience'
        AND coalesce(json_extract(payload,'\$.date'),$localCreation)=?
      ORDER BY kind,title LIMIT 21
    ''',
      [key, key],
    );
    final messages = [
      for (final row in rows.take(20))
        "${tr(row['kind'] == 'note' ? 'notes' : 'xExperience')} · ${row['title']}\n${row['excerpt']}",
    ];
    return [
      '$key\n${rows.isEmpty ? tr('empty') : messages.take(5).join('\n\n')}',
      ...messages.skip(5),
      if (rows.length > 20) tr('vaMoreInModule'),
    ];
  }

  Future<List<String>> spentThisWeek(
    DateTime now,
    String Function(String) tr,
  ) async {
    final end = now.toLocal();
    final start = DateTime(end.year, end.month, end.day - end.weekday + 1);
    final rows = await (await notes).rawQuery(
      '''
      SELECT json_extract(r.payload,'\$.currency') currency,
        coalesce(sum(json_extract(entry.value,'\$.amount')),0) total
      FROM private_records r LEFT JOIN json_each(r.payload,'\$.entries') entry
        ON json_extract(entry.value,'\$.type')='expense'
        AND json_extract(entry.value,'\$.void')=0
        AND json_extract(entry.value,'\$.date') BETWEEN ? AND ?
      WHERE r.kind='finance' GROUP BY r.id
    ''',
      [day(start), day(end)],
    );
    final totals = <String, BigInt>{};
    for (final row in rows) {
      final currency = row['currency'] as String;
      if (!currencies.containsKey(currency)) {
        throw const FormatException('currency');
      }
      totals.update(
        currency,
        (v) => v + BigInt.from(row['total'] as int),
        ifAbsent: () => BigInt.from(row['total'] as int),
      );
    }
    return [
      '${day(start)} — ${day(end)}\n${totals.isEmpty ? tr('empty') : totals.entries.map((r) => FinancePlanning.plannedMoney(r.value, r.key)).join('\n')}',
    ];
  }
}
