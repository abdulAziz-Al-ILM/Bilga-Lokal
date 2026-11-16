import 'dart:io';

import 'package:bilga/core/strings.dart';
import 'package:bilga/features/agent/agent_access.dart';
import 'package:bilga/features/experiences/experience_editor.dart';
import 'package:bilga/features/experiences/experience_page.dart';
import 'package:bilga/features/experiences/experiences_page.dart';
import 'package:bilga/features/experiences/experience_store.dart';
import 'package:bilga/features/experiences/experience_templates.dart';
import 'package:bilga/features/guidance/guide_host.dart';
import 'package:bilga/features/guidance/guide_controller.dart';
import 'package:bilga/features/notes/note_database.dart';
import 'package:bilga/features/todo/todo_database.dart';
import 'package:bilga/features/private_space/record_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

class FailableExperienceRecords extends RecordStore {
  bool fail = false;
  FailableExperienceRecords(Database db) : super(database: db);
  @override
  Future<PrivateRecord> save(
    String kind,
    Map<String, dynamic> data, {
    PrivateRecord? previous,
  }) async {
    if (fail) throw StateError('synthetic_save_failure');
    return super.save(kind, data, previous: previous);
  }
}

void registerExperienceUiCases({
  Future<Directory> Function()? createDirectory,
  bool secure = false,
  bool includeCompact = true,
}) {
  Future<void> settle(WidgetTester t) async {
    for (var i = 0; i < 25; i++) {
      await t.pump(const Duration(milliseconds: 40));
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 15)),
      );
    }
    await t.pumpAndSettle();
  }

  Future<void> tap(WidgetTester t, String key, {double direction = 300}) async {
    final f = find.byKey(Key(key));
    if (f.evaluate().isEmpty) {
      await t.scrollUntilVisible(
        f,
        direction,
        scrollable: find.byType(Scrollable).first,
        maxScrolls: 40,
      );
    } else {
      await t.ensureVisible(f);
    }
    await settle(t);
    await t.tap(f);
    await settle(t);
  }

  Future<void> enter(WidgetTester t, String key, String text) async {
    final f = find.byKey(Key(key));
    if (f.evaluate().isEmpty) {
      await t.scrollUntilVisible(
        f,
        300,
        scrollable: find.byType(Scrollable).first,
        maxScrolls: 40,
      );
    } else {
      await t.ensureVisible(f);
    }
    await settle(t);
    await t.tap(f);
    await t.enterText(f, text);
    await settle(t);
  }

  Future<
    (
      Directory,
      Database,
      Database,
      ExperienceStore,
      FailableExperienceRecords,
      AgentAccess,
    )
  >
  setup(WidgetTester t, {bool compact = false}) async {
    final r = (await t.runAsync(() async {
      await Strings.load();
      if (!secure) SharedPreferences.setMockInitialValues({});
      final dir =
          await (createDirectory?.call() ??
              Directory.systemTemp.createTemp('bilga-experience-ui-'));
      final notes = await NoteDatabase.openAt(
            '${dir.path}/notes.db',
            secure: secure,
          ),
          tasks = await TodoDatabase.openAt(
            '${dir.path}/tasks.db',
            secure: secure,
          );
      final records = FailableExperienceRecords(notes);
      return (
        dir,
        notes,
        tasks,
        ExperienceStore(records: records, tasks: tasks),
        records,
        AgentAccess()..owned.add(AgentAccess.core),
      );
    }))!;
    await t.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        builder: (c, child) => compact
            ? MediaQuery(
                data: MediaQuery.of(c)
                    .copyWith(textScaler: const TextScaler.linear(2)),
                child: Directionality(
                  textDirection: TextDirection.rtl,
                  child: child!,
                ),
              )
            : child!,
        home: ExperiencesPage(store: r.$4, access: r.$6),
      ),
    );
    await settle(t);
    return r;
  }

  Future<void> cleanup(
    WidgetTester t,
    (
      Directory,
      Database,
      Database,
      ExperienceStore,
      FailableExperienceRecords,
      AgentAccess,
    )
    r,
  ) async {
    await t.pumpWidget(const SizedBox.shrink());
    await settle(t);
    await t.runAsync(() async {
      await r.$2.close();
      await r.$3.close();
      await r.$1.delete(recursive: true);
    });
    r.$6.dispose();
  }

  GuideController guide(WidgetTester t) =>
      t.widget<GuideHost>(find.byType(GuideHost).last).controller;
  testWidgets(
    'Experiences guide uses a real draft, waits through failed Save, then opens actual saved results',
    (t) async {
      final r = await setup(t);
      try {
        await tap(t, 'experience-help');
        await t.tap(
          find.widgetWithText(FilledButton, Strings.get('en', 'continue')),
        );
        await settle(t);
        expect(guide(t).index, 0);
        await tap(t, 'experience-create');
        expect(find.byType(ExperienceEditor), findsOneWidget);
        expect(guide(t).index, 1);
        await enter(t, 'experience-title', 'Real reflection');
        await tap(t, 'guide-next');
        expect(guide(t).index, 2);
        await enter(t, 'experience-body', 'A useful event from today.');
        expect(guide(t).canNext, isTrue);
        await tap(t, 'guide-next');
        expect(guide(t).index, 3);
        r.$5.fail = true;
        await tap(t, 'experience-save');
        expect(guide(t).index, 3);
        expect(find.byType(ExperienceEditor), findsOneWidget);
        expect(await t.runAsync(() => r.$5.all('experience')), isEmpty);
        r.$5.fail = false;
        await tap(t, 'experience-save');
        expect(find.byType(ExperiencePage), findsOneWidget);
        expect(guide(t).index, 4);
        expect(guide(t).canBack, isFalse);
        expect(
          (await t.runAsync(() => r.$5.all('experience')))!.single.data['body'],
          'A useful event from today.',
        );
        await tap(t, 'guide-next');
        expect(guide(t).active, isFalse);
        expect(t.takeException(), isNull);
      } finally {
        await cleanup(t, r);
      }
    },
  );
  testWidgets(
    'Experiment editing keeps history; restore is a new version; follow-up creates one real Task',
    (t) async {
      final r = await setup(t);
      try {
        await tap(t, 'experience-create');
        await enter(t, 'experience-title', 'Small experiment');
        await t.ensureVisible(
          find.widgetWithText(ChoiceChip, Strings.get('en', 'eExperiment')),
        );
        await settle(t);
        await t.tap(
          find.widgetWithText(ChoiceChip, Strings.get('en', 'eExperiment')),
        );
        await settle(t);
        await enter(t, 'experience-body', '  Original observation.\n');
        await enter(t, 'experience-next', 'Try a second session');
        await enter(t, 'experience-hypothesis', 'One change will help.');
        await enter(t, 'experience-method', 'Compare two actual sessions.');
        await enter(t, 'experience-result', 'Observed a useful result.');
        await tap(t, 'experience-save');
        expect(find.byType(ExperiencePage), findsOneWidget);
        await tap(t, 'experience-edit');
        await enter(t, 'experience-body', 'Second saved version');
        await tap(t, 'experience-save');
        final entry = (await t.runAsync(() => r.$5.all('experience')))!.single;
        expect(entry.revision, 2);
        await tap(t, 'experience-history');
        await t.tap(find.text('${Strings.get('en', 'eRevision')} 1'));
        await settle(t);
        await t.tap(
          find.widgetWithText(FilledButton, Strings.get('en', 'restore')),
        );
        await settle(t);
        expect((await t.runAsync(() => r.$5.get(entry.id)))!.revision, 3);
        expect(
          (await t.runAsync(() => r.$5.get(entry.id)))!.data['body'],
          '  Original observation.\n',
        );
        await tap(t, 'experience-task');
        expect(find.text('Try a second session'), findsWidgets);
        await t.tap(find.widgetWithText(TextButton, Strings.get('en', 'save')));
        await settle(t);
        final tasks = (await t.runAsync(() => r.$3.query('todos')))!;
        expect(tasks, hasLength(1));
        expect(tasks.single['title'], 'Try a second session');
        expect((await t.runAsync(() => r.$4.history(entry.id)))!, hasLength(3));
        expect(t.takeException(), isNull);
      } finally {
        await cleanup(t, r);
      }
    },
  );
  testWidgets(
    'Twelve practical template previews and cancellation never create personal entries',
    (t) async {
      final r = await setup(t);
      try {
        expect(experienceTemplates, hasLength(12));
        await tap(t, 'experience-templates');
        await t.tap(find.text(Strings.get('en', 'eTemplate_daily')));
        await settle(t);
        expect(
          find.textContaining(Strings.get('en', 'ePrompt_body')),
          findsOneWidget,
        );
        await t.tap(
          find.widgetWithText(TextButton, Strings.get('en', 'cancel')),
        );
        await settle(t);
        await tap(t, 'experience-template-close');
        await settle(t);
        expect(await t.runAsync(() => r.$5.all('experience')), isEmpty);
        await tap(t, 'experience-calendar');
        expect(find.byType(ExperiencesPage), findsOneWidget);
        expect(t.takeException(), isNull);
      } finally {
        await cleanup(t, r);
      }
    },
  );
  if (includeCompact) {
    testWidgets(
      'Experiences purpose, actions and calendar remain usable in compact 2x RTL dark layout',
      (t) async {
        t.view.physicalSize = const Size(360, 800);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        final r = await setup(t, compact: true);
        try {
          await tap(t, 'experience-calendar');
          await tap(t, 'experience-create', direction: -300);
          expect(find.byType(ExperienceEditor), findsOneWidget);
          await enter(t, 'experience-title', 'Compact entry');
          await enter(t, 'experience-body', 'Readable reflection');
          await tap(t, 'experience-save');
          expect(find.byType(ExperiencePage), findsOneWidget);
          expect(t.takeException(), isNull);
        } finally {
          await cleanup(t, r);
        }
      },
    );
  }
}
