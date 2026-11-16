import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../experiences/experience_model.dart';

/// Small independently revisioned metadata. History is append-only; original
/// entries remain in their existing table and retain their existing IDs.
class ModuleData {
  static Future<void> createSchema(DatabaseExecutor db) async {
    await db.execute('''CREATE TABLE module_data(
      id TEXT PRIMARY KEY, module TEXT NOT NULL, kind TEXT NOT NULL,
      owner TEXT NOT NULL, payload TEXT NOT NULL, revision INTEGER NOT NULL,
      created_at TEXT NOT NULL, updated_at TEXT NOT NULL)''');
    await db.execute(
      'CREATE INDEX module_data_owner ON module_data(module, kind, owner, created_at)',
    );
    await db.execute(
      "CREATE UNIQUE INDEX module_history_revision ON module_data(owner,json_extract(payload,'\$.entryRevision')) WHERE module='experience' AND kind='history'",
    );
    await db.execute(
      "CREATE UNIQUE INDEX module_link_action ON module_data(module,owner,json_extract(payload,'\$.targetKind'),json_extract(payload,'\$.action')) WHERE kind='link'",
    );
    await db.execute(
      "CREATE TRIGGER module_history_no_update BEFORE UPDATE ON module_data WHEN old.module='experience' AND old.kind='history' BEGIN SELECT RAISE(ABORT,'immutable_history'); END",
    );
    await db.execute(
      "CREATE TRIGGER module_history_no_delete BEFORE DELETE ON module_data WHEN old.module='experience' AND old.kind='history' AND EXISTS(SELECT 1 FROM private_records WHERE id=old.owner) BEGIN SELECT RAISE(ABORT,'immutable_history'); END",
    );
    await db.execute(
      "CREATE UNIQUE INDEX module_link_target ON module_data(module,owner,json_extract(payload,'\$.targetKind'),json_extract(payload,'\$.target')) WHERE kind='link'",
    );
    // Retain the actual current state, never fabricate unavailable older edits.
    await db.execute("""INSERT INTO module_data SELECT 'experience:history:'||id||':'||revision,
      'experience','history',id,json_object('snapshot',json(payload),'entryRevision',revision),1,updated_at,updated_at
      FROM private_records WHERE kind='experience'""");
  }

  static Map<String, dynamic> decode(Map<String, Object?> row) {
    if (row['module'] is! String ||
        row['kind'] is! String ||
        row['id'] is! String ||
        (row['id'] as String).isEmpty ||
        row['owner'] is! String ||
        row['revision'] is! int ||
        (row['revision'] as int) < 1 ||
        row['payload'] is! String ||
        (row['payload'] as String).length > 5 * 1024 * 1024 ||
        ['created_at', 'updated_at'].any(
          (k) =>
              row[k] is! String || DateTime.tryParse(row[k] as String) == null,
        )) {
      throw const FormatException('module_row');
    }
    if (row['kind'] == 'category'
        ? row['owner'] != ''
        : (row['owner'] as String).isEmpty) {
      throw const FormatException('module_owner');
    }
    final data = Map<String, dynamic>.from(
      jsonDecode(row['payload'] as String),
    );
    validate(row['module'] as String, row['kind'] as String, data);
    return data;
  }

  static void validate(String module, String kind, Map<String, dynamic> data) {
    if (!['experience', 'habit', 'finance'].contains(module)) {
      throw const FormatException('module');
    }
    if (kind == 'category') {
      if (data['name'] is! String ||
          (data['name'] as String).trim().isEmpty ||
          (data['name'] as String).length > 100 ||
          (data['parent'] != null && data['parent'] is! String)) {
        throw const FormatException('module_category');
      }
    } else if (module == 'experience' && kind == 'history') {
      if (data['entryRevision'] is! int ||
          data['entryRevision'] < 1 ||
          data['snapshot'] is! Map) {
        throw const FormatException('experience_history');
      }
      ExperienceModel.validate(Map<String, dynamic>.from(data['snapshot']));
    } else if (kind == 'link' && module == 'experience') {
      if (!['note', 'todo', 'book', 'habit'].contains(data['targetKind']) ||
          data['target'] is! String ||
          (data['target'] as String).isEmpty ||
          data['action'] is! String ||
          !['ready', 'pending'].contains(data['state'])) {
        throw const FormatException('module_link');
      }
      if (data['state'] == 'pending') {
        final draft = data['draft'];
        if (data['targetKind'] != 'todo' ||
            draft is! Map ||
            draft['title'] is! String ||
            (draft['title'] as String).trim().isEmpty ||
            (draft['title'] as String).length > 200 ||
            draft['body'] is! String ||
            (draft['body'] as String).length > 100000 ||
            (draft['due'] != null && DateTime.tryParse(draft['due']) == null)) {
          throw const FormatException('module_link_draft');
        }
      }
    } else {
      throw const FormatException('module_kind');
    }
  }

  static Future<void> history(
    DatabaseExecutor db,
    String id,
    int revision,
    Map<String, dynamic> data,
    String stamp, {
    bool existing = false,
  }) => db
      .insert(
        'module_data',
        {
          'id': 'experience:history:$id:$revision',
          'module': 'experience',
          'kind': 'history',
          'owner': id,
          'payload': jsonEncode({'snapshot': data, 'entryRevision': revision}),
          'revision': 1,
          'created_at': stamp,
          'updated_at': stamp,
        },
        conflictAlgorithm: existing
            ? ConflictAlgorithm.ignore
            : ConflictAlgorithm.abort,
      )
      .then((_) {});
}
