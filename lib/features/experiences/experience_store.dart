import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../private_space/record_store.dart';
import '../modules/module_data.dart';
import '../notes/note_database.dart';
import '../search/search_index.dart';
import 'experience_model.dart';

class ExperienceStore {
  final RecordStore records;
  final Database? tasks;
  ExperienceStore({RecordStore? records, this.tasks})
    : records = records ?? RecordStore();
  Future<Database> get db async =>
      records.database ?? await NoteDatabase.database;
  static const dateSql =
      "coalesce(json_extract(p.payload,'\$.date'),date(p.created_at,'localtime'))";
  Future<List<Map<String, Object?>>> page({
    String query = '',
    String category = '',
    String tag = '',
    String status = '',
    bool favorites = false,
    String? from,
    String? until,
    int offset = 0,
    int limit = 50,
  }) async {
    if (offset < 0 || limit < 1 || limit > 100) throw ArgumentError('page');
    final args = <Object?>[];
    var where = "p.kind='experience'";
    final match = SearchIndex.expression(query);
    if (query.trim().isNotEmpty && match.isEmpty) return [];
    if (match.isNotEmpty) {
      where += ' AND p.id IN (SELECT id FROM bilga_search WHERE kind=\'experience\' AND bilga_search MATCH ?)';
      args.add(match);
    }
    if (category.isNotEmpty) {
      where += " AND coalesce(json_extract(p.payload,'\$.category'),'life')=?";
      args.add(category);
    }
    if (tag.isNotEmpty) {
      where += " AND EXISTS(SELECT 1 FROM json_each(p.payload,'\$.tags') WHERE value=?)";
      args.add(tag);
    }
    if (status.isNotEmpty) {
      where += " AND coalesce(json_extract(p.payload,'\$.status'),'active')=?";
      args.add(status);
    }
    if (favorites) where += " AND json_extract(p.payload,'\$.favorite')=1";
    if (from != null) {
      where += ' AND $dateSql>=?';
      args.add(from);
    }
    if (until != null) {
      where += ' AND $dateSql<?';
      args.add(until);
    }
    return (await db).rawQuery(
      '''SELECT p.id,p.revision,p.created_at,p.updated_at,
      json_extract(p.payload,'\$.title') AS title,$dateSql AS date,
      coalesce(json_extract(p.payload,'\$.category'),'life') AS category,
      coalesce(json_extract(p.payload,'\$.status'),'active') AS status,
      coalesce(json_extract(p.payload,'\$.favorite'),0) AS favorite,
      substr(coalesce(json_extract(p.payload,'\$.body'),''),1,220) AS excerpt
      FROM private_records p WHERE $where ORDER BY date DESC,p.created_at DESC,p.id LIMIT ? OFFSET ?''',
      [...args, limit, offset],
    );
  }

  Future<List<Map<String, Object?>>> history(String owner, {int offset = 0}) =>
      db.then(
        (d) => d.rawQuery(
          "SELECT id,module,kind,owner,created_at,json_extract(payload,'\$.entryRevision') AS entry_revision FROM module_data WHERE module='experience' AND kind='history' AND owner=? ORDER BY entry_revision DESC LIMIT 30 OFFSET ?",
          [owner, offset],
        ),
      );
  Future<PrivateRecord> restore(
    PrivateRecord current,
    Map<String, Object?> version,
  ) async {
    if (version['owner'] != current.id ||
        version['module'] != 'experience' ||
        version['kind'] != 'history') {
      throw StateError('history_owner');
    }
    final actual = await (await db).query(
      'module_data',
      where: 'id=?',
      whereArgs: [version['id']],
      limit: 1,
    );
    if (actual.isEmpty ||
        actual.single['owner'] != current.id ||
        actual.single['module'] != 'experience' ||
        actual.single['kind'] != 'history') {
      throw StateError('history_missing');
    }
    final data = ModuleData.decode(actual.single);
    return records.save(
      'experience',
      Map<String, dynamic>.from(data['snapshot']),
      previous: current,
    );
  }

  Future<Map<String, int>> summary() async {
    final r = (await (await db).rawQuery("""SELECT count(*) AS total,
      sum(json_extract(payload,'\$.status')='completed') AS completed,
      sum(length(trim(coalesce(json_extract(payload,'\$.lesson'),'')))>0 OR length(trim(coalesce(json_extract(payload,'\$.conclusions'),'')))>0) AS reflections,
      sum(json_extract(payload,'\$.mode')='experiment') AS experiments,
      count(DISTINCT coalesce(json_extract(payload,'\$.date'),date(created_at,'localtime'))) AS days
      FROM private_records WHERE kind='experience'""")).single;
    return {for (final e in r.entries) e.key: (e.value as num?)?.toInt() ?? 0};
  }

  Future<Map<String, int>> month(DateTime month) async {
    final from = ExperienceModel.day(DateTime(month.year, month.month));
    final until = ExperienceModel.day(DateTime(month.year, month.month + 1));
    final rows = await (await db).rawQuery(
      "SELECT $dateSql AS day,count(*) AS total FROM private_records p WHERE p.kind='experience' AND $dateSql>=? AND $dateSql<? GROUP BY day",
      [from, until],
    );
    return {for (final r in rows) r['day'] as String: r['total'] as int};
  }

  Future<Map<String, String>> categories() async {
    final rows = await (await db).query(
      'module_data',
      where: "module='experience' AND kind='category'",
      orderBy: 'created_at',
    );
    return {
      for (final r in rows)
        r['id'] as String: ModuleData.decode(r)['name'] as String,
    };
  }

  Future<String> addCategory(String name) async {
    final data = {'name': name.trim()};
    ModuleData.validate('experience', 'category', data);
    final id = 'custom:${localId()}',
        stamp = DateTime.now().toUtc().toIso8601String();
    await (await db).insert('module_data', {
      'id': id,
      'module': 'experience',
      'kind': 'category',
      'owner': '',
      'payload': jsonEncode(data),
      'revision': 1,
      'created_at': stamp,
      'updated_at': stamp,
    });
    return id;
  }

  Future<List<String>> tags() async => (await (await db).rawQuery(
    "SELECT DISTINCT j.value AS tag FROM private_records p,json_each(p.payload,'\$.tags') j WHERE p.kind='experience' ORDER BY tag LIMIT 300",
  )).map((r) => r['tag'] as String).toList();
}
