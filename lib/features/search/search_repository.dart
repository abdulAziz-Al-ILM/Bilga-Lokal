import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../notes/note_database.dart';
import '../todo/todo_database.dart';
import 'search_index.dart';

class SearchHit {
  final String id, kind, title, preview, updated;
  final bool archived;
  const SearchHit(
    this.id,
    this.kind,
    this.title,
    this.preview,
    this.updated,
    this.archived,
  );

  factory SearchHit.row(Map<String, Object?> row) {
    final kind = row['kind'] as String;
    var body = row['body'] as String;
    if ({'experience', 'book', 'finance'}.contains(kind)) {
      // The stored record, rather than a generated answer, supplies the excerpt.
      final payload = jsonDecode(body) as Map<String, dynamic>;
      body = recordText(payload);
    }
    if (kind == 'habit') {
      final plan = jsonDecode(body) as Map<String, dynamic>;
      body = [
        for (final k in ['reason', 'cue', 'minimum', 'unit'])
          if (plan[k] is String) plan[k],
      ].join(' · ');
    }
    return SearchHit(
      row['id'] as String,
      kind,
      row['title'] as String,
      body.length > 240 ? '${body.substring(0, 240)}…' : body,
      row['updated'] as String,
      row['archived'].toString() == '1',
    );
  }

  static String recordText(Map<String, dynamic> data) => [
    for (final key in ['body', 'feelings', 'lesson', 'next', 'characters'])
      if (data[key] is String && (data[key] as String).isNotEmpty) data[key],
    for (final c in data['chapters'] as List? ?? [])
      '${c['title']}\n${c['body']}',
    if (data['entries'] != null)
      const JsonEncoder.withIndent('  ').convert(data['entries']),
  ].join('\n\n');
}

class SearchRepository {
  final Database? notesDb, todoDb;
  SearchRepository({this.notesDb, this.todoDb});
  Future<Database> get notes async => notesDb ?? await NoteDatabase.database;
  Future<Database> get todos async => todoDb ?? await TodoDatabase.database;

  Future<List<SearchHit>> search(
    String query, {
    String? kind,
    bool includeArchived = false,
    int offset = 0,
    int limit = 50,
  }) async {
    if (offset < 0 || limit < 1 || limit > 100) throw ArgumentError('page');
    final expression = SearchIndex.expression(query);
    if (query.trim().isNotEmpty && expression.isEmpty) return [];
    final all = <SearchHit>[];
    for (final db in [await notes, await todos]) {
      final rows = await db.rawQuery(
        '''SELECT id, kind, title, updated, archived,
        CASE
          WHEN kind IN ('note', 'todo', 'folder', 'todoFolder') THEN substr(body, 1, 241)
          WHEN kind = 'habit' THEN json_object(
            'reason', substr(json_extract(body, '\$.reason'), 1, 200),
            'cue', substr(json_extract(body, '\$.cue'), 1, 200),
            'unit', substr(json_extract(body, '\$.unit'), 1, 100))
          ELSE json_object('body', substr(coalesce(
            json_extract(body, '\$.body'),
            json_extract(body, '\$.chapters[0].body'),
            json_extract(body, '\$.entries[0].description'), ''), 1, 241))
        END AS body
        FROM bilga_search
        WHERE ${expression.isEmpty ? '1' : 'bilga_search MATCH ?'}
        ${includeArchived ? '' : "AND CAST(archived AS INTEGER) = 0"}
        ${kind == null ? '' : 'AND kind = ?'}
        ORDER BY updated DESC, kind, id LIMIT ?''',
        [if (expression.isNotEmpty) expression, ?kind, offset + limit],
      );
      all.addAll(
        rows.map(SearchHit.row).where((h) => kind == null || h.kind == kind),
      );
    }
    all.sort((a, b) {
      final time = b.updated.compareTo(a.updated);
      if (time != 0) return time;
      final type = a.kind.compareTo(b.kind);
      return type == 0 ? a.id.compareTo(b.id) : type;
    });
    return all.skip(offset).take(limit).toList();
  }

  Future<Map<String, Object?>?> source(SearchHit hit) async {
    final table = switch (hit.kind) {
      'note' => 'notes',
      'todo' => 'todos',
      'habit' => 'habits',
      'folder' => 'folders',
      'todoFolder' => 'todo_folders',
      _ => 'private_records',
    };
    final db = ['todos', 'todo_folders'].contains(table)
        ? await todos
        : await notes;
    final rows = await db.query(
      table,
      where: 'id = ?',
      whereArgs: [hit.id],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.single;
  }
}
