import 'dart:convert';
import 'dart:io';
import 'dart:async';

import 'package:bilga/core/app_lock.dart';
import 'package:bilga/core/settings.dart';
import 'package:bilga/core/strings.dart';
import 'package:bilga/features/notes/note_database.dart';
import 'package:bilga/features/notes/note_widget_permission_store.dart';
import 'package:bilga/features/collections/collection_page.dart';
import 'package:bilga/features/collections/collection_repository.dart';
import 'package:bilga/features/backup/backup_store.dart';
import 'package:bilga/features/todo/todo_database.dart';
import 'package:bilga/features/notes/note_editor_page.dart';
import 'package:bilga/features/notes/note_model.dart';
import 'package:bilga/features/notes/note_service.dart';
import 'package:bilga/features/notes/note_tag_store.dart';
import 'package:bilga/features/notes/notes_changes.dart';
import 'package:bilga/features/notes/widget/notes_widget_bridge.dart';
import 'package:bilga/features/notes/widget/notes_widget_config_page.dart';
import 'package:bilga/features/notes/widget/notes_widget_data.dart';
import 'package:bilga/features/notes/widget/notes_widget_host.dart';
import 'package:bilga/features/notes/widget/notes_widget_sync.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'database_safety_test.dart' show initializeTestSqlite;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late Database db;
  late NoteService service;
  late NotesWidgetData data;
  List<Map<String, dynamic>> configs = [];
  final calls = <MethodCall>[];
  Map<String, dynamic>? launch;
  final stamp = DateTime(2026, 10, 12);
  final labels = {'note': 'Note', 'untitled': 'Untitled'};
  Note note(String id, {String? folder, List<String> tags = const []}) => Note(
    id: id,
    title: 'Title $id',
    body: 'Secret body $id',
    folderId: folder,
    tags: tags,
    createdAt: stamp,
    updatedAt: stamp,
  );
  Future<Note> stored(String id) async =>
      (await service.getAllActiveNotes()).singleWhere((n) => n.id == id);
  Future<NotesWidgetConfig> approved(Note note, WidgetPrivacy privacy) async {
    await NoteWidgetPermissionStore(db).setAllowed(note, true);
    return NotesWidgetConfig(id: 7, privacy: privacy);
  }

  setUpAll(() async {
    databaseFactory = createDatabaseFactoryFfi(ffiInit: initializeTestSqlite);
    for (final code in languages.keys) {
      await Strings.load(code: code);
    }
  });
  setUp(() async {
    root = await Directory.systemTemp.createTemp('bilga-widget-test-');
    db = await NoteDatabase.openAt('${root.path}/notes.db');
    service = NoteService(database: db);
    data = NotesWidgetData(db);
    configs = [];
    calls.clear();
    launch = null;
    AppSettings.instance.appLock = false;
    AppSettings.instance.language = 'en';
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(NotesWidgetBridge.channel, (call) async {
          calls.add(call);
          switch (call.method) {
            case 'configs':
              return configs;
            case 'consumeLaunch':
              final value = launch;
              launch = null;
              return value;
            case 'saveConfig':
              final value = Map<String, dynamic>.from(call.arguments as Map)
                ..['revision'] = 'saved';
              configs.removeWhere((c) => c['id'] == value['id']);
              configs.add(value);
              return null;
            default:
              return null;
          }
        });
  });
  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(NotesWidgetBridge.channel, null);
    await db.close();
    await root.delete(recursive: true);
  });

  test('Unknown/missing settings fail closed and each widget retains its own configuration', () {
    final a = NotesWidgetConfig.fromMap({
      'id': 7,
      'privacy': 'bad',
      'source': 'bad',
    });
    expect(a.privacy, WidgetPrivacy.hidden);
    expect(a.source, WidgetSource.recent);
    final b = NotesWidgetConfig(
      id: 8,
      source: WidgetSource.pinned,
      pinnedIds: ['one'],
      revision: 'v2',
    );
    expect(NotesWidgetConfig.fromMap(b.toMap()).pinnedIds, ['one']);
    expect(NotesWidgetConfig.fromMap(b.toMap()).revision, 'v2');
    expect(a.pinnedIds, isEmpty);
  });
  test('Recent feed spans folders, excludes trash/archive/deleted ancestors and never reads Private Space', () async {
    await db.insert('folders', {
      'id': 'gone',
      'name': 'Gone',
      'created_at': stamp.toIso8601String(),
      'updated_at': stamp.toIso8601String(),
      'is_deleted': 1,
    });
    await db.insert('folders', {
      'id': 'child',
      'name': 'Child',
      'parent_id': 'gone',
      'created_at': stamp.toIso8601String(),
      'updated_at': stamp.toIso8601String(),
    });
    for (final n in [
      note('old'),
      note('new').copyWith(updatedAt: stamp.add(const Duration(days: 1))),
      note('trash').copyWith(isDeleted: true),
      note('archive').copyWith(isArchived: true),
      note('under-deleted', folder: 'child'),
    ]) {
      await service.addNote(n);
    }
    await db.insert('private_records', {
      'id': 'private',
      'kind': 'book',
      'payload': '{"title":"Private sentinel"}',
      'revision': 1,
      'created_at': stamp.toIso8601String(),
      'updated_at': stamp.toIso8601String(),
    });
    expect(
      (await data.available(const NotesWidgetConfig(id: 7))).map((n) => n.id),
      ['new', 'old'],
    );
    expect(
      jsonEncode(await data.snapshot(const NotesWidgetConfig(id: 7), labels)),
      isNot(contains('Private sentinel')),
    );
  });
  test('Pinned instances stay independent; deleting and restoring a note updates eligibility', () async {
    await service.addNote(note('a'));
    await service.addNote(note('b'));
    const a = NotesWidgetConfig(
      id: 7,
      source: WidgetSource.pinned,
      pinnedIds: ['a'],
    );
    const b = NotesWidgetConfig(
      id: 8,
      source: WidgetSource.pinned,
      pinnedIds: ['b'],
    );
    expect((await data.available(a)).single.id, 'a');
    expect((await data.available(b)).single.id, 'b');
    await service.moveToTrash(await stored('a'));
    expect(await data.available(a), isEmpty);
    await service.restoreNote(note('a'));
    expect((await data.available(a)).single.id, 'a');
    await service.moveToTrash(await stored('a'));
    await service.deleteForever('a');
    expect(await data.available(a), isEmpty);
    expect((await data.available(b)).single.id, 'b');
  });
  test(
    'Tag source follows stable IDs through rename, detach and deletion',
    () async {
      await service.addNote(note('a', tags: ['Ish']));
      await service.addNote(note('b'));
      final tag = (await NoteTagStore(db).all()).single;
      final config = NotesWidgetConfig(
        id: 7,
        source: WidgetSource.tag,
        tagId: tag.id,
      );
      expect((await data.available(config)).single.id, 'a');
      await NoteTagStore(db).rename(tag.id, 'Work');
      expect((await data.available(config)).single.tags, ['Work']);
      await service.updateNote(
        (await stored('a')).copyWith(tagIds: <String>[]),
      );
      expect(await data.available(config), isEmpty);
      await NoteTagStore(db).delete(tag.id);
      expect(await data.available(config), isEmpty);
    },
  );
  test('Selection search can find older notes beyond the first page and escapes SQL wildcards', () async {
    await service.addNote(note('old').copyWith(title: '100%_ plan'));
    await service.addNote(
      note('new').copyWith(updatedAt: stamp.add(const Duration(days: 1))),
    );
    expect(
      (await data.available(
        const NotesWidgetConfig(id: 7),
        choosing: true,
        limit: 1,
      )).single.id,
      'new',
    );
    expect(
      (await data.available(
        const NotesWidgetConfig(id: 7),
        choosing: true,
        limit: 1,
        query: '%_',
      )).single.id,
      'old',
    );
    expect(
      await data.available(
        const NotesWidgetConfig(id: 7),
        choosing: true,
        query: 'missing',
      ),
      isEmpty,
    );
  });

  test(
    'Safe default and forced privacy never serialize title, body or tags',
    () async {
      await service.addNote(note('a', tags: ['Private tag']));
      final n = await stored('a');
      final open = await approved(n, WidgetPrivacy.preview);
      for (final result in [
        await data.snapshot(const NotesWidgetConfig(id: 7), labels),
        await data.snapshot(open, labels, forceHidden: true),
      ]) {
        expect(result.single['title'], 'Note 1');
        expect(result.single['body'], '');
        expect(result.single['tags'], '');
        expect(jsonEncode(result), isNot(contains('Secret')));
        expect(jsonEncode(result), isNot(contains('Private tag')));
      }
    },
  );
  test(
    'Preview exports only explicitly approved notes, with compact tags',
    () async {
      await service.addNote(note('a', tags: ['Ish']));
      await service.addNote(note('b'));
      final result = await data.snapshot(
        await approved(await stored('a'), WidgetPrivacy.preview),
        labels,
      );
      final a = result.single;
      expect(a['id'], 'a');
      expect(a['title'], 'Title a');
      expect(a['body'], 'Secret body a');
      expect(a['tags'], '#Ish');
      expect(result.any((r) => r['id'] == 'b'), isFalse);
    },
  );
  test('Global permission limits title mode; legacy per-widget approval cannot grant permission', () async {
    await service.addNote(note('a'));
    final n = await stored('a');
    final legacy = NotesWidgetConfig(
      id: 7,
      privacy: WidgetPrivacy.preview,
      approvals: {
        'a': await NotesWidgetData.fingerprint(n, WidgetPrivacy.preview),
      },
    );
    expect(await data.snapshot(legacy, labels), isEmpty);
    final titles = await approved(n, WidgetPrivacy.titles);
    final row = (await data.snapshot(titles, labels)).single;
    expect(row['title'], 'Title a');
    expect(row['body'], '');
    expect(row['tags'], '');
    await service.updateNote(n.copyWith(body: 'New private body'));
    expect(await data.snapshot(titles, labels), isEmpty);
    expect(await data.snapshot(legacy, labels), isEmpty);
  });
  test(
    'Body, title and global tag rename invalidate disclosure approval',
    () async {
      await service.addNote(note('a', tags: ['Ish']));
      var config = await approved(await stored('a'), WidgetPrivacy.preview);
      await service.updateNote(
        (await stored('a')).copyWith(body: 'Changed secret'),
      );
      expect(await data.snapshot(config, labels), isEmpty);
      config = await approved(await stored('a'), WidgetPrivacy.preview);
      await NoteTagStore(db)
          .rename((await NoteTagStore(db).all()).single.id, 'Private new tag');
      expect(await data.snapshot(config, labels), isEmpty);
      config = await approved(await stored('a'), WidgetPrivacy.titles);
      await service.updateNote(
        (await stored('a')).copyWith(title: 'Changed title'),
      );
      expect(await data.snapshot(config, labels), isEmpty);
    },
  );
  test(
    'Excerpts preserve Unicode scalars and published payloads are bounded',
    () async {
      expect(NotesWidgetData.excerpt('😀😀😀\n  x', 2), '😀😀');
      final n = note('a').copyWith(body: '😀' * 2000, title: 'T' * 1000);
      await service.addNote(n);
      final row = (await data.snapshot(
        await approved(n, WidgetPrivacy.preview),
        labels,
      )).single;
      expect((row['title'] as String).runes.length, 160);
      expect((row['body'] as String).runes.length, 240);
    },
  );
  test(
    'Change events follow successful commits and not rolled-back writes',
    () async {
      var count = 0;
      final subscription = NotesChanges.events.listen((_) => count++);
      try {
        await service.addNote(note('a'));
        expect(count, 1);
        await service.updateNote((await stored('a')).copyWith(body: 'edited'));
        expect(count, 2);
        await db.execute(
          "CREATE TRIGGER widget_fail BEFORE UPDATE ON notes BEGIN SELECT RAISE(ABORT, 'full'); END",
        );
        await expectLater(
          service.updateNote((await stored('a')).copyWith(body: 'failed')),
          throwsA(anything),
        );
        expect(count, 2);
      } finally {
        await subscription.cancel();
      }
    },
  );
  test(
    'Sync publishes isolated snapshots, then committed edits revoke previews',
    () async {
      await service.addNote(note('a'));
      configs = [
        (await approved(await stored('a'), WidgetPrivacy.preview)).toMap(),
        const NotesWidgetConfig(id: 8).toMap(),
      ];
      final sync = NotesWidgetSync(
        canRead: () => true,
        database: () async => db,
      );
      sync.start();
      try {
        await sync.refresh();
        var output = Map.from(
          calls.lastWhere((c) => c.method == 'publish').arguments as Map,
        );
        expect(output['widgets'][0]['rows'][0]['body'], 'Secret body a');
        expect(output['widgets'][1]['rows'][0]['body'], '');
        await service.updateNote(
          (await stored('a')).copyWith(body: 'New confidential content'),
        );
        await Future<void>.delayed(const Duration(milliseconds: 160));
        await sync.refresh();
        output = Map.from(
          calls.lastWhere((c) => c.method == 'publish').arguments as Map,
        );
        expect(output['widgets'][0]['rows'], isEmpty);
      } finally {
        sync.dispose();
      }
    },
  );
  test(
    'Locked sync and absent widgets never open the encrypted database',
    () async {
      var opens = 0;
      final sync = NotesWidgetSync(
        canRead: () => false,
        database: () async {
          opens++;
          return db;
        },
      );
      await sync.refresh();
      expect(opens, 0);
      expect(calls.last.method, 'redact');
      sync.dispose();
      final empty = NotesWidgetSync(
        canRead: () => true,
        database: () async {
          opens++;
          return db;
        },
      );
      await empty.refresh();
      expect(opens, 0);
      empty.dispose();
    },
  );
  test('All 43 catalogs and native launcher resources include widget privacy labels', () {
    for (final code in languages.keys) {
      for (final key in [
        'widgetNotes',
        'widgetSource',
        'widgetRecent',
        'widgetPinned',
        'widgetHidden',
        'widgetTitles',
        'widgetPreview',
        'widgetApprove',
        'widgetPrivacyInfo',
        'widgetAllow',
        'widgetPermissionHint',
      ]) {
        expect(Strings.catalogs[code]![key], isNotEmpty, reason: '$code/$key');
      }
      final xml = File(
        'android/app/src/main/res/values-${code == 'he' ? 'iw' : code}/notes_widget_strings.xml',
      ).readAsStringSync();
      expect(xml, contains('name="nw_hidden"'), reason: code);
      expect(xml, contains('name="nw_widget"'), reason: code);
    }
  });

  Future<void> settleIo(WidgetTester tester, {bool Function()? ready}) async {
    var stable = 0;
    for (var i = 0; i < 300; i++) {
      await tester.pump(const Duration(milliseconds: 20));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      if (find.byType(CircularProgressIndicator).evaluate().isEmpty &&
          (ready == null || ready())) {
        if (++stable >= 20) return;
      } else {
        stable = 0;
      }
    }
    fail('Widget UI did not finish SQLite I/O');
  }

  testWidgets(
    'Cold launch waits behind AppLock; warm launches open a new editor without discarding the first',
    (tester) async {
      final locked = ValueNotifier(true);
      launch = {'id': 7, 'action': 'create'};
      await tester.pumpWidget(
        MaterialApp(
          builder: (_, child) => ValueListenableBuilder<bool>(
            valueListenable: locked,
            builder: (_, value, _) =>
                AppLockScope(locked: value, child: child!),
          ),
          home: const NotesWidgetHost(child: Scaffold(body: Text('Home'))),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(NoteEditorPage), findsNothing);
      locked.value = false;
      await tester.pumpAndSettle();
      expect(find.byType(NoteEditorPage), findsOneWidget);
      launch = {'id': 8, 'action': 'create'};
      tester.binding.channelBuffers.push(
        NotesWidgetBridge.channel.name,
        const StandardMethodCodec().encodeMethodCall(
          const MethodCall('launch'),
        ),
        (_) {},
      );
      await tester.pumpAndSettle();
      expect(
        find.byType(NoteEditorPage, skipOffstage: false),
        findsNWidgets(2),
      );
      // A cached engine can outlive its native activity and miss the original
      // native notification. Resuming consumes the still-queued intent.
      launch = {'id': 9, 'action': 'create'};
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(
        find.byType(NoteEditorPage, skipOffstage: false),
        findsNWidgets(3),
      );
      // Rebinding an Activity to a cached engine must retry sync and consume the
      // still-queued intent even when there is no new lifecycle resume event.
      final reads = calls.where((call) => call.method == 'configs').length;
      launch = {'id': 10, 'action': 'create'};
      tester.binding.channelBuffers.push(
        NotesWidgetBridge.channel.name,
        const StandardMethodCodec().encodeMethodCall(
          const MethodCall('refresh'),
        ),
        (_) {},
      );
      await tester.pumpAndSettle();
      expect(
        calls.where((call) => call.method == 'configs').length,
        greaterThan(reads),
      );
      expect(
        find.byType(NoteEditorPage, skipOffstage: false),
        findsNWidgets(4),
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      locked.dispose();
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Configuration cancel removes its route and preserves the previous app page',
    (tester) async {
      configs = [const NotesWidgetConfig(id: 7).toMap()];
      final sync = NotesWidgetSync(
        canRead: () => true,
        database: () async => db,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) => NotesWidgetConfigPage(
                      widgetId: 7,
                      sync: sync,
                      database: db,
                    ),
                  ),
                ),
                child: const Text('Previous page'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Previous page'));
      await settleIo(tester);
      await tester.tap(find.byIcon(Icons.close));
      await settleIo(
        tester,
        ready: () => calls.any((c) => c.method == 'cancelConfiguration'),
      );
      await tester.pumpAndSettle();
      expect(find.byType(NotesWidgetConfigPage), findsNothing);
      expect(find.text('Previous page'), findsOneWidget);
      expect(calls.any((c) => c.method == 'cancelConfiguration'), isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
      sync.dispose();
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Configuration starts private and pins notes independently without editing Notes data',
    (tester) async {
      await tester.runAsync(() async {
        await service.addNote(note('a'));
        await service.addNote(note('b'));
      });
      configs = [const NotesWidgetConfig(id: 7).toMap()];
      final sync = NotesWidgetSync(
        canRead: () => true,
        database: () async => db,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: NotesWidgetConfigPage(widgetId: 7, sync: sync, database: db),
        ),
      );
      await settleIo(tester);
      expect(find.text(Strings.get('en', 'widgetHidden')), findsOneWidget);
      await tester.tap(find.byType(DropdownButtonFormField<WidgetSource>));
      await tester.pumpAndSettle();
      await tester.tap(find.text(Strings.get('en', 'widgetPinned')).last);
      await settleIo(tester);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('a')),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.byKey(const ValueKey('a')));
      await tester.pump();
      await tester.scrollUntilVisible(
        find.text('Save'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text('Save'));
      await settleIo(
        tester,
        ready: () => calls.any((c) => c.method == 'finishConfiguration'),
      );
      expect(configs.single['privacy'], 'hidden');
      expect(configs.single['pinnedIds'], ['a']);
      expect(configs.single['approvals'], isEmpty);
      await tester.runAsync(() async {
        expect((await stored('a')).isFavorite, false);
        expect(await service.getNoteVersions('a'), isEmpty);
      });
      await tester.pumpWidget(const SizedBox.shrink());
      sync.dispose();
      expect(tester.takeException(), isNull);
    },
  );
  test('v12 migration preserves notes, history and tags and creates no implicit permissions', () async {
    await service.addNote(note('a', tags: ['Ish']));
    await service.updateNote((await stored('a')).copyWith(body: 'edited'));
    final tables = [
      'notes',
      'folders',
      'note_versions',
      'note_tags',
      'note_tag_links',
    ];
    final before = {for (final table in tables) table: await db.query(table)};
    final triggers = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='trigger' AND name LIKE 'note_widget_%'",
    );
    for (final trigger in triggers) {
      await db.execute('DROP TRIGGER "${trigger['name']}"');
    }
    await db.execute('DROP TABLE note_widget_permissions');
    for (final row in await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'trigger' AND name LIKE 'search_%'",
    )) {
      await db.execute('DROP TRIGGER ${row['name']}');
    }
    await db.execute('DROP TABLE bilga_search');
    await db.execute('DROP INDEX search_note_folder');
    await db.execute('DROP INDEX search_attachment_owner');
    await db.setVersion(12);
    final path = db.path;
    await db.close();
    db = await NoteDatabase.openAt(path);
    expect(await db.getVersion(), 14);
    for (final table in tables) {
      expect(await db.query(table), before[table]);
    }
    expect(await db.query('note_widget_permissions'), isEmpty);
    expect(await db.rawQuery('PRAGMA foreign_key_check'), isEmpty);
  });

  test('Enabled consent survives reopening and allowed notes are filtered before the feed limit', () async {
    await service.addNote(
      note('allowed')
          .copyWith(updatedAt: stamp.subtract(const Duration(days: 1))),
    );
    await NoteWidgetPermissionStore(db)
        .setAllowed(await stored('allowed'), true);
    for (var i = 0; i < 15; i++) {
      await service.addNote(note('new-$i'));
    }
    final path = db.path;
    await db.close();
    db = await NoteDatabase.openAt(path);
    final feed = await NotesWidgetData(db).snapshot(
      const NotesWidgetConfig(id: 7, privacy: WidgetPrivacy.preview),
      labels,
    );
    expect(feed, hasLength(1));
    expect(feed.single['id'], 'allowed');
    expect(feed.single['body'], 'Secret body allowed');
  });

  test('Permission is off by default, persists, and revoke clears cache before completing without editing the note', () async {
    await service.addNote(note('a', tags: ['Ish']));
    final n = await stored('a');
    final before = await db.query('notes');
    final permissions = NoteWidgetPermissionStore(db);
    expect((await permissions.allowed([n]))['a'], false);
    await permissions.setAllowed(n, true);
    expect((await permissions.allowed([n]))['a'], true);
    final release = Completer<void>(), called = Completer<void>();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(NotesWidgetBridge.channel, (call) async {
          if (call.method == 'invalidatePermissions') {
            called.complete();
            await release.future;
          }
          return null;
        });
    var completed = false;
    final revoking = permissions
        .setAllowed(n, false)
        .then((_) => completed = true);
    await called.future;
    expect(completed, false);
    expect(await db.query('note_widget_permissions'), isEmpty);
    release.complete();
    await revoking;
    expect(completed, true);
    expect(await db.query('notes'), before);
    expect(await service.getNoteVersions(n.id), isEmpty);
    final path = db.path;
    await db.close();
    db = await NoteDatabase.openAt(path);
    expect((await NoteWidgetPermissionStore(db).allowed([n]))['a'], false);
  });

  test(
    'Stale review and private-record IDs cannot grant widget permission',
    () async {
      await service.addNote(note('a'));
      final reviewed = await stored('a');
      await service.updateNote(reviewed.copyWith(body: 'new private text'));
      await expectLater(
        NoteWidgetPermissionStore(db).setAllowed(reviewed, true),
        throwsStateError,
      );
      await db.insert('private_records', {
        'id': 'private',
        'kind': 'book',
        'payload': '{}',
        'revision': 1,
        'created_at': stamp.toIso8601String(),
        'updated_at': stamp.toIso8601String(),
      });
      await expectLater(
        NoteWidgetPermissionStore(db).setAllowed(note('private'), true),
        throwsStateError,
      );
      expect(await db.query('note_widget_permissions'), isEmpty);
    },
  );

  test('Rollback retains permission and does not clear cache; trash and permanent delete revoke it', () async {
    await service.addNote(note('a'));
    final n = await stored('a');
    final permissions = NoteWidgetPermissionStore(db);
    await permissions.setAllowed(n, true);
    await db.execute(
      "CREATE TRIGGER fail_revoke BEFORE DELETE ON note_widget_permissions BEGIN SELECT RAISE(ABORT, 'full'); END",
    );
    calls.clear();
    await expectLater(permissions.setAllowed(n, false), throwsA(anything));
    expect((await permissions.allowed([n]))['a'], true);
    expect(calls, isEmpty);
    await db.execute('DROP TRIGGER fail_revoke');
    await service.moveToTrash(n);
    await service.restoreNote(n.copyWith(isDeleted: true));
    expect(await db.query('note_widget_permissions'), isEmpty);
    await permissions.setAllowed(await stored('a'), true);
    await db.delete('notes', where: 'id=?', whereArgs: ['a']);
    expect(await db.query('note_widget_permissions'), isEmpty);
  });

  test('Unchanged tags and favorite changes keep consent; tag edits require fresh consent', () async {
    await service.addNote(note('a', tags: ['Ish']));
    final n = await stored('a');
    final permissions = NoteWidgetPermissionStore(db);
    await permissions.setAllowed(n, true);
    await service.updateNote(n.copyWith(isFavorite: true));
    expect((await permissions.allowed([await stored('a')]))['a'], true);
    await service.updateNote((await stored('a')).copyWith(tagIds: <String>[]));
    expect(await db.query('note_widget_permissions'), isEmpty);
  });

  test('Permission is device-local: backup restore cannot grant or resurrect consent', () async {
    await service.addNote(note('a'));
    final permissions = NoteWidgetPermissionStore(db);
    await permissions.setAllowed(await stored('a'), true);
    final todo = await TodoDatabase.openAt('${root.path}/todo.db');
    final restoredTodo = await TodoDatabase.openAt(
      '${root.path}/restored-todo.db',
    );
    final restored = await NoteDatabase.openAt('${root.path}/restored.db');
    try {
      final payload = await BackupStore(notesDb: db, todoDb: todo).snapshot();
      expect(
        (payload['data'] as Map).containsKey('note_widget_permissions'),
        false,
      );
      await permissions.setAllowed(await stored('a'), false);
      await BackupStore(notesDb: db, todoDb: todo).restore(payload, 'Imported');
      expect(await db.query('note_widget_permissions'), isEmpty);
      await BackupStore(
        notesDb: restored,
        todoDb: restoredTodo,
      ).restore(payload, 'Imported');
      expect(await restored.query('note_widget_permissions'), isEmpty);
    } finally {
      await restored.close();
      await restoredTodo.close();
      await todo.close();
    }
  });

  testWidgets(
    'Each note card has an off-by-default switch, warning and immediate revoke',
    (tester) async {
      await tester.runAsync(() => service.addNote(note('a')));
      await tester.pumpWidget(
        MaterialApp(
          home: CollectionPage(
            kind: CollectionKind.notes,
            repository: CollectionRepository(
              CollectionKind.notes,
              provided: db,
            ),
          ),
        ),
      );
      await settleIo(tester);
      final control = find.byKey(const ValueKey('widget-allow-a'));
      expect(tester.widget<SwitchListTile>(control).value, false);
      await tester.ensureVisible(control);
      await tester.tap(control);
      await tester.pumpAndSettle();
      expect(find.text(Strings.get('en', 'widgetPrivacyInfo')), findsOneWidget);
      // Cancelling disclosure must leave the default untouched.
      await tester.tap(find.text('Cancel'));
      await settleIo(tester);
      expect(tester.widget<SwitchListTile>(control).value, false);
      await tester.tap(control);
      await tester.pumpAndSettle();
      await tester.tap(find.text(Strings.get('en', 'continue')));
      // A visible value can update from the change stream before run() has
      // completed its final reload. Wait for the control to accept the next
      // interaction; otherwise a fast runner can tap a still-disabled switch.
      await settleIo(
        tester,
        ready: () {
          final tile = tester.widget<SwitchListTile>(control);
          return tile.value && tile.onChanged != null;
        },
      );
      expect(tester.widget<SwitchListTile>(control).value, true);
      calls.clear();
      await tester.tap(control);
      await settleIo(
        tester,
        ready: () {
          final tile = tester.widget<SwitchListTile>(control);
          return !tile.value && tile.onChanged != null;
        },
      );
      expect(tester.widget<SwitchListTile>(control).value, false);
      expect(calls.any((c) => c.method == 'invalidatePermissions'), true);
      await tester.runAsync(() async {
        expect(await db.query('note_widget_permissions'), isEmpty);
        expect(await service.getNoteVersions('a'), isEmpty);
      });
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Widget configuration selects pinned notes but never grants disclosure permission',
    (tester) async {
      await tester.runAsync(() => service.addNote(note('a')));
      configs = [const NotesWidgetConfig(id: 7).toMap()];
      final sync = NotesWidgetSync(
        canRead: () => true,
        database: () async => db,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: NotesWidgetConfigPage(widgetId: 7, sync: sync, database: db),
        ),
      );
      await settleIo(tester);
      await tester.tap(find.byType(DropdownButtonFormField<WidgetPrivacy>));
      await tester.pumpAndSettle();
      await tester.tap(find.text(Strings.get('en', 'widgetPreview')).last);
      await settleIo(tester);
      expect(
        find.text('Title a'),
        findsOneWidget,
      ); // Disclosure control is always available.
      expect(
        find.text(Strings.get('en', 'widgetPermissionHint')),
        findsOneWidget,
      );
      await tester.tap(find.byType(DropdownButtonFormField<WidgetSource>));
      await tester.pumpAndSettle();
      await tester.tap(find.text(Strings.get('en', 'widgetPinned')).last);
      await settleIo(tester);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('a')),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.byKey(const ValueKey('a')));
      await tester.scrollUntilVisible(
        find.text('Save'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text('Save'));
      await settleIo(
        tester,
        ready: () => calls.any((c) => c.method == 'finishConfiguration'),
      );
      expect(configs.single['pinnedIds'], ['a']);
      expect(configs.single['approvals'], isEmpty);
      await tester.runAsync(() async {
        expect(await db.query('note_widget_permissions'), isEmpty);
        expect(
          await data.snapshot(
            NotesWidgetConfig.fromMap(configs.single),
            labels,
          ),
          isEmpty,
        );
      });
      await tester.pumpWidget(const SizedBox.shrink());
      sync.dispose();
      expect(tester.takeException(), isNull);
    },
  );
}
