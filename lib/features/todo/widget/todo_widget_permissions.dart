import 'package:sqflite/sqflite.dart';
import 'package:flutter/services.dart';

import '../reminders/todo_bridge.dart';

import '../todo_changes.dart';

/// Device-local disclosure consent; never restored from portable backups.
class TodoWidgetPermissions {
  static Future<void> createSchema(DatabaseExecutor db) async {
    await db.execute(
      'CREATE TABLE todo_widget_permissions (todo_id TEXT PRIMARY KEY REFERENCES todos(id) ON DELETE CASCADE, title TEXT NOT NULL)',
    );
    await db.execute('''CREATE TRIGGER todo_widget_revoke AFTER UPDATE OF title,is_deleted ON todos
      WHEN NEW.title IS NOT OLD.title OR NEW.is_deleted=1
      BEGIN DELETE FROM todo_widget_permissions WHERE todo_id=NEW.id; END''');
  }

  static Future<void> set(
    Database db,
    Map<String, Object?> reviewed,
    bool allowed,
  ) async {
    await db.transaction((txn) async {
      await txn.delete(
        'todo_widget_permissions',
        where: 'todo_id=?',
        whereArgs: [reviewed['id']],
      );
      if (allowed) {
        final current = await txn.query(
          'todos',
          where: 'id=? AND title=? AND is_deleted=0',
          whereArgs: [reviewed['id'], reviewed['title']],
        );
        if (current.isEmpty) throw StateError('task_changed');
        await txn.insert('todo_widget_permissions', {
          'todo_id': reviewed['id'],
          'title': reviewed['title'],
        });
      }
    });
    try {
      await TodoBridge.channel.invokeMethod<void>(
        'invalidateWidgetPermission',
        reviewed['id'],
      );
    } on MissingPluginException {
      // No Android widget cache on other platforms/tests.
    } finally {
      TodoChanges.committed();
    }
  }

  static Future<Map<String, bool>> allowed(DatabaseExecutor db) async => {
    for (final r in await db.rawQuery(
      'SELECT p.todo_id FROM todo_widget_permissions p JOIN todos t ON t.id=p.todo_id WHERE p.title=t.title AND t.is_deleted=0',
    ))
      r['todo_id'] as String: true,
  };
}
