import 'package:sqflite/sqflite.dart';

import 'reminders/todo_reminder_store.dart';

class TodoChecklistItem {
  final String id, title;
  final bool done;
  const TodoChecklistItem(this.id, this.title, {this.done = false});
  TodoChecklistItem copyWith({String? title, bool? done}) =>
      TodoChecklistItem(id, title ?? this.title, done: done ?? this.done);
}

/// Checklist writes share the editor/completion/backup transaction. Completing
/// a parent keeps its original checklist; new occurrences start unchecked.
class TodoChecklistStore {
  static const maxItems = 200, maxTitle = 2000;

  static Future<void> createSchema(DatabaseExecutor db) async {
    await db.execute('''CREATE TABLE todo_checklist (
      id TEXT PRIMARY KEY, todo_id TEXT NOT NULL REFERENCES todos(id) ON DELETE CASCADE,
      title TEXT NOT NULL CHECK(length(trim(title))>0),
      is_done INTEGER NOT NULL DEFAULT 0 CHECK(is_done IN (0,1)),
      position INTEGER NOT NULL CHECK(position>=0))''');
    await db.execute(
      'CREATE INDEX todo_checklist_owner ON todo_checklist(todo_id,position)',
    );
    await _installSearch(db);
  }

  static const _select = """SELECT id,'todo',title,
    description || char(10) || COALESCE((SELECT group_concat(title,' ')
      FROM todo_checklist WHERE todo_id=todos.id),''),updated_at,0,''
    FROM todos WHERE is_deleted=0""";

  static Future<void> _installSearch(DatabaseExecutor db) async {
    // Rebuild only derived task search rows, retaining the existing FTS table
    // and folder index. All trigger updates share the original transaction.
    for (final action in ['INSERT', 'UPDATE', 'DELETE']) {
      await db.execute(
        'DROP TRIGGER IF EXISTS search_todos_${action.toLowerCase()}',
      );
      await db.execute(
        '''CREATE TRIGGER search_todos_${action.toLowerCase()}
        AFTER $action ON todos BEGIN
        DELETE FROM bilga_search WHERE kind='todo' AND id=${action == 'DELETE' ? 'old' : 'new'}.id;
        ${action == 'DELETE' ? '' : 'INSERT INTO bilga_search $_select AND id=new.id;'} END''',
      );
      final owners = [
        if (action != 'INSERT') 'old.todo_id',
        if (action != 'DELETE') 'new.todo_id',
      ].join(',');
      await db.execute(
        '''CREATE TRIGGER search_checklist_${action.toLowerCase()}
        AFTER $action ON todo_checklist BEGIN
        DELETE FROM bilga_search WHERE kind='todo' AND id IN ($owners);
        INSERT INTO bilga_search $_select AND id IN ($owners); END''',
      );
    }
    await db.execute("DELETE FROM bilga_search WHERE kind='todo'");
    await db.execute('INSERT INTO bilga_search $_select');
  }

  static bool validTitles(Object? value) =>
      value is List &&
      value.length <= maxItems &&
      value.every(
        (title) =>
            title is String &&
            title.trim().isNotEmpty &&
            title.length <= maxTitle,
      );

  static Future<List<TodoChecklistItem>> load(
    DatabaseExecutor db,
    String task,
  ) async => [
    for (final row in await db.query(
      'todo_checklist',
      where: 'todo_id=?',
      whereArgs: [task],
      orderBy: 'position,id',
    ))
      TodoChecklistItem(
        row['id'] as String,
        row['title'] as String,
        done: row['is_done'] == 1,
      ),
  ];

  static Future<void> replace(
    DatabaseExecutor db,
    String task,
    List<TodoChecklistItem> items,
  ) async {
    if (!validTitles(items.map((item) => item.title).toList()) ||
        items.any((item) => item.id.isEmpty || item.id.length > 512) ||
        items.map((item) => item.id).toSet().length != items.length) {
      throw const FormatException('checklist_invalid');
    }
    await db.delete('todo_checklist', where: 'todo_id=?', whereArgs: [task]);
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      await db.insert('todo_checklist', {
        'id': item.id,
        'todo_id': task,
        'title': item.title.trim(),
        'is_done': item.done ? 1 : 0,
        'position': i,
      });
    }
  }

  static Future<void> fromTitles(
    DatabaseExecutor db,
    String task,
    List<String> titles,
  ) => replace(db, task, [
    for (final title in titles)
      TodoChecklistItem('check:${TodoReminderStore.revision()}', title),
  ]);
}
