import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../modules/module_data.dart';
import '../private_space/record_store.dart';
import '../todo/todo_database.dart';
import '../todo/todo_model.dart';
import '../todo/todo_changes.dart';
import 'experience_store.dart';

class ExperienceLinks {
  final ExperienceStore store;
  final Database? tasks;
  ExperienceLinks(this.store, {this.tasks});
  Future<List<Map<String, Object?>>> all(String owner) => store.db.then(
    (db) => db.query(
      'module_data',
      where: "module='experience' AND kind='link' AND owner=?",
      whereArgs: [owner],
      orderBy: 'created_at',
    ),
  );
  Future<String> task(
    PrivateRecord entry, {
    required String title,
    required String body,
    DateTime? due,
    required bool Function() allowed,
  }) async {
    if (!allowed()) throw StateError('access_expired');
    late Map<String, Object?> link;
    final stamp = DateTime.now().toUtc().toIso8601String();
    final db = await store.db;
    await db.transaction((txn) async {
      if (!allowed()) throw StateError('access_expired');
      if ((await txn.query(
        'private_records',
        columns: ['id'],
        where: "id=? AND kind='experience'",
        whereArgs: [entry.id],
      )).isEmpty) {
        throw StateError('experience_missing');
      }
      final old = await txn.rawQuery(
        "SELECT * FROM module_data WHERE module='experience' AND kind='link' AND owner=? AND json_extract(payload,'\$.action')='followup' AND json_extract(payload,'\$.targetKind')='todo' LIMIT 1",
        [entry.id],
      );
      if (old.isNotEmpty) {
        link = old.single;
        return;
      }
      final data = {
        'targetKind': 'todo',
        'target': localId(),
        'action': 'followup',
        'state': 'pending',
        'draft': {
          'title': title.trim(),
          'body': body,
          'due': due?.toIso8601String(),
        },
      };
      ModuleData.validate('experience', 'link', data);
      link = {
        'id': localId(),
        'module': 'experience',
        'kind': 'link',
        'owner': entry.id,
        'payload': jsonEncode(data),
        'revision': 1,
        'created_at': stamp,
        'updated_at': stamp,
      };
      await txn.insert('module_data', link);
    });
    final data = ModuleData.decode(link);
    if (data['state'] == 'ready') return data['target'];
    if (!allowed()) throw StateError('access_expired');
    final draft = Map<String, dynamic>.from(data['draft']);
    await (tasks ?? store.tasks ?? await TodoDatabase.database).transaction((
      txn,
    ) async {
      if (!allowed()) throw StateError('access_expired');
      final existing = await txn.query(
        'todos',
        where: 'id=?',
        whereArgs: [data['target']],
        limit: 1,
      );
      if (existing.isEmpty) {
        final now = DateTime.now();
        await txn.insert(
          'todos',
          Todo(
            id: data['target'],
            title: draft['title'],
            isDone: false,
            createdAt: now,
            updatedAt: now,
            dueAt: DateTime.tryParse(draft['due'] ?? ''),
          ).toMap()..['description'] = draft['body'],
        );
      }
    });
    TodoChanges.committed();
    final done = {...data, 'state': 'ready'}..remove('draft');
    await db.update(
      'module_data',
      {
        'payload': jsonEncode(done),
        'revision': (link['revision'] as int) + 1,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id=? AND revision=?',
      whereArgs: [link['id'], link['revision']],
    );
    return data['target'];
  }

  Future<void> attach(
    String owner,
    String kind,
    String target, {
    required bool Function() allowed,
  }) async {
    if (!['note', 'book', 'habit'].contains(kind)) {
      throw const FormatException('link_kind');
    }
    await (await store.db).transaction((txn) async {
      if (!allowed()) throw StateError('access_expired');
      final table = kind == 'note'
          ? 'notes'
          : kind == 'habit'
          ? 'habits'
          : 'private_records';
      final rows = await txn.query(
        table,
        columns: ['id'],
        where: kind == 'book'
            ? "id=? AND kind='book'"
            : kind == 'note'
            ? 'id=? AND is_deleted=0'
            : 'id=?',
        whereArgs: [target],
        limit: 1,
      );
      if (rows.isEmpty) throw StateError('link_target_missing');
      final entry = await txn.query(
        'private_records',
        columns: ['id'],
        where: "id=? AND kind='experience'",
        whereArgs: [owner],
        limit: 1,
      );
      if (entry.isEmpty) throw StateError('experience_missing');
      final data = {
        'targetKind': kind,
        'target': target,
        'action': 'attach:$kind:$target',
        'state': 'ready',
      };
      ModuleData.validate('experience', 'link', data);
      final stamp = DateTime.now().toUtc().toIso8601String();
      await txn.insert('module_data', {
        'id': localId(),
        'module': 'experience',
        'kind': 'link',
        'owner': owner,
        'payload': jsonEncode(data),
        'revision': 1,
        'created_at': stamp,
        'updated_at': stamp,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    });
  }
}
