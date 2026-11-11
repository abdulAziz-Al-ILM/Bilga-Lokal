import 'dart:convert';
import 'dart:io';

import 'package:bilga/features/backup/backup_store.dart';
import 'package:bilga/features/collections/collection_repository.dart';
import 'package:bilga/features/notes/note_database.dart';
import 'package:bilga/features/todo/todo_database.dart';
import 'package:bilga/features/todo/todo_project_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

void registerTodoProjectTests({
  Future<Directory> Function()? createDirectory,
  bool secure = false,
}) {
  late Directory directory;
  late Database db;
  late TodoProjectStore store;
  final now = DateTime.utc(2030, 1, 31, 10),
      stamp = DateTime.utc(2030, 1, 31, 10).toIso8601String();
  setUp(() async {
    directory =
        await (createDirectory?.call() ??
            Directory.systemTemp.createTemp('bilga-project-'));
    db = await TodoDatabase.openAt(
      '${directory.path}/tasks.db',
      secure: secure,
    );
    store = TodoProjectStore(db);
  });
  tearDown(() async {
    await db.close();
    await directory.delete(recursive: true);
  });
  Future<String> project({String? parent, String name = 'Project'}) =>
      store.save(
        parentId: parent,
        name: name,
        description: 'Distinctiveproject details',
        status: 'active',
        dueDate: '2030-02-15',
      );
  Future<void> folder(String id, String? parent, {bool deleted = false}) => db
      .insert('todo_folders', {
        'id': id,
        'name': id,
        'parent_id': parent,
        'is_deleted': deleted ? 1 : 0,
        'created_at': stamp,
        'updated_at': stamp,
      })
      .then((_) {});
  Future<void> task(
    String id,
    String? folder, {
    bool done = false,
    bool deleted = false,
  }) => db
      .insert('todos', {
        'id': id,
        'title': id,
        'folder_id': folder,
        'is_done': done ? 1 : 0,
        'is_deleted': deleted ? 1 : 0,
        'due_at': now.subtract(const Duration(minutes: 1)).toIso8601String(),
        'created_at': stamp,
        'updated_at': stamp,
      })
      .then((_) {});

  test('Tasks 12 upgrade adds projects without rewriting folder, task or template data', () async {
    await folder('list', null);
    await task('a', 'list');
    await db.execute('DROP TABLE todo_projects');
    await db.setVersion(12);
    final tasks = await db.query('todos'),
        folders = await db.query('todo_folders');
    await db.close();
    db = await TodoDatabase.openAt(
      '${directory.path}/tasks.db',
      secure: secure,
    );
    store = TodoProjectStore(db);
    expect(await db.getVersion(), 13);
    expect(await db.query('todos'), tasks);
    expect(await db.query('todo_folders'), folders);
    expect(await store.all(), isEmpty);
    expect(await db.query('todo_templates'), isEmpty);
  });
  test('Project progress counts real nested tasks and excludes trash, hidden ancestors and other projects', () async {
    final root = await project();
    await folder('child', root);
    await folder('trash', root, deleted: true);
    await folder('deep-hidden', 'trash');
    await task('done', root, done: true);
    await task('pending', 'child');
    await task('ignored', 'deep-hidden');
    await task('deleted', root, deleted: true);
    await task('outside', null);
    final nested = await project(parent: 'child', name: 'Nested project');
    await task('nested', nested, done: true);
    final counts = await TodoProjectStore.progress(db, now);
    expect(counts[root], (total: 3, done: 2, overdue: 1));
    expect(counts[nested], (total: 1, done: 1, overdue: 0));
    await db.update(
      'todo_folders',
      {'is_deleted': 1},
      where: 'id=?',
      whereArgs: [root],
    );
    final hidden = await TodoProjectStore.progress(db, now);
    expect(hidden.containsKey(root), false);
    expect(hidden.containsKey(nested), false);
  });
  test('Convert/edit/remove metadata preserves tasks and rejects stale project or folder edits', () async {
    await folder('list', null);
    await task('a', 'list');
    final before = await db.query('todos');
    await store.save(
      folderId: 'list',
      name: 'Original project',
      description: 'Distinctiveproject',
      status: 'active',
      expectedFolderStamp: stamp,
    );
    final original = (await store.all())['list']!;
    await store.save(
      folderId: 'list',
      name: 'Updated project',
      description: 'Updated details',
      status: 'paused',
      expectedRevision: original.revision,
      expectedFolderStamp: original.folderStamp,
    );
    await expectLater(
      store.save(
        folderId: 'list',
        name: 'Lost edit',
        description: '',
        status: 'closed',
        expectedRevision: original.revision,
        expectedFolderStamp: original.folderStamp,
      ),
      throwsStateError,
    );
    await expectLater(store.removeMarker(original), throwsStateError);
    final current = (await store.all())['list']!;
    await db.update(
      'todo_folders',
      {'updated_at': '2031-01-01T00:00:00'},
      where: 'id=?',
      whereArgs: ['list'],
    );
    await expectLater(
      store.save(
        folderId: 'list',
        name: 'Lost rename',
        description: '',
        status: 'active',
        expectedRevision: current.revision,
        expectedFolderStamp: current.folderStamp,
      ),
      throwsStateError,
    );
    await store.removeMarker(current);
    expect(await store.all(), isEmpty);
    expect(await db.query('todos'), before);
    expect((await db.query('todo_folders')).single['name'], 'Updated project');
  });
  test('Invalid project writes and storage failures leave folders and tasks unchanged', () async {
    await db.execute(
      "CREATE TRIGGER fail_project BEFORE INSERT ON todo_projects BEGIN SELECT RAISE(ABORT,'synthetic'); END",
    );
    await expectLater(project(), throwsA(anything));
    expect(await db.query('todo_folders'), isEmpty);
    await db.execute('DROP TRIGGER fail_project');
    await expectLater(
      store.save(name: ' ', description: '', status: 'active'),
      throwsFormatException,
    );
    await expectLater(
      store.save(name: 'Bad', description: '', status: 'unknown'),
      throwsFormatException,
    );
    await expectLater(
      store.save(
        name: 'Bad',
        description: '',
        status: 'active',
        dueDate: '2030-02-31',
      ),
      throwsFormatException,
    );
    await expectLater(project(parent: 'missing'), throwsStateError);
    await folder('hidden', null, deleted: true);
    await folder('child', 'hidden');
    await expectLater(project(parent: 'child'), throwsStateError);
    await folder('cycle-a', 'cycle-b');
    await folder('cycle-b', 'cycle-a');
    await expectLater(project(parent: 'cycle-a'), throwsStateError);
    expect(await store.all(), isEmpty);
    expect(await db.query('todos'), isEmpty);
  });
  test('Project search and metadata follow trash, restoration and conversion without ghost rows', () async {
    final id = await project();
    await task('a', id);
    Future<List<Map<String, Object?>>> search() => db.rawQuery(
      "SELECT id FROM bilga_search WHERE bilga_search MATCH 'Distinctiveproject' AND kind='todoFolder'",
    );
    expect(await search(), hasLength(1));
    final repo = CollectionRepository(CollectionKind.todos, provided: db);
    await repo.trash(id, folder: true);
    expect(await search(), isEmpty);
    expect((await store.all()).containsKey(id), true);
    await repo.restore(id, folder: true);
    expect(await search(), hasLength(1));
    expect((await db.query('todos')).single['is_deleted'], 0);
    await store.removeMarker((await store.all())[id]!);
    expect(await search(), isEmpty);
    expect(await db.query('todos'), hasLength(1));
    await store.save(
      folderId: id,
      name: 'Recreated',
      description: 'Distinctiveproject',
      status: 'active',
    );
    await repo.trash(id, folder: true);
    await repo.removeForever(id, folder: true);
    expect(await store.all(), isEmpty);
    expect(await search(), isEmpty);
    expect(await db.query('todos'), isEmpty);
  });
  test('Portable project backup remaps nested ownership, progress and search and rejects orphan metadata', () async {
    final id = await project();
    await folder('child', id);
    await task('a', 'child', done: true);
    final notes = await NoteDatabase.openAt(
      '${directory.path}/notes.db',
      secure: secure,
    );
    final targetNotes = await NoteDatabase.openAt(
      '${directory.path}/target-notes.db',
      secure: secure,
    );
    final target = await TodoDatabase.openAt(
      '${directory.path}/target-tasks.db',
      secure: secure,
    );
    try {
      final snapshot = await BackupStore(notesDb: notes, todoDb: db).snapshot();
      expect(snapshot['todoSchema'], 11);
      final backup = BackupStore(notesDb: targetNotes, todoDb: target);
      expect(await backup.restore(snapshot, 'Import'), true);
      final restored = (await TodoProjectStore(target).all()).values.single;
      expect(restored.folderId, isNot(id));
      expect(restored.dueDate, '2030-02-15');
      expect(
        (await TodoProjectStore.progress(target, now))[restored.folderId],
        (total: 1, done: 1, overdue: 0),
      );
      expect(
        await target.rawQuery(
          "SELECT id FROM bilga_search WHERE bilga_search MATCH 'Distinctiveproject'",
        ),
        hasLength(1),
      );
      expect(await backup.restore(snapshot, 'Again'), false);
      final bad = jsonDecode(jsonEncode(snapshot)) as Map<String, dynamic>;
      ((bad['data'] as Map)['todo_projects'] as List).single['folder_id'] =
          'missing';
      await expectLater(backup.restore(bad, 'Invalid'), throwsFormatException);
      expect(await TodoProjectStore(target).all(), hasLength(1));
      final old = jsonDecode(jsonEncode(snapshot)) as Map<String, dynamic>;
      old['todoSchema'] = 10;
      (old['data'] as Map).remove('todo_projects');
      expect(BackupStore.validate(old)['todo_projects'], isEmpty);
    } finally {
      await notes.close();
      await targetNotes.close();
      await target.close();
    }
  });
}
