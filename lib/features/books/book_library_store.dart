import 'package:sqflite/sqflite.dart';

import '../notes/note_database.dart';
import '../private_space/record_store.dart';
import '../search/search_index.dart';
import 'book_library.dart';

class BookSummary {
  final String? format, cover, opened;
  final double? progress;
  final String id, title, author, status, updated, description;
  final int revision, chapters, currentPage;
  final int? pages, rating;
  final bool favorite;
  BookSummary._(
    this.id,
    this.title,
    this.author,
    this.status,
    this.updated,
    this.description,
    this.revision,
    this.chapters,
    this.currentPage,
    this.pages,
    this.rating,
    this.favorite,
    this.format,
    this.cover,
    this.opened,
    this.progress,
  );
  factory BookSummary.row(Map<String, Object?> row) {
    final version = row['library_version'];
    if ((version != null || row['library_type'] != null) &&
        (version is! int || version != 1 || row['library_type'] != 'object')) {
      throw const FormatException('book_library_version');
    }
    final status = row['status'] as String;
    if (!BookLibrary.statuses.contains(status)) {
      throw const FormatException('book_status');
    }
    return BookSummary._(
      row['id'] as String,
      row['title'] as String,
      row['author'] as String,
      status,
      row['updated_at'] as String,
      row['description'] as String,
      row['revision'] as int,
      row['chapters'] as int,
      row['current_page'] as int,
      row['pages'] as int?,
      row['rating'] as int?,
      row['favorite'] == 1,
      row['source_format'] as String?,
      row['cover'] as String?,
      row['opened'] as String?,
      (row['progress'] as num?)?.toDouble(),
    );
  }
}

/// Paged, thin projections avoid loading all chapter text/history into memory
/// when browsing a library. The full record is loaded only when opening/editing.
class BookLibraryStore {
  final RecordStore records;
  BookLibraryStore({RecordStore? records}) : records = records ?? RecordStore();
  Future<Database> get database async =>
      records.database ?? await NoteDatabase.database;
  Future<List<BookSummary>> page({
    String query = '',
    String? status,
    bool favoritesOnly = false,
    String? shelf,
    String? tag,
    String? category,
    String sort = 'updated',
    int offset = 0,
    int limit = 50,
  }) async {
    if (offset < 0 ||
        limit < 1 ||
        limit > 100 ||
        (status != null && !BookLibrary.statuses.contains(status)) ||
        !{'updated', 'title', 'author', 'opened', 'added'}.contains(sort)) {
      throw ArgumentError('book_page');
    }
    final where = <String>["kind='book'"], args = <Object?>[];
    if (query.trim().isNotEmpty) {
      final expression = SearchIndex.expression(query);
      if (expression.isEmpty) return [];
      where.add(
        "id IN (SELECT id FROM bilga_search WHERE kind='book' AND bilga_search MATCH ?)",
      );
      args.add(expression);
    }
    if (status != null) {
      where.add(
        "coalesce(json_extract(payload,'\$.library.status'),'unspecified')=?",
      );
      args.add(status);
    }
    if (favoritesOnly) {
      where.add("coalesce(json_extract(payload,'\$.library.favorite'),0)=1");
    }
    for (final filter in [
      ('shelves', shelf),
      ('tags', tag),
      ('categories', category),
    ]) {
      if (filter.$2 != null) {
        where.add(
          "EXISTS(SELECT 1 FROM json_each(payload,'\$.library.${filter.$1}') WHERE value=?)",
        );
        args.add(filter.$2);
      }
    }
    final order = switch (sort) {
      'opened' => "(SELECT json_extract(r.payload,'\$.opened') FROM book_reading r WHERE r.book_id=private_records.id AND r.kind='progress' LIMIT 1) DESC,updated_at DESC,id",
      'added' => 'created_at DESC,id',
      'title' => "json_extract(payload,'\$.title') COLLATE NOCASE ASC,updated_at DESC,id",
      'author' => "coalesce(json_extract(payload,'\$.library.author'),'') COLLATE NOCASE ASC,updated_at DESC,id",
      _ => 'updated_at DESC,id',
    };
    final rows = await (await database).rawQuery(
      '''SELECT id,revision,updated_at,
      json_extract(payload,'\$.title') AS title,
      json_extract(payload,'\$.libraryVersion') AS library_version,
      json_type(payload,'\$.library') AS library_type,
      coalesce(json_extract(payload,'\$.library.author'),'') AS author,
      substr(coalesce(json_extract(payload,'\$.library.description'),''),1,241) AS description,
      coalesce(json_extract(payload,'\$.library.status'),'unspecified') AS status,
      coalesce(json_extract(payload,'\$.library.favorite'),0) AS favorite,
      coalesce((SELECT json_extract(r.payload,'\$.location.page') FROM book_reading r WHERE r.book_id=private_records.id AND r.kind='progress' LIMIT 1),json_extract(payload,'\$.library.currentPage'),0) AS current_page,
      json_extract(payload,'\$.library.pages') AS pages,
      json_extract(payload,'\$.library.rating') AS rating,
      json_array_length(payload,'\$.chapters') AS chapters,
      (SELECT json_extract(r.payload,'\$.format') FROM book_reading r WHERE r.book_id=private_records.id AND r.kind='source' LIMIT 1) AS source_format,
      (SELECT json_extract(r.payload,'\$.cover') FROM book_reading r WHERE r.book_id=private_records.id AND r.kind='source' LIMIT 1) AS cover,
      (SELECT json_extract(r.payload,'\$.opened') FROM book_reading r WHERE r.book_id=private_records.id AND r.kind='progress' LIMIT 1) AS opened,
      (SELECT json_extract(r.payload,'\$.fraction') FROM book_reading r WHERE r.book_id=private_records.id AND r.kind='progress' LIMIT 1) AS progress
      FROM private_records WHERE ${where.join(' AND ')} ORDER BY $order LIMIT ? OFFSET ?''',
      [...args, limit, offset],
    );
    return rows.map(BookSummary.row).toList();
  }

  Future<Map<String, List<String>>> filters() async {
    final result = <String, List<String>>{};
    for (final field in ['shelves', 'tags', 'categories']) {
      final rows = await (await database).rawQuery(
        "SELECT DISTINCT value FROM private_records,json_each(payload,'\$.library.$field') WHERE kind='book' ORDER BY value COLLATE NOCASE",
      );
      result[field] = [for (final row in rows) row['value'] as String];
    }
    return result;
  }

  Future<PrivateRecord> load(String id) async {
    final rows = await (await database).query(
      'private_records',
      where: 'id=? AND kind=?',
      whereArgs: [id, 'book'],
      limit: 1,
    );
    if (rows.isEmpty) throw StateError('book_missing');
    final record = PrivateRecord.row(rows.single);
    RecordStore.validate('book', record.data);
    return record;
  }
}
