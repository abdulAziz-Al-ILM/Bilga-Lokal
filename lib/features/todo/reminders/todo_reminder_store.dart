import 'dart:math';

import 'package:sqflite/sqflite.dart';

/// Reminder wall time is independent from todos.due_at. No existing row rewrite.
class TodoReminderStore {
  final Database db;
  TodoReminderStore(this.db);
  static String revision() =>
      '${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}';

  static Future<void> createSchema(DatabaseExecutor db) async {
    await db.execute('''CREATE TABLE todo_reminders (
      todo_id TEXT PRIMARY KEY REFERENCES todos(id) ON DELETE CASCADE,
      enabled INTEGER NOT NULL DEFAULT 0 CHECK(enabled IN (0,1)),
      remind_at TEXT NOT NULL,
      revision TEXT NOT NULL,
      fired INTEGER NOT NULL DEFAULT 0 CHECK(fired IN (0,1)))''');
    await db.execute('''CREATE TRIGGER todo_reminder_cancel
      AFTER UPDATE OF is_done,is_deleted,due_at ON todos
      WHEN NEW.is_done=1 OR NEW.is_deleted=1 OR NEW.due_at IS NOT OLD.due_at
      BEGIN DELETE FROM todo_reminders WHERE todo_id=NEW.id; END''');
    await db.execute(
      '''CREATE TRIGGER todo_reminder_delete AFTER DELETE ON todos
      BEGIN DELETE FROM todo_reminders WHERE todo_id=OLD.id; END''',
    );
  }

  static Future<void> save(
    DatabaseExecutor db,
    String id,
    DateTime? at, {
    bool enabled = true,
  }) async {
    if (at == null || !enabled) {
      await db.delete('todo_reminders', where: 'todo_id=?', whereArgs: [id]);
    } else {
      await db.insert('todo_reminders', {
        'todo_id': id,
        'enabled': 1,
        'remind_at': at.toIso8601String(),
        'revision': revision(),
        'fired': 0,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  /// Durable native delivery/snooze acknowledgement. Old task generations lose.
  Future<void> applyEvents(List<Map<String, dynamic>> events) async {
    await db.transaction((txn) async {
      for (final event in events) {
        final at = DateTime.tryParse(event['at'] as String? ?? '');
        if (at == null || !['fired', 'snooze'].contains(event['kind'])) {
          continue;
        }
        await txn.update(
          'todo_reminders',
          {
            'remind_at': at.toIso8601String(),
            'fired': event['kind'] == 'fired' ? 1 : 0,
          },
          where: 'todo_id=? AND revision=?',
          whereArgs: [event['id'], event['revision']],
        );
      }
    });
  }

  static Future<List<Map<String, Object?>>> active(DatabaseExecutor db) =>
      db.rawQuery('''
    WITH RECURSIVE hidden(id) AS (
      SELECT id FROM todo_folders WHERE is_deleted=1 UNION
      SELECT f.id FROM todo_folders f JOIN hidden h ON f.parent_id=h.id)
    SELECT t.* FROM todos t WHERE t.is_deleted=0 AND
      (t.folder_id IS NULL OR t.folder_id NOT IN (SELECT id FROM hidden))
    ORDER BY t.created_at DESC,t.id''');
}
