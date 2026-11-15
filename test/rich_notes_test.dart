import 'dart:convert';
import 'dart:io';

import 'package:bilga/core/strings.dart';
import 'package:bilga/features/backup/backup_store.dart';
import 'package:bilga/features/notes/note_database.dart';
import 'package:bilga/features/notes/note_model.dart';
import 'package:bilga/features/notes/note_editor_page.dart';
import 'package:bilga/features/notes/note_service.dart';
import 'package:bilga/features/notes/rich_note_codec.dart';
import 'package:bilga/features/search/search_repository.dart';
import 'package:bilga/features/todo/todo_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'database_safety_test.dart' show initializeTestSqlite;
import 'support/rich_editor_input.dart';
import 'widget_test.dart' show MemoryNotes, openEditor;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  databaseFactory = createDatabaseFactoryFfi(ffiInit: initializeTestSqlite);
  setUpAll(Strings.load);
  const body = 'Knowledge\nTask';
  final formatted = RichNoteCodec.encode([
    {
      'insert': 'Knowledge',
      'attributes': {'bold': true},
    },
    {
      'insert': '\n',
      'attributes': {'header': 2},
    },
    {'insert': 'Task'},
    {
      'insert': '\n',
      'attributes': {'list': 'unchecked'},
    },
  ], body: body);

  test('Versioned rich text rejects mismatched projections, embeds, unsafe links and unknown operations', () {
    expect(RichNoteCodec.decode(formatted, expectedBody: body), hasLength(4));
    for (final raw in [
      jsonEncode({
        'version': 999,
        'ops': [
          {'insert': 'x\n'},
        ],
      }),
      jsonEncode({
        'version': 1,
        'ops': [
          {
            'insert': {'image': '../../private'},
          },
        ],
      }),
      jsonEncode({
        'version': 1,
        'ops': [
          {'delete': 1},
        ],
      }),
      jsonEncode({
        'version': 1,
        'ops': [
          {
            'insert': 'x\n',
            'attributes': {'link': 'javascript:alert(1)'},
          },
        ],
      }),
    ]) {
      expect(() => RichNoteCodec.decode(raw), throwsFormatException);
    }
    expect(
      () => RichNoteCodec.decode(formatted, expectedBody: 'Other text'),
      throwsFormatException,
    );
    expect(RichNoteCodec.safeLink('https://example.com/path?q=one'), isTrue);
    expect(RichNoteCodec.safeLink('file:///private/data'), isFalse);
    expect(RichNoteCodec.safeLink('https://user:secret@example.com'), isFalse);
  });

  test('Formatting-only changes, restore, backup and search preserve text and style atomically', () async {
    final dir = await Directory.systemTemp.createTemp('bilga-rich-');
    final n = await NoteDatabase.openAt('${dir.path}/notes.db');
    final t = await TodoDatabase.openAt('${dir.path}/tasks.db');
    try {
      final service = NoteService(database: n), now = DateTime(2026, 11, 10);
      final note = Note(
        id: 'note',
        title: 'Rich note',
        body: body,
        richBody: formatted,
        createdAt: now,
        updatedAt: now,
      );
      await service.addNote(note);
      final other = formatted.replaceFirst('"bold":true', '"italic":true');
      await service.updateNote(note.copyWith(richBody: other));
      final version = (await service.getNoteVersions('note')).single;
      expect(version.richBody, formatted);
      final restored = await service.restoreVersion(
        note.copyWith(richBody: other),
        version,
      );
      expect(restored.richBody, formatted);
      expect(restored.body, body);
      final before = await n.query('notes');
      await expectLater(
        service.updateNote(note.copyWith(richBody: '{}')),
        throwsFormatException,
      );
      expect(await n.query('notes'), before);
      final store = BackupStore(notesDb: n, todoDb: t),
          payload = await BackupStore(notesDb: n, todoDb: t).snapshot();
      expect(payload['notesSchema'], 13);
      expect(await store.restore(payload, 'Imported'), isTrue);
      final rows = await n.query('notes');
      expect(rows, hasLength(2));
      expect(
        rows.every((r) => r['body'] == body && r['rich_body'] == formatted),
        isTrue,
      );
      expect(
        await SearchRepository(notesDb: n, todoDb: t).search('Knowledge'),
        hasLength(2),
      );
      expect(
        (await n.query('note_versions')).every((r) => r['rich_body'] is String),
        isTrue,
      );
    } finally {
      await n.close();
      await t.close();
      await dir.delete(recursive: true);
    }
  });

  test('Notes 14 upgrade preserves original text, timestamps and history with nullable formatting', () async {
    final dir = await Directory.systemTemp.createTemp('bilga-rich-upgrade-');
    var db = await NoteDatabase.openAt('${dir.path}/notes.db');
    try {
      final now = DateTime(2026, 11, 10);
      final original = Note(
        id: 'old',
        title: 'Legacy',
        body: '  Original\r\n😀\n',
        createdAt: now,
        updatedAt: now,
      );
      await NoteService(database: db).addNote(original);
      await db.execute('ALTER TABLE notes DROP COLUMN rich_body');
      await db.execute('ALTER TABLE note_versions DROP COLUMN rich_body');
      await db.setVersion(14);
      await db.close();
      db = await NoteDatabase.openAt('${dir.path}/notes.db');
      expect(await db.getVersion(), 17);
      final migrated = (await NoteService(
        database: db,
      ).getAllActiveNotes()).single;
      expect(migrated.body, original.body);
      expect(migrated.updatedAt, original.updatedAt);
      expect(migrated.richBody, isNull);
    } finally {
      await db.close();
      await dir.delete(recursive: true);
    }
  });

  testWidgets(
    'Toolbar formatting and history survive autosave; IME learning stays disabled',
    (tester) async {
      final service = MemoryNotes();
      await openEditor(tester, service);
      await enterNoteBody(tester, 'Private writing');
      final editor = tester.widget<quill.QuillEditor>(
        find.byKey(const Key('note-body')),
      );
      editor.controller.updateSelection(
        const TextSelection(baseOffset: 0, extentOffset: 7),
        quill.ChangeSource.local,
      );
      await tester.pump();
      await tester.tap(find.byTooltip('Bold'));
      await tester.pump(const Duration(milliseconds: 750));
      await tester.pump();
      expect(service.writes.last.body, 'Private writing');
      expect(service.writes.last.richBody, contains('"bold":true'));
      await tester.tap(find.byKey(const Key('note-body')));
      await tester.pump();
      final clients = tester.testTextInput.log
          .where((call) => call.method == 'TextInput.setClient')
          .toList();
      expect(clients, isNotEmpty);
      final config = (clients.last.arguments as List)[1] as Map;
      expect(config['enableIMEPersonalizedLearning'], false);
      expect(config['enableSuggestions'], false);
      expect(config['autocorrect'], false);
      await tester.tap(find.byTooltip('Save'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Large-font editor keeps writing space visible above the keyboard',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpWidget(
        MaterialApp(
          builder: (c, child) => MediaQuery(
            data: MediaQuery.of(c)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: NoteEditorPage(service: MemoryNotes()),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byKey(const Key('note-body'))).height,
        greaterThan(40),
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'Opening and closing an unchanged legacy note does not rewrite it',
    (tester) async {
      final now = DateTime(2026, 11, 10), service = MemoryNotes();
      await openEditor(
        tester,
        service,
        note: Note(
          id: 'legacy',
          title: 'Legacy',
          body: '  text\n',
          createdAt: now,
          updatedAt: now,
        ),
      );
      await tester.tap(find.byTooltip('Save'));
      await tester.pumpAndSettle();
      expect(service.writes, isEmpty);
    },
  );
}
