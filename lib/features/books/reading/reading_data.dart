import 'dart:convert';

import 'package:sqflite/sqflite.dart';

/// Normalized, independently revisioned rows keep frequent position writes small.
class ReadingData {
  static const kinds = {
    'source',
    'progress',
    'settings',
    'bookmark',
    'highlight',
    'annotation',
    'card',
    'review',
    'session',
    'link',
  };
  static const cardTypes = {
    'idea',
    'quote',
    'definition',
    'explanation',
    'question',
    'lesson',
    'summary',
    'comparison',
    'observation',
    'action',
  };
  static Future<void> createSchema(DatabaseExecutor db) async {
    await db.execute(
      '''CREATE TABLE IF NOT EXISTS book_reading(
      id TEXT PRIMARY KEY, book_id TEXT NOT NULL,
      kind TEXT NOT NULL, payload TEXT NOT NULL,
      revision INTEGER NOT NULL DEFAULT 1,
      created_at TEXT NOT NULL, updated_at TEXT NOT NULL,
      FOREIGN KEY(book_id) REFERENCES private_records(id) ON DELETE CASCADE)''',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS book_reading_owner ON book_reading(book_id,kind,updated_at)',
    );
    await db.execute(
      "CREATE UNIQUE INDEX IF NOT EXISTS book_reading_single ON book_reading(book_id,kind) WHERE kind IN ('source','progress','settings')",
    );
    await db.execute(
      "CREATE UNIQUE INDEX IF NOT EXISTS book_reading_link ON book_reading(book_id,json_extract(payload,'\$.origin'),json_extract(payload,'\$.targetKind')) WHERE kind='link'",
    );
    await db.execute(
      "CREATE INDEX IF NOT EXISTS book_reading_due ON book_reading(book_id,julianday(json_extract(payload,'\$.due'))) WHERE kind='card'",
    );
    await createSearch(db);
  }

  static Future<void> createSearch(DatabaseExecutor db) async {
    await db.execute(
      "CREATE VIRTUAL TABLE IF NOT EXISTS book_reading_search USING fts4(id,book_id,kind,body,notindexed=id,notindexed=book_id,notindexed=kind,tokenize=unicode61)",
    );
    const kinds = "('bookmark','highlight','annotation','card')";
    const body =
        "coalesce(json_extract(payload,'\$.front'),'') || char(10) || coalesce(json_extract(payload,'\$.back'),'') || char(10) || coalesce(json_extract(payload,'\$.text'),'') || char(10) || coalesce(json_extract(payload,'\$.note'),'') || char(10) || coalesce(json_extract(payload,'\$.explanation'),'') || char(10) || coalesce(json_extract(payload,'\$.tags'),'')";
    const select =
        "SELECT id,book_id,kind,$body FROM book_reading WHERE kind IN $kinds";
    await db.execute('DELETE FROM book_reading_search');
    await db.execute('INSERT INTO book_reading_search $select');
    for (final action in ['INSERT', 'UPDATE', 'DELETE']) {
      final owner = action == 'DELETE' ? 'old' : 'new';
      await db.execute(
        "CREATE TRIGGER IF NOT EXISTS reading_search_${action.toLowerCase()} AFTER $action ON book_reading WHEN $owner.kind IN $kinds BEGIN ${action == 'INSERT' ? '' : 'DELETE FROM book_reading_search WHERE id=old.id;'} ${action == 'DELETE' ? '' : 'INSERT INTO book_reading_search $select AND id=new.id;'} END",
      );
    }
  }

  static bool date(String s) => DateTime.tryParse(s) != null;
  static bool hash(Object? v) =>
      v is String && RegExp(r'^[0-9a-f]{64}$').hasMatch(v);
  static void location(dynamic value) {
    if (value is! Map) throw const FormatException('reading_location');
    if (value['kind'] == 'pdf') {
      if (value['page'] is! int ||
          value['page'] < 1 ||
          value['page'] > 1000000) {
        throw const FormatException('reading_page');
      }
      for (final k in ['y', 'zoom']) {
        final v = value[k];
        if (v != null &&
            (v is! num || !v.isFinite || v < 0 || v > (k == 'y' ? 1 : 16))) {
          throw const FormatException('reading_geometry');
        }
      }
    } else if (value['kind'] == 'text') {
      if (value['section'] is! String ||
          (value['section'] as String).length > 2048 ||
          value['block'] is! int ||
          value['block'] < 0 ||
          value['block'] > 1000000 ||
          value['offset'] is! int ||
          value['offset'] < 0 ||
          value['offset'] > 10000000) {
        throw const FormatException('reading_text_location');
      }
    } else {
      throw const FormatException('reading_location_kind');
    }
  }

  static void validate(String kind, Map<String, dynamic> p) {
    if (!kinds.contains(kind) ||
        p['v'] is! int ||
        p['v'] != 1 ||
        utf8.encode(jsonEncode(p)).length > 256 * 1024) {
      throw const FormatException('reading_data');
    }
    for (final entry in p.entries) {
      if (entry.value is String && (entry.value as String).length > 64000) {
        throw const FormatException('reading_text_large');
      }
    }
    if (p['location'] != null) location(p['location']);
    if (kind == 'source') {
      if (!{'pdf', 'epub', 'txt', 'html', 'fb2'}.contains(p['format']) ||
          !{'managed', 'reference'}.contains(p['mode']) ||
          !hash(p['hash']) ||
          p['size'] is! int ||
          p['size'] < 1 ||
          p['size'] > 1024 * 1024 * 1024 ||
          p['filename'] is! String ||
          (p['filename'] as String).length > 200 ||
          (p['mode'] == 'managed' && p['blob'] != p['hash']) ||
          (p['mode'] == 'reference' &&
              (p['uri'] is! String || !p['uri'].startsWith('content://'))) ||
          (p['pages'] != null &&
              (p['pages'] is! int || p['pages'] < 1 || p['pages'] > 1000000))) {
        throw const FormatException('reading_source');
      }
      if ((p['cover'] != null && !hash(p['cover'])) ||
          (p['index'] != null && !hash(p['index']))) {
        throw const FormatException('reading_cover');
      }
    }
    if (kind == 'progress') {
      location(p['location']);
      if (p['opened'] is! String ||
          !date(p['opened']) ||
          p['fraction'] is! num ||
          !p['fraction'].isFinite ||
          p['fraction'] < 0 ||
          p['fraction'] > 1) {
        throw const FormatException('reading_progress');
      }
    }
    if (kind == 'settings') {
      if (p['paged'] != null && p['paged'] is! bool) {
        throw const FormatException('reading_settings');
      }
      for (final item in {
        'font': (12, 40),
        'line': (1.0, 2.5),
        'margin': (8, 64),
      }.entries) {
        final n = p[item.key];
        if (n is! num ||
            !n.isFinite ||
            n < item.value.$1 ||
            n > item.value.$2) {
          throw const FormatException('reading_settings');
        }
      }
      if (!{'light', 'dark', 'sepia'}.contains(p['theme']) ||
          !{'sans', 'serif', 'mono'}.contains(p['family'])) {
        throw const FormatException('reading_settings');
      }
    }
    if ({'bookmark', 'highlight', 'annotation'}.contains(kind)) {
      location(p['location']);
      if (p['text'] is! String ||
          p['note'] is! String ||
          (p['color'] != null &&
              !{'yellow', 'green', 'blue', 'pink'}.contains(p['color'])) ||
          (p['end'] != null &&
              (p['end'] is! int || p['end'] < 0 || p['end'] > 10000000))) {
        throw const FormatException('reading_mark');
      }
    }
    if (p['rects'] != null) {
      final rs = p['rects'];
      if (kind != 'highlight' || rs is! List || rs.length > 5000) {
        throw const FormatException('reading_rects');
      }
      for (final r in rs) {
        if (r is! List ||
            r.length != 5 ||
            r[0] is! int ||
            r[0] < 1 ||
            r[0] > 1000000 ||
            r
                .skip(1)
                .any((n) => n is! num || !n.isFinite || n < 0 || n > 1000000) ||
            r[1] > r[3] ||
            r[2] < r[4]) {
          throw const FormatException('reading_rects');
        }
      }
    }
    if (kind == 'card') {
      if (!cardTypes.contains(p['type']) ||
          p['front'] is! String ||
          p['front'].trim().isEmpty ||
          p['back'] is! String ||
          (p['type'] == 'question' && (p['back'] as String).trim().isEmpty) ||
          p['explanation'] is! String ||
          p['tags'] is! List ||
          p['tags'].length > 50 ||
          p['tags'].any((v) => v is! String || v.length > 100) ||
          p['box'] is! int ||
          p['box'] < 0 ||
          p['box'] > 6 ||
          p['due'] is! String ||
          !date(p['due']) ||
          p['reviews'] is! int ||
          p['reviews'] < 0) {
        throw const FormatException('reading_card');
      }
    }
    if (kind == 'review') {
      if (p['card'] is! String ||
          p['rating'] is! int ||
          p['rating'] < 0 ||
          p['rating'] > 3 ||
          p['at'] is! String ||
          !date(p['at']) ||
          p['next'] is! String ||
          !date(p['next'])) {
        throw const FormatException('reading_review');
      }
    }
    if (kind == 'session') {
      if (p['day'] is! String ||
          !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(p['day']) ||
          !date(p['day'])) {
        throw const FormatException('reading_day');
      }
      if (p['start'] is! String ||
          !date(p['start']) ||
          p['end'] is! String ||
          !date(p['end']) ||
          DateTime.parse(p['end']).isBefore(DateTime.parse(p['start'])) ||
          p['seconds'] is! int ||
          p['seconds'] < 1 ||
          p['seconds'] > 86400 ||
          DateTime.parse(p['end'])
                      .difference(DateTime.parse(p['start']))
                      .inSeconds +
                  1 <
              p['seconds']) {
        throw const FormatException('reading_session');
      }
    }
    if (kind == 'link' && p['state'] == 'pending') {
      final draft = p['draft'];
      if (p['targetKind'] != 'todo' ||
          draft is! Map ||
          draft['title'] is! String ||
          draft['title'].trim().isEmpty ||
          draft['title'].length > 200 ||
          draft['body'] is! String ||
          draft['body'].length > 100000 ||
          (draft['due'] != null &&
              (draft['due'] is! String || !date(draft['due'])))) {
        throw const FormatException('reading_link_draft');
      }
    }
    if (kind == 'link' &&
        (!{'note', 'todo', 'habit', 'experience'}.contains(p['targetKind']) ||
            p['target'] is! String ||
            p['target'].isEmpty ||
            p['origin'] is! String ||
            !{'pending', 'ready'}.contains(p['state']))) {
      throw const FormatException('reading_link');
    }
  }

  static Map<String, dynamic> decode(Map<String, Object?> row) {
    if (row['id'] is! String ||
        (row['id'] as String).isEmpty ||
        row['book_id'] is! String ||
        row['kind'] is! String ||
        row['payload'] is! String ||
        row['revision'] is! int ||
        (row['revision'] as int) < 1 ||
        row['created_at'] is! String ||
        row['updated_at'] is! String ||
        !date(row['created_at'] as String) ||
        !date(row['updated_at'] as String)) {
      throw const FormatException('reading_row');
    }
    final p = Map<String, dynamic>.from(jsonDecode(row['payload'] as String));
    validate(row['kind'] as String, p);
    return p;
  }
}
