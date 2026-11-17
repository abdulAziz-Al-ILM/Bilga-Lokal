import 'settle_io.dart';
import 'guide_preference_guard.dart';

import 'dart:io';

import 'package:bilga/core/strings.dart';
import 'package:bilga/features/agent/agent_access.dart';
import 'package:bilga/features/books/book_library_page.dart';
import 'package:bilga/features/collections/collection_page.dart';
import 'package:bilga/features/collections/collection_repository.dart';
import 'package:bilga/features/experiences/experiences_page.dart';
import 'package:bilga/features/finance/finance_page.dart';
import 'package:bilga/features/guidance/help_hub.dart';
import 'package:bilga/features/guidance/guide_host.dart';
import 'package:bilga/features/guidance/module_help.dart';
import 'package:bilga/features/habits/habit_store.dart';
import 'package:bilga/features/habits/habits_page.dart';
import 'package:bilga/features/notes/note_database.dart';
import 'package:bilga/features/private_space/record_store.dart';
import 'package:bilga/features/todo/todo_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import 'rich_editor_input.dart';

void registerHelpHubUiCases({
  Future<Directory> Function()? createDirectory,
  bool secure = false,
  bool includeCompact = true,
}) {
  preserveGuidePreferences(secure, [
    'notes.create',
    'tasks.create',
    'habit.create',
    'finance.journal',
    'finance.category',
    'experience.create',
    'book.import',
  ]);
  Future<void> settle(WidgetTester t) => settleIo(t);

  Future<void> tap(WidgetTester t, Finder f) async {
    if (f.evaluate().isEmpty) {
      await t.scrollUntilVisible(
        f,
        250,
        scrollable: find
            .byWidgetPredicate(
              (w) =>
                  w is Scrollable &&
                  (w.axisDirection == AxisDirection.down ||
                      w.axisDirection == AxisDirection.up),
            )
            .first,
        maxScrolls: 50,
      );
    } else {
      await t.ensureVisible(f);
    }
    await settle(t);
    await t.tap(f);
    await settle(t);
  }

  Future<void> key(WidgetTester t, String id) => tap(t, find.byKey(Key(id)));
  Future<(Directory, Database, Database, AgentAccess)> setup(
    WidgetTester t, {
    bool compact = false,
  }) async {
    final r = (await t.runAsync(() async {
      await Strings.load();
      if (!secure) SharedPreferences.setMockInitialValues({});
      final dir =
          await (createDirectory?.call() ??
              Directory.systemTemp.createTemp('bilga-help-hub-'));
      final notes = await NoteDatabase.openAt(
            '${dir.path}/notes.db',
            secure: secure,
          ),
          tasks = await TodoDatabase.openAt(
            '${dir.path}/tasks.db',
            secure: secure,
          );
      return (
        dir,
        notes,
        tasks,
        AgentAccess()..owned.addAll([AgentAccess.core, AgentAccess.finance]),
      );
    }))!;
    Widget route(String id, bool tutorial) => switch (id) {
      'notes' => CollectionPage(
        kind: CollectionKind.notes,
        repository: CollectionRepository(CollectionKind.notes, provided: r.$2),
        tutorial: tutorial,
      ),
      'tasks' => CollectionPage(
        kind: CollectionKind.todos,
        repository: CollectionRepository(CollectionKind.todos, provided: r.$3),
        tutorial: tutorial,
      ),
      'habits' => HabitsPage(
        store: HabitStore(provided: r.$2),
        access: r.$4,
        tutorial: tutorial,
      ),
      'finance' => FinancePage(
        store: RecordStore(database: r.$2),
        access: r.$4,
        tutorial: tutorial,
      ),
      'experiences' => ExperiencesPage(
        records: RecordStore(database: r.$2),
        access: r.$4,
        tutorial: tutorial,
      ),
      'books' => BookLibraryPage(
        records: RecordStore(database: r.$2),
        access: r.$4,
        tutorial: tutorial,
      ),
      _ => throw StateError('module'),
    };
    await t.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        builder: (c, child) => compact
            ? MediaQuery(
                data: MediaQuery.of(c)
                    .copyWith(textScaler: TextScaler.linear(2)),
                child: Directionality(
                  textDirection: TextDirection.rtl,
                  child: child!,
                ),
              )
            : child!,
        home: HelpHubPage(openModule: route),
      ),
    );
    await settle(t);
    return r;
  }

  Future<void> cleanup(
    WidgetTester t,
    (Directory, Database, Database, AgentAccess) r,
  ) async {
    await t.pumpWidget(const SizedBox.shrink());
    await settle(t);
    await t.runAsync(() async {
      await r.$2.close();
      await r.$3.close();
      await r.$1.delete(recursive: true);
    });
    r.$4.dispose();
  }

  Future<void> empty(
    WidgetTester t,
    (Directory, Database, Database, AgentAccess) r,
  ) async {
    final counts = (await t.runAsync(
      () async => [
        for (final table in ['notes', 'habits', 'private_records'])
          Sqflite.firstIntValue(
            await r.$2.rawQuery('SELECT count(*) FROM $table'),
          ),
        Sqflite.firstIntValue(
          await r.$3.rawQuery('SELECT count(*) FROM todos'),
        ),
      ],
    ))!;
    expect(counts, [0, 0, 0, 0]);
  }

  testWidgets(
    'Help Hub searches translated purpose/examples and opens all six real guided modules without creating records',
    (t) async {
      final r = await setup(t);
      try {
        await t.enterText(find.byKey(const Key('help-search')), 'quota');
        await settle(t);
        expect(find.byKey(const Key('help-article-habits')), findsOneWidget);
        expect(find.byKey(const Key('help-article-finance')), findsNothing);
        await t.enterText(
          find.byKey(const Key('help-search')),
          'no-such-help-token',
        );
        await settle(t);
        expect(find.text(Strings.get('en', 'helpNoResults')), findsOneWidget);
        await t.enterText(find.byKey(const Key('help-search')), '');
        await settle(t);
        for (final info in moduleHelp) {
          await key(t, 'help-tutorial-${info.id}');
          final guides = t
              .widgetList<GuideHost>(find.byType(GuideHost))
              .map((h) => h.controller)
              .where((g) => g.active)
              .toList();
          expect(guides, isNotEmpty, reason: info.id);
          await key(t, 'guide-exit');
          if (info.id == 'habits') {
            await t.pageBack();
            await settle(t);
          }
          await t.pageBack();
          await settle(t);
          expect(find.byType(HelpHubPage), findsOneWidget);
          await empty(t, r);
        }
        expect(t.takeException(), isNull);
      } finally {
        await cleanup(t, r);
      }
    },
  );
  testWidgets(
    'Notes guide uses real rich editor, preserves autosave, and advances only after successful confirmation',
    (t) async {
      final r = await setup(t);
      try {
        await key(t, 'help-tutorial-notes');
        var guide = t
            .widget<GuideHost>(find.byType(GuideHost).first)
            .controller;
        await tap(t, find.byType(FloatingActionButton));
        expect(guide.step.id, 'title');
        await t.enterText(
          find.byKey(const Key('note-title')),
          'Actual guided thought',
        );
        await settle(t);
        await key(t, 'guide-next');
        expect(guide.step.id, 'body');
        await enterNoteBody(t, 'My own reflection.');
        await settle(t);
        await key(t, 'guide-next');
        expect(guide.step.id, 'save');
        // Existing autosave must remain real, rather than being disabled for the tour.
        expect(
          (await t.runAsync(() => r.$2.query('notes')))!.single['body'],
          'My own reflection.',
        );
        await tap(t, find.byTooltip(Strings.get('en', 'save')));
        expect(guide.step.id, 'results');
        expect(guide.canBack, isFalse);
        expect(
          (await t.runAsync(() => r.$2.query('notes')))!.single['title'],
          'Actual guided thought',
        );
        await key(t, 'guide-next');
        expect(guide.active, isFalse);
        expect(t.takeException(), isNull);
      } finally {
        await cleanup(t, r);
      }
    },
  );
  testWidgets(
    'Task guide detects a real failed Save, retains the draft and creates exactly one task on retry',
    (t) async {
      final r = await setup(t);
      try {
        await key(t, 'help-tutorial-tasks');
        var guide = t
            .widget<GuideHost>(find.byType(GuideHost).first)
            .controller;
        await tap(t, find.byType(FloatingActionButton));
        expect(guide.step.id, 'title');
        final title = find.byWidgetPredicate(
          (w) =>
              w is TextField &&
              w.decoration?.labelText == Strings.get('en', 'title'),
        );
        await t.enterText(title, 'A real next action');
        await settle(t);
        await key(t, 'guide-next');
        await key(t, 'guide-next');
        expect(guide.step.id, 'save');
        await t.runAsync(
          () => r.$3.execute(
            "CREATE TRIGGER reject_guided_task BEFORE INSERT ON todos BEGIN SELECT RAISE(ABORT,'synthetic_failure'); END",
          ),
        );
        await tap(t, find.byTooltip(Strings.get('en', 'save')));
        expect(guide.step.id, 'save');
        expect((await t.runAsync(() => r.$3.query('todos')))!, isEmpty);
        await t.runAsync(() => r.$3.execute('DROP TRIGGER reject_guided_task'));
        await tap(t, find.byTooltip(Strings.get('en', 'save')));
        expect(guide.step.id, 'results');
        expect(guide.canBack, isFalse);
        expect(
          (await t.runAsync(() => r.$3.query('todos')))!.single['title'],
          'A real next action',
        );
        await key(t, 'guide-next');
        expect(guide.active, isFalse);
        expect(t.takeException(), isNull);
      } finally {
        await cleanup(t, r);
      }
    },
  );
  if (includeCompact) {
    testWidgets(
      'Help articles and module guidance remain usable at 360px 2x RTL dark layout',
      (t) async {
        t.view.physicalSize = const Size(360, 800);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        final r = await setup(t, compact: true);
        try {
          await key(t, 'help-article-notes');
          await key(t, 'help-guide-notes');
          await key(t, 'guide-skip');
          await key(t, 'collection-module-help');
          await key(t, 'module-help-tutorial');
          expect(find.byKey(const Key('guide-exit')), findsOneWidget);
          await key(t, 'guide-exit');
          await empty(t, r);
          expect(t.takeException(), isNull);
        } finally {
          await cleanup(t, r);
        }
      },
    );
  }
}
