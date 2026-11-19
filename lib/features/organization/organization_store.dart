import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../private_space/record_store.dart' show localId;
import '../notes/note_database.dart';

typedef FolderItem = ({String id, String title, String entry, String subtitle});

class RecordFolder {
  final String id, name, parent, icon, updated;
  final int color, count;
  final bool deleted;

  RecordFolder(Map<String, Object?> row, Map data, this.count)
    : id = row['id'] as String,
      name = data['name'] as String,
      parent = data['parent'] as String,
      icon = data['icon'] as String,
      updated = row['updated_at'] as String,
      color = data['color'] as int,
      deleted = data['deleted'] as bool;
}

/// Module folders and their references live beside existing encrypted records.
/// Finance references a ledger and entry ID, keeping transaction bytes intact.
class OrganizationStore {
  static const modules = {'habit', 'finance', 'experience', 'book'};
  static const icons = ['folder', 'work', 'study', 'heart', 'book'];
  final String module;
  final Database? provided;
  OrganizationStore(this.module, {this.provided}) {
    if (!modules.contains(module)) throw ArgumentError.value(module);
  }
  Future<Database> get db async => provided ?? await NoteDatabase.database;

  static Future<void> upgrade(DatabaseExecutor db) async {
    await db.execute('''
      CREATE UNIQUE INDEX IF NOT EXISTS module_folder_membership
      ON module_data(module, owner, json_extract(payload,'\$.folder'),
        json_extract(payload,'\$.entry')) WHERE kind='folder_item'
    ''');
    await importShelves(db);
  }

  /// Convert all legacy shelf memberships, including books on several shelves.
  /// Keep the original metadata bytes readable for old exports and history.
  static Future<void> importShelves(
    DatabaseExecutor db, {
    String? prefix,
  }) async {
    final shelves = await db.rawQuery('''
      SELECT r.id, trim(s.value) AS name FROM private_records r
      JOIN json_each(r.payload, '\$.library.shelves') s
      WHERE r.kind='book' AND s.type='text' AND trim(s.value) != ''
      ${prefix == null ? '' : "AND substr(r.id,1,?)=?"}
      ORDER BY r.id, s.key
    ''', prefix == null ? [] : [prefix.length, prefix]);
    if (shelves.isEmpty) return;
    final ids = <String, String>{};
    final stamp = DateTime.now().toUtc().toIso8601String();
    final batch = db.batch();
    for (final shelf in shelves) {
      final name = shelf['name'] as String;
      final id = ids.putIfAbsent(name.toLowerCase(), () {
        final id = localId();
        batch.insert(
          'module_data',
          _row(id, 'book', 'folder', '', stamp, {
            'name': name,
            'parent': '',
            'deleted': false,
            'icon': 'book',
            'color': 0,
          }),
        );
        return id;
      });
      batch.insert(
        'module_data',
        _row(localId(), 'book', 'folder_item', shelf['id'] as String, stamp, {
          'folder': id,
          'entry': '',
        }),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
    await batch.commit(noResult: true);
  }

  static Map<String, Object?> _row(
    String id,
    String module,
    String kind,
    String owner,
    String stamp,
    Map data,
  ) => {
    'id': id,
    'module': module,
    'kind': kind,
    'owner': owner,
    'payload': jsonEncode(data),
    'revision': 1,
    'created_at': stamp,
    'updated_at': stamp,
  };

  static Map<String, dynamic> data(Map<String, Object?> row) =>
      Map<String, dynamic>.from(jsonDecode(row['payload'] as String) as Map);

  Future<List<RecordFolder>> folders() async {
    final rows = await (await db).rawQuery(
      '''
      SELECT f.*, (SELECT COUNT(*) FROM module_data m
        WHERE m.module=f.module AND m.kind='folder_item'
        AND json_extract(m.payload,'\$.folder')=f.id) AS items
      FROM module_data f WHERE f.module=? AND f.kind='folder'
    ''',
      [module],
    );
    return [
      for (final row in rows) RecordFolder(row, data(row), row['items'] as int),
    ];
  }

  Future<void> saveFolder(
    String name, {
    String? id,
    String parent = '',
    String icon = 'folder',
    int color = 0,
    bool deleted = false,
    required bool Function() allowed,
  }) async {
    name = name.trim();
    if (name.isEmpty ||
        name.length > 100 ||
        !icons.contains(icon) ||
        color < 0 ||
        color > 5) {
      throw const FormatException('folder');
    }
    await (await db).transaction((txn) async {
      if (!allowed()) throw StateError('access_expired');
      final rows = await txn.query(
        'module_data',
        where: "module=? AND kind='folder'",
        whereArgs: [module],
      );
      final byId = {for (final row in rows) row['id'] as String: data(row)};
      if (id != null && !byId.containsKey(id)) {
        throw StateError('folder_missing');
      }
      final seen = <String>{?id};
      var ancestor = parent;
      while (ancestor.isNotEmpty) {
        final folder = byId[ancestor];
        if (!seen.add(ancestor) ||
            folder == null ||
            (!deleted && folder['deleted'] == true)) {
          throw StateError('folder_parent');
        }
        ancestor = folder['parent'] as String;
      }
      if (!deleted &&
          byId.entries.any(
            (e) =>
                e.key != id &&
                e.value['deleted'] == false &&
                e.value['parent'] == parent &&
                (e.value['name'] as String).toLowerCase() == name.toLowerCase(),
          )) {
        throw StateError('folder_name_exists');
      }
      final row = _row(
        id ?? localId(),
        module,
        'folder',
        '',
        DateTime.now().toUtc().toIso8601String(),
        {
          'name': name,
          'parent': parent,
          'icon': icon,
          'color': color,
          'deleted': deleted,
        },
      );
      if (id == null) {
        await txn.insert('module_data', row);
      } else {
        await txn.update(
          'module_data',
          {'payload': row['payload'], 'updated_at': row['updated_at']},
          where: 'id=?',
          whereArgs: [id],
        );
      }
    });
  }

  Future<List<FolderItem>> items({
    required String? folder,
    required String query,
    int offset = 0,
    String? ledger,
  }) async {
    final db = await this.db;
    final title = switch (module) {
      'habit' => 'r.title',
      'finance' => "coalesce(nullif(json_extract(e.value,'\$.party'),''),nullif(json_extract(e.value,'\$.description'),''),nullif(json_extract(e.value,'\$.category'),''),json_extract(e.value,'\$.date'))",
      _ => "json_extract(r.payload,'\$.title')",
    };
    final entry = module == 'finance' ? "json_extract(e.value,'\$.id')" : "''";
    final subtitle = module == 'finance'
        ? "json_extract(r.payload,'\$.title') || ' · ' || json_extract(e.value,'\$.date')"
        : "''";
    final from = module == 'habit'
        ? 'habits r'
        : module == 'finance'
        ? "private_records r JOIN json_each(r.payload,'\$.entries') e"
        : 'private_records r';
    final membership = """SELECT 1 FROM module_data m
      WHERE m.module=? AND m.kind='folder_item' AND m.owner=r.id
        AND json_extract(m.payload,'\$.entry')=$entry""";
    final sql =
        '''
      SELECT r.id,$title AS title,$entry AS entry,$subtitle AS subtitle FROM $from
      WHERE ${module == 'habit' ? '1=1' : 'r.kind=?'}
      ${ledger == null ? '' : 'AND r.id=?'}
      AND instr(lower($title || ' ' || $subtitle),lower(?))>0
      ${folder == null
            ? ''
            : folder.isEmpty
            ? "AND NOT EXISTS($membership AND EXISTS(SELECT 1 FROM module_data f WHERE f.id=json_extract(m.payload,'\$.folder') AND json_extract(f.payload,'\$.deleted')=0))"
            : "AND EXISTS($membership AND json_extract(m.payload,'\$.folder')=?)"}
      ORDER BY title COLLATE NOCASE,r.id,entry LIMIT 51 OFFSET ?
    ''';
    final rows = await db.rawQuery(sql, [
      if (module != 'habit') module,
      ?ledger,
      query.trim(),
      if (folder != null) module,
      if (folder != null && folder.isNotEmpty) folder,
      offset,
    ]);
    return [
      for (final row in rows)
        (
          id: row['id'] as String,
          title: row['title'] as String,
          entry: row['entry'] as String,
          subtitle: row['subtitle'] as String,
        ),
    ];
  }

  Future<void> move(
    FolderItem item,
    String destination, {
    String? from,
    required bool Function() allowed,
  }) async {
    await (await db).transaction((txn) async {
      if (!allowed()) throw StateError('access_expired');
      final ownerRows = await txn.query(
        module == 'habit' ? 'habits' : 'private_records',
        columns: [module == 'finance' ? 'payload' : 'id'],
        where: module == 'habit' ? 'id=?' : 'id=? AND kind=?',
        whereArgs: [item.id, if (module != 'habit') module],
      );
      if (ownerRows.isEmpty ||
          module == 'finance' &&
              !(jsonDecode(ownerRows.single['payload'] as String)['entries']
                      as List)
                  .any((e) => e['id'] == item.entry)) {
        throw StateError('folder_item_missing');
      }
      var ancestor = destination;
      final seen = <String>{};
      while (ancestor.isNotEmpty) {
        final rows = await txn.query(
          'module_data',
          where: "id=? AND module=? AND kind='folder'",
          whereArgs: [ancestor, module],
        );
        if (!seen.add(ancestor) ||
            rows.isEmpty ||
            data(rows.single)['deleted'] == true) {
          throw StateError('folder_missing');
        }
        ancestor = data(rows.single)['parent'] as String;
      }
      await txn.delete(
        'module_data',
        where:
            """
        module=? AND kind='folder_item' AND owner=? AND json_extract(payload,'\$.entry')=?
        ${from == null ? '' : "AND json_extract(payload,'\$.folder')=?"}
      """,
        whereArgs: [module, item.id, item.entry, ?from],
      );
      if (destination.isNotEmpty) {
        await txn.insert(
          'module_data',
          _row(
            localId(),
            module,
            'folder_item',
            item.id,
            DateTime.now().toUtc().toIso8601String(),
            {'folder': destination, 'entry': item.entry},
          ),
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
    });
  }
}
