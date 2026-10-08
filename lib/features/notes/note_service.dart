import 'package:sqflite/sqflite.dart';

import 'note_database.dart';
import 'note_model.dart';
import 'note_version_model.dart';

class NoteService {
  final Database? _providedDatabase;
  NoteService({Database? database}) : _providedDatabase = database;
  Future<Database> get _db async =>
      _providedDatabase ?? await NoteDatabase.database;

  Future<List<Note>> getNotes() async {
    final db = await _db;

    final maps = await db.query(
      'notes',
      where: 'is_deleted = ? AND folder_id IS NULL',
      whereArgs: [0],
      orderBy: 'updated_at DESC',
    );

    return maps.map((map) => Note.fromMap(map)).toList();
  }

  Future<List<Note>> getAllActiveNotes() async {
    final db = await _db;

    final maps = await db.query(
      'notes',
      where: 'is_deleted = ?',
      whereArgs: [0],
      orderBy: 'updated_at DESC',
    );

    return maps.map((map) => Note.fromMap(map)).toList();
  }

  Future<List<Note>> getNotesByFolder(String folderId) async {
    final db = await _db;

    final maps = await db.query(
      'notes',
      where: 'is_deleted = ? AND folder_id = ?',
      whereArgs: [0, folderId],
      orderBy: 'updated_at DESC',
    );

    return maps.map((map) => Note.fromMap(map)).toList();
  }

  Future<List<Note>> getDeletedNotes() async {
    final db = await _db;

    final maps = await db.rawQuery('''
      SELECT notes.*
      FROM notes
      LEFT JOIN folders
        ON notes.folder_id = folders.id
      WHERE notes.is_deleted = 1
        AND (
          notes.folder_id IS NULL
          OR folders.id IS NULL
          OR folders.is_deleted = 0
        )
      ORDER BY notes.updated_at DESC
      ''');

    return maps.map((map) => Note.fromMap(map)).toList();
  }

  Future<void> addNote(Note note) async {
    final db = await _db;

    await db.insert('notes', note.toMap());
  }

  Future<void> updateNote(Note note, {bool recordHistory = true}) async {
    final db = await _db;
    await db.transaction((txn) async {
      final rows = await txn.query(
        'notes',
        where: 'id = ?',
        whereArgs: [note.id],
      );
      if (rows.isEmpty) throw StateError('Yozuv topilmadi');
      final old = Note.fromMap(rows.single);
      if (recordHistory && (old.title != note.title || old.body != note.body)) {
        await _saveVersion(txn, old);
      }
      await txn.update(
        'notes',
        note.toMap(),
        where: 'id = ?',
        whereArgs: [note.id],
      );
    });
  }

  Future<void> _saveVersion(DatabaseExecutor db, Note note) async {
    final latest = await db.query(
      'note_versions',
      where: 'note_id = ?',
      whereArgs: [note.id],
      orderBy: 'version_id DESC',
      limit: 1,
    );
    if (latest.isNotEmpty &&
        latest.first['title'] == note.title &&
        latest.first['body'] == note.body) {
      return;
    }
    await db.insert(
      'note_versions',
      NoteVersion(
        noteId: note.id,
        title: note.title,
        body: note.body,
        createdAt: DateTime.now(),
      ).toMap(),
    );
  }

  Future<List<NoteVersion>> getNoteVersions(String noteId) async {
    final db = await _db;

    final maps = await db.query(
      'note_versions',
      where: 'note_id = ?',
      whereArgs: [noteId],
      orderBy: 'version_id DESC',
    );

    return maps.map((map) => NoteVersion.fromMap(map)).toList();
  }

  Future<Note> restoreVersion(Note currentNote, NoteVersion version) async {
    if (version.noteId != currentNote.id) {
      throw ArgumentError('Tarix boshqa yozuvga tegishli');
    }
    final db = await _db;
    return db.transaction((txn) async {
      final rows = await txn.query(
        'notes',
        where: 'id = ?',
        whereArgs: [currentNote.id],
      );
      if (rows.isEmpty) throw StateError('Yozuv topilmadi');
      final stored = Note.fromMap(rows.single);
      // Preserve both the durable version and any editor draft.
      await _saveVersion(txn, stored);
      if (stored.title != currentNote.title ||
          stored.body != currentNote.body) {
        await _saveVersion(txn, currentNote);
      }
      final restored = stored.copyWith(
        title: version.title,
        body: version.body,
        updatedAt: DateTime.now(),
      );
      await txn.update(
        'notes',
        restored.toMap(),
        where: 'id = ?',
        whereArgs: [stored.id],
      );
      return restored;
    });
  }

  Future<int> deleteSelectedVersions({
    required String noteId,
    required Set<int> versionIds,
  }) async {
    if (versionIds.isEmpty) {
      return 0;
    }

    final db = await _db;

    return db.transaction((txn) async {
      int deletedCount = 0;

      for (final versionId in versionIds) {
        deletedCount += await txn.delete(
          'note_versions',
          where: 'note_id = ? AND version_id = ?',
          whereArgs: [noteId, versionId],
        );
      }

      return deletedCount;
    });
  }

  Future<void> moveToTrash(Note note) async {
    await updateNote(note.copyWith(isDeleted: true, updatedAt: DateTime.now()));
  }

  Future<void> moveNoteToFolder(Note note, String? folderId) async {
    final db = await _db;
    if (folderId != null) {
      final folders = await db.query(
        'folders',
        where: 'id = ? AND is_deleted = 0',
        whereArgs: [folderId],
      );
      if (folders.isEmpty) throw StateError('Papka topilmadi');
    }
    await updateNote(
      note.copyWith(folderId: folderId, updatedAt: DateTime.now()),
    );
  }

  Future<void> restoreNote(Note note) async {
    final db = await _db;
    await db.transaction((txn) async {
      String? folderId = note.folderId;
      if (folderId != null) {
        final folders = await txn.query(
          'folders',
          where: 'id = ? AND is_deleted = 0',
          whereArgs: [folderId],
        );
        if (folders.isEmpty) folderId = null;
      }
      await txn.update(
        'notes',
        {
          'is_deleted': 0,
          'trash_batch': null,
          'folder_id': folderId,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [note.id],
      );
    });
  }

  Future<void> deleteForever(String id) async {
    final db = await _db;

    await db.transaction((txn) async {
      await txn.delete('note_versions', where: 'note_id = ?', whereArgs: [id]);

      await txn.delete('notes', where: 'id = ?', whereArgs: [id]);
    });
  }
}
