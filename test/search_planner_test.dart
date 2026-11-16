import 'dart:convert';
import 'dart:io';

import 'package:bilga/features/backup/backup_store.dart';
import 'package:bilga/features/habits/habit_store.dart';
import 'package:bilga/features/notes/note_database.dart';
import 'package:bilga/features/notes/note_model.dart';
import 'package:bilga/features/notes/note_service.dart';
import 'package:bilga/features/planning/planner_repository.dart';
import 'package:bilga/features/search/search_repository.dart';
import 'package:bilga/features/todo/todo_database.dart';
import 'package:bilga/features/todo/todo_model.dart';
import 'package:bilga/features/todo/todo_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'database_safety_test.dart' show initializeTestSqlite;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  databaseFactory = createDatabaseFactoryFfi(ffiInit: initializeTestSqlite);
  late Directory dir;
  late Database notes, todos;
  late SearchRepository search;
  final now = DateTime(2026, 11, 9, 15);
  Note note(String id, String title) => Note(
    id: id,
    title: title,
    body: 'Private searchable text',
    createdAt: now,
    updatedAt: now,
  );
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('bilga-search-');
    notes = await NoteDatabase.openAt('${dir.path}/notes.db');
    todos = await TodoDatabase.openAt('${dir.path}/todos.db');
    search = SearchRepository(notesDb: notes, todoDb: todos);
  });
  tearDown(() async {
    await notes.close();
    await todos.close();
    await dir.delete(recursive: true);
  });

  test('Cross-module literal search updates atomically, excludes trash and respects archive', () async {
    final ns = NoteService(database: notes);
    await ns.addNote(note('n', 'Orchid notes'));
    await TodoService(database: todos).addTodo(
      Todo(
        id: 't',
        title: 'Orchid task',
        isDone: false,
        createdAt: now,
        updatedAt: now,
      ),
    );
    await HabitStore(provided: notes).create('Orchid habit');
    expect((await search.search('orch')).map((h) => h.kind).toSet(), {
      'note',
      'todo',
      'habit',
    });
    expect(await search.search('" OR "nonexistent'), isEmpty);
    await ns.updateNote(note('n', 'Replacement'));
    expect((await search.search('orchid', kind: 'note')), isEmpty);
    await ns.updateNote(
      note('n', 'Orchid archived').copyWith(isArchived: true),
    );
    expect(await search.search('orchid', kind: 'note'), isEmpty);
    expect(
      await search.search('orchid', kind: 'note', includeArchived: true),
      hasLength(1),
    );
    await ns.moveToTrash(note('n', 'Orchid archived'));
    expect(
      await search.search('orchid', kind: 'note', includeArchived: true),
      isEmpty,
    );
    await ns.restoreNote(note('n', 'Orchid archived'));
    expect(await search.search('orchid', kind: 'note'), hasLength(1));
    await notes.execute(
      "CREATE TRIGGER reject_note BEFORE UPDATE ON notes BEGIN SELECT RAISE(ABORT, 'failure'); END",
    );
    await expectLater(ns.updateNote(note('n', 'Lost text')), throwsA(anything));
    expect(await search.search('orchid', kind: 'note'), hasLength(1));
    expect(await search.search('Lost'), isEmpty);
  });

  test(
    'Record type filtering and paging do not lose results among other modules',
    () async {
      for (var i = 0; i < 75; i++) {
        await notes.insert('private_records', {
          'id': '$i',
          'kind': i < 60 ? 'book' : 'experience',
          'payload': jsonEncode({
            'title': 'Orchid $i',
            if (i < 60) 'chapters': [],
            if (i >= 60) 'category': 'life',
            'body': 'journal',
          }),
          'revision': 1,
          'created_at': now.toIso8601String(),
          'updated_at': now.toIso8601String(),
        });
      }
      expect(await search.search('orchid', kind: 'experience'), hasLength(15));
      final first = await search.search('orchid', limit: 50);
      final next = await search.search('orchid', offset: 50);
      expect(first.length + next.length, 75);
      expect({
        ...first.map((h) => h.id),
        ...next.map((h) => h.id),
      }, hasLength(75));
    },
  );

  test('Backup restores original content and automatically rebuilds searchable derived rows', () async {
    await NoteService(database: notes).addNote(note('n', 'Orchid'));
    final store = BackupStore(notesDb: notes, todoDb: todos);
    final payload = await store.snapshot();
    expect((payload['data'] as Map).containsKey('bilga_search'), isFalse);
    expect(await store.restore(payload, 'Imported'), isTrue);
    expect(await search.search('orchid'), hasLength(2));
    expect(await store.restore(payload, 'Imported'), isFalse);
    expect(await search.search('orchid'), hasLength(2));
  });

  test('Existing WIP Notes 13 and Tasks 8 migrate with content and reminder rows intact', () async {
    await NoteService(database: notes)
        .addNote(note('legacy-note', 'Orchid original'));
    await TodoService(database: todos).addTodo(
      Todo(
        id: 'legacy-task',
        title: 'Orchid task',
        isDone: false,
        createdAt: now,
        updatedAt: now,
      ),
    );
    for (final (db, version) in [(notes, 13), (todos, 8)]) {
      final triggers = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'trigger' AND name LIKE 'search_%'",
      );
      for (final t in triggers) {
        await db.execute('DROP TRIGGER ${t['name']}');
      }
      await db.execute('DROP TABLE bilga_search');
      for (final index
          in db == notes
              ? ['search_note_folder', 'search_attachment_owner']
              : ['planner_due', 'planner_completed']) {
        await db.execute('DROP INDEX $index');
      }
      if (db == notes) {
        await db.execute('DROP TABLE module_data');
        await db.execute('ALTER TABLE notes DROP COLUMN rich_body');
        await db.execute('ALTER TABLE note_versions DROP COLUMN rich_body');
      }
      if (db == todos) {
        await db.execute('DROP TRIGGER todo_series_trash');
        await db.execute('DROP TRIGGER todo_series_delete');
        await db.execute('DROP TABLE todo_projects');
        await db.execute('DROP TABLE todo_templates');
        await db.execute('DROP TABLE todo_checklist');
        await db.execute('DROP TABLE todo_occurrences');
        await db.execute('DROP TABLE todo_series');
      }
      await db.setVersion(version);
      await db.close();
    }
    notes = await NoteDatabase.openAt('${dir.path}/notes.db');
    todos = await TodoDatabase.openAt('${dir.path}/todos.db');
    search = SearchRepository(notesDb: notes, todoDb: todos);
    expect(await notes.getVersion(), 18);
    expect(await todos.getVersion(), 13);
    expect((await search.search('Orchid')).map((h) => h.id).toSet(), {
      'legacy-note',
      'legacy-task',
    });
    expect(
      (await notes.rawQuery('PRAGMA integrity_check')).single.values.single,
      'ok',
    );
    expect(
      (await todos.rawQuery('PRAGMA integrity_check')).single.values.single,
      'ok',
    );
  });

  test('Planner uses civil dates, source IDs, completion dates and scheduled habits', () async {
    for (final (id, date, done) in [
      ('overdue', DateTime(2026, 11, 8, 23, 59), false),
      ('today', DateTime(2026, 11, 9, 23), false),
      ('upcoming', DateTime(2026, 11, 15, 23), false),
      ('nextWeek', DateTime(2026, 11, 17), false),
      ('done', DateTime(2026, 11, 8), true),
    ]) {
      await TodoService(database: todos).addTodo(
        Todo(
          id: id,
          title: id,
          isDone: done,
          dueAt: date,
          createdAt: now,
          updatedAt: now,
        ),
      );
    }
    await todos.update(
      'todos',
      {'completed_at': now.toIso8601String()},
      where: 'id = ?',
      whereArgs: ['done'],
    );
    await notes.insert('habits', {
      'id': 'h',
      'title': 'Read',
      'days': '[]',
      'details': HabitPlan(weekdays: {DateTime.monday}).encode(),
      'created_at': DateTime(2026, 1, 1).toIso8601String(),
      'updated_at': now.toIso8601String(),
      'is_archived': 0,
    });
    final p = await PlannerRepository(notesDb: notes, todoDb: todos).load(now);
    expect(p.overdue.single['id'], 'overdue');
    expect(p.today.single['id'], 'today');
    expect(p.upcoming.single['id'], 'upcoming');
    expect(p.completed.single['id'], 'done');
    expect(p.habits.single.id, 'h');
    expect((await todos.query('todos')).length, 5);
  });

  test('Search pages across 6000 source records without loading all note bodies', () async {
    final watch = Stopwatch()..start();
    for (final (db, table) in [(notes, 'notes'), (todos, 'todos')]) {
      await db.transaction((txn) async {
        final batch = txn.batch();
        for (var i = 0; i < 3000; i++) {
          batch.insert(table, {
            'id': 'bulk-$i',
            'title': i % 20 == 0 ? 'Orchid $i' : 'Other $i',
            if (table == 'notes') 'body': 'Long-lived private record $i',
            'created_at': now.toIso8601String(),
            'updated_at': now.toIso8601String(),
          });
        }
        await batch.commit(noResult: true);
      });
    }
    final insertMs = watch.elapsedMilliseconds;
    watch.reset();
    final first = await search.search('orch');
    final later = await search.search('orch', offset: 250);
    final queryMs = watch.elapsedMilliseconds;
    expect(first, hasLength(50));
    expect(later, hasLength(50));
    expect(first.every((h) => h.title.startsWith('Orchid')), isTrue);
    // ignore: avoid_print
    print(
      'SEARCH BENCHMARK: 6000 inserts=$insertMs ms; two paged queries=$queryMs ms (host FFI, not Android)',
    );
  });
}
