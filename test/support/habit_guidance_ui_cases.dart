import 'settle_io.dart';
import 'guide_preference_guard.dart';

import 'dart:io';

import 'package:bilga/core/strings.dart';
import 'package:bilga/features/agent/agent_access.dart';
import 'package:bilga/features/guidance/guide_controller.dart';
import 'package:bilga/features/guidance/guide_host.dart';
import 'package:bilga/features/habits/habit_store.dart';
import 'package:bilga/features/habits/habits_page.dart';
import 'package:bilga/features/notes/note_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

class FailableHabitStore extends HabitStore {
  bool fail = false;
  FailableHabitStore(Database db) : super(provided: db);
  @override
  Future<void> create(String title, {String? id, HabitPlan? plan}) async {
    if (fail) throw StateError('synthetic_failure');
    await super.create(title, id: id, plan: plan);
  }
}

void registerHabitGuidanceUiCases({
  Future<Directory> Function()? createDirectory,
  bool secure = false,
  bool includeCompact = true,
}) {
  preserveGuidePreferences(secure, ['habit.create']);
  Future<void> settle(WidgetTester t) => settleIo(t);

  Future<void> tap(WidgetTester t, String key) async {
    final finder = find.byElementPredicate(
      (element) =>
          element.widget.key == Key(key) &&
          ModalRoute.of(element)?.isCurrent != false,
    );
    final deadline = Stopwatch()..start();
    while (finder.evaluate().length != 1 &&
        deadline.elapsed < const Duration(seconds: 10)) {
      await settle(t);
    }
    await t.ensureVisible(finder);
    await t.tap(finder);
    await settle(t);
  }

  Future<(Directory, Database, FailableHabitStore, AgentAccess)> setup(
    WidgetTester t, {
    bool compact = false,
  }) async {
    final result = (await t.runAsync(() async {
      await Strings.load();
      if (!secure) SharedPreferences.setMockInitialValues({});
      final dir =
          await (createDirectory?.call() ??
              Directory.systemTemp.createTemp('bilga-habit-guide-'));
      final db = await NoteDatabase.openAt(
        '${dir.path}/notes.db',
        secure: secure,
      );
      return (
        dir,
        db,
        FailableHabitStore(db),
        AgentAccess()..owned.add(AgentAccess.core),
      );
    }))!;
    await t.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        builder: (context, child) => compact
            ? MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: const TextScaler.linear(2)),
                child: Directionality(
                  textDirection: TextDirection.rtl,
                  child: child!,
                ),
              )
            : child!,
        home: HabitsPage(store: result.$3, access: result.$4),
      ),
    );
    await settle(t);
    return result;
  }

  Future<List<Habit>> read(WidgetTester t, HabitStore store) async =>
      (await t.runAsync(() => store.all(includeArchived: true)))!;
  Future<void> cleanup(WidgetTester t, Directory dir, Database db) async {
    await t.pumpWidget(const SizedBox());
    await settle(t);
    await t.runAsync(() async {
      await db.close();
      await dir.delete(recursive: true);
    });
  }

  GuideController guide(WidgetTester t) =>
      t.widget<GuideHost>(find.byType(GuideHost).last).controller;
  Future<void> start(WidgetTester t) async {
    await tap(t, 'habit-help');
    await tap(t, 'habit-guide-start');
  }

  Future<void> title(WidgetTester t, String value) async {
    final field = find.byKey(const Key('editor-field-title'));
    await t.ensureVisible(field);
    await t.enterText(field, value);
    await settle(t);
    if (find.byKey(const Key('guide-next')).evaluate().isNotEmpty) {
      expect(guide(t).step.id, 'title');
      await tap(t, 'guide-next');
    }
  }

  testWidgets(
    'Habit templates preview without writes, customize and save one independent habit',
    (t) async {
      final (dir, db, store, _) = await setup(t);
      try {
        await tap(t, 'habit-templates');
        await t.enterText(
          find.byKey(const Key('habit-template-search')),
          'water',
        );
        await settle(t);
        await tap(t, 'habit-template-water');
        expect(await read(t, store), isEmpty);
        await t.tap(find.text('Cancel').last);
        await settle(t);
        expect(await read(t, store), isEmpty);
        await tap(t, 'habit-template-water');
        await tap(t, 'habit-template-customize');
        expect(await read(t, store), isEmpty);
        await title(t, 'My chosen water target');
        await t.enterText(find.byKey(const Key('editor-field-target')), '3');
        await t.tap(find.text('Save').last);
        await settle(t);
        final h = (await read(t, store)).single;
        expect(h.title, 'My chosen water target');
        expect(h.plan.target, 3);
        expect(h.plan.unit, 'glasses');
        expect(h.days, isEmpty);
        expect(h.plan.entries, isEmpty);
      } finally {
        await cleanup(t, dir, db);
      }
    },
  );
  testWidgets(
    'Habit guide follows real fields, Back and Next; failed/expired saves retain draft then one retry persists',
    (t) async {
      final (dir, db, store, access) = await setup(t);
      try {
        await start(t);
        expect(guide(t).step.id, 'title');
        expect(find.byKey(const Key('guide-next')), findsNothing);
        await title(t, 'Guided reading');
        expect(guide(t).step.id, 'schedule');
        await tap(t, 'guide-back');
        expect(guide(t).step.id, 'title');
        await title(t, 'Guided reading habit');
        await tap(t, 'guide-next');
        expect(guide(t).step.id, 'target');
        await tap(t, 'guide-next');
        expect(guide(t).step.id, 'unit');
        await tap(t, 'guide-next');
        expect(guide(t).step.id, 'save');
        expect(await read(t, store), isEmpty);
        store.fail = true;
        await t.tap(find.text('Save').last);
        await settle(t);
        expect(guide(t).step.id, 'save');
        expect(await read(t, store), isEmpty);
        final draftTitle = find.byKey(const Key('editor-field-title'));
        for (var i = 0; i < 4; i++) {
          await tap(t, 'guide-back');
        }
        expect(guide(t).step.id, 'title');
        expect(
          t.widget<TextField>(draftTitle).controller!.text,
          'Guided reading habit',
        );
        for (var i = 0; i < 4; i++) {
          await tap(t, 'guide-next');
        }
        store.fail = false;
        access.owned.clear();
        await t.tap(find.text('Save').last);
        await settle(t);
        expect(guide(t).step.id, 'save');
        expect(await read(t, store), isEmpty);
        access.owned.add(AgentAccess.core);
        await t.tap(find.text('Save').last);
        await settle(t);
        expect((await read(t, store)).single.title, 'Guided reading habit');
        expect(guide(t).step.id, 'progress');
        expect(find.byKey(const Key('guide-back')), findsNothing);
        await tap(t, 'guide-next');
        expect(guide(t).active, false);
        expect(t.takeException(), isNull);
      } finally {
        await cleanup(t, dir, db);
      }
    },
  );
  testWidgets(
    'Skipping a guide leaves the real draft; Android Back confirms discard without inserting',
    (t) async {
      final (dir, db, store, _) = await setup(t);
      try {
        await start(t);
        await title(t, 'Unsaved draft');
        await tap(t, 'guide-skip');
        expect(find.text('Unsaved draft'), findsOneWidget);
        expect(await read(t, store), isEmpty);
        await t.binding.handlePopRoute();
        await settle(t);
        await t.tap(find.text('Continue').last);
        await settle(t);
        expect(find.byKey(const Key('habit-add')), findsOneWidget);
        expect(await read(t, store), isEmpty);
        expect(t.takeException(), isNull);
      } finally {
        await cleanup(t, dir, db);
      }
    },
  );
  if (includeCompact) {
    testWidgets(
      'Habit guide stays usable on 360px 2x RTL dark layout with keyboard',
      (t) async {
        t.view.physicalSize = const Size(360, 800);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        final (dir, db, store, _) = await setup(t, compact: true);
        try {
          await start(t);
          await title(t, 'Compact habit');
          await tap(t, 'guide-next');
          await tap(t, 'guide-next');
          await tap(t, 'guide-next');
          await t.tap(find.text('Save').last);
          await settle(t);
          expect((await read(t, store)).single.title, 'Compact habit');
          await tap(t, 'guide-exit');
          expect(t.takeException(), isNull);
        } finally {
          await cleanup(t, dir, db);
        }
      },
    );
  }
}
