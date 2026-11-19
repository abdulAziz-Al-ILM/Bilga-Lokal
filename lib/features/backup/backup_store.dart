import '../finance/finance_planning.dart';
import '../organization/organization_store.dart';
import '../habits/habit_changes.dart';
import '../modules/module_data.dart';
import '../notes/rich_note_codec.dart';
import '../todo/todo_changes.dart';
import '../todo/todo_series_store.dart';
import '../todo/recurrence_rule.dart';
import '../todo/todo_checklist_store.dart';
import '../templates/task_template_store.dart';
import '../todo/todo_project_store.dart';
import '../todo/reminders/todo_reminder_store.dart';
import '../../core/private_database.dart';
import '../habits/habit_plan.dart';
import '../private_space/record_store.dart';
import '../books/reading/reading_data.dart';

import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:sqflite/sqflite.dart';

import '../notes/note_database.dart';
import '../notes/notes_changes.dart';
import '../notes/note_tag_store.dart';
import '../todo/todo_database.dart';

/// The databases retain their filenames. Rollback journals make the attached
/// multi-database restore atomic, including on process interruption.
class BackupStore {
  final Database? notesDb;
  final Database? todoDb;
  BackupStore({this.notesDb, this.todoDb});
  Future<Database> get _notes async => notesDb ?? await NoteDatabase.database;
  Future<Database> get _todo async => todoDb ?? await TodoDatabase.database;
  static const tableColumns = <String, Set<String>>{
    'module_data': {
      'id',
      'module',
      'kind',
      'owner',
      'payload',
      'revision',
      'created_at',
      'updated_at',
    },
    'book_reading': {
      'id',
      'book_id',
      'kind',
      'payload',
      'revision',
      'created_at',
      'updated_at',
    },
    'private_records': {
      'id',
      'kind',
      'payload',
      'revision',
      'created_at',
      'updated_at',
    },
    'habits': {
      'details',
      'id',
      'title',
      'days',
      'is_archived',
      'created_at',
      'updated_at',
    },
    'folders': {
      'id',
      'name',
      'parent_id',
      'created_at',
      'updated_at',
      'is_deleted',
      'trash_batch',
    },
    'notes': {
      'rich_body',
      'id',
      'title',
      'body',
      'folder_id',
      'created_at',
      'updated_at',
      'is_deleted',
      'trash_batch',
      'is_favorite',
      'is_archived',
      'tags',
    },
    'note_versions': {
      'version_id',
      'note_id',
      'title',
      'body',
      'rich_body',
      'created_at',
    },
    'note_tags': {'id', 'name', 'normalized_name', 'created_at', 'updated_at'},
    'note_tag_links': {'note_id', 'tag_id'},
    'todo_folders': {
      'id',
      'name',
      'parent_id',
      'created_at',
      'updated_at',
      'is_deleted',
      'trash_batch',
    },
    'todo_reminders': {'todo_id', 'enabled', 'remind_at', 'revision', 'fired'},
    'todo_series': {
      'id',
      'rule',
      'anchor_at',
      'template',
      'head_task_id',
      'current_sequence',
      'active',
      'created_at',
      'updated_at',
    },
    'todo_occurrences': {'todo_id', 'series_id', 'sequence', 'nominal_at'},
    'todo_checklist': {'id', 'todo_id', 'title', 'is_done', 'position'},
    'todo_templates': {
      'id',
      'name',
      'payload',
      'revision',
      'created_at',
      'updated_at',
    },
    'todo_projects': {
      'folder_id',
      'description',
      'status',
      'due_date',
      'revision',
      'created_at',
      'updated_at',
    },
    'todos': {
      'id',
      'title',
      'is_done',
      'priority',
      'due_at',
      'folder_id',
      'is_deleted',
      'created_at',
      'updated_at',
      'trash_batch',
      'description',
      'completed_at',
    },
  };

  Future<Map<String, dynamic>> snapshot({String? ownerId}) async {
    final notes = await _notes, todo = await _todo;
    // UI keeps this operation exclusive; no editor is open during a backup.
    final data = <String, dynamic>{};
    var bytes = 0, count = 0;
    Future<void> boundedRead(DatabaseExecutor txn, String table) async {
      final sum = tableColumns[table]!
          .map((c) => "length(CAST(coalesce($c,'') AS BLOB))")
          .join('+');
      final sizes = (await txn.rawQuery(
        'SELECT coalesce(SUM($sum),0) AS bytes,COUNT(*) AS n FROM $table',
      )).single;
      bytes += (sizes['bytes'] as int);
      count += (sizes['n'] as int);
      if (bytes > 14 * 1024 * 1024 || count > 100000) {
        throw const FormatException('backup_large');
      }
      data[table] = await txn.query(table);
    }

    await notes.transaction((txn) async {
      for (final table in [
        'folders',
        'notes',
        'note_versions',
        'note_tags',
        'note_tag_links',
        'habits',
        'private_records',
        'book_reading',
        'module_data',
      ]) {
        await boundedRead(txn, table);
      }
    });
    await todo.transaction((txn) async {
      for (final table in [
        'todo_folders',
        'todos',
        'todo_reminders',
        'todo_series',
        'todo_occurrences',
        'todo_checklist',
        'todo_templates',
        'todo_projects',
      ]) {
        await boundedRead(txn, table);
      }
    });
    return {
      'format': 'bilga-data',
      'version': 1,
      // Portable content schema. Device-local widget consent (DB v13) is excluded.
      'notesSchema':
          (data['module_data'] as List).any(
                (row) => {'folder', 'folder_item'}.contains(row['kind']),
              ) ||
              (data['private_records'] as List).any(
                (row) =>
                    row['kind'] == 'finance' &&
                    FinancePlanning.hasCategoryManagement(
                      Map<String, dynamic>.from(
                        jsonDecode(row['payload'] as String),
                      ),
                    ),
              )
          ? 19
          : (data['private_records'] as List).any(
              (r) =>
                  r['kind'] == 'finance' &&
                  (jsonDecode(r['payload'] as String) as Map).containsKey(
                    'planning',
                  ),
            )
          ? 18
          : (data['habits'] as List).any(
              (r) => HabitPlan.decode(r['details'] as String).advanced,
            )
          ? 17
          : (data['module_data'] as List).isNotEmpty
          ? 16
          : (data['book_reading'] as List).isNotEmpty
          ? 15
          : (data['private_records'] as List).any(
              (row) =>
                  row['kind'] == 'finance' &&
                  (jsonDecode(row['payload'] as String) as Map).containsKey(
                    'accountsVersion',
                  ),
            )
          ? 14
          : 13,
      'todoSchema': 11,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'ownerId': ownerId,
      'data': data,
    };
  }

  static Map<String, List<Map<String, Object?>>> validate(
    Map<String, dynamic> payload,
  ) {
    if (payload['format'] != 'bilga-data' ||
        payload['version'] != 1 ||
        ![
          8,
          9,
          10,
          11,
          12,
          13,
          14,
          15,
          16,
          17,
          18,
          19,
        ].contains(payload['notesSchema']) ||
        ![6, 7, 8, 9, 10, 11].contains(payload['todoSchema']) ||
        DateTime.tryParse(payload['createdAt'] as String? ?? '') == null) {
      throw const FormatException('backup_invalid');
    }
    final raw = payload['data'];
    if (raw is! Map) throw const FormatException('backup_invalid');
    if ((payload['notesSchema'] as int) < 19 &&
        raw['private_records'] is List &&
        (raw['private_records'] as List).any(
          (row) =>
              row is Map &&
              row['kind'] == 'finance' &&
              row['payload'] is String &&
              FinancePlanning.hasCategoryManagement(
                Map<String, dynamic>.from(jsonDecode(row['payload'])),
              ),
        )) {
      throw const FormatException('finance_category_schema');
    }
    if ((payload['notesSchema'] as int) < 18 &&
        raw['private_records'] is List &&
        (raw['private_records'] as List).any(
          (r) =>
              r is Map &&
              r['kind'] == 'finance' &&
              r['payload'] is String &&
              (jsonDecode(r['payload'] as String) as Map).containsKey(
                'planning',
              ),
        )) {
      throw const FormatException('finance_planning_schema');
    }
    if ((payload['notesSchema'] as int) < 17 &&
        raw['habits'] is List &&
        (raw['habits'] as List).any(
          (r) =>
              r is Map &&
              r['details'] is String &&
              HabitPlan.decode(r['details']).advanced,
        )) {
      throw const FormatException('habit_schema');
    }
    if ((payload['notesSchema'] as int) < 16 &&
        raw['module_data'] is List &&
        (raw['module_data'] as List).isNotEmpty) {
      throw const FormatException('module_schema');
    }
    if ((payload['notesSchema'] as int) < 15 &&
        raw['book_reading'] is List &&
        (raw['book_reading'] as List).isNotEmpty) {
      throw const FormatException('reading_schema');
    }
    final result = <String, List<Map<String, Object?>>>{};
    var count = 0;
    for (final entry in tableColumns.entries) {
      final list =
          (entry.key == 'module_data' &&
                  (payload['notesSchema'] as int) < 16) ||
              (entry.key == 'book_reading' &&
                  (payload['notesSchema'] as int) < 15) ||
              (entry.key == 'todo_reminders' && payload['todoSchema'] == 6) ||
              (entry.key == 'todo_projects' &&
                  (payload['todoSchema'] as int) < 11) ||
              (entry.key == 'todo_templates' &&
                  (payload['todoSchema'] as int) < 10) ||
              (entry.key == 'todo_checklist' &&
                  (payload['todoSchema'] as int) < 9) ||
              (['todo_series', 'todo_occurrences'].contains(entry.key) &&
                  (payload['todoSchema'] as int) < 8) ||
              (entry.key == 'habits' && payload['notesSchema'] == 8) ||
              (entry.key == 'private_records' &&
                  (payload['notesSchema'] as int) < 10) ||
              (['note_tags', 'note_tag_links'].contains(entry.key) &&
                  (payload['notesSchema'] as int) < 12)
          ? const <dynamic>[]
          : raw[entry.key];
      if (list is! List || (count += list.length) > 100000) {
        throw const FormatException('backup_invalid');
      }
      final rows = <Map<String, Object?>>[];
      final ids = <Object>{};
      for (final value in list) {
        if (value is! Map || value.keys.any((k) => !entry.value.contains(k))) {
          throw const FormatException('backup_invalid');
        }
        final row = Map<String, Object?>.from(value);
        if (entry.key == 'module_data') ModuleData.decode(row);
        if (entry.key == 'book_reading') ReadingData.decode(row);
        if (entry.key == 'todo_projects') {
          TodoProject.validate(row);
          if (!ids.add(row['folder_id']!) ||
              ['created_at', 'updated_at'].any(
                (key) =>
                    row[key] is! String ||
                    DateTime.tryParse(row[key] as String) == null,
              )) {
            throw const FormatException('backup_invalid');
          }
          rows.add(row);
          continue;
        }
        if (entry.key == 'todo_templates') {
          TaskTemplate.row(row);
          if (!ids.add(row['id']!) ||
              ['created_at', 'updated_at'].any(
                (key) =>
                    row[key] is! String ||
                    DateTime.tryParse(row[key] as String) == null,
              )) {
            throw const FormatException('backup_invalid');
          }
          rows.add(row);
          continue;
        }
        if (entry.key == 'todo_checklist') {
          if (row['id'] is! String ||
              (row['id'] as String).isEmpty ||
              (row['id'] as String).length > 512 ||
              !ids.add(row['id']!) ||
              row['todo_id'] is! String ||
              row['title'] is! String ||
              !TodoChecklistStore.validTitles([row['title']]) ||
              row['is_done'] is! int ||
              ![0, 1].contains(row['is_done']) ||
              row['position'] is! int ||
              (row['position'] as int) < 0 ||
              (row['position'] as int) >= TodoChecklistStore.maxItems) {
            throw const FormatException('backup_invalid');
          }
          rows.add(row);
          continue;
        }
        if (entry.key == 'todo_series') {
          if (row['id'] is! String ||
              !RegExp(r'^[A-Za-z0-9:_-]{1,1024}$')
                  .hasMatch(row['id'] as String) ||
              !ids.add(row['id']!) ||
              row['rule'] is! String ||
              row['template'] is! String ||
              row['current_sequence'] is! int ||
              (row['current_sequence'] as int) < 0 ||
              row['active'] is! int ||
              ![0, 1].contains(row['active']) ||
              (row['head_task_id'] != null && row['head_task_id'] is! String) ||
              (row['active'] == 1 && row['head_task_id'] == null)) {
            throw const FormatException('recurrence_invalid');
          }
          for (final key in ['anchor_at', 'created_at', 'updated_at']) {
            if (row[key] is! String ||
                DateTime.tryParse(row[key] as String) == null) {
              throw const FormatException('recurrence_invalid');
            }
          }
          RecurrenceRule.decode(row['rule'] as String);
          TodoSeriesStore.decodeTemplate(row['template'] as String);
          rows.add(row);
          continue;
        }
        if (entry.key == 'todo_occurrences') {
          if (row['todo_id'] is! String ||
              !ids.add(row['todo_id']!) ||
              row['series_id'] is! String ||
              row['sequence'] is! int ||
              (row['sequence'] as int) < 0 ||
              row['nominal_at'] is! String ||
              DateTime.tryParse(row['nominal_at'] as String) == null) {
            throw const FormatException('recurrence_invalid');
          }
          rows.add(row);
          continue;
        }
        if (entry.key == 'todo_reminders') {
          if (row['todo_id'] is! String ||
              !ids.add(row['todo_id']!) ||
              ![0, 1].contains(row['enabled']) ||
              ![0, 1].contains(row['fired']) ||
              row['revision'] is! String ||
              (row['revision'] as String).isEmpty ||
              row['remind_at'] is! String ||
              DateTime.tryParse(row['remind_at'] as String) == null) {
            throw const FormatException('backup_invalid');
          }
          rows.add(row);
          continue;
        }
        if (entry.key == 'note_tag_links') {
          if (row['note_id'] is! String ||
              row['tag_id'] is! String ||
              !ids.add(jsonEncode([row['note_id'], row['tag_id']]))) {
            throw const FormatException('backup_invalid');
          }
          rows.add(row);
          continue;
        }
        if (entry.key == 'note_tags' &&
            (row['name'] is! String ||
                (row['name'] as String).trim().isEmpty ||
                row['normalized_name'] !=
                    NoteTagStore.normalizeName(row['name'] as String))) {
          throw const FormatException('backup_invalid');
        }
        if (entry.key == 'notes' || entry.key == 'note_versions') {
          if (row['rich_body'] != null && row['rich_body'] is! String) {
            throw const FormatException('rich_note_format');
          }
          if (row['body'] is! String) {
            throw const FormatException('backup_invalid');
          }
          RichNoteCodec.validate(
            row['rich_body'] as String?,
            row['body'] as String,
          );
        }
        if (entry.key == 'private_records') {
          if (row['kind'] is! String ||
              row['payload'] is! String ||
              row['revision'] is! int ||
              (row['revision'] as int) < 1) {
            throw const FormatException('record');
          }
          RecordStore.validate(
            row['kind'] as String,
            Map<String, dynamic>.from(jsonDecode(row['payload'] as String)),
          );
        }
        if (entry.key == 'habits') {
          row['details'] ??= '{}';
          final habitPlan = HabitPlan.decode(row['details'] as String);
          if (habitPlan.advanced && (payload['notesSchema'] as int) < 17) {
            throw const FormatException('habit_schema');
          }
          if (row['days'] is! String) {
            throw const FormatException('backup_invalid');
          }
          final days = jsonDecode(row['days'] as String);
          if (days is! List ||
              days.any(
                (d) =>
                    d is! String ||
                    !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(d) ||
                    DateTime.tryParse(d) == null,
              )) {
            throw const FormatException('backup_invalid');
          }
        }
        final id = row[entry.key == 'note_versions' ? 'version_id' : 'id'];
        if (id == null ||
            (entry.key == 'note_versions'
                ? id is! int
                : id is! String || id.isEmpty) ||
            !ids.add(id)) {
          throw const FormatException('backup_invalid');
        }
        for (final field in [
          'created_at',
          if (entry.key != 'note_versions') 'updated_at',
        ]) {
          if (row[field] is! String ||
              DateTime.tryParse(row[field] as String) == null) {
            throw const FormatException('backup_invalid');
          }
        }
        for (final field in ['name', 'title', 'body', 'description']) {
          if (entry.value.contains(field) && row[field] is! String) {
            throw const FormatException('backup_invalid');
          }
        }
        for (final field in [
          'parent_id',
          'folder_id',
          'trash_batch',
          'due_at',
          'completed_at',
        ]) {
          if (row[field] != null && row[field] is! String) {
            throw const FormatException('backup_invalid');
          }
        }
        for (final field in ['due_at', 'completed_at']) {
          if (row[field] != null &&
              DateTime.tryParse(row[field] as String) == null) {
            throw const FormatException('backup_invalid');
          }
        }
        for (final field in [
          'is_deleted',
          'is_favorite',
          'is_archived',
          'is_done',
        ]) {
          if (entry.value.contains(field) &&
              row[field] != 0 &&
              row[field] != 1) {
            throw const FormatException('backup_invalid');
          }
        }
        if (entry.key == 'todos' &&
            (row['priority'] is! int ||
                (row['priority'] as int) < 0 ||
                (row['priority'] as int) > 3)) {
          throw const FormatException('backup_invalid');
        }
        if (entry.key == 'notes') {
          final tags = jsonDecode(row['tags'] as String? ?? 'null');
          if (tags is! List || tags.any((t) => t is! String)) {
            throw const FormatException('backup_invalid');
          }
        }
        rows.add(row);
      }
      result[entry.key] = rows;
    }
    for (final pair in [('folders', 'notes'), ('todo_folders', 'todos')]) {
      final byId = {for (final row in result[pair.$1]!) row['id']: row};
      for (final row in result[pair.$1]!) {
        final seen = <Object>{row['id']!};
        Object? parent = row['parent_id'];
        while (parent != null) {
          if (!seen.add(parent)) throw const FormatException('backup_invalid');
          // Historical orphan references are recovered to the import root.
          parent = byId[parent]?['parent_id'];
        }
      }
    }
    final todoIds = result['todos']!.map((r) => r['id']).toSet();
    final todoFolders = result['todo_folders']!.map((row) => row['id']).toSet();
    if (result['todo_projects']!.any(
      (row) => !todoFolders.contains(row['folder_id']),
    )) {
      throw const FormatException('backup_invalid');
    }
    final checklistPositions = <String>{};
    for (final item in result['todo_checklist']!) {
      if (!todoIds.contains(item['todo_id']) ||
          !checklistPositions.add(
            jsonEncode([item['todo_id'], item['position']]),
          )) {
        throw const FormatException('backup_invalid');
      }
    }
    final seriesById = {for (final r in result['todo_series']!) r['id']: r};
    final occurrences = {
      for (final r in result['todo_occurrences']!) r['todo_id']: r,
    };
    final sequences = <String>{};
    for (final occurrence in occurrences.values) {
      if (!todoIds.contains(occurrence['todo_id']) ||
          !seriesById.containsKey(occurrence['series_id']) ||
          !sequences.add(
            jsonEncode([occurrence['series_id'], occurrence['sequence']]),
          )) {
        throw const FormatException('recurrence_invalid');
      }
    }
    final todosById = {for (final r in result['todos']!) r['id']: r};
    for (final series in seriesById.values) {
      final head = series['head_task_id'];
      if (head == null) continue;
      final occurrence = occurrences[head], task = todosById[head];
      if (task == null ||
          occurrence == null ||
          occurrence['series_id'] != series['id'] ||
          occurrence['sequence'] != series['current_sequence'] ||
          (series['active'] == 1 &&
              (task['is_done'] != 0 || task['is_deleted'] != 0))) {
        throw const FormatException('recurrence_invalid');
      }
    }
    if (result['todo_reminders']!.any((r) => !todoIds.contains(r['todo_id']))) {
      throw const FormatException('backup_invalid');
    }
    final noteIds = result['notes']!.map((r) => r['id']).toSet();
    final tagIds = result['note_tags']!.map((r) => r['id']).toSet();
    final tagNames = result['note_tags']!
        .map((r) => r['normalized_name'])
        .toSet();
    if (tagNames.length != result['note_tags']!.length ||
        result['note_tag_links']!.any(
          (r) =>
              !noteIds.contains(r['note_id']) || !tagIds.contains(r['tag_id']),
        )) {
      throw const FormatException('backup_invalid');
    }
    if (result['note_versions']!.any((r) => !noteIds.contains(r['note_id']))) {
      throw const FormatException('backup_invalid');
    }
    final experiences = result['private_records']!
        .where((r) => r['kind'] == 'experience')
        .map((r) => r['id'])
        .toSet();
    final folderRows = {
      for (final row in result['module_data']!.where(
        (r) => r['kind'] == 'folder',
      ))
        row['id']: row,
    };
    final recordRows = {
      for (final row in result['private_records']!) row['id']: row,
    };
    final habitIds = result['habits']!.map((row) => row['id']).toSet();
    final ledgerEntries = <Object?, Set<Object?>>{};
    final memberships = <(Object?, Object?, Object?, Object?)>{};
    for (final row in result['module_data']!.where(
      (r) => {'folder', 'folder_item'}.contains(r['kind']),
    )) {
      if ((payload['notesSchema'] as int) < 19) {
        throw const FormatException('folder_schema');
      }
      final data = ModuleData.decode(row);
      final module = row['module'];
      if (row['kind'] == 'folder') {
        final seen = {row['id']};
        var parent = data['parent'] as String;
        while (parent.isNotEmpty) {
          final folder = folderRows[parent];
          if (!seen.add(parent) ||
              folder == null ||
              folder['module'] != module) {
            throw const FormatException('folder_tree');
          }
          parent = ModuleData.decode(folder)['parent'] as String;
        }
      } else {
        final owner = row['owner'];
        final source = recordRows[owner];
        if (folderRows[data['folder']]?['module'] != module ||
            (module == 'habit'
                ? !habitIds.contains(owner)
                : source?['kind'] != module) ||
            !memberships.add((module, owner, data['folder'], data['entry']))) {
          throw const FormatException('folder_membership');
        }
        if (module == 'finance' &&
            !ledgerEntries
                .putIfAbsent(
                  owner,
                  () => {
                    for (final entry in jsonDecode(
                      source!['payload'] as String,
                    )['entries'])
                      entry['id'],
                  },
                )
                .contains(data['entry'])) {
          throw const FormatException('folder_entry');
        }
      }
    }
    final uniqueModule = <String>{};
    final moduleTargets = <String>{};
    for (final row in result['module_data']!) {
      final d = ModuleData.decode(row);
      if (row['module'] == 'experience' &&
          !{'category', 'folder'}.contains(row['kind']) &&
          !experiences.contains(row['owner'])) {
        throw const FormatException('module_owner');
      }
      if (row['kind'] == 'link' &&
          !moduleTargets.add(
            '${row['module']}:${row['owner']}:${d['targetKind']}:${d['target']}',
          )) {
        throw const FormatException('module_link_duplicate');
      }
      final key = row['kind'] == 'history'
          ? '${row['owner']}:history:${d['entryRevision']}'
          : row['kind'] == 'link'
          ? '${row['owner']}:link:${d['targetKind']}:${d['action']}'
          : '${row['id']}';
      if (!uniqueModule.add(key)) {
        throw const FormatException('module_duplicate');
      }
    }
    final books = result['private_records']!
        .where((r) => r['kind'] == 'book')
        .map((r) => r['id'])
        .toSet();
    if (result['book_reading']!.any((r) => !books.contains(r['book_id']))) {
      throw const FormatException('reading_owner');
    }
    final singles = <String>{};
    final sources = <String, Map<String, dynamic>>{};
    for (final row in result['book_reading']!) {
      if ({'source', 'progress', 'settings'}.contains(row['kind']) &&
          !singles.add('${row['book_id']}:${row['kind']}')) {
        throw const FormatException('reading_duplicate');
      }
      if (row['kind'] == 'source') {
        sources[row['book_id'] as String] = ReadingData.decode(row);
      }
    }
    final media = <String, Map<String, dynamic>>{};
    for (final r in result['private_records']!.where(
      (r) => r['kind'] == 'attachment',
    )) {
      final d = Map<String, dynamic>.from(jsonDecode(r['payload'] as String));
      if (d['ownerKind'] == 'book' &&
          {'bookSource', 'bookCover', 'bookIndex'}.contains(d['role'])) {
        media['${d['owner']}:${d['role']}'] = d;
      }
    }
    for (final entry in sources.entries) {
      final d = entry.value;
      for (final role in ['bookSource', 'bookCover', 'bookIndex']) {
        final hash = role == 'bookSource'
            ? (d['mode'] == 'managed' ? d['blob'] : null)
            : d[role == 'bookCover' ? 'cover' : 'index'];
        if (hash == null) continue;
        final attachment = media['${entry.key}:$role'];
        if (attachment == null ||
            attachment['blob'] != hash ||
            (role == 'bookSource' && attachment['size'] != d['size'])) {
          throw const FormatException('reading_media_manifest');
        }
      }
    }
    return result;
  }

  Future<bool> restore(Map<String, dynamic> payload, String folderLabel) async {
    final tables = validate(
      payload,
    ); // All validation happens before attaching or writing.
    final digest = await Sha256().hash(utf8.encode(jsonEncode(payload)));
    final fingerprint = base64UrlEncode(digest.bytes).replaceAll('=', '');
    final prefix = 'restore:$fingerprint:item:';
    final root = 'restore:$fingerprint:root';
    final stamp = DateTime.now().toIso8601String();
    final notes = await _notes, todo = await _todo;
    for (final db in [notes, todo]) {
      final mode = (await db.rawQuery('PRAGMA journal_mode'))
          .single
          .values
          .single;
      if (mode.toString().toLowerCase() != 'delete') {
        throw StateError('journal_mode');
      }
    }
    // Injected databases can also be encrypted. Constructor injection is not
    // evidence about a file's cipher state. SQLCipher must receive an explicit
    // key for each attached file; an empty key opens a plaintext legacy file.
    final cipher = (await notes.rawQuery('PRAGMA cipher_version')).isNotEmpty;
    if (cipher) {
      final key = await PrivateDatabase.plain(File(todo.path))
          ? ''
          : await PrivateDatabase.key();
      await notes.execute(
        'ATTACH DATABASE ${PrivateDatabase.quote(todo.path)} AS bilga_restore_todo KEY ${PrivateDatabase.quote(key)}',
      );
    } else {
      await notes.execute('ATTACH DATABASE ? AS bilga_restore_todo', [
        todo.path,
      ]);
    }
    try {
      await notes.execute('PRAGMA bilga_restore_todo.synchronous = FULL');
      final restored = await notes.transaction((txn) async {
        // Import marker survives renaming/moving; the same backup cannot duplicate data.
        await txn.execute(
          'CREATE TABLE IF NOT EXISTS bilga_imports (fingerprint TEXT PRIMARY KEY, restored_at TEXT NOT NULL)',
        );
        if ((await txn.query(
          'bilga_imports',
          where: 'fingerprint = ?',
          whereArgs: [fingerprint],
        )).isNotEmpty) {
          return false;
        }
        final importedTags = <String, String>{};
        for (final row in tables['note_tags']!) {
          final tag = await NoteTagStore.ensure(
            txn,
            row['name'] as String,
            id: '$prefix${row['id']}',
            createdAt: row['created_at'] as String,
            legacy: true,
          );
          importedTags[row['id'] as String] = tag.id;
        }
        final importedLinks = <String, List<String>>{};
        for (final row in tables['note_tag_links']!) {
          (importedLinks[row['note_id'] as String] ??= []).add(
            importedTags[row['tag_id']]!,
          );
        }
        for (final pair in [('folders', 'notes'), ('todo_folders', 'todos')]) {
          final namespace = pair.$1 == 'folders' ? '' : 'bilga_restore_todo.';
          await _insert(txn, '$namespace${pair.$1}', {
            'id': root,
            'name': folderLabel,
            'parent_id': null,
            'is_deleted': 0,
            'created_at': stamp,
            'updated_at': stamp,
            'trash_batch': null,
          });
          final folderIds = tables[pair.$1]!.map((r) => r['id']).toSet();
          for (final row in tables[pair.$1]!) {
            await _insert(txn, '$namespace${pair.$1}', {
              ...row,
              'id': '$prefix${row['id']}',
              'parent_id': folderIds.contains(row['parent_id'])
                  ? '$prefix${row['parent_id']}'
                  : root,
              'trash_batch': row['trash_batch'] == null
                  ? null
                  : '$prefix${row['trash_batch']}',
            });
          }
          for (final row in tables[pair.$2]!) {
            await _insert(txn, '$namespace${pair.$2}', {
              ...row,
              'id': '$prefix${row['id']}',
              'folder_id': folderIds.contains(row['folder_id'])
                  ? '$prefix${row['folder_id']}'
                  : root,
              'trash_batch': row['trash_batch'] == null
                  ? null
                  : '$prefix${row['trash_batch']}',
            });
            if (pair.$2 == 'notes') {
              if ((payload['notesSchema'] as int) < 12) {
                final ids = <String>[];
                for (final name in NoteTagStore.legacyNames(row['tags'])) {
                  if (name.trim().isNotEmpty) {
                    ids.add(
                      (await NoteTagStore.ensure(txn, name, legacy: true)).id,
                    );
                  }
                }
                await NoteTagStore.assign(txn, '$prefix${row['id']}', ids: ids);
              } else {
                final ids = importedLinks[row['id']] ?? const <String>[];
                await NoteTagStore.assign(txn, '$prefix${row['id']}', ids: ids);
              }
            }
          }
        }
        for (var i = 0; i < tables['todo_checklist']!.length; i++) {
          final row = tables['todo_checklist']![i];
          await _insert(txn, 'bilga_restore_todo.todo_checklist', {
            ...row,
            'id': '${prefix}check:$i',
            'todo_id': '$prefix${row['todo_id']}',
          });
        }
        for (var i = 0; i < tables['todo_templates']!.length; i++) {
          await _insert(txn, 'bilga_restore_todo.todo_templates', {
            ...tables['todo_templates']![i],
            'id': '${prefix}template:$i',
          });
        }
        for (final project in tables['todo_projects']!) {
          await _insert(txn, 'bilga_restore_todo.todo_projects', {
            ...project,
            'folder_id': '$prefix${project['folder_id']}',
          });
        }
        final seriesIds = <String, String>{};
        for (var i = 0; i < tables['todo_series']!.length; i++) {
          seriesIds[tables['todo_series']![i]['id'] as String] =
              '${prefix}series:$i';
        }
        final todoFolderIds = tables['todo_folders']!
            .map((r) => r['id'])
            .toSet();
        for (final row in tables['todo_series']!) {
          final template = TodoSeriesStore.decodeTemplate(
            row['template'] as String,
          );
          final folder = template['folder_id'];
          template['folder_id'] = todoFolderIds.contains(folder)
              ? '$prefix$folder'
              : root;
          await _insert(txn, 'bilga_restore_todo.todo_series', {
            ...row,
            'id': seriesIds[row['id']],
            'head_task_id': row['head_task_id'] == null
                ? null
                : '$prefix${row['head_task_id']}',
            'template': jsonEncode(template),
          });
        }
        for (final row in tables['todo_occurrences']!) {
          await _insert(txn, 'bilga_restore_todo.todo_occurrences', {
            ...row,
            'todo_id': '$prefix${row['todo_id']}',
            'series_id': seriesIds[row['series_id']],
          });
        }
        for (final row in tables['todo_reminders']!) {
          await _insert(txn, 'bilga_restore_todo.todo_reminders', {
            ...row, 'todo_id': '$prefix${row['todo_id']}',
            'revision': TodoReminderStore.revision(),
            // A restore never emits a storm of historical reminders.
            'fired':
                DateTime.parse(row['remind_at'] as String)
                    .isBefore(DateTime.now())
                ? 1
                : row['fired'],
          });
        }
        for (final row in tables['private_records']!) {
          final data = Map<String, dynamic>.from(
            jsonDecode(row['payload'] as String),
          );
          if (row['kind'] == 'experience' &&
              tables['module_data']!.any(
                (c) => c['kind'] == 'category' && c['id'] == data['category'],
              )) {
            data['category'] = '$prefix${data['category']}';
          }
          if (row['kind'] == 'attachment') {
            data['owner'] = '$prefix${data['owner']}';
          }
          await _insert(txn, 'private_records', {
            ...row,
            'id': '$prefix${row['id']}',
            'payload': jsonEncode(data),
          });
        }
        for (final row in tables['module_data']!) {
          final data = ModuleData.decode(row);
          if (row['kind'] == 'history') {
            final snap = Map<String, dynamic>.from(data['snapshot']);
            if (tables['module_data']!.any(
              (c) => c['kind'] == 'category' && c['id'] == snap['category'],
            )) {
              snap['category'] = '$prefix${snap['category']}';
            }
            data['snapshot'] = snap;
          }
          if (row['kind'] == 'link') {
            data['target'] = '$prefix${data['target']}';
          }
          if (row['kind'] == 'category' && data['parent'] != null) {
            data['parent'] = '$prefix${data['parent']}';
          }
          if (row['kind'] == 'folder' && data['parent'] != '') {
            data['parent'] = '$prefix${data['parent']}';
          }
          if (row['kind'] == 'folder_item') {
            data['folder'] = '$prefix${data['folder']}';
          }
          await _insert(txn, 'module_data', {
            ...row,
            'id': '$prefix${row['id']}',
            'owner': row['owner'] == '' ? '' : '$prefix${row['owner']}',
            'payload': jsonEncode(data),
          });
        }
        if ((payload['notesSchema'] as int) < 19) {
          await OrganizationStore.importShelves(txn, prefix: prefix);
        }
        for (final row in tables['book_reading']!) {
          final data = Map<String, dynamic>.from(
            jsonDecode(row['payload'] as String),
          );
          if (row['kind'] == 'review') data['card'] = '$prefix${data['card']}';
          if (row['kind'] == 'link') {
            data['target'] = '$prefix${data['target']}';
            data['origin'] = '$prefix${data['origin']}';
          }
          await _insert(txn, 'book_reading', {
            ...row,
            'id': '$prefix${row['id']}',
            'book_id': '$prefix${row['book_id']}',
            'payload': jsonEncode(data),
          });
        }
        for (final row in tables['private_records']!.where(
          (r) => r['kind'] == 'experience',
        )) {
          final id = '$prefix${row['id']}';
          final actual = (await txn.query(
            'private_records',
            where: 'id=?',
            whereArgs: [id],
            limit: 1,
          )).single;
          await ModuleData.history(
            txn,
            id,
            actual['revision'] as int,
            Map<String, dynamic>.from(jsonDecode(actual['payload'] as String)),
            actual['updated_at'] as String,
            existing: true,
          );
        }
        for (final row in tables['habits']!) {
          await _insert(txn, 'habits', {...row, 'id': '$prefix${row['id']}'});
        }
        for (final row in tables['note_versions']!) {
          final copy = {...row, 'note_id': '$prefix${row['note_id']}'}
            ..remove('version_id');
          await _insert(txn, 'note_versions', copy);
        }
        await txn.insert('bilga_imports', {
          'fingerprint': fingerprint,
          'restored_at': stamp,
        });
        return true;
      });
      if (restored) {
        NotesChanges.committed();
        TodoChanges.committed();
        HabitChanges.committed();
      }
      return restored;
    } finally {
      await notes.execute('DETACH DATABASE bilga_restore_todo');
    }
  }

  Future<void> _insert(
    DatabaseExecutor db,
    String table,
    Map<String, Object?> row,
  ) async {
    final keys = row.keys.toList();
    await db.rawInsert(
      'INSERT INTO $table (${keys.join(',')}) VALUES (${List.filled(keys.length, '?').join(',')})',
      keys.map((k) => row[k]).toList(),
    );
  }
}
