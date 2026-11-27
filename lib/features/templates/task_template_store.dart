import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../todo/reminders/todo_reminder_store.dart';
import '../todo/todo_changes.dart';
import '../todo/todo_checklist_store.dart';

class TaskTemplate {
  final String id, name, title, description;
  final int priority, revision;
  final List<String> checklist;
  TaskTemplate({
    required this.id,
    required this.name,
    required this.title,
    required this.description,
    required this.priority,
    required this.checklist,
    required this.revision,
  });

  Map<String, dynamic> get content => {
    'version': 1,
    'title': title,
    'description': description,
    'priority': priority,
    'checklist': checklist,
  };

  static Map<String, dynamic> decode(String raw) {
    if (utf8.encode(raw).length > 4 * 1024 * 1024) {
      throw const FormatException('template_invalid');
    }
    final data = jsonDecode(raw);
    if (data is! Map<String, dynamic> ||
        data['version'] is! int ||
        data['version'] != 1 ||
        data.keys.any(
          (key) => !{
            'version',
            'title',
            'description',
            'priority',
            'checklist',
          }.contains(key),
        ) ||
        data['title'] is! String ||
        (data['title'] as String).trim().isEmpty ||
        (data['title'] as String).length > 100000 ||
        data['description'] is! String ||
        (data['description'] as String).length > 1000000 ||
        data['priority'] is! int ||
        data['priority'] < 0 ||
        data['priority'] > 3 ||
        !TodoChecklistStore.validTitles(data['checklist'])) {
      throw const FormatException('template_invalid');
    }
    return data;
  }

  factory TaskTemplate.row(Map<String, Object?> row) {
    if (row['id'] is! String ||
        (row['id'] as String).isEmpty ||
        (row['id'] as String).length > 512 ||
        row['name'] is! String ||
        (row['name'] as String).trim().isEmpty ||
        (row['name'] as String).length > 200 ||
        row['revision'] is! int ||
        (row['revision'] as int) < 1 ||
        row['payload'] is! String) {
      throw const FormatException('template_invalid');
    }
    final data = decode(row['payload'] as String);
    return TaskTemplate(
      id: row['id'] as String,
      name: row['name'] as String,
      title: data['title'] as String,
      description: data['description'] as String,
      priority: data['priority'] as int,
      checklist: List<String>.from(data['checklist'] as List),
      revision: row['revision'] as int,
    );
  }
}

class TaskTemplateStore {
  final Database db;
  TaskTemplateStore(this.db);

  static Future<void> createSchema(DatabaseExecutor db) => db.execute('''
    CREATE TABLE todo_templates(id TEXT PRIMARY KEY,name TEXT NOT NULL,
      payload TEXT NOT NULL,revision INTEGER NOT NULL CHECK(revision>0),
      created_at TEXT NOT NULL,updated_at TEXT NOT NULL)''');

  Future<List<TaskTemplate>> all() async => [
    for (final row in await db.query(
      'todo_templates',
      orderBy: 'name COLLATE NOCASE,id',
    ))
      TaskTemplate.row(row),
  ];

  Future<TaskTemplate> fromTask(String id) => db.transaction((txn) async {
    final row = (await txn.query(
      'todos',
      where: 'id=? AND is_deleted=0',
      whereArgs: [id],
    )).single;
    return TaskTemplate(
      id: '',
      name: String.fromCharCodes((row['title'] as String).runes.take(100)),
      title: row['title'] as String,
      description: row['description'] as String,
      priority: row['priority'] as int,
      checklist: (await TodoChecklistStore.load(
        txn,
        id,
      )).map((item) => item.title).toList(),
      revision: 0,
    );
  });

  Future<String> save(TaskTemplate template) => db.transaction((txn) async {
    final id = template.id.isEmpty
        ? 'template:${TodoReminderStore.revision()}'
        : template.id;
    final row = <String, Object?>{
      'id': id,
      'name': template.name.trim(),
      'payload': jsonEncode(template.content),
      'revision': template.revision + 1,
    };
    TaskTemplate.row(row); // Validate all fields before writing.
    final stamp = DateTime.now().toIso8601String();
    if (template.id.isEmpty) {
      await txn.insert('todo_templates', {
        ...row,
        'created_at': stamp,
        'updated_at': stamp,
      });
    } else {
      final changed = await txn.update(
        'todo_templates',
        {...row, 'updated_at': stamp},
        where: 'id=? AND revision=?',
        whereArgs: [id, template.revision],
      );
      if (changed != 1) throw StateError('template_changed');
    }
    return id;
  });

  Future<void> delete(TaskTemplate template) async {
    final count = await db.delete(
      'todo_templates',
      where: 'id=? AND revision=?',
      whereArgs: [template.id, template.revision],
    );
    if (count != 1) throw StateError('template_changed');
  }

  Future<Map<String, Object?>> instantiate(String id, {String? folderId}) =>
      TodoChanges.after(
        db.transaction((txn) async {
          final template = TaskTemplate.row(
            (await txn.query(
              'todo_templates',
              where: 'id=?',
              whereArgs: [id],
            )).single,
          );
          var parent = folderId;
          final seen = <String>{};
          while (parent != null) {
            if (!seen.add(parent)) throw StateError('folder_cycle');
            final rows = await txn.query(
              'todo_folders',
              where: 'id=? AND is_deleted=0',
              whereArgs: [parent],
            );
            if (rows.isEmpty) throw StateError('folder_missing');
            parent = rows.single['parent_id'] as String?;
          }
          final stamp = DateTime.now().toIso8601String();
          final task = <String, Object?>{
            'id': 'from-template:${TodoReminderStore.revision()}',
            'title': template.title,
            'description': template.description,
            'priority': template.priority,
            'folder_id': folderId,
            'due_at': null,
            'is_done': 0,
            'is_deleted': 0,
            'created_at': stamp,
            'updated_at': stamp,
          };
          await txn.insert('todos', task);
          await TodoChecklistStore.fromTitles(
            txn,
            task['id'] as String,
            template.checklist,
          );
          return task;
        }),
      );
}
