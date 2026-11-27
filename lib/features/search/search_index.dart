import 'package:sqflite/sqflite.dart';

/// Derived data only. Triggers participate in the original write/restore
/// transaction; no independent copy of a user's task or completion state.
class SearchIndex {
  static Future<void> create(DatabaseExecutor db, {required bool notes}) async {
    await db.execute('''CREATE VIRTUAL TABLE bilga_search USING fts4(
      id, kind, title, body, updated, archived, tags,
      notindexed=id, notindexed=kind, notindexed=updated, notindexed=archived,
      tokenize=unicode61
    )''');
    final sources = notes
        ? [
            ('notes', 'note', 'title', 'body', 'is_deleted = 0', 'is_archived'),
            ('folders', 'folder', 'name', "''", 'is_deleted = 0', '0'),
            ('habits', 'habit', 'title', 'details', '1', 'is_archived'),
            (
              'private_records',
              'record',
              "json_extract(payload, '\$.title')",
              'payload',
              "kind IN ('experience', 'book', 'finance')",
              '0',
            ),
          ]
        : [
            ('todos', 'todo', 'title', 'description', 'is_deleted = 0', '0'),
            ('todo_folders', 'todoFolder', 'name', "''", 'is_deleted = 0', '0'),
          ];
    for (final (table, kind, title, body, active, archived) in sources) {
      // Names and SQL expressions are compile-time constants, never user input.
      final kindSql = table == 'private_records' ? 'kind' : "'$kind'";
      final oldKind = table == 'private_records' ? 'old.kind' : "'$kind'";
      final tags = table == 'notes' ? 'tags' : "''";
      final select =
          "SELECT id, $kindSql, $title, $body, updated_at, $archived, $tags FROM $table WHERE $active";
      await db.execute('INSERT INTO bilga_search $select');
      for (final action in ['INSERT', 'UPDATE', 'DELETE']) {
        await db.execute(
          '''CREATE TRIGGER search_${table}_${action.toLowerCase()}
          AFTER $action ON $table BEGIN
          ${action == 'INSERT' ? '' : "DELETE FROM bilga_search WHERE id = old.id AND kind = $oldKind;"}
          ${action == 'DELETE' ? '' : 'INSERT INTO bilga_search $select AND id = new.id;'}
          END''',
        );
      }
    }
    if (notes) {
      await db.execute(
        'CREATE INDEX search_note_folder ON notes(is_deleted, folder_id, updated_at)',
      );
      await db.execute(
        '''CREATE INDEX search_attachment_owner ON private_records(
        kind, json_extract(payload, '\$.ownerKind'), json_extract(payload, '\$.owner'))''',
      );
    } else {
      await db.execute(
        'CREATE INDEX planner_due ON todos(is_deleted, is_done, due_at)',
      );
      await db.execute(
        'CREATE INDEX planner_completed ON todos(is_deleted, completed_at)',
      );
    }
  }

  /// Literal prefix terms; punctuation and FTS operators cannot become syntax.
  static String expression(String query) => RegExp(
    r'[\p{L}\p{N}_]+',
    unicode: true,
  ).allMatches(query).take(20).map((m) => '"${m[0]}*"').join(' AND ');
}
