import 'dart:async';
import 'dart:io';

import 'package:bilga/core/strings.dart';
import 'package:bilga/features/collections/collection_page.dart';
import 'package:bilga/features/collections/collection_repository.dart';
import 'package:bilga/features/templates/task_template_store.dart';
import 'package:bilga/features/templates/task_templates_page.dart';
import 'package:bilga/features/todo/todo_database.dart';
import 'package:bilga/features/todo/todo_editor_page.dart';
import 'package:bilga/features/todo/todo_checklist_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

void registerTaskTemplateUiTests({
  Future<Directory> Function()? createDirectory,
  bool secure = false,
  bool includeCompact = true,
  VoidCallback? onUiVerified,
}) {
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 25; i++) {
      await tester.pump(const Duration(milliseconds: 20));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
    }
    await tester.pumpAndSettle();
  }

  Future<T> io<T>(WidgetTester tester, Future<T> Function() work) async {
    T? value;
    Object? error;
    var done = false;
    unawaited(
      work().then<void>(
        (result) {
          value = result;
          done = true;
        },
        onError: (Object failure) {
          error = failure;
          done = true;
        },
      ),
    );
    for (var i = 0; i < 500 && !done; i++) {
      await tester.pump(const Duration(milliseconds: 20));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
    }
    if (error != null) throw error!;
    expect(done, true, reason: 'Synthetic template I/O must finish');
    return value as T;
  }

  Future<(Directory, Database)> fixture(WidgetTester tester) async =>
      (await tester.runAsync(() async {
        await Strings.load(code: 'en');
        final directory =
            await (createDirectory?.call() ??
                Directory.systemTemp.createTemp('bilga-template-ui-'));
        return (
          directory,
          await TodoDatabase.openAt(
            '${directory.path}/tasks.db',
            secure: secure,
          ),
        );
      }))!;

  testWidgets(
    'Custom task template create, preview, apply, edit, snapshot and delete work through real routes',
    (tester) async {
      final (directory, db) = await fixture(tester);
      try {
        final repo = CollectionRepository(CollectionKind.todos, provided: db);
        await tester.pumpWidget(
          MaterialApp(
            home: CollectionPage(kind: CollectionKind.todos, repository: repo),
          ),
        );
        await settle(tester);
        Future<void> library() async {
          await tester.tap(find.byType(FloatingActionButton));
          await settle(tester);
          await tester.tap(find.text('Templates'));
          await settle(tester);
        }

        await library();
        await tester.tap(find.byKey(const Key('task-template-create')));
        await settle(tester);
        await tester.enterText(
          find.byKey(const Key('task-template-name')),
          'Weekly workflow',
        );
        await tester.pump();
        await tester.enterText(
          find.byKey(const Key('task-template-title')),
          'Prepare weekly review',
        );
        await tester.pump();
        await tester.enterText(
          find.byKey(const Key('task-template-description')),
          'Reflect on the week',
        );
        await tester.pump();
        final add = find.byKey(const Key('task-checklist-add'));
        FocusManager.instance.primaryFocus?.unfocus();
        await settle(tester);
        await tester.ensureVisible(add);
        await settle(tester);
        await tester.tap(add);
        await settle(tester);
        await tester.enterText(
          find.byType(TextFormField).last,
          'Review lessons',
        );
        await tester.pump();
        expect(find.byType(Checkbox), findsNothing);
        await tester.tap(find.byTooltip('Save'));
        await settle(tester);
        expect(find.text('Weekly workflow'), findsOneWidget);
        await tester.tap(find.text('Weekly workflow'));
        await settle(tester);
        await tester.tap(find.text('Cancel'));
        await settle(tester);
        expect(await io(tester, () => db.query('todos')), isEmpty);
        await tester.tap(find.text('Weekly workflow'));
        await settle(tester);
        await tester.tap(find.text('Create from template'));
        await settle(tester);
        expect(find.byType(TodoEditorPage), findsOneWidget);
        await tester.tap(find.byTooltip('Save'));
        await settle(tester);
        final task = (await io(tester, () => db.query('todos'))).single;
        expect(task['title'], 'Prepare weekly review');
        expect(task['due_at'], isNull);
        final checklist = await io(
          tester,
          () => TodoChecklistStore.load(db, task['id'] as String),
        );
        expect(checklist.single.title, 'Review lessons');
        expect(checklist.single.done, false);
        final tile = find
            .ancestor(
              of: find.text('Prepare weekly review'),
              matching: find.byType(ListTile),
            )
            .first;
        await tester.tap(
          find.descendant(
            of: tile,
            matching: find.byType(PopupMenuButton<String>),
          ),
        );
        await settle(tester);
        await tester.tap(find.text('Save as template'));
        await settle(tester);
        await tester.enterText(
          find.byKey(const Key('task-template-name')),
          'Snapshot',
        );
        await tester.pump();
        await tester.tap(find.byTooltip('Save'));
        await settle(tester);
        expect(
          await io(tester, () => TaskTemplateStore(db).all()),
          hasLength(2),
        );
        await library();
        final custom = find
            .ancestor(
              of: find.text('Weekly workflow'),
              matching: find.byType(ListTile),
            )
            .first;
        await tester.tap(
          find.descendant(
            of: custom,
            matching: find.byType(PopupMenuButton<String>),
          ),
        );
        await settle(tester);
        await tester.tap(find.text('Edit template'));
        await settle(tester);
        await tester.enterText(
          find.byKey(const Key('task-template-title')),
          'Updated future default',
        );
        await tester.pump();
        await tester.tap(find.byTooltip('Save'));
        await settle(tester);
        final snapshot = find
            .ancestor(
              of: find.text('Snapshot'),
              matching: find.byType(ListTile),
            )
            .first;
        await tester.tap(
          find.descendant(
            of: snapshot,
            matching: find.byType(PopupMenuButton<String>),
          ),
        );
        await settle(tester);
        await tester.tap(find.text('Delete template'));
        await settle(tester);
        await tester.tap(find.text('Continue'));
        await settle(tester);
        expect(
          await io(tester, () => TaskTemplateStore(db).all()),
          hasLength(1),
        );
        expect(
          (await io(tester, () => db.query('todos'))).single['title'],
          'Prepare weekly review',
        );
        expect(tester.takeException(), isNull);
        onUiVerified?.call();
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(() async {
          await db.close();
          await directory.delete(recursive: true);
        });
      }
    },
  );
  if (includeCompact) {
    testWidgets(
      'Small large-text RTL template editor preserves draft on cancel and discards only on confirmation',
      (tester) async {
        final (directory, db) = await fixture(tester);
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1;
        try {
          await tester.pumpWidget(
            MaterialApp(
              builder: (c, child) => MediaQuery(
                data: MediaQuery.of(c)
                    .copyWith(textScaler: const TextScaler.linear(2)),
                child: Directionality(
                  textDirection: TextDirection.rtl,
                  child: child!,
                ),
              ),
              home: Builder(
                builder: (c) => Scaffold(
                  body: TextButton(
                    onPressed: () => Navigator.push<void>(
                      c,
                      MaterialPageRoute(
                        builder: (_) =>
                            TaskTemplateEditor(store: TaskTemplateStore(db)),
                      ),
                    ),
                    child: const Text('Open draft'),
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.text('Open draft'));
          await settle(tester);
          expect(
            Directionality.of(
              tester.element(find.byKey(const Key('task-template-name'))),
            ),
            TextDirection.rtl,
          );
          await tester.enterText(
            find.byKey(const Key('task-template-name')),
            'Unsaved draft',
          );
          await tester.pump();
          await tester.tap(find.byIcon(Icons.arrow_back));
          await settle(tester);
          await tester.tap(find.text('Cancel'));
          await settle(tester);
          expect(find.text('Unsaved draft'), findsOneWidget);
          await tester.tap(find.byIcon(Icons.arrow_back));
          await settle(tester);
          await tester.tap(find.text('Continue'));
          await settle(tester);
          expect(find.text('Open draft'), findsOneWidget);
          expect(await io(tester, () => TaskTemplateStore(db).all()), isEmpty);
          expect(tester.takeException(), isNull);
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
          await tester.runAsync(() async {
            await db.close();
            await directory.delete(recursive: true);
          });
        }
      },
    );
  }
}
