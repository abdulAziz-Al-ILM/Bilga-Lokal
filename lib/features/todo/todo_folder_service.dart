import 'package:sqflite/sqflite.dart';

import 'todo_database.dart';
import 'todo_folder_model.dart';

class TodoFolderService {
  final Database? _providedDatabase;
  TodoFolderService({Database? database}) : _providedDatabase = database;
  Future<Database> get _db async =>
      _providedDatabase ?? await TodoDatabase.database;

  Future<List<TodoFolder>> getRootFolders() async {
    final db = await _db;

    final maps = await db.query(
      'todo_folders',
      where: 'parent_id IS NULL AND is_deleted = 0',
      orderBy: 'name COLLATE NOCASE ASC',
    );

    return maps.map(TodoFolder.fromMap).toList();
  }

  Future<List<TodoFolder>> getSubFolders(String parentId) async {
    final db = await _db;

    final maps = await db.query(
      'todo_folders',
      where: 'parent_id = ? AND is_deleted = 0',
      whereArgs: [parentId],
      orderBy: 'name COLLATE NOCASE ASC',
    );

    return maps.map(TodoFolder.fromMap).toList();
  }

  Future<List<TodoFolder>> getAllFolders() async {
    final db = await _db;

    final maps = await db.query(
      'todo_folders',
      where: 'is_deleted = 0',
      orderBy: 'name COLLATE NOCASE ASC',
    );

    return maps.map(TodoFolder.fromMap).toList();
  }

  Future<void> addFolder(TodoFolder folder) async {
    final db = await _db;

    await db.insert(
      'todo_folders',
      folder.toMap(),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  Future<void> renameFolder(TodoFolder folder, String newName) async {
    final db = await _db;

    await db.update(
      'todo_folders',
      {'name': newName, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [folder.id],
    );
  }

  Future<void> moveFolder(TodoFolder folder, String? newParentId) async {
    final db = await _db;

    if (newParentId != null) {
      final rows = await db.query('todo_folders');
      final byId = {for (final row in rows) row['id'] as String: row};
      final visited = <String>{folder.id};
      String? current = newParentId;
      while (current != null) {
        if (!visited.add(current)) {
          throw StateError('Papkani o‘z ichiga ko‘chirib bo‘lmaydi');
        }
        final row = byId[current];
        if (row == null || row['is_deleted'] == 1) {
          throw StateError('Papka topilmadi');
        }
        current = row['parent_id'] as String?;
      }
    }

    await db.update(
      'todo_folders',
      {
        'parent_id': newParentId,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [folder.id],
    );
  }

  Future<void> deleteFolder(String folderId) async {
    final db = await _db;

    await db.transaction((txn) async {
      final children = await txn.query(
        'todo_folders',
        where: 'parent_id = ?',
        whereArgs: [folderId],
        limit: 1,
      );
      final tasks = await txn.query(
        'todos',
        where: 'folder_id = ?',
        whereArgs: [folderId],
        limit: 1,
      );
      if (children.isNotEmpty || tasks.isNotEmpty) {
        throw StateError('Bo‘sh bo‘lmagan papkani o‘chirib bo‘lmaydi');
      }
      await txn.delete('todo_folders', where: 'id = ?', whereArgs: [folderId]);
    });
  }
}
