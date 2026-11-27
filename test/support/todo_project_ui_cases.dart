import 'dart:io';

import 'package:bilga/core/strings.dart';
import 'package:bilga/features/collections/collection_page.dart';
import 'package:bilga/features/collections/collection_repository.dart';
import 'package:bilga/features/todo/todo_database.dart';
import 'package:bilga/features/todo/todo_project_editor.dart';
import 'package:bilga/features/todo/todo_project_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

void registerTodoProjectUiTests({
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
    T? result;
    Object? error;
    var done = false;
    work().then<void>(
      (value) {
        result = value;
        done = true;
      },
      onError: (Object failure) {
        error = failure;
        done = true;
      },
    );
    for (var i = 0; i < 500 && !done; i++) {
      await tester.pump(const Duration(milliseconds: 20));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
    }
    if (error != null) throw error!;
    expect(done, true);
    return result as T;
  }

  Future<(Directory, Database)> fixture(WidgetTester tester) async =>
      (await tester.runAsync(() async {
        await Strings.load(code: 'en');
        final directory =
            await (createDirectory?.call() ??
                Directory.systemTemp.createTemp('bilga-project-ui-'));
        return (
          directory,
          await TodoDatabase.openAt(
            '${directory.path}/tasks.db',
            secure: secure,
          ),
        );
      }))!;
  testWidgets(
    'Project UI creates nested lists/tasks, tracks completion, edits status and converts without data loss',
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
        await tester.tap(find.byType(FloatingActionButton));
        await settle(tester);
        await tester.tap(find.text('New project'));
        await settle(tester);
        await tester.enterText(
          find.byKey(const Key('task-project-name')),
          'Launch project',
        );
        await tester.pump();
        await tester.enterText(
          find.byKey(const Key('task-project-description')),
          'Release carefully',
        );
        await tester.pump();
        FocusManager.instance.primaryFocus?.unfocus();
        await settle(tester);
        await tester.ensureVisible(
          find.byKey(const Key('task-project-status')),
        );
        await settle(tester);
        await tester.tap(find.byKey(const Key('task-project-status')));
        await settle(tester);
        await tester.tap(find.text('Paused').last);
        await settle(tester);
        await tester.tap(find.byTooltip('Save'));
        await settle(tester);
        expect(find.byType(TodoProjectSummary), findsOneWidget);
        expect(find.text('Project progress: 0 / 0'), findsOneWidget);
        await tester.tap(find.byType(FloatingActionButton));
        await settle(tester);
        await tester.tap(find.text('New folder'));
        await settle(tester);
        await tester.enterText(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(TextField),
          ),
          'Milestones',
        );
        await tester.tap(find.text('Save'));
        await settle(tester);
        await tester.tap(find.text('Milestones'));
        await settle(tester);
        await tester.tap(find.byType(FloatingActionButton));
        await settle(tester);
        await tester.tap(find.text('New task'));
        await settle(tester);
        await tester.enterText(
          find.byWidgetPredicate(
            (widget) =>
                widget is TextField && widget.decoration?.labelText == 'Title',
          ),
          'Ship first milestone',
        );
        await tester.pump();
        await tester.tap(find.byTooltip('Save'));
        await settle(tester);
        await tester.tap(find.byType(Checkbox));
        await settle(tester);
        await tester.pageBack();
        await settle(tester);
        expect(find.text('Project progress: 1 / 1'), findsOneWidget);
        expect(find.text('Paused'), findsOneWidget);
        await tester.ensureVisible(find.byKey(const Key('task-project-edit')));
        await settle(tester);
        await tester.tap(find.byKey(const Key('task-project-edit')));
        await settle(tester);
        await tester.ensureVisible(
          find.byKey(const Key('task-project-status')),
        );
        await settle(tester);
        await tester.tap(find.byKey(const Key('task-project-status')));
        await settle(tester);
        await tester.tap(find.text('Closed').last);
        await settle(tester);
        await tester.tap(find.byTooltip('Save'));
        await settle(tester);
        expect(find.text('Closed'), findsOneWidget);
        expect(find.text('Project progress: 1 / 1'), findsOneWidget);
        await tester.tap(find.byKey(const Key('collection-folder-actions')));
        await settle(tester);
        await tester.tap(find.text('Convert to list'));
        await settle(tester);
        await tester.tap(find.text('Continue'));
        await settle(tester);
        expect(find.byType(TodoProjectSummary), findsNothing);
        expect(find.text('Milestones'), findsOneWidget);
        expect(await io(tester, () => TodoProjectStore(db).all()), isEmpty);
        final tasks = await io(tester, () => db.query('todos'));
        expect(tasks.single['title'], 'Ship first milestone');
        expect(tasks.single['is_done'], 1);
        expect(await io(tester, () => db.query('todo_folders')), hasLength(2));
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
      'Large-text RTL empty project summary scrolls without inventing completion',
      (tester) async {
        final (directory, db) = await fixture(tester);
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1;
        try {
          final id = await io(
            tester,
            () => TodoProjectStore(db).save(
              name: 'Project',
              description: 'Detailed reflection ' * 30,
              status: 'active',
            ),
          );
          await tester.pumpWidget(
            MaterialApp(
              builder: (c, child) => MediaQuery(
                data: MediaQuery.of(c)
                    .copyWith(textScaler: TextScaler.linear(2)),
                child: Directionality(
                  textDirection: TextDirection.rtl,
                  child: child!,
                ),
              ),
              home: CollectionPage(
                kind: CollectionKind.todos,
                folderId: id,
                folderName: 'Project',
                repository: CollectionRepository(
                  CollectionKind.todos,
                  provided: db,
                ),
              ),
            ),
          );
          await settle(tester);
          expect(find.text('Project progress: 0 / 0'), findsOneWidget);
          expect(find.byType(LinearProgressIndicator), findsNothing);
          expect(
            Directionality.of(tester.element(find.byType(TodoProjectSummary))),
            TextDirection.rtl,
          );
          final edit = find.byKey(const Key('task-project-edit'));
          await tester.ensureVisible(edit);
          await settle(tester);
          await tester.tap(edit);
          await settle(tester);
          expect(find.byType(TodoProjectEditor), findsOneWidget);
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
