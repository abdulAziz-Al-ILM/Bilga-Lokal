import 'dart:async';
import 'dart:io';

import 'package:bilga/core/strings.dart';
import 'package:bilga/features/voice/voice_page.dart';
import 'package:bilga/features/voice/voice_actions.dart';
import 'package:bilga/features/voice/speech_bridge.dart';
import 'package:bilga/features/agent/agent_access.dart';
import 'package:bilga/features/notes/note_database.dart';
import 'package:bilga/features/todo/todo_database.dart';
import 'package:bilga/features/notes/note_editor_page.dart';
import 'package:bilga/features/experiences/experience_editor.dart';
import 'package:bilga/features/experiences/experience_page.dart';
import 'package:bilga/features/private_space/record_store.dart';
import 'package:bilga/features/private_space/space_page.dart';
import 'package:bilga/features/search/library_page.dart';
import 'package:bilga/features/habits/habit_store.dart';
import 'package:bilga/features/habits/habit_statistics_page.dart';
import 'package:bilga/features/books/reading/reading_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import 'settle_io.dart';

class ControlledSpeech extends SpeechBridge {
  final calls = <String>[];
  final followUps = <bool>[];
  Completer<String?>? pending;
  bool available = true;
  @override
  Future<Map<String, dynamic>> state() async {
    calls.add('state');
    return {'available': available, 'onDevice': available};
  }

  @override
  Future<String?> listen({
    required String language,
    required bool onDevice,
    bool followUp = false,
  }) {
    calls.add('listen:$language:$onDevice');
    followUps.add(followUp);
    pending = Completer<String?>();
    return pending!.future;
  }

  @override
  Future<void> stop() async {
    calls.add('stop');
  }

  @override
  Future<void> cancel() async {
    calls.add('cancel');
  }
}

void registerVoiceUiCases({
  Future<Directory> Function()? createDirectory,
  bool secure = false,
  bool includeCompact = true,
}) {
  Future<void> tap(WidgetTester t, Finder f) async {
    if (f.evaluate().isEmpty) {
      await t.scrollUntilVisible(
        f,
        250,
        scrollable: find.byType(Scrollable).first,
        maxScrolls: 50,
      );
    } else {
      await t.ensureVisible(f);
    }
    await settleIo(t);
    await t.tap(f);
    await settleIo(t);
  }

  Future<void> key(WidgetTester t, String id) => tap(t, find.byKey(Key(id)));
  Future<void> field(WidgetTester t, String label, String value) async {
    final f = find.byWidgetPredicate(
      (w) => w is TextField && w.decoration?.labelText == label,
    );
    await tap(t, f);
    await t.enterText(f, value);
    await settleIo(t);
  }

  Future<(Directory, Database, Database, AgentAccess, ControlledSpeech)> setup(
    WidgetTester t, {
    bool compact = false,
  }) async {
    final r = (await t.runAsync(() async {
      await Strings.load();
      if (!secure) SharedPreferences.setMockInitialValues({});
      final dir =
          await (createDirectory?.call() ??
              Directory.systemTemp.createTemp('bilga-voice-ui-'));
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
        ControlledSpeech(),
      );
    }))!;
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
        home: VoicePage(
          speech: r.$5,
          actions: VoiceActions(notesDb: r.$2, tasksDb: r.$3, access: r.$4),
        ),
      ),
    );
    await settleIo(t);
    return r;
  }

  Future<void> cleanup(
    WidgetTester t,
    (Directory, Database, Database, AgentAccess, ControlledSpeech) r,
  ) async {
    await t.pumpWidget(const SizedBox.shrink());
    await settleIo(t);
    await t.runAsync(() async {
      await r.$2.close();
      await r.$3.close();
      await r.$1.delete(recursive: true);
    });
    r.$4.dispose();
  }

  Future<void> command(WidgetTester t, String value) async {
    await field(t, Strings.get('en', 'voicePreview'), value);
    await key(t, 'voice-review');
    await key(t, 'voice-execute');
  }

  testWidgets(
    'Push-to-talk never starts on open, cancellation ignores late recognition, and text stays editable',
    (t) async {
      final r = await setup(t);
      try {
        expect(r.$5.calls, ['state']);
        await field(
          t,
          Strings.get('en', 'voicePreview'),
          'Existing corrected command',
        );
        await key(t, 'voice-listen');
        expect(r.$5.calls, contains('listen:uz-UZ:true'));
        await key(t, 'voice-cancel-listen');
        r.$5.pending!.complete('xarajat yoz 50000 UZS');
        await settleIo(t);
        expect(
          t
              .widget<TextField>(find.byKey(const Key('voice-transcript')))
              .controller!
              .text,
          'Existing corrected command',
        );
        expect(
          (await t.runAsync(() => r.$2.query('private_records')))!,
          isEmpty,
        );
        expect((await t.runAsync(() => r.$2.query('notes')))!, isEmpty);
        await key(t, 'voice-review');
        expect(find.byKey(const Key('voice-execute')), findsNothing);
        expect(t.takeException(), isNull);
      } finally {
        await cleanup(t, r);
      }
    },
  );

  const output = MethodChannel('bilga/speech_output');
  void mockOutput(Future<Object?> Function(MethodCall) handler) {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(output, handler);
    addTearDown(() => messenger.setMockMethodCallHandler(output, null));
  }

  testWidgets(
    'Conversation waits for playback, then accepts another question and stops on silence',
    (t) async {
      final playback = Completer<void>();
      final spoken = <String>[];
      mockOutput((call) async {
        if (call.method != 'speak') return null;
        spoken.add(call.arguments['text'] as String);
        expect(call.arguments['language'], 'uz-UZ');
        if (spoken.length == 1) await playback.future;
        if (spoken.length == 2) throw PlatformException(code: 'language');
        return null;
      });
      final r = await setup(t);
      try {
        await key(t, 'voice-conversation');
        expect(r.$5.followUps, [false]);
        r.$5.pending!.complete('Bugun nima qilishim kerak?');
        await settleIo(t);
        expect(
          spoken.single,
          contains('${Strings.get('uz', 'todayPlan')} · 0'),
        );
        expect(r.$5.followUps, [false]);
        playback.complete();
        await settleIo(t);
        expect(r.$5.followUps, [false, true]);
        r.$5.pending!.complete('Bu hafta qancha sarfladim?');
        await settleIo(t);
        expect(spoken, hasLength(2));
        expect(r.$5.followUps, [false, true, true]);
        expect(find.text(Strings.get('en', 'vaNoVoice')), findsOneWidget);
        r.$5.pending!.completeError(PlatformException(code: 'no_speech'));
        await settleIo(t);
        expect(r.$5.followUps, [false, true, true]);
        expect(
          find.text(Strings.get('en', 'voiceConversationStart')),
          findsOneWidget,
        );
        expect(find.text(Strings.get('en', 'voiceNoSpeech')), findsOneWidget);
        expect(find.text(Strings.get('en', 'vaNoVoice')), findsOneWidget);
      } finally {
        await cleanup(t, r);
      }
    },
  );

  testWidgets(
    'Conversation asks for system provider consent and stops at a financial draft',
    (t) async {
      final r = await setup(t);
      try {
        await key(t, 'voice-device-only');
        await key(t, 'voice-conversation');
        expect(r.$5.followUps, isEmpty);
        await tap(
          t,
          find.widgetWithText(FilledButton, Strings.get('en', 'continue')),
        );
        expect(r.$5.followUps, [false]);
        expect(r.$5.calls.last, 'listen:uz-UZ:false');
        r.$5.pending!.complete('xarajat yoz 50000 UZS');
        await settleIo(t);
        expect(find.byKey(const Key('voice-execute')), findsOneWidget);
        expect(
          find.text(Strings.get('en', 'voiceConversationStart')),
          findsOneWidget,
        );
        expect(r.$5.followUps, [false]);
        expect(
          (await t.runAsync(() => r.$2.query('private_records')))!,
          isEmpty,
        );
      } finally {
        await cleanup(t, r);
      }
    },
  );

  testWidgets(
    'Leaving the foreground stops an active answer and never reopens the mic',
    (t) async {
      final playback = Completer<void>();
      final outputCalls = <String>[];
      mockOutput((call) async {
        outputCalls.add(call.method);
        if (call.method == 'speak') await playback.future;
        return null;
      });
      final r = await setup(t);
      try {
        await key(t, 'voice-conversation');
        r.$5.pending!.complete('Bugun nima qilishim kerak?');
        await settleIo(t);
        expect(outputCalls, ['speak']);
        for (final state in [
          AppLifecycleState.inactive,
          AppLifecycleState.hidden,
          AppLifecycleState.paused,
          AppLifecycleState.hidden,
          AppLifecycleState.inactive,
          AppLifecycleState.resumed,
        ]) {
          t.binding.handleAppLifecycleStateChanged(state);
        }
        await settleIo(t);
        expect(outputCalls, ['speak', 'stop']);
        playback.complete();
        await settleIo(t);
        expect(r.$5.followUps, [false]);
        expect(
          find.text(Strings.get('en', 'voiceConversationStart')),
          findsOneWidget,
        );
      } finally {
        await cleanup(t, r);
      }
    },
  );
  testWidgets(
    'Voice financial draft requires actual ledger/account and explicit confirmation; cancelling preserves exact editable amount',
    (t) async {
      final r = await setup(t);
      try {
        final store = RecordStore(database: r.$2);
        final ledger = (await t.runAsync(
          () => store.save('finance', {
            'title': 'Actual USD ledger',
            'currency': 'USD',
            'entries': <dynamic>[],
          }),
        ))!;
        await command(t, 'record expense: 12.50 USD lunch');
        await tap(t, find.text('Actual USD ledger · USD').last);
        await tap(t, find.text('Actual USD ledger').last);
        expect(
          (await t.runAsync(() => store.get(ledger.id)))!.data['entries'],
          isEmpty,
        );
        final amount = '${Strings.get('en', 'xAmount')} (USD)';
        expect(
          t
              .widget<TextField>(
                find.byKey(const ValueKey('editor-field-amount')),
              )
              .controller!
              .text,
          '12.50',
        );
        await tap(t, find.text(Strings.get('en', 'save')).last);
        await tap(t, find.text(Strings.get('en', 'cancel')).last);
        expect(
          (await t.runAsync(() => store.get(ledger.id)))!.data['entries'],
          isEmpty,
        );
        expect(find.text(Strings.get('en', 'saveError')), findsNothing);
        await field(t, amount, '13.25');
        await tap(t, find.text(Strings.get('en', 'save')).last);
        await tap(
          t,
          find.widgetWithText(FilledButton, Strings.get('en', 'continue')).last,
        );
        final saved = (await t.runAsync(() => store.get(ledger.id)))!;
        expect(saved.data['entries'], hasLength(1));
        expect(saved.data['entries'].single['amount'], 1325);
        expect(saved.data['entries'].single['currency'], 'USD');
        expect(r.$5.calls, ['state']);
        expect(t.takeException(), isNull);
      } finally {
        await cleanup(t, r);
      }
    },
  );
  testWidgets(
    'Voice note/task/experience drafts use actual storage only after Save and shared search opens original content',
    (t) async {
      final r = await setup(t);
      try {
        await command(t, 'qayd yoz: A unique voice idea');
        expect((await t.runAsync(() => r.$2.query('notes')))!, isEmpty);
        await tap(t, find.text(Strings.get('en', 'save')).last);
        expect(find.byType(NoteEditorPage), findsOneWidget);
        expect(
          (await t.runAsync(() => r.$2.query('notes')))!.single['body'],
          'A unique voice idea',
        );
        await t.pageBack();
        await settleIo(t);
        await command(t, 'vazifa yarat: Read a real chapter');
        expect((await t.runAsync(() => r.$3.query('todos')))!, isEmpty);
        await tap(t, find.byTooltip(Strings.get('en', 'save')));
        expect(
          (await t.runAsync(() => r.$3.query('todos')))!.single['title'],
          'Read a real chapter',
        );
        await command(t, 'tajriba yoz: What I actually learned');
        expect(find.byType(ExperienceEditor), findsOneWidget);
        expect(
          (await t.runAsync(() => r.$2.query('private_records')))!,
          isEmpty,
        );
        await key(t, 'experience-save');
        expect(find.byType(ExperiencePage), findsOneWidget);
        expect(
          (await t.runAsync(
            () => r.$2.query('private_records', where: "kind='experience'"),
          ))!.single['revision'],
          1,
        );
        await t.pageBack();
        await settleIo(t);
        await command(t, 'qaydlardan qidir: unique');
        expect(find.byType(LibraryPage), findsOneWidget);
        expect(find.text('A unique voice idea'), findsWidgets);
        expect(r.$5.calls, ['state']);
        expect(t.takeException(), isNull);
      } finally {
        await cleanup(t, r);
      }
    },
  );
  testWidgets(
    'Voice selects real habits/books/cards, preserves historical notes and does not invent a book',
    (t) async {
      final r = await setup(t);
      try {
        final habits = HabitStore(provided: r.$2),
            store = RecordStore(database: r.$2);
        final book = (await t.runAsync(() async {
          await habits.create(
            'Walking',
            id: 'walking',
            plan: HabitPlan(target: 10, unit: 'minutes'),
          );
          await habits.checkIn(
            'walking',
            DateTime.now(),
            3,
            note: 'Actual earlier minutes',
          );
          return store.save('book', {
            'title': 'Actual book',
            'chapters': [
              {
                'title': 'Chapter',
                'body': 'Real saved reading content',
                'versions': [],
              },
            ],
            'bookmark': 0,
            'characters': '',
          });
        }))!;
        await command(t, 'complete habit: Walking');
        await tap(t, find.text('Walking').last);
        await tap(
          t,
          find.widgetWithText(FilledButton, Strings.get('en', 'continue')).last,
        );
        final h = (await t.runAsync(() => habits.get('walking')))!;
        expect(h.plan.done(DateTime.now(), h.days), isTrue);
        expect(
          h.plan.entries[dayKey(DateTime.now())]['note'],
          'Actual earlier minutes',
        );
        // SQLite can expose the committed check-in before the action's async
        // continuation has pushed its result route. Wait for the actual UI,
        // rather than racing a Back gesture against that continuation.
        final opening = Stopwatch()..start();
        while (find.byType(HabitStatisticsPage).evaluate().isEmpty &&
            opening.elapsed < const Duration(seconds: 20)) {
          await settleIo(t);
        }
        expect(find.byType(HabitStatisticsPage), findsOneWidget);
        await t.pageBack();
        await settleIo(t);
        await command(t, 'open book: Actual book');
        await key(t, 'voice-book-${book.id}');
        expect(find.byType(RecordPage), findsOneWidget);
        await t.pageBack();
        await settleIo(t);
        await command(t, 'create knowledge card: An actual idea');
        await key(t, 'voice-book-${book.id}');
        await tap(t, find.text(Strings.get('en', 'rCard_idea')).last);
        expect(
          (await t.runAsync(
            () => ReadingStore(records: store).rows(book.id, 'card'),
          ))!,
          isEmpty,
        );
        await tap(t, find.text(Strings.get('en', 'save')).last);
        final cards = (await t.runAsync(
          () => ReadingStore(records: store).rows(book.id, 'card'),
        ))!;
        expect(cards, hasLength(1));
        expect(cards.single.data['front'], 'An actual idea');
        expect((await t.runAsync(() => store.all('book')))!, hasLength(1));
        expect(t.takeException(), isNull);
      } finally {
        await cleanup(t, r);
      }
    },
  );
  if (includeCompact) {
    testWidgets(
      'Voice preview and unknown-command cancellation work at 360px 2x RTL without microphone activation',
      (t) async {
        t.view.physicalSize = const Size(360, 800);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        final r = await setup(t, compact: true);
        try {
          await field(
            t,
            Strings.get('en', 'voicePreview'),
            'delete all records',
          );
          await key(t, 'voice-review');
          expect(find.byKey(const Key('voice-execute')), findsNothing);
          await key(t, 'voice-cancel-command');
          expect(r.$5.calls, ['state']);
          expect(
            (await t.runAsync(() => r.$2.query('private_records')))!,
            isEmpty,
          );
          expect(t.takeException(), isNull);
        } finally {
          await cleanup(t, r);
        }
      },
    );
  }
}
