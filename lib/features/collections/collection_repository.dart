import '../todo/todo_changes.dart';
import '../todo/todo_series_store.dart';
import '../todo/todo_checklist_store.dart';

import 'dart:math';

import 'package:sqflite/sqflite.dart';

import '../templates/template_catalog.dart';

import '../notes/note_database.dart';
import '../notes/note_tag_store.dart';
import '../notes/notes_changes.dart';

import 'dart:convert';

import '../todo/todo_database.dart';

enum CollectionKind { notes, todos }

class CollectionRows {
  final List<Map<String, Object?>> folders;
  final List<Map<String, Object?>> items;
  final Map<String, ({int total, int done})> checklistProgress;
  CollectionRows(this.folders, this.items, {this.checklistProgress = const {}});
}

class CollectionRepository {
  final CollectionKind kind;
  final Database? provided;
  CollectionRepository(this.kind, {this.provided});
  bool get notes => kind == CollectionKind.notes;
  String get items => notes ? 'notes' : 'todos';
  String get folders => notes ? 'folders' : 'todo_folders';
  Future<Database> get database async =>
      provided ?? await (notes ? NoteDatabase.database : TodoDatabase.database);
  String get now => DateTime.now().toIso8601String();
  Future<T> _changed<T>(Future<T> write) =>
      notes ? NotesChanges.after(write) : TodoChanges.after(write);

  Future<CollectionRows> load({
    String? folderId,
    bool trash = false,
    String query = '',
    String filter = 'all',
    String? tagId,
  }) async {
    final db = await database;
    final args = <Object?>[trash ? 1 : 0];
    var where = 'i.is_deleted = ?';
    if (query.isNotEmpty) {
      final escaped = query
          .replaceAll('\\', '\\\\')
          .replaceAll('%', '\\%')
          .replaceAll('_', '\\_');
      where += notes
          ? " AND (i.title LIKE ? ESCAPE '\\' OR i.body LIKE ? ESCAPE '\\' OR EXISTS (SELECT 1 FROM note_tag_links l JOIN note_tags t ON t.id=l.tag_id WHERE l.note_id=i.id AND t.normalized_name LIKE ? ESCAPE '\\'))"
          : " AND (i.title LIKE ? ESCAPE '\\' OR i.description LIKE ? ESCAPE '\\' OR EXISTS (SELECT 1 FROM todo_checklist c WHERE c.todo_id=i.id AND c.title LIKE ? ESCAPE '\\'))";
      args.addAll(List.filled(notes ? 2 : 3, '%$escaped%'));
      if (notes) {
        args.add(
          '%${escaped.toLowerCase().replaceAll(RegExp('[‘’ʻʼ]'), "'")}%',
        );
      }
    } else if (notes && tagId != null) {
      // Tag filters always span every folder, including nested folders.
    } else if (!notes && !trash && filter != 'all') {
      // Smart folders search all active tasks, including nested folders.
    } else if (folderId != null) {
      where += ' AND i.folder_id = ?';
      args.add(folderId);
    } else if (trash) {
      where += ' AND (f.id IS NULL OR f.is_deleted = 0)';
    } else if (filter == 'all') {
      where += ' AND i.folder_id IS NULL';
    }
    if (notes && !trash) {
      if (filter != 'all' || tagId == null) {
        where += filter == 'archive'
            ? ' AND i.is_archived = 1'
            : ' AND i.is_archived = 0';
      }
      if (filter == 'favorites') where += ' AND i.is_favorite = 1';
    }
    if (notes && tagId != null) {
      where += ' AND EXISTS (SELECT 1 FROM note_tag_links l WHERE l.note_id=i.id AND l.tag_id=?)';
      args.add(tagId);
    }
    final rows = await db.rawQuery(
      'SELECT i.* FROM $items i LEFT JOIN $folders f ON i.folder_id=f.id WHERE $where ORDER BY ${notes ? 'i.updated_at DESC' : 'i.is_done ASC, i.priority DESC, i.created_at DESC'}',
      args,
    );
    final allFolders = await db.query(
      folders,
      where: 'is_deleted = ?',
      whereArgs: [trash ? 1 : 0],
      orderBy: 'name COLLATE NOCASE',
    );
    final deletedIds = allFolders.map((f) => f['id']).toSet();
    final visible = allFolders
        .where(
          (f) =>
              query.isEmpty &&
              (!notes || tagId == null) &&
              filter == 'all' &&
              (folderId != null
                  ? f['parent_id'] == folderId
                  : trash
                  ? !deletedIds.contains(f['parent_id'])
                  : f['parent_id'] == null),
        )
        .toList();
    return CollectionRows(
      visible,
      notes ? await NoteTagStore.hydrate(db, rows) : rows,
      checklistProgress: {
        if (!notes)
          for (final row in await db.rawQuery(
            'SELECT todo_id,count(*) AS total,sum(is_done) AS done FROM todo_checklist GROUP BY todo_id',
          ))
            row['todo_id'] as String: (
              total: row['total'] as int,
              done: row['done'] as int,
            ),
      },
    );
  }

  Future<List<Map<String, Object?>>> activeFolders() async => (await database)
      .query(folders, where: 'is_deleted = 0', orderBy: 'name COLLATE NOCASE');

  Future<void> createFolder(String name, String? parentId) async {
    final db = await database;
    await db.insert(folders, {
      'id': DateTime.now().microsecondsSinceEpoch.toString(),
      'name': name,
      'parent_id': parentId,
      'created_at': now,
      'updated_at': now,
      'is_deleted': 0,
    });
  }

  /// One transaction prevents half-created checklists. No schema migration.
  Future<Map<String, Object?>> createFromTemplate(
    EntryTemplate template,
    String language,
    String? parentId,
  ) async {
    if (template.todo == notes) throw ArgumentError('template_kind');
    final db = await database;
    return _changed(
      db.transaction((txn) async {
        if (parentId != null) {
          final parent = await txn.query(
            folders,
            where: 'id = ? AND is_deleted = 0',
            whereArgs: [parentId],
          );
          if (parent.isEmpty) throw StateError('folder_missing');
        }
        final random = Random.secure();
        final id =
            'tpl-${DateTime.now().microsecondsSinceEpoch}-${random.nextInt(1 << 32)}';
        final timestamp = now;
        if (notes) {
          final row = <String, Object?>{
            'id': id,
            'title': template.title(language),
            'body': template.body(language),
            'folder_id': parentId,
            'created_at': timestamp,
            'updated_at': timestamp,
            'is_deleted': 0,
            'is_favorite': 0,
            'is_archived': 0,
            'tags': '[]',
          };
          await txn.insert(items, row);
          return row;
        }
        final folder = <String, Object?>{
          'id': id,
          'name': template.title(language),
          'parent_id': parentId,
          'created_at': timestamp,
          'updated_at': timestamp,
          'is_deleted': 0,
        };
        await txn.insert(folders, folder);
        final lines = template.lines(language);
        for (var i = 0; i < lines.length; i++) {
          await txn.insert(items, {
            'id': '$id-$i',
            'title': lines[i],
            'description': '',
            'folder_id': id,
            'priority': 0,
            'is_done': 0,
            'is_deleted': 0,
            'due_at': null,
            'completed_at': null,
            'created_at': DateTime.parse(timestamp)
                .subtract(Duration(microseconds: i))
                .toIso8601String(),
            'updated_at': timestamp,
          });
        }
        return folder;
      }),
    );
  }

  Future<void> renameFolder(String id, String name) async {
    await (await database).update(
      folders,
      {'name': name, 'updated_at': now},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// A copy is independent: no repeated series, notifications, media ownership
  /// or private widget consent is silently transferred to a new task.
  Future<String> duplicateTask(String id) async {
    if (notes) throw StateError('task_required');
    final db = await database;
    return _changed(
      db.transaction((txn) async {
        final original = (await txn.query(
          'todos',
          where: 'id=? AND is_deleted=0',
          whereArgs: [id],
        )).single;
        final next =
            'copy:${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}';
        final stamp = now;
        await txn.insert('todos', {
          ...original,
          'id': next,
          'is_done': 0,
          'completed_at': null,
          'trash_batch': null,
          'created_at': stamp,
          'updated_at': stamp,
        });
        await TodoChecklistStore.fromTitles(
          txn,
          next,
          (await TodoChecklistStore.load(
            txn,
            id,
          )).map((item) => item.title).toList(),
        );
        return next;
      }),
    );
  }

  Future<void> move(
    String id,
    String? destination, {
    bool folder = false,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      final rows = await txn.query(folders);
      final byId = {for (final row in rows) row['id'] as String: row};
      final seen = <String>{if (folder) id};
      String? current = destination;
      while (current != null) {
        if (!seen.add(current)) throw StateError('folder_cycle');
        final target = byId[current];
        if (target == null || target['is_deleted'] == 1) {
          throw StateError('folder_missing');
        }
        current = target['parent_id'] as String?;
      }
      await txn.update(
        folder ? folders : items,
        {folder ? 'parent_id' : 'folder_id': destination, 'updated_at': now},
        where: 'id = ?',
        whereArgs: [id],
      );
    });
    if (notes) {
      NotesChanges.committed();
    } else {
      TodoChanges.committed();
    }
  }

  Future<void> setField(String id, String key, Object? value) async {
    final allowed = notes
        ? {'is_favorite', 'is_archived', 'tags'}
        : {'is_done'};
    if (!allowed.contains(key)) throw ArgumentError('field');
    if (!notes && key == 'is_done') {
      if (value != 0 && value != 1) throw ArgumentError('completion');
      await TodoSeriesStore(await database).setCompleted(id, value == 1);
      return;
    }
    if (notes && key == 'tags') {
      final names = List<String>.from(jsonDecode(value as String) as List);
      final db = await database;
      await db.transaction((txn) async {
        await NoteTagStore.assign(txn, id, names: names);
        await txn.update(
          'notes',
          {'updated_at': now},
          where: 'id = ?',
          whereArgs: [id],
        );
      });
      NotesChanges.committed();
      return;
    }
    await (await database).update(
      items,
      {
        key: value,
        'updated_at': now,
        if (!notes && key == 'is_done') 'completed_at': value == 1 ? now : null,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    if (notes) {
      NotesChanges.committed();
    } else {
      TodoChanges.committed();
    }
  }

  Set<String> _tree(
    List<Map<String, Object?>> rows,
    String root, {
    bool activeOnly = false,
    String? batch,
  }) {
    final result = <String>{root};
    final queue = <String>[root];
    for (var i = 0; i < queue.length; i++) {
      for (final row in rows) {
        if (row['parent_id'] == queue[i] &&
            (!activeOnly || row['is_deleted'] == 0) &&
            (batch == null || row['trash_batch'] == batch) &&
            result.add(row['id'] as String)) {
          queue.add(row['id'] as String);
        }
      }
    }
    return result;
  }

  Future<void> trash(String id, {bool folder = false}) async {
    final db = await database;
    await db.transaction((txn) async {
      if (!folder) {
        await txn.update(
          items,
          {'is_deleted': 1, 'trash_batch': null, 'updated_at': now},
          where: 'id = ?',
          whereArgs: [id],
        );
        return;
      }
      final rows = await txn.query(folders);
      final root = rows.where((r) => r['id'] == id);
      if (root.isEmpty || root.first['is_deleted'] == 1) return;
      final batch = '$id:$now';
      final changes = {
        'is_deleted': 1,
        'trash_batch': batch,
        'updated_at': now,
      };
      for (final f in _tree(rows, id, activeOnly: true)) {
        await txn.update(
          folders,
          changes,
          where: 'id = ? AND is_deleted = 0',
          whereArgs: [f],
        );
        await txn.update(
          items,
          changes,
          where: 'folder_id = ? AND is_deleted = 0',
          whereArgs: [f],
        );
      }
    });
    if (notes) {
      NotesChanges.committed();
    } else {
      TodoChanges.committed();
    }
  }

  Future<void> restore(String id, {bool folder = false}) async {
    final db = await database;
    await db.transaction((txn) async {
      final table = folder ? folders : items;
      final roots = await txn.query(table, where: 'id = ?', whereArgs: [id]);
      if (roots.isEmpty || roots.first['is_deleted'] == 0) return;
      final row = roots.single;
      final link = folder ? 'parent_id' : 'folder_id';
      final all = await txn.query(folders);
      final parent =
          all.any((f) => f['id'] == row[link] && f['is_deleted'] == 0)
          ? row[link]
          : null;
      final batch = row['trash_batch'] as String?;
      final ids = folder && batch != null ? _tree(all, id, batch: batch) : {id};
      for (final target in ids) {
        await txn.update(
          table,
          {
            'is_deleted': 0,
            'trash_batch': null,
            'updated_at': now,
            if (target == id) link: parent,
          },
          where: 'id = ?',
          whereArgs: [target],
        );
        if (folder && batch != null) {
          await txn.update(
            items,
            {'is_deleted': 0, 'trash_batch': null, 'updated_at': now},
            where: 'folder_id = ? AND trash_batch = ?',
            whereArgs: [target, batch],
          );
        }
      }
    });
    if (notes) {
      NotesChanges.committed();
    } else {
      TodoChanges.committed();
    }
  }

  Future<void> removeForever(String id, {bool folder = false}) async {
    final db = await database;
    await db.transaction((txn) async {
      final table = folder ? folders : items;
      final root = await txn.query(
        table,
        where: 'id = ? AND is_deleted = 1',
        whereArgs: [id],
      );
      if (root.isEmpty) throw StateError('not_in_trash');
      final ids = folder ? _tree(await txn.query(folders), id) : <String>{};
      final targets = folder
          ? <Map<String, Object?>>[]
          : List<Map<String, Object?>>.from(root);
      for (final f in ids) {
        targets.addAll(
          await txn.query(items, where: 'folder_id = ?', whereArgs: [f]),
        );
      }
      for (final item in targets) {
        if (notes) {
          await txn.delete(
            'note_versions',
            where: 'note_id = ?',
            whereArgs: [item['id']],
          );
        }
        await txn.delete(items, where: 'id = ?', whereArgs: [item['id']]);
      }
      for (final f in ids) {
        await txn.delete(folders, where: 'id = ?', whereArgs: [f]);
      }
    });
    if (notes) {
      NotesChanges.committed();
    } else {
      TodoChanges.committed();
    }
  }
}
