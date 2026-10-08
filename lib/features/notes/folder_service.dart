import 'package:sqflite/sqflite.dart';

import 'folder_model.dart';
import 'note_database.dart';

class FolderService {
  final Database? _providedDatabase;
  FolderService({Database? database}) : _providedDatabase = database;
  Future<Database> get _db async =>
      _providedDatabase ?? await NoteDatabase.database;

  Future<List<Folder>> getRootFolders() async {
    final db = await _db;

    final maps = await db.query(
      'folders',
      where: 'parent_id IS NULL AND is_deleted = ?',
      whereArgs: [0],
      orderBy: 'name ASC',
    );

    return maps.map((map) => Folder.fromMap(map)).toList();
  }

  Future<List<Folder>> getSubFolders(String parentId) async {
    final db = await _db;

    final maps = await db.query(
      'folders',
      where: 'parent_id = ? AND is_deleted = ?',
      whereArgs: [parentId, 0],
      orderBy: 'name ASC',
    );

    return maps.map((map) => Folder.fromMap(map)).toList();
  }

  Future<void> addFolder(Folder folder) async {
    final db = await _db;

    await db.insert('folders', folder.toMap());
  }

  Future<void> updateFolder(Folder folder) async {
    final db = await _db;

    await db.update(
      'folders',
      folder.toMap(),
      where: 'id = ?',
      whereArgs: [folder.id],
    );
  }

  Future<List<Folder>> getAllFolders() async {
    final db = await _db;

    final maps = await db.query(
      'folders',
      where: 'is_deleted = ?',
      whereArgs: [0],
      orderBy: 'name ASC',
    );

    return maps.map((map) => Folder.fromMap(map)).toList();
  }

  Future<List<Folder>> getAllFoldersIncludingDeleted() async {
    final db = await _db;

    final maps = await db.query('folders', orderBy: 'name ASC');

    return maps.map((map) => Folder.fromMap(map)).toList();
  }

  Future<List<Folder>> getDeletedRootFolders() async {
    final db = await _db;

    final maps = await db.query(
      'folders',
      where: 'is_deleted = ?',
      whereArgs: [1],
      orderBy: 'updated_at DESC',
    );

    final deletedFolders = maps.map((map) => Folder.fromMap(map)).toList();

    final deletedIds = deletedFolders.map((folder) => folder.id).toSet();

    return deletedFolders.where((folder) {
      final parentId = folder.parentId;

      if (parentId == null) {
        return true;
      }

      return !deletedIds.contains(parentId);
    }).toList();
  }

  Future<Folder?> getFolderById(String folderId) async {
    final db = await _db;

    final maps = await db.query(
      'folders',
      where: 'id = ?',
      whereArgs: [folderId],
      limit: 1,
    );

    if (maps.isEmpty) {
      return null;
    }

    return Folder.fromMap(maps.first);
  }

  Future<List<Folder>> getFolderPath(String? folderId) async {
    if (folderId == null) {
      return [];
    }

    final allFolders = await getAllFoldersIncludingDeleted();

    final folderMap = {for (final folder in allFolders) folder.id: folder};

    final path = <Folder>[];
    final visited = <String>{};

    String? currentId = folderId;

    while (currentId != null) {
      if (!visited.add(currentId)) {
        break;
      }

      final folder = folderMap[currentId];

      if (folder == null) {
        break;
      }

      path.add(folder);
      currentId = folder.parentId;
    }

    return path.reversed.toList();
  }

  Future<String> getFolderPathText(String? folderId) async {
    final path = await getFolderPath(folderId);

    if (path.isEmpty) {
      return 'Bosh sahifa';
    }

    return 'Bosh sahifa > ${path.map((folder) => folder.name).join(' > ')}';
  }

  Future<Set<String>> getDescendantFolderIds(String folderId) async {
    final allFolders = await getAllFoldersIncludingDeleted();

    final descendants = <String>{};

    void collectChildren(String parentId) {
      for (final folder in allFolders) {
        if (folder.parentId == parentId) {
          if (descendants.add(folder.id)) {
            collectChildren(folder.id);
          }
        }
      }
    }

    collectChildren(folderId);

    return descendants;
  }

  Future<bool> canMoveFolder(Folder folder, String? newParentId) async {
    if (newParentId == null) {
      return true;
    }

    if (newParentId == folder.id) {
      return false;
    }

    final descendantIds = await getDescendantFolderIds(folder.id);

    if (descendantIds.contains(newParentId)) {
      return false;
    }

    final target = await getFolderById(newParentId);
    return target != null && !target.isDeleted;
  }

  Future<bool> moveFolder(Folder folder, String? newParentId) async {
    final allowed = await canMoveFolder(folder, newParentId);

    if (!allowed) {
      return false;
    }

    final db = await _db;

    await db.update(
      'folders',
      {
        'parent_id': newParentId,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [folder.id],
    );

    return true;
  }

  Future<void> moveFolderTreeToTrash(Folder folder) async {
    final db = await _db;
    await db.transaction((txn) async {
      final rows = await txn.query('folders');
      final root = rows.where((row) => row['id'] == folder.id);
      if (root.isEmpty || root.first['is_deleted'] == 1) return;
      final ids = <String>{folder.id};
      final queue = <String>[folder.id];
      // Previously deleted subtrees keep their own deletion identity.
      for (var i = 0; i < queue.length; i++) {
        for (final row in rows) {
          if (row['parent_id'] == queue[i] &&
              row['is_deleted'] == 0 &&
              ids.add(row['id'] as String)) {
            queue.add(row['id'] as String);
          }
        }
      }
      final now = DateTime.now().toIso8601String();
      final batch = '${folder.id}:$now';
      for (final id in ids) {
        final changes = {
          'is_deleted': 1,
          'trash_batch': batch,
          'updated_at': now,
        };
        await txn.update(
          'folders',
          changes,
          where: 'id = ? AND is_deleted = 0',
          whereArgs: [id],
        );
        await txn.update(
          'notes',
          changes,
          where: 'folder_id = ? AND is_deleted = 0',
          whereArgs: [id],
        );
      }
    });
  }

  Future<void> restoreFolderTree(Folder folder) async {
    final db = await _db;
    await db.transaction((txn) async {
      final rows = await txn.query(
        'folders',
        where: 'id = ?',
        whereArgs: [folder.id],
      );
      if (rows.isEmpty || rows.first['is_deleted'] == 0) return;
      final batch = rows.first['trash_batch'];
      final now = DateTime.now().toIso8601String();
      final all = await txn.query('folders');
      final ids = <String>{folder.id};
      final queue = <String>[folder.id];
      if (batch != null) {
        for (var i = 0; i < queue.length; i++) {
          for (final row in all) {
            if (row['parent_id'] == queue[i] &&
                row['trash_batch'] == batch &&
                ids.add(row['id'] as String)) {
              queue.add(row['id'] as String);
            }
          }
        }
      }
      String? parent = rows.first['parent_id'] as String?;
      if (parent != null &&
          !all.any((r) => r['id'] == parent && r['is_deleted'] == 0)) {
        parent = null;
      }
      for (final id in ids) {
        await txn.update(
          'folders',
          {
            'is_deleted': 0,
            'trash_batch': null,
            'updated_at': now,
            if (id == folder.id) 'parent_id': parent,
          },
          where: 'id = ?',
          whereArgs: [id],
        );
        if (batch != null) {
          await txn.update(
            'notes',
            {'is_deleted': 0, 'trash_batch': null, 'updated_at': now},
            where: 'folder_id = ? AND trash_batch = ?',
            whereArgs: [id, batch],
          );
        }
      }
      // Version 6 has no deletion provenance. Restore its folder only:
      // old deleted children become separately accessible in the trash.
    });
  }

  Future<void> deleteFolderTreeForever(Folder folder) async {
    final db = await _db;

    final descendantIds = await getDescendantFolderIds(folder.id);

    final folderIds = <String>{folder.id, ...descendantIds};

    await db.transaction((txn) async {
      for (final folderId in folderIds) {
        final noteMaps = await txn.query(
          'notes',
          columns: ['id'],
          where: 'folder_id = ?',
          whereArgs: [folderId],
        );

        for (final noteMap in noteMaps) {
          final noteId = noteMap['id'] as String;

          await txn.delete(
            'note_versions',
            where: 'note_id = ?',
            whereArgs: [noteId],
          );
        }

        await txn.delete(
          'notes',
          where: 'folder_id = ?',
          whereArgs: [folderId],
        );
      }

      for (final folderId in folderIds) {
        await txn.delete('folders', where: 'id = ?', whereArgs: [folderId]);
      }
    });
  }

  Future<bool> isFolderEmpty(String folderId) async {
    final db = await _db;

    final subFolders = await db.query(
      'folders',
      columns: ['id'],
      where: 'parent_id = ?',
      whereArgs: [folderId],
      limit: 1,
    );

    if (subFolders.isNotEmpty) {
      return false;
    }

    final notes = await db.query(
      'notes',
      columns: ['id'],
      where: 'folder_id = ?',
      whereArgs: [folderId],
      limit: 1,
    );

    if (notes.isNotEmpty) {
      return false;
    }

    return true;
  }

  Future<bool> deleteFolderSafely(String folderId) async {
    final empty = await isFolderEmpty(folderId);

    if (!empty) {
      return false;
    }

    final db = await _db;

    final deletedCount = await db.delete(
      'folders',
      where: 'id = ?',
      whereArgs: [folderId],
    );

    return deletedCount > 0;
  }
}
