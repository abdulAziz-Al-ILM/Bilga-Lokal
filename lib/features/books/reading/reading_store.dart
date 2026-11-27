import '../../reminders/module_reminder_changes.dart';

import 'dart:convert';
import 'dart:io';

import 'package:sqflite/sqflite.dart';

import '../../notes/note_database.dart';
import '../../private_space/record_store.dart';
import 'reading_data.dart';
import '../../search/search_index.dart';
import 'book_vault.dart';

class ReadingRow {
  final String id, book, kind, created, updated;
  final int revision;
  final Map<String, dynamic> data;
  ReadingRow(Map<String, Object?> row)
    : id = row['id'] as String,
      book = row['book_id'] as String,
      kind = row['kind'] as String,
      revision = row['revision'] as int,
      created = row['created_at'] as String,
      updated = row['updated_at'] as String,
      data = ReadingData.decode(row);
}

class ReadingStore {
  final RecordStore records;
  final BookVault vault;
  final Directory? previewRoot;
  ReadingStore({
    RecordStore? records,
    this.vault = const AppBookVault(),
    this.previewRoot,
  }) : records = records ?? RecordStore();
  Future<Database> get db async =>
      records.database ?? await NoteDatabase.database;
  Future<List<ReadingRow>> rows(
    String book,
    String kind, {
    int limit = 1000,
    int offset = 0,
    String query = '',
  }) async {
    final expression = SearchIndex.expression(query);
    if (query.trim().isNotEmpty && expression.isEmpty) return [];
    final rows = await (await db).query(
      'book_reading',
      where:
          "book_id=? AND kind=? ${expression.isEmpty ? '' : 'AND id IN (SELECT id FROM book_reading_search WHERE book_reading_search MATCH ?)'}",
      whereArgs: [book, kind, if (expression.isNotEmpty) expression],
      orderBy: 'updated_at DESC,id',
      limit: limit.clamp(1, 5000),
      offset: offset,
    );
    return rows.map(ReadingRow.new).toList();
  }

  Future<List<ReadingRow>> due(String book, {DateTime? at}) async =>
      (await (await db).rawQuery(
        "SELECT * FROM book_reading WHERE book_id=? AND kind='card' AND json_extract(payload,'\$.type')='question' AND julianday(json_extract(payload,'\$.due'))<=julianday(?) ORDER BY julianday(json_extract(payload,'\$.due')),id LIMIT 100",
        [book, (at ?? DateTime.now()).toUtc().toIso8601String()],
      )).map(ReadingRow.new).toList();

  Stream<List<int>> export(String book, String title) async* {
    yield utf8.encode(
      '{"format":"bilga-reading-export","version":1,"book":${jsonEncode(title)},"rows":[',
    );
    var first = true;
    // Keyset traversal never silently truncates large collections.
    String after = '';
    while (true) {
      final batch = await (await db).query(
        'book_reading',
        where: 'book_id=? AND id>?',
        whereArgs: [book, after],
        orderBy: 'id',
        limit: 100,
      );
      if (batch.isEmpty) break;
      for (final raw in batch) {
        final r = ReadingRow(raw);
        if (!first) yield utf8.encode(',');
        first = false;
        yield utf8.encode(
          jsonEncode({
            'id': r.id,
            'kind': r.kind,
            'created': r.created,
            'updated': r.updated,
            'data': r.data,
          }),
        );
      }
      after = batch.last['id'] as String;
    }
    yield utf8.encode(']}');
  }

  Future<ReadingRow?> one(String book, String kind) async {
    final r = await rows(book, kind, limit: 1);
    return r.firstOrNull;
  }

  Future<ReadingRow> put(
    String book,
    String kind,
    Map<String, dynamic> data, {
    ReadingRow? previous,
    String? id,
  }) async {
    if (kind == 'review') throw StateError('reading_review_immutable');
    ReadingData.validate(kind, data);
    final stamp = DateTime.now().toUtc().toIso8601String();
    final row = <String, Object?>{
      'id': previous?.id ?? id ?? localId(),
      'book_id': book,
      'kind': kind,
      'payload': jsonEncode(data),
      'revision': (previous?.revision ?? 0) + 1,
      'created_at': previous?.created ?? stamp,
      'updated_at': stamp,
    };
    if (previous != null && (previous.book != book || previous.kind != kind)) {
      throw StateError('reading_owner');
    }
    await (await db).transaction((txn) async {
      if ((await txn.rawQuery(
        "SELECT 1 FROM private_records WHERE id=? AND kind='book'",
        [book],
      )).isEmpty) {
        throw StateError('book_missing');
      }
      if (previous == null) {
        await txn.insert('book_reading', row);
      } else if (await txn.update(
            'book_reading',
            row,
            where: 'id=? AND revision=?',
            whereArgs: [previous.id, previous.revision],
          ) !=
          1) {
        throw StateError('reading_changed');
      }
    });
    return ReadingRow(row);
  }

  Future<void> remove(ReadingRow row) async {
    if (row.kind == 'review') throw StateError('reading_review_immutable');
    if (await (await db).delete(
          'book_reading',
          where: 'id=? AND revision=?',
          whereArgs: [row.id, row.revision],
        ) !=
        1) {
      throw StateError('reading_changed');
    }
  }

  Future<void> progress(
    String book,
    Map<String, dynamic> location,
    double fraction,
  ) async {
    final old = await one(book, 'progress');
    await put(
      book,
      'progress',
      {
        'v': 1,
        'location': location,
        'fraction': fraction.clamp(0, 1),
        'opened': DateTime.now().toUtc().toIso8601String(),
      },
      previous: old,
      id: '$book-progress',
    );
  }

  /// Bounded Leitner intervals in calendar days. Again=tomorrow/reset; Hard
  /// retains box; Good advances one; Easy advances two. No retroactive edits.
  static Map<String, dynamic> schedule(
    Map<String, dynamic> card,
    int rating,
    DateTime now,
  ) {
    if (rating < 0 || rating > 3) throw ArgumentError('rating');
    final box = rating == 0
        ? 0
        : ((card['box'] as int) +
                  (rating == 1
                      ? 0
                      : rating == 2
                      ? 1
                      : 2))
              .clamp(0, 6);
    const days = [1, 2, 4, 7, 14, 30, 60];
    return {
      ...card,
      'box': box,
      'reviews': (card['reviews'] as int) + 1,
      'due': DateTime(
        now.year,
        now.month,
        now.day + days[box],
      ).toUtc().toIso8601String(),
    };
  }

  Future<void> review(ReadingRow card, int rating, {DateTime? at}) async {
    if (card.kind != 'card' || card.data['type'] != 'question') {
      throw StateError('not_flashcard');
    }
    final now = at ?? DateTime.now();
    final next = schedule(card.data, rating, now);
    ReadingData.validate('card', next);
    await (await db).transaction((txn) async {
      final stamp = now.toUtc().toIso8601String();
      if (await txn.update(
            'book_reading',
            {
              'payload': jsonEncode(next),
              'revision': card.revision + 1,
              'updated_at': stamp,
            },
            where: 'id=? AND book_id=? AND revision=?',
            whereArgs: [card.id, card.book, card.revision],
          ) !=
          1) {
        throw StateError('reading_changed');
      }
      final history = {
        'v': 1,
        'card': card.id,
        'rating': rating,
        'at': stamp,
        'next': next['due'],
        'front': card.data['front'],
        'back': card.data['back'],
        if (card.data['location'] is Map) 'location': card.data['location'],
        'previousBox': card.data['box'],
        'nextBox': next['box'],
      };
      ReadingData.validate('review', history);
      await txn.insert('book_reading', {
        'id': localId(),
        'book_id': card.book,
        'kind': 'review',
        'payload': jsonEncode(history),
        'revision': 1,
        'created_at': stamp,
        'updated_at': stamp,
      });
    });
    ModuleReminderChanges.committed();
  }

  Future<List<Map<String, Object?>>> activity({String? book}) async =>
      (await db).rawQuery('''
    SELECT json_extract(payload,'\$.day') AS day,
      SUM(json_extract(payload,'\$.seconds')) AS seconds, COUNT(*) AS sessions
    FROM book_reading WHERE kind='session' ${book == null ? '' : 'AND book_id=?'}
    GROUP BY day ORDER BY day DESC LIMIT 366''', book == null ? [] : [book]);
  Future<List<Map<String, Object?>>> duplicates(String digest) async =>
      (await db).rawQuery(
        '''
    SELECT p.id, json_extract(p.payload,'\$.title') AS title FROM book_reading r
    JOIN private_records p ON p.id=r.book_id WHERE r.kind='source'
    AND json_extract(r.payload,'\$.hash')=? ORDER BY p.created_at''',
        [digest],
      );
}
