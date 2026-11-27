import 'dart:convert';
import 'dart:math';

import 'package:sqflite/sqflite.dart';

import 'notes_changes.dart';

class NoteTag {
  final String id, name;
  const NoteTag(this.id, this.name);
  factory NoteTag.fromMap(Map<String, Object?> row) =>
      NoteTag(row['id'] as String, row['name'] as String);
}

class TagNameException implements Exception {
  final String messageKey;
  const TagNameException(this.messageKey);
}

/// Notes-only library. IDs survive rename; names never identify links.
class NoteTagStore {
  final Database db;
  NoteTagStore(this.db);
  static String displayName(String name) {
    final trimmed = name.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (trimmed.isEmpty ||
        trimmed.runes.length > 80 ||
        trimmed.contains(RegExp(r'[\x00-\x1f\x7f]'))) {
      throw const TagNameException('tagNameInvalid');
    }
    return trimmed;
  }

  static String normalizeName(String name) => name
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ')
      .toLowerCase()
      .replaceAll(RegExp('[‘’ʻʼ]'), "'");
  static String nameKey(String name) => normalizeName(displayName(name));

  static Future<void> createSchema(DatabaseExecutor db) async {
    await db.execute('''CREATE TABLE note_tags (
      id TEXT PRIMARY KEY, name TEXT NOT NULL, normalized_name TEXT NOT NULL UNIQUE,
      created_at TEXT NOT NULL, updated_at TEXT NOT NULL)''');
    await db.execute('''CREATE TABLE note_tag_links (
      note_id TEXT NOT NULL REFERENCES notes(id) ON DELETE CASCADE,
      tag_id TEXT NOT NULL REFERENCES note_tags(id) ON DELETE CASCADE,
      PRIMARY KEY(note_id, tag_id))''');
    await db.execute(
      'CREATE INDEX note_tag_links_tag ON note_tag_links(tag_id, note_id)',
    );
  }

  static List<String> legacyNames(Object? value) {
    try {
      final decoded = jsonDecode(value as String? ?? '[]');
      return decoded is List ? decoded.whereType<String>().toList() : [];
    } on FormatException {
      return [];
    }
  }

  static Future<void> migrateLegacy(DatabaseExecutor db) async {
    for (final row in await db.query('notes', columns: ['id', 'tags'])) {
      final ids = <String>{};
      for (final name in legacyNames(row['tags'])) {
        // Preserve unusual historical names; new edits obey the name limit.
        if (name.trim().isNotEmpty) {
          ids.add((await ensure(db, name, legacy: true)).id);
        }
      }
      for (final id in ids) {
        await db.insert('note_tag_links', {'note_id': row['id'], 'tag_id': id});
      }
    }
  }

  static Future<NoteTag> ensure(
    DatabaseExecutor db,
    String name, {
    String? id,
    String? createdAt,
    bool legacy = false,
  }) async {
    final display = legacy
        ? name.trim().replaceAll(RegExp(r'\s+'), ' ')
        : displayName(name);
    final key = display.toLowerCase().replaceAll(RegExp('[‘’ʻʼ]'), "'");
    final existing = await db.query(
      'note_tags',
      where: 'normalized_name = ?',
      whereArgs: [key],
    );
    if (existing.isNotEmpty) return NoteTag.fromMap(existing.single);
    final stamp = DateTime.now().toIso8601String();
    final tagId =
        id ??
        'tag-${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}';
    await db.insert('note_tags', {
      'id': tagId,
      'name': display,
      'normalized_name': key,
      'created_at': createdAt ?? stamp,
      'updated_at': stamp,
    });
    return NoteTag(tagId, display);
  }

  Future<List<NoteTag>> all() async => (await db.query(
    'note_tags',
    orderBy: 'normalized_name',
  )).map(NoteTag.fromMap).toList();
  Future<NoteTag> create(String name) =>
      NotesChanges.after(db.transaction((txn) => ensure(txn, name)));
  Future<void> rename(String id, String name) => NotesChanges.after(
    db.transaction((txn) async {
      final display = displayName(name), key = nameKey(name);
      if ((await txn.query(
        'note_tags',
        where: 'normalized_name = ? AND id != ?',
        whereArgs: [key, id],
      )).isNotEmpty) {
        throw const TagNameException('tagDuplicate');
      }
      await txn.update(
        'note_tags',
        {
          'name': display,
          'normalized_name': key,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [id],
      );
      for (final row in await txn.query(
        'note_tag_links',
        columns: ['note_id'],
        where: 'tag_id = ?',
        whereArgs: [id],
      )) {
        await syncMirror(txn, row['note_id'] as String);
      }
    }),
  );
  Future<void> delete(String id) => NotesChanges.after(
    db.transaction((txn) async {
      final linked = await txn.query(
        'note_tag_links',
        columns: ['note_id'],
        where: 'tag_id = ?',
        whereArgs: [id],
      );
      await txn.delete('note_tag_links', where: 'tag_id = ?', whereArgs: [id]);
      await txn.delete('note_tags', where: 'id = ?', whereArgs: [id]);
      for (final row in linked) {
        await syncMirror(txn, row['note_id'] as String);
      }
    }),
  );
  Future<List<NoteTag>> forNote(String noteId) => linked(db, noteId);
  static Future<List<NoteTag>> linked(
    DatabaseExecutor db,
    String noteId,
  ) async => (await db.rawQuery(
    '''SELECT t.* FROM note_tags t JOIN note_tag_links l ON l.tag_id=t.id
    WHERE l.note_id=? ORDER BY t.normalized_name''',
    [noteId],
  )).map(NoteTag.fromMap).toList();

  /// Caller owns the transaction. Deleted IDs are discarded, never recreated
  /// from stale editor names after a global rename/delete.
  static Future<void> assign(
    DatabaseExecutor db,
    String noteId, {
    List<String>? ids,
    List<String> names = const [],
  }) async {
    final selected = <String>{};
    if (ids != null) {
      for (final id in ids.toSet()) {
        if ((await db.query(
          'note_tags',
          columns: ['id'],
          where: 'id = ?',
          whereArgs: [id],
        )).isNotEmpty) {
          selected.add(id);
        }
      }
    } else {
      for (final name in names) {
        if (name.trim().isNotEmpty) selected.add((await ensure(db, name)).id);
      }
    }
    final existing = (await db.query(
      'note_tag_links',
      columns: ['tag_id'],
      where: 'note_id = ?',
      whereArgs: [noteId],
    )).map((row) => row['tag_id'] as String).toSet();
    if (existing.length == selected.length && existing.containsAll(selected)) {
      await syncMirror(db, noteId);
      return;
    }
    await db.delete(
      'note_tag_links',
      where: 'note_id = ?',
      whereArgs: [noteId],
    );
    for (final id in selected) {
      await db.insert('note_tag_links', {'note_id': noteId, 'tag_id': id});
    }
    await syncMirror(db, noteId);
  }

  // Compatibility mirror for existing Note APIs/backup. No SQLite JSON1 needed.
  static Future<void> syncMirror(DatabaseExecutor db, String noteId) async {
    final tags = await linked(db, noteId);
    await db.update(
      'notes',
      {'tags': jsonEncode(tags.map((t) => t.name).toList())},
      where: 'id = ?',
      whereArgs: [noteId],
    );
  }

  static Future<List<Map<String, Object?>>> hydrate(
    DatabaseExecutor db,
    List<Map<String, Object?>> rows,
  ) async {
    final tags = <String, List<NoteTag>>{};
    for (var start = 0; start < rows.length; start += 500) {
      final ids = rows.skip(start).take(500).map((r) => r['id']).toList();
      final found = await db.rawQuery(
        '''SELECT l.note_id, t.* FROM note_tag_links l
      JOIN note_tags t ON t.id=l.tag_id WHERE l.note_id IN (${List.filled(ids.length, '?').join(',')}) ORDER BY t.normalized_name''',
        ids,
      );
      for (final row in found) {
        (tags[row['note_id'] as String] ??= []).add(NoteTag.fromMap(row));
      }
    }
    return rows.map((row) {
      final attached = tags[row['id']] ?? const <NoteTag>[];
      return <String, Object?>{
        ...row,
        'tags': jsonEncode(attached.map((t) => t.name).toList()),
        'tag_ids': jsonEncode(attached.map((t) => t.id).toList()),
      };
    }).toList();
  }
}
