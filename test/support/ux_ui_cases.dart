import 'dart:io';

import 'package:bilga/core/strings.dart';
import 'package:bilga/features/agent/agent_access.dart';
import 'package:bilga/features/finance/finance_page.dart';
import 'package:bilga/features/habits/habit_store.dart';
import 'package:bilga/features/habits/habits_page.dart';
import 'package:bilga/features/notes/note_database.dart';
import 'package:bilga/features/private_space/record_store.dart';
import 'package:bilga/features/voice/voice_answer_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import 'settle_io.dart';

void registerUxUiCases({
  Future<Directory> Function()? fixture,
  bool secure = false,
}) {
  Future<(Directory, Database)> setup(WidgetTester tester) async =>
      (await tester.runAsync(() async {
        await Strings.load();
        final dir =
            await (fixture?.call() ??
                Directory.systemTemp.createTemp('bilga-ux-ui-'));
        return (
          dir,
          await NoteDatabase.openAt('${dir.path}/notes.db', secure: secure),
        );
      }))!;
  Future<void> cleanup(WidgetTester tester, Directory dir, Database db) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await settleIo(tester);
    await tester.runAsync(() async {
      await db.close();
      await dir.delete(recursive: true);
    });
  }

  Future<void> tap(WidgetTester tester, Finder element) async {
    await tester.ensureVisible(element);
    await tester.pump();
    await tester.tap(element);
    await settleIo(tester);
  }

  testWidgets(
    'Habit tile exposes exact progress ratio and allows correction above target',
    (tester) async {
      final (dir, db) = await setup(tester);
      final store = HabitStore(provided: db);
      final access = AgentAccess()..owned.add(AgentAccess.core);
      try {
        await tester.runAsync(() async {
          await store.create(
            'Push ups',
            id: 'exercise',
            plan: HabitPlan(target: 12, unit: 'reps'),
          );
          await store.checkIn('exercise', DateTime.now(), 11);
        });
        await tester.pumpWidget(
          MaterialApp(
            home: HabitsPage(store: store, access: access),
          ),
        );
        await settleIo(tester);
        final amount = find.byKey(const Key('habit-quantity-exercise'));
        final progress = find.byKey(const Key('habit-progress-exercise'));
        expect(tester.widget<Text>(amount).data, '11 / 12 reps');
        expect(
          tester.widget<LinearProgressIndicator>(progress).value,
          closeTo(11 / 12, .00001),
        );
        await tap(tester, find.byKey(const Key('habit-plus-exercise')));
        await tap(tester, find.byKey(const Key('habit-plus-exercise')));
        expect(tester.widget<Text>(amount).data, '13 / 12 reps');
        expect(tester.widget<LinearProgressIndicator>(progress).value, 1);
        await tap(tester, find.byKey(const Key('habit-minus-exercise')));
        expect(tester.widget<Text>(amount).data, '12 / 12 reps');
      } finally {
        await cleanup(tester, dir, db);
        access.dispose();
      }
    },
  );

  testWidgets(
    'Simple expense creates a category and an exact transaction together only on Save',
    (tester) async {
      final (dir, db) = await setup(tester);
      final store = RecordStore(database: db);
      final access = AgentAccess()..owned.add(AgentAccess.core);
      try {
        final ledger = (await tester.runAsync(
          () => store.save('finance', {
            'title': 'Travel journal',
            'currency': 'USD',
            'entries': [],
          }),
        ))!;
        await tester.pumpWidget(
          MaterialApp(
            home: FinancePage(store: store, access: access),
          ),
        );
        await settleIo(tester);
        await tap(tester, find.byKey(const Key('finance-add-expense')));
        expect(find.byType(DropdownButtonFormField<String>), findsNothing);
        await tester.enterText(
          find.byKey(const Key('editor-field-amount')),
          '12.34',
        );
        await settleIo(tester);
        await tap(tester, find.byKey(const Key('finance-quick-category')));
        await tap(tester, find.text('Create category').last);
        await tester.enterText(
          find.byKey(const Key('editor-field-name')),
          'Food on trips',
        );
        await tap(tester, find.text('Save').last);
        expect(
          (await tester.runAsync(() => store.get(ledger.id)))!.data['entries'],
          isEmpty,
        );
        await tap(tester, find.text('Save').last);
        final saved = (await tester.runAsync(() => store.get(ledger.id)))!;
        expect(saved.data['entries'].single['amount'], 1234);
        expect(saved.data['entries'].single['category'], 'Food on trips');
        expect(
          saved.data['planning']['categories'].single['name'],
          'Food on trips',
        );
      } finally {
        await cleanup(tester, dir, db);
        access.dispose();
      }
    },
  );

  if (!secure) {
    testWidgets(
      'Speech output keeps real text available when the selected language has no installed voice',
      (tester) async {
        const channel = MethodChannel('bilga/speech_output');
        final calls = <MethodCall>[];
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        messenger.setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          if (call.method == 'speak') throw PlatformException(code: 'language');
          return null;
        });
        addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
        await tester.pumpWidget(
          const MaterialApp(
            home: VoiceAnswerPage(
              title: 'A response',
              language: 'uz-UZ',
              excerpts: ['Only a standalone answer.', 'A second excerpt.'],
            ),
          ),
        );
        await settleIo(tester);
        expect(calls.first.arguments['language'], 'uz-UZ');
        expect(find.text('Only a standalone answer.'), findsOneWidget);
        expect(find.textContaining('no installed voice'), findsOneWidget);
        await tap(tester, find.text('Continue'));
        expect(calls.any((call) => call.method == 'stop'), true);
        expect(calls.last.arguments['text'], 'A second excerpt.');
        expect(
          calls
              .where((call) => call.method == 'speak')
              .every((call) => call.arguments['language'] == 'uz-UZ'),
          true,
        );
        await tester.pumpWidget(const SizedBox.shrink());
        await settleIo(tester);
        expect(calls.last.method, 'stop');
      },
    );
  }
}
