import 'package:sqflite/sqflite.dart';

import '../note_model.dart';
import '../note_tag_store.dart';
import '../note_widget_permission_store.dart';

enum WidgetSource { recent, pinned, tag }

enum WidgetPrivacy { hidden, titles, preview }

class NotesWidgetConfig {
  final int id;
  final WidgetSource source;
  final WidgetPrivacy privacy;
  final String? tagId;
  final List<String> pinnedIds;
  final Map<String, String> approvals;
  final String revision;
  final int permissionEpoch;
  const NotesWidgetConfig({
    required this.id,
    this.source = WidgetSource.recent,
    this.privacy = WidgetPrivacy.hidden,
    this.tagId,
    this.pinnedIds = const [],
    this.approvals = const {},
    this.revision = '',
    this.permissionEpoch = 0,
  });

  factory NotesWidgetConfig.fromMap(Map<String, dynamic> map) =>
      NotesWidgetConfig(
        id: map['id'] as int,
        source:
            WidgetSource.values
                .where((v) => v.name == map['source'])
                .firstOrNull ??
            WidgetSource.recent,
        privacy:
            WidgetPrivacy.values
                .where((v) => v.name == map['privacy'])
                .firstOrNull ??
            WidgetPrivacy.hidden,
        tagId: map['tagId'] as String?,
        pinnedIds: List<String>.from(map['pinnedIds'] as List? ?? []),
        approvals: Map<String, String>.from(map['approvals'] as Map? ?? {}),
        revision: map['revision'] as String? ?? '',
        permissionEpoch: map['permissionEpoch'] as int? ?? 0,
      );
  Map<String, dynamic> toMap() => {
    'id': id,
    'source': source.name,
    'privacy': privacy.name,
    'tagId': tagId,
    'pinnedIds': pinnedIds,
    'approvals': approvals,
    'revision': revision,
    'permissionEpoch': permissionEpoch,
  };
}

/// Uses the normal SQLCipher connection. Never reads private_records or files.
class NotesWidgetData {
  final Database db;
  NotesWidgetData(this.db);

  Future<List<Note>> available(
    NotesWidgetConfig config, {
    bool choosing = false,
    int limit = 100,
    String query = '',
    bool exporting = false,
  }) => db.transaction((txn) async {
    final args = <Object?>[];
    var where = 'is_deleted=0';
    if (exporting) {
      where += ' AND EXISTS (SELECT 1 FROM note_widget_permissions p WHERE p.note_id=notes.id)';
    }
    if (choosing && query.trim().isNotEmpty) {
      final escaped = query
          .trim()
          .replaceAll('\\', '\\\\')
          .replaceAll('%', '\\%')
          .replaceAll('_', '\\_');
      where += " AND (title LIKE ? ESCAPE '\\' OR body LIKE ? ESCAPE '\\')";
      args.addAll(['%$escaped%', '%$escaped%']);
    }
    if (!choosing && config.source == WidgetSource.pinned) {
      if (config.pinnedIds.isEmpty) return <Note>[];
      final ids = config.pinnedIds.take(100).toList();
      where += ' AND id IN (${List.filled(ids.length, '?').join(',')})';
      args.addAll(ids);
    } else {
      if (!choosing) where += ' AND is_archived=0';
      if (config.source == WidgetSource.tag) {
        if (config.tagId == null) return <Note>[];
        where += ' AND EXISTS (SELECT 1 FROM note_tag_links l WHERE l.note_id=notes.id AND l.tag_id=?)';
        args.add(config.tagId);
      }
    }
    // Exclude deleted ancestors even if an old/imported row is inconsistent.
    final rows = await txn.rawQuery(
      '''WITH RECURSIVE hidden(id) AS (
      SELECT id FROM folders WHERE is_deleted=1 UNION
      SELECT f.id FROM folders f JOIN hidden h ON f.parent_id=h.id)
      SELECT notes.* FROM notes WHERE $where AND
      (folder_id IS NULL OR folder_id NOT IN (SELECT id FROM hidden))
      ORDER BY updated_at DESC, id LIMIT ?''',
      [...args, limit.clamp(1, 100)],
    );
    return (await NoteTagStore.hydrate(txn, rows)).map(Note.fromMap).toList();
  });

  static Future<String> fingerprint(Note note, WidgetPrivacy privacy) async {
    return NoteWidgetPermissionStore.fingerprint(
      note,
      titlesOnly: privacy == WidgetPrivacy.titles,
    );
  }

  static String excerpt(String text, int length) => String.fromCharCodes(
    text.replaceAll(RegExp(r'\s+'), ' ').trim().runes.take(length),
  );

  Future<List<Map<String, Object?>>> snapshot(
    NotesWidgetConfig config,
    Map<String, String> labels, {
    bool forceHidden = false,
  }) async {
    final rows = await available(config, limit: 12, exporting: true);
    final permissions = await NoteWidgetPermissionStore(db).allowed(rows);
    final result = <Map<String, Object?>>[];
    for (final note in rows) {
      if (permissions[note.id] != true) continue;
      final approved =
          !forceHidden &&
          config.privacy != WidgetPrivacy.hidden &&
          permissions[note.id] == true;
      result.add({
        'id': note.id,
        'title': approved
            ? (excerpt(note.title, 160).isEmpty
                  ? labels['untitled']!
                  : excerpt(note.title, 160))
            : '${labels['note']} ${result.length + 1}',
        'body': approved && config.privacy == WidgetPrivacy.preview
            ? excerpt(note.body, 240)
            : '',
        'tags': approved && config.privacy == WidgetPrivacy.preview
            ? note.tags.take(3).map((t) => '#${excerpt(t, 40)}').join('  ')
            : '',
      });
    }
    return result;
  }
}
