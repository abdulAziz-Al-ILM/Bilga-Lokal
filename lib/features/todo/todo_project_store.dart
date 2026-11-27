import 'package:sqflite/sqflite.dart';

import 'reminders/todo_reminder_store.dart';
import 'todo_changes.dart';

class TodoProject {
  final String folderId, name, description, status, folderStamp;
  final String? dueDate;
  final int revision;
  const TodoProject({
    required this.folderId,
    required this.name,
    required this.description,
    required this.status,
    required this.folderStamp,
    required this.revision,
    this.dueDate,
  });
  static const statuses = {'active', 'paused', 'closed'};
  static void validate(Map<String, Object?> row) {
    final due = row['due_date'];
    if (row['folder_id'] is! String ||
        (row['folder_id'] as String).isEmpty ||
        row['description'] is! String ||
        (row['description'] as String).length > 100000 ||
        !statuses.contains(row['status']) ||
        row['revision'] is! int ||
        (row['revision'] as int) < 1 ||
        (due != null &&
            (due is! String ||
                !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(due) ||
                DateTime.tryParse(due) == null ||
                DateTime.parse(due).year < 1 ||
                DateTime.parse(due).year > 9999 ||
                DateTime.parse(due).toIso8601String().substring(0, 10) !=
                    due))) {
      throw const FormatException('project_invalid');
    }
  }

  factory TodoProject.row(Map<String, Object?> row) {
    validate(row);
    return TodoProject(
      folderId: row['folder_id'] as String,
      name: row['name'] as String,
      description: row['description'] as String,
      status: row['status'] as String,
      dueDate: row['due_date'] as String?,
      revision: row['revision'] as int,
      folderStamp: row['folder_stamp'] as String,
    );
  }
}

class TodoProjectStore {
  final Database db;
  TodoProjectStore(this.db);
  static Future<void> createSchema(DatabaseExecutor db) async {
    await db.execute(
      '''
    CREATE TABLE todo_projects(folder_id TEXT PRIMARY KEY REFERENCES todo_folders(id) ON DELETE CASCADE,
      description TEXT NOT NULL DEFAULT '',status TEXT NOT NULL DEFAULT 'active'
      CHECK(status IN ('active','paused','closed')),due_date TEXT,
      revision INTEGER NOT NULL CHECK(revision>0),created_at TEXT NOT NULL,updated_at TEXT NOT NULL)''',
    );
    await _installSearch(db);
  }

  static const _select = """SELECT f.id,'todoFolder',f.name,COALESCE(p.description,''),f.updated_at,0,''
    FROM todo_folders f LEFT JOIN todo_projects p ON p.folder_id=f.id WHERE f.is_deleted=0""";
  static Future<void> _installSearch(DatabaseExecutor db) async {
    for (final action in ['INSERT', 'UPDATE', 'DELETE']) {
      await db.execute(
        'DROP TRIGGER IF EXISTS search_todo_folders_${action.toLowerCase()}',
      );
      await db.execute(
        '''CREATE TRIGGER search_todo_folders_${action.toLowerCase()}
        AFTER $action ON todo_folders BEGIN
        DELETE FROM bilga_search WHERE kind='todoFolder' AND id=${action == 'DELETE' ? 'old' : 'new'}.id;
        ${action == 'DELETE' ? '' : 'INSERT INTO bilga_search $_select AND f.id=new.id;'} END''',
      );
      final source = action == 'DELETE' ? 'old.folder_id' : 'new.folder_id';
      await db.execute('''CREATE TRIGGER search_project_${action.toLowerCase()}
        AFTER $action ON todo_projects BEGIN
        DELETE FROM bilga_search WHERE kind='todoFolder' AND id=$source;
        INSERT INTO bilga_search $_select AND f.id=$source; END''');
    }
    await db.execute("DELETE FROM bilga_search WHERE kind='todoFolder'");
    await db.execute('INSERT INTO bilga_search $_select');
  }

  Future<Map<String, TodoProject>> all() async => {
    for (final row in await db.rawQuery(
      '''SELECT p.*,f.name,f.updated_at AS folder_stamp
      FROM todo_projects p JOIN todo_folders f ON f.id=p.folder_id''',
    ))
      row['folder_id'] as String: TodoProject.row(row),
  };

  static Future<Map<String, ({int total, int done, int overdue})>> progress(
    DatabaseExecutor db,
    DateTime now,
  ) async {
    final roots = await db.rawQuery(
      '''WITH RECURSIVE hidden(id) AS (
      SELECT id FROM todo_folders WHERE is_deleted=1 UNION
      SELECT f.id FROM todo_folders f JOIN hidden h ON f.parent_id=h.id),tree(root,id) AS (
      SELECT p.folder_id,p.folder_id FROM todo_projects p JOIN todo_folders f
        ON f.id=p.folder_id WHERE f.is_deleted=0 AND f.id NOT IN (SELECT id FROM hidden)
      UNION SELECT tree.root,f.id FROM todo_folders f JOIN tree ON f.parent_id=tree.id WHERE f.is_deleted=0)
      SELECT tree.root,t.is_done,t.due_at FROM tree JOIN todos t ON t.folder_id=tree.id WHERE t.is_deleted=0''',
    );
    final result = <String, ({int total, int done, int overdue})>{};
    for (final task in roots) {
      final root = task['root'] as String,
          old = result[root] ?? (total: 0, done: 0, overdue: 0);
      final due = DateTime.tryParse(task['due_at'] as String? ?? '');
      final completed = task['is_done'] == 1;
      result[root] = (
        total: old.total + 1,
        done: old.done + (completed ? 1 : 0),
        overdue:
            old.overdue +
            (!completed && due != null && due.isBefore(now) ? 1 : 0),
      );
    }
    return result;
  }

  Future<String> save({
    String? folderId,
    String? parentId,
    required String name,
    required String description,
    required String status,
    String? dueDate,
    int? expectedRevision,
    String? expectedFolderStamp,
  }) => TodoChanges.after(
    db.transaction((txn) async {
      if (name.trim().isEmpty || name.length > 200) {
        throw const FormatException('project_invalid');
      }
      final id = folderId ?? 'project:${TodoReminderStore.revision()}';
      final stamp = DateTime.now().toIso8601String();
      final current = await txn.query(
        'todo_projects',
        where: 'folder_id=?',
        whereArgs: [id],
      );
      if ((expectedRevision == null && current.isNotEmpty) ||
          (expectedRevision != null &&
              (current.isEmpty ||
                  current.single['revision'] != expectedRevision))) {
        throw StateError('project_changed');
      }
      final row = <String, Object?>{
        'folder_id': id,
        'description': description,
        'status': status,
        'due_date': dueDate,
        'revision': (expectedRevision ?? 0) + 1,
      };
      TodoProject.validate(row);
      var ancestor = folderId ?? parentId;
      final seen = <String>{};
      while (ancestor != null) {
        if (!seen.add(ancestor)) throw StateError('folder_cycle');
        final folders = await txn.query(
          'todo_folders',
          where: 'id=? AND is_deleted=0',
          whereArgs: [ancestor],
        );
        if (folders.isEmpty) throw StateError('folder_missing');
        if (ancestor == folderId &&
            expectedFolderStamp != null &&
            folders.single['updated_at'] != expectedFolderStamp) {
          throw StateError('project_changed');
        }
        ancestor = folders.single['parent_id'] as String?;
      }
      if (folderId == null) {
        await txn.insert('todo_folders', {
          'id': id,
          'name': name.trim(),
          'parent_id': parentId,
          'is_deleted': 0,
          'created_at': stamp,
          'updated_at': stamp,
        });
      } else {
        await txn.update(
          'todo_folders',
          {'name': name.trim(), 'updated_at': stamp},
          where: 'id=?',
          whereArgs: [id],
        );
      }
      if (current.isEmpty) {
        await txn.insert('todo_projects', {
          ...row,
          'created_at': stamp,
          'updated_at': stamp,
        });
      } else {
        await txn.update(
          'todo_projects',
          {...row, 'updated_at': stamp},
          where: 'folder_id=?',
          whereArgs: [id],
        );
      }
      return id;
    }),
  );

  Future<void> removeMarker(TodoProject project) => TodoChanges.after(
    db.transaction((txn) async {
      final count = await txn.delete(
        'todo_projects',
        where: 'folder_id=? AND revision=?',
        whereArgs: [project.folderId, project.revision],
      );
      if (count != 1) throw StateError('project_changed');
    }),
  );
}
