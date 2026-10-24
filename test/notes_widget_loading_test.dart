import 'dart:async';
import 'dart:io';

import 'package:bilga/core/strings.dart';
import 'package:bilga/core/settings.dart';
import 'package:bilga/features/notes/note_database.dart';
import 'package:bilga/features/notes/widget/notes_widget_bridge.dart';
import 'package:bilga/features/notes/widget/notes_widget_config_page.dart';
import 'package:bilga/features/notes/widget/notes_widget_loading.dart';
import 'package:bilga/features/notes/widget/notes_widget_sync.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const cipher = MethodChannel('com.davidmartos96.sqflite_sqlcipher');
  const vault = MethodChannel('bilga/vault');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUp(() {
    AppSettings.instance.language = 'en';
  });

  test('Encrypted Notes verifies the retained connection before configuration, without temporary close', () async {
    final directory = await Directory.systemTemp.createTemp(
      'bilga-notes-open-',
    );
    final file = File('${directory.path}/notes.db');
    await file.writeAsBytes(
      List.filled(32, 7),
    ); // Synthetic encrypted-file header.
    final calls = <String>[];
    var integrity = 'ok';
    messenger.setMockMethodCallHandler(vault, (_) async => ''.padLeft(64, '0'));
    messenger.setMockMethodCallHandler(cipher, (call) async {
      final args = call.arguments as Map;
      calls.add(call.method);
      switch (call.method) {
        case 'openDatabase':
          return {'id': 71};
        case 'query':
          final sql = args['sql'] as String;
          if (sql == 'PRAGMA integrity_check') {
            calls.add('integrity');
            return {
              'columns': ['integrity_check'],
              'rows': [
                [integrity],
              ],
            };
          }
          if (sql == 'PRAGMA user_version') {
            return {
              'columns': ['user_version'],
              'rows': [
                [13],
              ],
            };
          }
          return {
            'columns': ['value'],
            'rows': [
              [1],
            ],
          };
        case 'execute':
          calls.add('configure');
          return null;
        case 'closeDatabase':
          return null;
        default:
          throw StateError('Unexpected synthetic SQL operation');
      }
    });
    try {
      final db = await NoteDatabase.openAt(file.path, secure: true);
      expect(calls.where((c) => c == 'openDatabase'), hasLength(1));
      expect(calls, isNot(contains('closeDatabase')));
      expect(calls.indexOf('integrity'), lessThan(calls.indexOf('configure')));
      expect(await file.readAsBytes(), List.filled(32, 7));
      await db.close();
      // A failed integrity check must still fail closed before schema writes.
      calls.clear();
      integrity = 'not ok';
      await expectLater(
        NoteDatabase.openAt(file.path, secure: true),
        throwsStateError,
      );
      expect(calls, isNot(contains('configure')));
      expect(await file.readAsBytes(), List.filled(32, 7));
    } finally {
      messenger.setMockMethodCallHandler(cipher, null);
      messenger.setMockMethodCallHandler(vault, null);
      await directory.delete(recursive: true);
    }
  });

  testWidgets(
    'Unavailable native store times out, preserves consent, and offers bounded retry',
    (tester) async {
      await Strings.load(code: 'en');
      var fail = true;
      final writes = <String>[];
      messenger.setMockMethodCallHandler(NotesWidgetBridge.channel, (
        call,
      ) async {
        if (call.method == 'configs') {
          if (fail) return Completer<Object?>().future;
          throw PlatformException(code: 'notes_widget');
        }
        writes.add(call.method);
        return null;
      });
      final sync = NotesWidgetSync(canRead: () => false);
      try {
        await tester.pumpWidget(
          MaterialApp(home: NotesWidgetConfigPage(widgetId: 7, sync: sync)),
        );
        await tester.pump();
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        await tester.pump(
          NotesWidgetLoading.timeout + const Duration(seconds: 1),
        );
        await tester.pump();
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(
          find.text(Strings.get('en', 'widgetNotesUnavailable')),
          findsOneWidget,
        );
        expect(find.text('Try again'), findsOneWidget);
        expect(
          writes,
          isEmpty,
        ); // No save/invalidate/permission deletion on failed read.
        fail = false;
        await tester.tap(find.text('Try again'));
        await tester.pumpAndSettle();
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(writes, isEmpty);
        await tester.pumpWidget(const SizedBox.shrink());
        sync.dispose();
        expect(tester.takeException(), isNull);
      } finally {
        messenger.setMockMethodCallHandler(NotesWidgetBridge.channel, null);
      }
    },
  );

  testWidgets(
    'Database timeout can be cancelled and late completion cannot resurrect a disposed page',
    (tester) async {
      await Strings.load(code: 'en');
      final pending = Completer<Never>();
      var reads = 0;
      messenger.setMockMethodCallHandler(NotesWidgetBridge.channel, (
        call,
      ) async {
        if (call.method == 'configs') {
          reads++;
          return [
            {'id': 7},
          ];
        }
        return null;
      });
      final sync = NotesWidgetSync(canRead: () => false);
      await tester.pumpWidget(
        MaterialApp(
          home: NotesWidgetConfigPage(
            widgetId: 7,
            sync: sync,
            databaseLoader: () => pending.future,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(
        NotesWidgetLoading.timeout + const Duration(seconds: 1),
      );
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      await tester.tap(find.text('Try again'));
      await tester.pump();
      expect(
        reads,
        1,
      ); // Retain existing source/privacy/pins while retrying DB readiness.
      await tester.pumpWidget(const SizedBox.shrink());
      pending.completeError(StateError('synthetic unavailable'));
      await tester.pump();
      sync.dispose();
      messenger.setMockMethodCallHandler(NotesWidgetBridge.channel, null);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Locked host never opens the database or overwrites widget configuration',
    (tester) async {
      var reads = 0;
      final sync = NotesWidgetSync(canRead: () => false);
      await tester.pumpWidget(
        MaterialApp(
          home: NotesWidgetConfigPage(
            widgetId: 7,
            sync: sync,
            canRead: () => false,
            databaseLoader: () {
              reads++;
              return Completer<Never>().future;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(reads, 0);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      sync.dispose();
    },
  );
  testWidgets(
    'Disposing sync cancels its deadline even when the native read never answers',
    (tester) async {
      messenger.setMockMethodCallHandler(NotesWidgetBridge.channel, (
        call,
      ) async {
        if (call.method == 'configs') return Completer<Object?>().future;
        return null;
      });
      final sync = NotesWidgetSync(canRead: () => true)..start();
      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      await tester.pump();
      sync.dispose();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      messenger.setMockMethodCallHandler(NotesWidgetBridge.channel, null);
      expect(tester.takeException(), isNull);
      // Flutter also asserts that no pending deadline Timer survives disposal.
    },
  );
  testWidgets(
    'Closing config while the store is loading cancels its deadline',
    (tester) async {
      messenger.setMockMethodCallHandler(NotesWidgetBridge.channel, (
        call,
      ) async {
        if (call.method == 'configs') return Completer<Object?>().future;
        return null;
      });
      final sync = NotesWidgetSync(canRead: () => false);
      await tester.pumpWidget(
        MaterialApp(home: NotesWidgetConfigPage(widgetId: 7, sync: sync)),
      );
      await tester.pump();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      sync.dispose();
      messenger.setMockMethodCallHandler(NotesWidgetBridge.channel, null);
      expect(tester.takeException(), isNull);
    },
  );
}
