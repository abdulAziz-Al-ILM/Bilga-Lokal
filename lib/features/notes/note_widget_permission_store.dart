import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';

import 'note_model.dart';
import 'note_tag_store.dart';
import 'notes_changes.dart';
import 'widget/notes_widget_bridge.dart';

/// Device-local disclosure consent. Never included in a backup or note history.
class NoteWidgetPermissionStore {
  final Database db;
  NoteWidgetPermissionStore(this.db);

  static Future<void> createSchema(DatabaseExecutor db) async {
    await db.execute('''
    CREATE TABLE note_widget_permissions (
      note_id TEXT PRIMARY KEY REFERENCES notes(id) ON DELETE CASCADE,
      fingerprint TEXT NOT NULL
    )
  ''');
    await db.execute('''CREATE TRIGGER note_widget_content_changed
      AFTER UPDATE OF title, body, is_deleted ON notes
      WHEN NEW.title != OLD.title OR NEW.body != OLD.body OR NEW.is_deleted != OLD.is_deleted
      BEGIN DELETE FROM note_widget_permissions WHERE note_id=NEW.id; END''');
    for (final event in ['INSERT', 'DELETE', 'UPDATE']) {
      final row = event == 'DELETE' ? 'OLD' : 'NEW';
      await db.execute('''CREATE TRIGGER note_widget_tags_${event.toLowerCase()}
        AFTER $event ON note_tag_links
        BEGIN DELETE FROM note_widget_permissions WHERE note_id=$row.note_id;
        ${event == 'UPDATE' ? 'DELETE FROM note_widget_permissions WHERE note_id=OLD.note_id;' : ''}
        END''');
    }
    await db.execute('''CREATE TRIGGER note_widget_tag_renamed
      AFTER UPDATE OF name ON note_tags WHEN NEW.name != OLD.name
      BEGIN DELETE FROM note_widget_permissions WHERE note_id IN
        (SELECT note_id FROM note_tag_links WHERE tag_id=NEW.id); END''');
  }

  static Future<String> fingerprint(
    Note note, {
    bool titlesOnly = false,
  }) async {
    final value = titlesOnly
        ? ['titles', note.id, note.title]
        : ['preview', note.id, note.title, note.body, note.tags];
    return base64UrlEncode(
      (await Sha256().hash(utf8.encode(jsonEncode(value)))).bytes,
    );
  }

  Future<Map<String, bool>> allowed(List<Note> notes) async {
    final grants = {
      for (final row in await db.query('note_widget_permissions'))
        row['note_id'] as String: row['fingerprint'] as String,
    };
    return {
      for (final note in notes)
        note.id:
            !note.isDeleted &&
            grants.containsKey(note.id) &&
            grants[note.id] == await fingerprint(note),
    };
  }

  Future<void> setAllowed(Note reviewed, bool enabled) async {
    final hash = enabled ? await fingerprint(reviewed) : null;
    await db.transaction((txn) async {
      if (!enabled) {
        await txn.delete(
          'note_widget_permissions',
          where: 'note_id = ?',
          whereArgs: [reviewed.id],
        );
        return;
      }
      final rows = await txn.query(
        'notes',
        where: 'id = ? AND is_deleted = 0',
        whereArgs: [reviewed.id],
      );
      if (rows.isEmpty) throw StateError('note_missing');
      final current = Note.fromMap(
        (await NoteTagStore.hydrate(txn, rows)).single,
      );
      if (await fingerprint(current) != hash) throw StateError('note_changed');
      await txn.insert('note_widget_permissions', {
        'note_id': reviewed.id,
        'fingerprint': hash,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
    try {
      // No debounce: clear native snapshots before this operation completes.
      // A native epoch also rejects any export already in flight.
      await NotesWidgetBridge.channel.invokeMethod<void>(
        'invalidatePermissions',
      );
    } on MissingPluginException {
      // Non-Android builds have no home-screen widget or native cache.
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) rethrow;
    } finally {
      NotesChanges.committed();
    }
  }
}
