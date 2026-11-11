import 'dart:io';

import 'package:bilga/core/settings.dart';
import 'package:bilga/core/strings.dart';
import 'package:bilga/features/backup/backup_codec.dart';
import 'package:bilga/features/backup/backup_store.dart';
import 'package:bilga/features/habits/habit_store.dart';
import 'package:bilga/features/notes/note_database.dart';
import 'package:bilga/features/notes/note_editor_page.dart';
import 'package:bilga/features/notes/note_service.dart';
import 'package:bilga/features/search/search_repository.dart';
import 'package:bilga/features/todo/todo_database.dart';
import 'package:bilga/features/todo/todo_model.dart';
import 'package:bilga/features/todo/todo_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

import '../test/support/rich_editor_input.dart';
import 'data_safety_test.dart' as safety;
import 'private_device_test.dart' as private;
import 'review_guard.dart';
import 'app_journey_cases.dart';
import 'notification_cases.dart';
import 'recurrence_cases.dart';
import 'checklist_cases.dart';
import 'task_template_cases.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(requireReviewPackage);
  group('Android SQLCipher and Keystore', private.main);
  group('Non-destructive migration and restore fixtures', safety.main);

  testWidgets(
    'Rich editor persists style through encrypted reopen and backup',
    (tester) async {
      await Strings.load(code: 'en');
      AppSettings.instance.language = 'en';
      final root = await getTemporaryDirectory();
      final dir = await Directory(
        '${root.path}/review-rich-${DateTime.now().microsecondsSinceEpoch}',
      ).create();
      var notes = await NoteDatabase.openAt(
        '${dir.path}/notes.db',
        secure: true,
      );
      final todos = await TodoDatabase.openAt(
        '${dir.path}/tasks.db',
        secure: true,
      );
      try {
        final service = NoteService(database: notes);
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => NoteEditorPage(service: service),
                    ),
                  ),
                  child: const Text('Open synthetic note'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open synthetic note'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('note-title')),
          'Tablet review',
        );
        await enterNoteBody(tester, 'Private knowledge 🌿\nSecond line');
        final editor = tester.widget<quill.QuillEditor>(
          find.byKey(const Key('note-body')),
        );
        editor.controller.updateSelection(
          const TextSelection(baseOffset: 0, extentOffset: 7),
          quill.ChangeSource.local,
        );
        await tester.pump();
        await tester.tap(find.byTooltip('Bold'));
        await tester.pump(const Duration(seconds: 1));
        await SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeLeft,
        ]);
        for (
          var i = 0;
          i < 20 &&
              tester.view.physicalSize.width < tester.view.physicalSize.height;
          i++
        ) {
          await tester.pump(const Duration(milliseconds: 250));
        }
        expect(
          tester.view.physicalSize.width,
          greaterThan(tester.view.physicalSize.height),
        );
        expect(
          editor.controller.document.toPlainText(),
          contains('Private knowledge'),
        );
        expect(tester.takeException(), isNull);
        await SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
        ]);
        for (
          var i = 0;
          i < 20 &&
              tester.view.physicalSize.width > tester.view.physicalSize.height;
          i++
        ) {
          await tester.pump(const Duration(milliseconds: 250));
        }
        await tester.tap(find.byTooltip('Save'));
        await tester.pumpAndSettle();
        expect(find.text('Open synthetic note'), findsOneWidget);
        expect(tester.takeException(), isNull);

        final saved = (await service.getAllActiveNotes()).single;
        expect(saved.body, 'Private knowledge 🌿\nSecond line');
        expect(saved.richBody, contains('"bold":true'));
        await notes.close();
        notes = await NoteDatabase.openAt('${dir.path}/notes.db', secure: true);
        expect(
          (await NoteService(
            database: notes,
          ).getAllActiveNotes()).single.richBody,
          saved.richBody,
        );
        expect(
          String.fromCharCodes(await File(notes.path).openRead(0, 16).first),
          isNot('SQLite format 3\x00'),
        );

        final now = DateTime.now();
        final task = Todo(
          id: 'review-task',
          title: 'Review knowledge',
          isDone: false,
          createdAt: now,
          updatedAt: now,
        );
        await TodoService(database: todos).addTodo(task);
        await TodoService(database: todos).toggleTodo(task);
        expect(
          (await TodoService(database: todos).getTodos()).single.isDone,
          isTrue,
        );
        final habits = HabitStore(provided: notes);
        await habits.create('Review knowledge daily', id: 'review-habit');
        await habits.mark('review-habit', now, true);
        expect((await habits.all()).single.days, contains(dayKey(now)));

        final search = SearchRepository(notesDb: notes, todoDb: todos);
        expect((await search.search('knowledge')).map((h) => h.kind).toSet(), {
          'note',
          'todo',
          'habit',
        });
        final store = BackupStore(notesDb: notes, todoDb: todos);
        final snapshot = await store.snapshot();
        final encrypted = await BackupCodec.encrypt(
          snapshot,
          'synthetic review passphrase',
        );
        final decoded = await BackupCodec.decrypt(
          encrypted,
          'synthetic review passphrase',
        );
        expect(await store.restore(decoded, 'Tablet fixture import'), isTrue);
        final restored = await NoteService(database: notes).getAllActiveNotes();
        expect(restored, hasLength(2));
        expect(
          restored.every(
            (n) => n.richBody == saved.richBody && n.body == saved.body,
          ),
          isTrue,
        );
      } finally {
        await SystemChrome.setPreferredOrientations([]);
        await tester.pumpWidget(const SizedBox.shrink());
        if (notes.isOpen) await notes.close();
        if (todos.isOpen) await todos.close();
        await dir.delete(recursive: true);
      }
    },
  );
  registerAppJourney(binding);
  registerNotificationCases(binding);
  registerRecurrenceCases(binding);
  registerChecklistCases(binding);
  registerTaskTemplateCases(binding);
}
