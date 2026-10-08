import 'dart:async';

import 'package:bilga/core/strings.dart';

import 'package:bilga/app/bilga_app.dart';
import 'package:bilga/features/notes/note_editor_page.dart';
import 'package:bilga/features/notes/note_model.dart';
import 'package:bilga/features/notes/note_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class MemoryNotes extends NoteService {
  final List<Note> writes = [];
  final List<bool> history = [];
  bool fail = false;
  Completer<void>? blocked;

  @override
  Future<void> addNote(Note note) async {
    if (fail) throw StateError('disk full');
    await blocked?.future;
    writes.add(note);
  }

  @override
  Future<void> updateNote(Note note, {bool recordHistory = true}) async {
    if (fail) throw StateError('disk full');
    await blocked?.future;
    writes.add(note);
    history.add(recordHistory);
  }
}

Future<void> openEditor(
  WidgetTester tester,
  MemoryNotes service, {
  Note? note,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.push<Note>(
              context,
              MaterialPageRoute(
                builder: (_) => NoteEditorPage(note: note, service: service),
              ),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(Strings.load);
  testWidgets('Free home exposes only the two working sections', (
    tester,
  ) async {
    await tester.pumpWidget(const BilgaApp());
    await tester.pumpAndSettle();
    expect(find.text(Strings.get('uz', 'notes')), findsOneWidget);
    expect(find.text(Strings.get('uz', 'todos')), findsOneWidget);
    expect(find.text('Reminder'), findsNothing);
    expect(find.text('Tajriba'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Autosave preserves whitespace and back flushes the last edit', (
    tester,
  ) async {
    final service = MemoryNotes();
    await openEditor(tester, service);
    await tester.enterText(find.byKey(const Key('note-body')), '  satr\n');
    await tester.pump(const Duration(milliseconds: 750));
    await tester.pump();
    expect(service.writes.single.body, '  satr\n');
    await tester.enterText(find.byKey(const Key('note-body')), 'ikkinchi satr');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(service.writes.last.body, 'ikkinchi satr');
    expect(find.text('Open'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Storage failure keeps the editor and unsaved text open', (
    tester,
  ) async {
    final service = MemoryNotes()..fail = true;
    await openEditor(tester, service);
    await tester.enterText(find.byKey(const Key('note-body')), 'Yo‘qolmasin');
    await tester.tap(find.byTooltip(Strings.get('en', 'back')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('note-body')), findsOneWidget);
    expect(find.text('Yo‘qolmasin'), findsOneWidget);
    expect(find.text(Strings.get('en', 'saveError')), findsOneWidget);
    service.fail = false;
    await tester.tap(find.byTooltip(Strings.get('en', 'save')));
    await tester.pumpAndSettle();
    expect(service.writes.single.body, 'Yo‘qolmasin');
    expect(find.text('Open'), findsOneWidget);
  });

  testWidgets('Slow autosaves stay ordered and insert only once', (
    tester,
  ) async {
    final gate = Completer<void>();
    final service = MemoryNotes()..blocked = gate;
    await openEditor(tester, service);
    await tester.enterText(find.byKey(const Key('note-body')), 'birinchi');
    await tester.pump(const Duration(milliseconds: 750));
    await tester.enterText(find.byKey(const Key('note-body')), 'ikkinchi');
    await tester.pump(const Duration(milliseconds: 750));
    gate.complete();
    await tester.pumpAndSettle();
    expect(service.writes.map((n) => n.body), ['birinchi', 'ikkinchi']);
    expect(service.history, [false]);
    await tester.tap(find.byTooltip(Strings.get('en', 'back')));
    await tester.pumpAndSettle();
  });

  testWidgets('An editing session records its previous state once', (
    tester,
  ) async {
    final now = DateTime(2026, 9, 6);
    final service = MemoryNotes();
    await openEditor(
      tester,
      service,
      note: Note(
        id: 'existing',
        title: 'old',
        body: '',
        createdAt: now,
        updatedAt: now,
      ),
    );
    await tester.enterText(find.byKey(const Key('note-title')), 'new');
    await tester.pump(const Duration(milliseconds: 750));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('note-title')), 'newer');
    await tester.pump(const Duration(milliseconds: 750));
    await tester.pump();
    expect(service.history, [true, false]);
    await tester.tap(find.byTooltip(Strings.get('en', 'back')));
    await tester.pumpAndSettle();
  });
}
