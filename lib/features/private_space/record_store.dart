import 'dart:convert';
import 'dart:math';

import 'package:sqflite/sqflite.dart';

import '../notes/note_database.dart';
import '../finance/ledger.dart';
import '../books/book_library.dart';

String localId() => List.generate(
  24,
  (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
).join();

class PrivateRecord {
  final String id, kind;
  final int revision;
  final Map<String, dynamic> data;
  PrivateRecord(this.id, this.kind, this.revision, this.data);
  factory PrivateRecord.row(Map<String, Object?> r) => PrivateRecord(
    r['id'] as String,
    r['kind'] as String,
    r['revision'] as int,
    jsonDecode(r['payload'] as String),
  );
}

class RecordStore {
  final Database? database;
  RecordStore({this.database});
  Future<Database> get _db async => database ?? await NoteDatabase.database;
  static const kinds = {'experience', 'book', 'finance', 'attachment'};
  static void validate(String kind, Map<String, dynamic> data) {
    if (!kinds.contains(kind) ||
        data['title'] is! String ||
        (data['title'] as String).trim().isEmpty ||
        (data['title'] as String).length > 200 ||
        utf8.encode(jsonEncode(data)).length > 4 * 1024 * 1024) {
      throw const FormatException('record');
    }
    if (kind == 'finance') Ledger.validate(data);
    if (kind == 'experience') {
      if (!{
        'work',
        'life',
        'feelings',
        'gratitude',
        'spiritual',
        'lesson',
      }.contains(data['category'] ?? 'life')) {
        throw const FormatException('category');
      }
      for (final k in ['body', 'feelings', 'lesson', 'next']) {
        if (data[k] != null &&
            (data[k] is! String || (data[k] as String).length > 100000)) {
          throw const FormatException('experience');
        }
      }
    }
    if (kind == 'book') {
      BookLibrary.validate(data);
      if (data['bookmark'] != null &&
          (data['bookmark'] is! int || data['bookmark'] < 0)) {
        throw const FormatException('bookmark');
      }
      if (data['chapters'] is! List ||
          (data['chapters'] as List).length > 2000 ||
          (data['characters'] != null && data['characters'] is! String)) {
        throw const FormatException('book');
      }
      final trash = data['chapterTrash'] ?? [];
      if (trash is! List) throw const FormatException('chapter_trash');
      for (final c in [...data['chapters'], ...trash]) {
        if (c is! Map ||
            c['title'] is! String ||
            c['body'] is! String ||
            (c['versions'] != null && c['versions'] is! List)) {
          throw const FormatException('chapter');
        }
        for (final v in c['versions'] ?? []) {
          if (v is! Map ||
              v['title'] is! String ||
              v['body'] is! String ||
              v['date'] is! String) {
            throw const FormatException('revision');
          }
        }
      }
    }
    if (kind == 'attachment') {
      if (!{
            'note',
            'todo',
            'habit',
            'experience',
            'book',
            'finance',
          }.contains(data['ownerKind']) ||
          data['owner'] is! String ||
          (data['owner'] as String).isEmpty) {
        throw const FormatException('owner');
      }
      if (data['blob'] != null &&
          (!RegExp(r'^[0-9a-f]{64}$').hasMatch('${data['blob']}') ||
              data['size'] is! int ||
              data['size'] < 0 ||
              data['size'] > 1024 * 1024 * 1024)) {
        throw const FormatException('blob');
      }
      if (data['blob'] == null &&
          (data['text'] is! String ||
              (data['text'] as String).length > 100000)) {
        throw const FormatException('attachment');
      }
    }
  }

  Future<List<PrivateRecord>> all(String kind) async =>
      (await (await _db).query(
        'private_records',
        where: 'kind = ?',
        whereArgs: [kind],
        orderBy: 'updated_at DESC',
      )).map(PrivateRecord.row).toList();
  Future<PrivateRecord> get(String id) async {
    final rows = await (await _db).query(
      'private_records',
      where: 'id=?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) throw StateError('record_missing');
    final record = PrivateRecord.row(rows.single);
    validate(record.kind, record.data);
    return record;
  }

  Future<List<PrivateRecord>> attachments(String kind, String owner) async =>
      (await (await _db).query(
        'private_records',
        where: "kind = ? AND json_extract(payload, '\$.ownerKind') = ? AND json_extract(payload, '\$.owner') = ?",
        whereArgs: ['attachment', kind, owner],
      )).map(PrivateRecord.row).toList();

  Future<bool> hasAttachmentBlob(String blob) async =>
      (await (await _db).rawQuery(
        "SELECT 1 FROM private_records WHERE kind = 'attachment' AND json_extract(payload, '\$.blob') = ? LIMIT 1",
        [blob],
      )).isNotEmpty;

  Future<PrivateRecord> save(
    String kind,
    Map<String, dynamic> data, {
    PrivateRecord? previous,
  }) async {
    validate(kind, data);
    if (previous != null && previous.kind != kind) {
      throw StateError('record_kind');
    }
    final db = await _db, stamp = DateTime.now().toUtc().toIso8601String();
    final id = previous?.id ?? localId(), rev = (previous?.revision ?? 0) + 1;
    final row = {
      'id': id,
      'kind': kind,
      'payload': jsonEncode(data),
      'revision': rev,
      'updated_at': stamp,
    };
    if (previous == null) {
      await db.insert('private_records', {...row, 'created_at': stamp});
    } else {
      if (await db.update(
            'private_records',
            row,
            where: 'id = ? AND revision = ?',
            whereArgs: [id, previous.revision],
          ) !=
          1) {
        throw StateError('record_changed');
      }
    }
    return PrivateRecord(id, kind, rev, Map.from(data));
  }

  Future<void> remove(PrivateRecord r) async {
    await (await _db).transaction((txn) async {
      if (await txn.delete(
            'private_records',
            where: 'id=? AND revision=?',
            whereArgs: [r.id, r.revision],
          ) !=
          1) {
        throw StateError('record_changed');
      }
      if (r.kind == 'book') {
        // Remove owned metadata with the book. Content-addressed encrypted files
        // can be shared by other records, so their physical deletion is deferred.
        await txn.delete(
          'private_records',
          where: "kind='attachment' AND json_extract(payload,'\$.ownerKind')='book' AND json_extract(payload,'\$.owner')=?",
          whereArgs: [r.id],
        );
      }
    });
  }
}
