import 'dart:io';

import 'package:bilga/core/strings.dart';
import 'package:bilga/features/agent/agent_access.dart';
import 'package:bilga/features/guidance/guide_host.dart';
import 'package:bilga/features/habits/habit_advanced_page.dart';
import 'package:bilga/features/habits/habit_statistics_page.dart';
import 'package:bilga/features/habits/habits_page.dart';
import 'package:bilga/features/habits/habit_store.dart';
import 'package:bilga/features/notes/note_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

class AdvancedHabitStore extends HabitStore {
  bool fail = false;
  AdvancedHabitStore(Database db) : super(provided: db);
  @override
  Future<void> configure(String id, String title, HabitPlan plan) async {
    if (fail) throw StateError('synthetic_configure_failure');
    await super.configure(id, title, plan);
  }
}

void registerAdvancedHabitUiCases({
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

  Future<void> tap(WidgetTester t, String key) async {
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
    await settle(t);
  }

  Future<void> enter(WidgetTester t, String key, String text) async {
    final f = find.byKey(Key(key));
    await t.ensureVisible(f);
    await settle(t);
    await t.tap(f);
    await t.enterText(f, text);
    await settle(t);
  }

  Future<(Directory, Database, AdvancedHabitStore, AgentAccess)> setup(
    WidgetTester t, {
    bool compact = false,
  }) async {
    final r = (await t.runAsync(() async {
      await Strings.load();
      if (!secure) SharedPreferences.setMockInitialValues({});
      final dir =
          await (createDirectory?.call() ??
              Directory.systemTemp.createTemp('bilga-advanced-habit-ui-'));
      final db = await NoteDatabase.openAt(
            '${dir.path}/notes.db',
            secure: secure,
          ),
          store = AdvancedHabitStore(db);
      await store.create(
        'Existing reading habit',
        id: 'habit',
        plan: HabitPlan(target: 10, unit: 'pages'),
      );
      final now = DateTime.now();
      await store.checkIn(
        'habit',
        DateTime(now.year, now.month, now.day - 1),
        10,
        note: 'Actual prior reading',
      );
      return (dir, db, store, AgentAccess()..owned.add(AgentAccess.core));
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
        home: HabitsPage(store: r.$3, access: r.$4),
      ),
    );
    await settle(t);
    return r;
  }

  Future<void> cleanup(
    WidgetTester t,
    (Directory, Database, AdvancedHabitStore, AgentAccess) r,
  ) async {
    await t.pumpWidget(const SizedBox.shrink());
    await settle(t);
    await t.runAsync(() async {
      await r.$2.close();
      await r.$1.delete(recursive: true);
    });
    r.$4.dispose();
  }

  Future<void> menu(WidgetTester t, String text) async {
    await tap(t, 'habit-menu-habit');
    await t.tap(find.text(Strings.get('en', text)).last);
    await settle(t);
  }

  testWidgets(
    'Advanced Habit settings persist quota/category/tags/goals and retain drafts through failed Save',
    (t) async {
      final r = await setup(t);
      try {
        await menu(t, 'haAdvanced');
        expect(find.byType(HabitAdvancedPage), findsOneWidget);
        await tap(t, 'habit-schedule-weekly');
        await enter(t, 'habit-advanced-quota', '3');
        await enter(t, 'habit-advanced-target', '20');
        await enter(t, 'habit-category', 'Learning');
        await enter(t, 'habit-tags', 'study, reading');
        await enter(t, 'habit-advanced-goal', '40');
        r.$3.fail = true;
        await tap(t, 'habit-advanced-save');
        expect(find.byType(HabitAdvancedPage), findsOneWidget);
        expect((await t.runAsync(() => r.$3.get('habit')))!.plan.target, 10);
        r.$3.fail = false;
        await tap(t, 'habit-advanced-save');
        expect(find.byType(HabitsPage), findsOneWidget);
        final h = (await t.runAsync(() => r.$3.get('habit')))!;
        expect(h.plan.schedule!.type, 'weekly');
        expect(h.plan.schedule!.quota, 3);
        expect(h.plan.target, 20);
        expect(h.plan.category, 'Learning');
        expect(h.plan.tags, {'study', 'reading'});
        expect(h.plan.goalTarget, 40);
        expect(h.days, hasLength(1));
        expect(h.plan.entries.values.single['target'], 10);
        await enter(t, 'habit-search', 'Learning');
        expect(find.text('Existing reading habit'), findsOneWidget);
        await enter(t, 'habit-search', 'No matching habit');
        expect(find.text('Existing reading habit'), findsNothing);
        expect(t.takeException(), isNull);
      } finally {
        await cleanup(t, r);
      }
    },
  );
  testWidgets(
    'Habit calendar guide edits a real day, waits for successful save, and future days earn no progress',
    (t) async {
      final r = await setup(t);
      try {
        await menu(t, 'haStatistics');
        expect(find.byType(HabitStatisticsPage), findsOneWidget);
        await t.tap(find.byIcon(Icons.help_outline));
        await settle(t);
        final guide = t
            .widget<GuideHost>(find.byType(GuideHost).last)
            .controller;
        expect(guide.index, 0);
        final today = DateTime.now();
        await tap(t, 'activity-day-${dayKey(today)}');
        expect(guide.index, 1);
        expect(guide.canBack, isFalse);
        final amount = find.byType(TextField).first;
        await t.ensureVisible(amount);
        await settle(t);
        await t.enterText(amount, '10');
        await settle(t);
        await tap(t, 'guide-next');
        expect(guide.index, 2);
        final host = t.widget<GuideHost>(find.byType(GuideHost).last);
        await t.tap(find.byKey(host.targets['save']!));
        await settle(t);
        expect(guide.index, 3);
        expect(guide.canBack, isFalse);
        expect(
          (await t.runAsync(() => r.$3.get('habit')))!
              .plan
              .entries[dayKey(today)]['amount'],
          10,
        );
        await tap(t, 'guide-next');
        final future = DateTime(today.year, today.month, today.day + 1);
        if (future.month != today.month) {
          await t.tap(find.byTooltip('Next month'));
          await settle(t);
        }
        await tap(t, 'activity-day-${dayKey(future)}');
        expect(
          t
              .widget<OutlinedButton>(
                find.byKey(const Key('habit-edit-selected-day')),
              )
              .onPressed,
          isNull,
        );
        expect(
          (await t.runAsync(() => r.$3.get('habit')))!.plan.entries
              .containsKey(dayKey(future)),
          isFalse,
        );
        expect(t.takeException(), isNull);
      } finally {
        await cleanup(t, r);
      }
    },
  );
  testWidgets(
    'Habit reminders require a chosen time and explicit successful Save; disabling persists',
    (t) async {
      final r = await setup(t);
      try {
        expect(
          (await t.runAsync(() => r.$3.get('habit')))!.plan.reminderMinute,
          isNull,
        );
        await menu(t, 'haAdvanced');
        await tap(t, 'habit-reminder-toggle');
        expect(find.byType(TimePickerDialog), findsOneWidget);
        await t.tap(find.text('OK'));
        await settle(t);
        expect(
          (await t.runAsync(() => r.$3.get('habit')))!.plan.reminderMinute,
          isNull,
        );
        await tap(t, 'habit-advanced-save');
        expect(
          (await t.runAsync(() => r.$3.get('habit')))!.plan.reminderMinute,
          inInclusiveRange(0, 1439),
        );
        await menu(t, 'haAdvanced');
        await tap(t, 'habit-reminder-toggle');
        await tap(t, 'habit-advanced-save');
        expect(
          (await t.runAsync(() => r.$3.get('habit')))!.plan.reminderMinute,
          isNull,
        );
        expect(t.takeException(), isNull);
      } finally {
        await cleanup(t, r);
      }
    },
  );
  if (includeCompact) {
    testWidgets(
      'Advanced Habit settings remain usable in 360px 2x RTL dark layout',
      (t) async {
        t.view.physicalSize = const Size(360, 800);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        final r = await setup(t, compact: true);
        try {
          await menu(t, 'haAdvanced');
          await tap(t, 'habit-schedule-monthly');
          await enter(t, 'habit-advanced-quota', '5');
          await enter(t, 'habit-advanced-goal', '30');
          await tap(t, 'habit-advanced-save');
          expect(
            (await t.runAsync(() => r.$3.get('habit')))!.plan.schedule!.type,
            'monthly',
          );
          expect(t.takeException(), isNull);
        } finally {
          await cleanup(t, r);
        }
      },
    );
  }
}
