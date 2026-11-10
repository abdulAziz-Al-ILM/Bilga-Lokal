import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:sqflite/sqflite.dart';

import 'recurrence_rule.dart';
import 'reminders/todo_reminder_store.dart';
import 'todo_changes.dart';
import 'todo_checklist_store.dart';

/// One pending head per series. Completed occurrences retain their own rows.
/// All task/head/reminder writes belong to the caller's single transaction.
class TodoSeriesStore {
  final Database db;
  TodoSeriesStore(this.db);

  static Future<void> createSchema(DatabaseExecutor db) async {
    await db.execute('''CREATE TABLE todo_series (
      id TEXT PRIMARY KEY, rule TEXT NOT NULL, anchor_at TEXT NOT NULL,
      template TEXT NOT NULL,
      head_task_id TEXT REFERENCES todos(id) ON DELETE SET NULL,
      current_sequence INTEGER NOT NULL DEFAULT 0 CHECK(current_sequence>=0),
      active INTEGER NOT NULL DEFAULT 1 CHECK(active IN (0,1)),
      created_at TEXT NOT NULL, updated_at TEXT NOT NULL,
      CHECK(active=0 OR head_task_id IS NOT NULL))''');
    await db.execute('''CREATE TABLE todo_occurrences (
      todo_id TEXT PRIMARY KEY REFERENCES todos(id) ON DELETE CASCADE,
      series_id TEXT NOT NULL REFERENCES todo_series(id) ON DELETE CASCADE,
      sequence INTEGER NOT NULL CHECK(sequence>=0), nominal_at TEXT NOT NULL,
      UNIQUE(series_id,sequence))''');
    await db.execute(
      'CREATE INDEX todo_series_head ON todo_series(head_task_id)',
    );
    await db.execute(
      '''CREATE TRIGGER todo_series_trash AFTER UPDATE OF is_deleted ON todos
      WHEN NEW.is_deleted=1 BEGIN
      UPDATE todo_series SET active=0 WHERE head_task_id=NEW.id; END''',
    );
    await db.execute(
      '''CREATE TRIGGER todo_series_delete BEFORE DELETE ON todos BEGIN
      UPDATE todo_series SET active=0 WHERE head_task_id=OLD.id; END''',
    );
  }

  static Future<Map<String, Object?>?> forTask(
    DatabaseExecutor db,
    String id,
  ) async {
    final rows = await db.rawQuery(
      '''SELECT s.*, o.sequence AS task_sequence,
      o.nominal_at FROM todo_series s JOIN todo_occurrences o ON o.series_id=s.id
      WHERE o.todo_id=?''',
      [id],
    );
    return rows.firstOrNull;
  }

  static Map<String, dynamic> decodeTemplate(String raw) {
    if (utf8.encode(raw).length > 4 * 1024 * 1024) {
      throw const FormatException('recurrence_invalid');
    }
    final value = jsonDecode(raw);
    if (value is! Map<String, dynamic> ||
        value['version'] is! int ||
        value['version'] != 1 ||
        value.keys.any(
          (k) => !{
            'version',
            'title',
            'description',
            'priority',
            'folder_id',
            'reminder',
            'checklist',
          }.contains(k),
        ) ||
        value['title'] is! String ||
        (value['title'] as String).trim().isEmpty ||
        (value['title'] as String).length > 100000 ||
        value['description'] is! String ||
        (value['description'] as String).length > 1000000 ||
        value['priority'] is! int ||
        value['priority'] < 0 ||
        value['priority'] > 3 ||
        (value['folder_id'] != null && value['folder_id'] is! String)) {
      throw const FormatException('recurrence_invalid');
    }
    if (value.containsKey('checklist') &&
        !TodoChecklistStore.validTitles(value['checklist'])) {
      throw const FormatException('recurrence_invalid');
    }
    final reminder = value['reminder'];
    if (reminder != null) {
      const bounds = {
        'days': 3660000,
        'hour': 23,
        'minute': 59,
        'second': 59,
        'millisecond': 999,
        'microsecond': 999,
      };
      if (reminder is! Map ||
          reminder.length != bounds.length ||
          bounds.entries.any(
            (e) =>
                reminder[e.key] is! int ||
                reminder[e.key] > e.value ||
                reminder[e.key] < (e.key == 'days' ? -e.value : 0),
          )) {
        throw const FormatException('recurrence_invalid');
      }
    }
    return value;
  }

  static int _day(DateTime d) =>
      DateTime.utc(d.year, d.month, d.day).millisecondsSinceEpoch ~/
      Duration.millisecondsPerDay;

  static Future<String> _snapshot(
    DatabaseExecutor db,
    Map<String, Object?> task,
  ) async {
    final due = DateTime.parse(task['due_at'] as String);
    final reminders = await db.query(
      'todo_reminders',
      where: 'todo_id=? AND enabled=1',
      whereArgs: [task['id']],
    );
    Map<String, int>? pattern;
    if (reminders.isNotEmpty) {
      final raw = DateTime.parse(reminders.single['remind_at'] as String);
      final at = due.isUtc ? raw.toUtc() : raw.toLocal();
      pattern = {
        'days': _day(at) - _day(due),
        'hour': at.hour,
        'minute': at.minute,
        'second': at.second,
        'millisecond': at.millisecond,
        'microsecond': at.microsecond,
      };
    }
    final raw = jsonEncode({
      'version': 1,
      'title': task['title'],
      'description': task['description'] ?? '',
      'priority': task['priority'] ?? 0,
      'folder_id': task['folder_id'],
      'reminder': pattern,
      'checklist': (await TodoChecklistStore.load(
        db,
        task['id'] as String,
      )).map((item) => item.title).toList(),
    });
    decodeTemplate(raw);
    return raw;
  }

  static Future<void> configure(
    DatabaseExecutor db,
    String taskId,
    RecurrenceRule rule, {
    bool updateDefaults = true,
    bool resetAnchor = false,
  }) async {
    final rows = await db.query(
      'todos',
      where: 'id=? AND is_done=0 AND is_deleted=0',
      whereArgs: [taskId],
    );
    final due = rows.isEmpty
        ? null
        : DateTime.tryParse(rows.single['due_at'] as String? ?? '');
    if (due == null || due.year < 1 || due.year > 9999) {
      throw StateError('recurrence_requires_due');
    }
    final task = rows.single, existing = await forTask(db, taskId);
    final canonicalDue = due.toIso8601String();
    final now = DateTime.now().toIso8601String();
    if (existing == null) {
      final id = 'series:${TodoReminderStore.revision()}';
      await db.insert('todo_series', {
        'id': id,
        'rule': rule.canonical(due).encode(),
        'anchor_at': canonicalDue,
        'template': await _snapshot(db, task),
        'head_task_id': taskId,
        'current_sequence': 0,
        'active': 1,
        'created_at': now,
        'updated_at': now,
      });
      await db.insert('todo_occurrences', {
        'todo_id': taskId,
        'series_id': id,
        'sequence': 0,
        'nominal_at': canonicalDue,
      });
    } else {
      if (existing['head_task_id'] != taskId) {
        throw StateError('recurrence_historical_occurrence');
      }
      final previousRule = RecurrenceRule.decode(existing['rule'] as String);
      final changed = !rule.sameSchedule(
        previousRule,
        anchor: DateTime.parse(existing['anchor_at'] as String),
      );
      final reanchor = resetAnchor || changed;
      await db.update(
        'todo_series',
        {
          'rule': changed || resetAnchor
              ? rule.canonical(due).encode()
              : existing['rule'],
          'active': 1,
          'updated_at': now,
          if (reanchor) 'anchor_at': canonicalDue,
          if (updateDefaults) 'template': await _snapshot(db, task),
        },
        where: 'id=?',
        whereArgs: [existing['id']],
      );
      if (reanchor) {
        await db.update(
          'todo_occurrences',
          {'nominal_at': canonicalDue},
          where: 'todo_id=?',
          whereArgs: [taskId],
        );
      }
    }
  }

  static Future<void> stop(DatabaseExecutor db, String taskId) async {
    final series = await forTask(db, taskId);
    if (series == null) return;
    if (series['head_task_id'] != taskId) {
      throw StateError('recurrence_historical_occurrence');
    }
    await db.update(
      'todo_series',
      {'active': 0, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id=?',
      whereArgs: [series['id']],
    );
  }

  static String occurrenceId(String seriesId, int sequence) =>
      'occurrence:${sha256.convert(utf8.encode(seriesId))}:$sequence';

  static Future<String?> _accessibleFolder(
    DatabaseExecutor db,
    String? folder,
  ) async {
    final seen = <String>{};
    var current = folder;
    while (current != null) {
      if (!seen.add(current)) return null;
      final rows = await db.query(
        'todo_folders',
        columns: ['parent_id', 'is_deleted'],
        where: 'id=?',
        whereArgs: [current],
      );
      if (rows.isEmpty || rows.single['is_deleted'] != 0) return null;
      current = rows.single['parent_id'] as String?;
    }
    return folder;
  }

  Future<String?> setCompleted(
    String id,
    bool completed, {
    DateTime? at,
  }) async {
    final result = await db.transaction(
      (txn) => setCompletedInTransaction(txn, id, completed, at: at),
    );
    TodoChanges.committed();
    return result;
  }

  static Future<String?> setCompletedInTransaction(
    DatabaseExecutor db,
    String id,
    bool completed, {
    DateTime? at,
  }) async {
    final rows = await db.query(
      'todos',
      where: 'id=? AND is_deleted=0',
      whereArgs: [id],
    );
    if (rows.isEmpty) throw StateError('task_missing');
    if ((rows.single['is_done'] == 1) == completed) return null;
    final clock = at ?? DateTime.now();
    final stamp = clock.toIso8601String();
    await db.update(
      'todos',
      {
        'is_done': completed ? 1 : 0,
        'completed_at': completed ? stamp : null,
        'updated_at': stamp,
      },
      where: 'id=?',
      whereArgs: [id],
    );
    if (!completed) return null;
    final series = await forTask(db, id);
    if (series == null ||
        series['active'] != 1 ||
        series['head_task_id'] != id) {
      return null;
    }
    final anchor = DateTime.parse(series['anchor_at'] as String),
        nominal = DateTime.parse(series['nominal_at'] as String);
    final next = RecurrenceRule.decode(series['rule'] as String)
        .next(anchor, after: nominal.isAfter(clock) ? nominal : clock);
    if (next == null) {
      await db.update(
        'todo_series',
        {'active': 0, 'updated_at': stamp},
        where: 'id=?',
        whereArgs: [series['id']],
      );
      return null;
    }
    final template = decodeTemplate(series['template'] as String);
    final sequence = (series['current_sequence'] as int) + 1;
    final nextId = occurrenceId(series['id'] as String, sequence);
    await db.insert('todos', {
      'id': nextId,
      'title': template['title'],
      'description': template['description'],
      'priority': template['priority'],
      'due_at': next.toIso8601String(),
      'folder_id': await _accessibleFolder(
        db,
        template['folder_id'] as String?,
      ),
      'is_done': 0,
      'is_deleted': 0,
      'created_at': stamp,
      'updated_at': stamp,
      'completed_at': null,
      'trash_batch': null,
    });
    await db.insert('todo_occurrences', {
      'todo_id': nextId,
      'series_id': series['id'],
      'sequence': sequence,
      'nominal_at': next.toIso8601String(),
    });
    await TodoChecklistStore.fromTitles(
      db,
      nextId,
      List<String>.from(template['checklist'] as List? ?? const []),
    );
    await db.update(
      'todo_series',
      {
        'head_task_id': nextId,
        'current_sequence': sequence,
        'updated_at': stamp,
      },
      where: 'id=?',
      whereArgs: [series['id']],
    );
    if (template['reminder'] case final Map pattern) {
      final construct = next.isUtc ? DateTime.utc : DateTime.new;
      final reminder = construct(
        next.year,
        next.month,
        next.day + (pattern['days'] as int),
        pattern['hour'] as int,
        pattern['minute'] as int,
        pattern['second'] as int,
        pattern['millisecond'] as int,
        pattern['microsecond'] as int,
      );
      await TodoReminderStore.save(db, nextId, reminder);
      if (!reminder.isAfter(clock)) {
        await db.update(
          'todo_reminders',
          {'fired': 1},
          where: 'todo_id=?',
          whereArgs: [nextId],
        );
      }
    }
    return nextId;
  }
}
