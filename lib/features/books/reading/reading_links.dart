import '../../modules/module_data.dart';

import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../notes/note_model.dart';
import '../../notes/notes_changes.dart';
import '../../todo/todo_model.dart';
import '../../todo/todo_database.dart';
import '../../todo/todo_changes.dart';
import '../../habits/habit_plan.dart';
import '../../private_space/record_store.dart';
import 'reading_data.dart';
import 'reading_store.dart';

/// A confirmed source/action pair creates one stable target. Tasks live in a
/// separate database, so a durable pending link makes interrupted retries safe.
class ReadingLinks {
  final ReadingStore store;
  final Database? todos;
  ReadingLinks(this.store, {this.todos});
  Future<ReadingRow?> existing(
    String book,
    String origin,
    String targetKind,
  ) async {
    final rows = await (await store.db).rawQuery(
      "SELECT * FROM book_reading WHERE book_id=? AND kind='link' AND json_extract(payload,'\$.origin')=? AND json_extract(payload,'\$.targetKind')=? LIMIT 1",
      [book, origin, targetKind],
    );
    return rows.isEmpty ? null : ReadingRow(rows.single);
  }

  Future<ReadingRow> create({
    required String book,
    required String origin,
    required String kind,
    required String title,
    required String body,
    required bool Function() allowed,
    DateTime? due,
    HabitPlan? plan,
  }) async {
    if (!{'note', 'todo', 'habit', 'experience'}.contains(kind) ||
        title.trim().isEmpty ||
        title.length > 200 ||
        body.length > 100000) {
      throw const FormatException('reading_link');
    }
    if (!allowed()) throw StateError('access_expired');
    final now = DateTime.now(),
        stamp = DateTime.now().toUtc().toIso8601String();
    ReadingRow? link;
    await (await store.db).transaction((txn) async {
      final rows = await txn.rawQuery(
        "SELECT * FROM book_reading WHERE book_id=? AND kind='link' AND json_extract(payload,'\$.origin')=? AND json_extract(payload,'\$.targetKind')=? LIMIT 1",
        [book, origin, kind],
      );
      if (rows.isNotEmpty) {
        link = ReadingRow(rows.single);
        return;
      }
      final target = localId();
      final data = {
        'v': 1,
        'origin': origin,
        'targetKind': kind,
        'target': target,
        'state': kind == 'todo' ? 'pending' : 'ready',
        if (kind == 'todo')
          'draft': {
            'title': title,
            'body': body,
            'due': due?.toIso8601String(),
          },
      };
      ReadingData.validate('link', data);
      if (!allowed()) throw StateError('access_expired');
      if (kind == 'note') {
        await txn.insert(
          'notes',
          Note(
            id: target,
            title: title,
            body: body,
            createdAt: now,
            updatedAt: now,
          ).toMap(),
        );
      } else if (kind == 'habit') {
        if (body.length > 1800) throw const FormatException('habit_reason');
        final base = plan ?? HabitPlan(target: 15, unit: 'min');
        final p = HabitPlan.decode(
          jsonEncode({
            ...jsonDecode(base.encode()) as Map<String, dynamic>,
            'reason': body.isEmpty ? base.reason : body,
          }),
        );
        HabitPlan.decode(p.encode());
        await txn.insert('habits', {
          'id': target,
          'title': title,
          'days': '[]',
          'details': p.encode(),
          'is_archived': 0,
          'created_at': stamp,
          'updated_at': stamp,
        });
      } else if (kind == 'experience') {
        final record = {
          'title': title,
          'category': 'lesson',
          'body': body,
          'lesson': '',
          'next': '',
        };
        RecordStore.validate('experience', record);
        await txn.insert('private_records', {
          'id': target,
          'kind': 'experience',
          'payload': jsonEncode(record),
          'revision': 1,
          'created_at': stamp,
          'updated_at': stamp,
        });
        await ModuleData.history(txn, target, 1, record, stamp);
      }
      final row = {
        'id': localId(),
        'book_id': book,
        'kind': 'link',
        'payload': jsonEncode(data),
        'revision': 1,
        'created_at': stamp,
        'updated_at': stamp,
      };
      await txn.insert('book_reading', row);
      link = ReadingRow(row);
    });
    var result = link!;
    if (kind == 'todo' && result.data['state'] == 'pending') {
      if (!allowed()) throw StateError('access_expired');
      final draft = Map<String, dynamic>.from(result.data['draft']);
      final tasks = todos ?? await TodoDatabase.database;
      await tasks.transaction((txn) async {
        final rows = await txn.query(
          'todos',
          where: 'id=?',
          whereArgs: [result.data['target']],
          limit: 1,
        );
        if (rows.isEmpty) {
          await txn.insert(
            'todos',
            Todo(
              id: result.data['target'],
              title: draft['title'],
              isDone: false,
              createdAt: now,
              updatedAt: now,
              dueAt: DateTime.tryParse(draft['due'] ?? ''),
            ).toMap()..['description'] = draft['body'] ?? '',
          );
        }
      });
      TodoChanges.committed();
      result = await store.put(
        book,
        'link',
        {...result.data, 'state': 'ready'}..remove('draft'),
        previous: result,
      );
    }
    if (kind == 'note') NotesChanges.committed();
    return result;
  }
}
