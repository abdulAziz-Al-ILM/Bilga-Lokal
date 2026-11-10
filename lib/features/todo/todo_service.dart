import 'todo_changes.dart';

import 'package:sqflite/sqflite.dart';

import 'todo_database.dart';
import 'todo_model.dart';
import 'todo_series_store.dart';

class TodoService {
  final Database? _providedDatabase;
  TodoService({Database? database}) : _providedDatabase = database;
  Future<Database> get _db async =>
      _providedDatabase ?? await TodoDatabase.database;

  Future<List<Todo>> getTodos() async {
    final db = await _db;

    final maps = await db.query(
      'todos',
      where: 'is_deleted = 0',
      orderBy: 'is_done ASC, created_at DESC',
    );

    return maps.map(Todo.fromMap).toList();
  }

  Future<List<Todo>> getRootTodos() async {
    final db = await _db;

    final maps = await db.query(
      'todos',
      where: 'folder_id IS NULL AND is_deleted = 0',
      orderBy: 'is_done ASC, created_at DESC',
    );

    return maps.map(Todo.fromMap).toList();
  }

  Future<List<Todo>> getTodosByFolder(String folderId) async {
    final db = await _db;

    final maps = await db.query(
      'todos',
      where: 'folder_id = ? AND is_deleted = 0',
      whereArgs: [folderId],
      orderBy: 'is_done ASC, created_at DESC',
    );

    return maps.map(Todo.fromMap).toList();
  }

  Future<void> addTodo(Todo todo) async {
    final db = await _db;

    await db.insert(
      'todos',
      todo.toMap(),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
    TodoChanges.committed();
  }

  Future<void> updateTodo(Todo todo) async {
    final db = await _db;

    await db.transaction((txn) async {
      final fields = todo.toMap()..remove('is_done');
      await txn.update('todos', fields, where: 'id=?', whereArgs: [todo.id]);
      await TodoSeriesStore.setCompletedInTransaction(
        txn,
        todo.id,
        todo.isDone,
        at: todo.updatedAt,
      );
    });
    TodoChanges.committed();
  }

  Future<void> toggleTodo(Todo todo) async {
    await TodoSeriesStore(await _db).setCompleted(todo.id, !todo.isDone);
  }

  Future<void> moveTodoToFolder(Todo todo, String? folderId) async {
    final db = await _db;

    await db.update(
      'todos',
      {'folder_id': folderId, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [todo.id],
    );
    TodoChanges.committed();
  }

  Future<void> deleteTodo(String id) async {
    final db = await _db;

    await db.update(
      'todos',
      {
        'is_deleted': 1,
        'trash_batch': null,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    TodoChanges.committed();
  }
}
