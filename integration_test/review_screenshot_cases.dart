import 'dart:io';

import 'package:bilga/core/settings.dart';
import 'package:bilga/core/strings.dart';
import 'package:bilga/features/agent/agent_access.dart';
import 'package:bilga/features/books/book_library.dart';
import 'package:bilga/features/books/book_library_page.dart';
import 'package:bilga/features/habits/habit_store.dart';
import 'package:bilga/features/habits/habits_page.dart';
import 'package:bilga/features/notes/note_database.dart';
import 'package:bilga/features/private_space/record_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

import 'review_guard.dart';

void registerReviewScreenshots(IntegrationTestWidgetsFlutterBinding binding) {
  testWidgets('Capture actual Review UI with synthetic fixtures only', (
    tester,
  ) async {
    await requireReviewPackage();
    await Strings.load();
    final root = await getTemporaryDirectory();
    final fixture = await root.createTemp('review-screenshots-');
    final output = await Directory('${root.path}/review-visual-evidence')
        .create();
    final db = await NoteDatabase.openAt(
      '${fixture.path}/notes.db',
      secure: true,
    );
    final access = AgentAccess()..owned.add(AgentAccess.core);
    const security = MethodChannel('bilga/security');
    Future<void> settle() async {
      for (var i = 0; i < 25; i++) {
        await tester.pump(const Duration(milliseconds: 40));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
      }
      await tester.pumpAndSettle();
    }

    Widget app(Widget page) => MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: bilgaTheme('forest', Brightness.light),
      builder: (_, child) => Banner(
        message: 'DEMO · isolated review',
        location: BannerLocation.topEnd,
        child: child!,
      ),
      home: page,
    );
    final captures = <String>[];
    Future<void> capture(String name) async {
      await requireReviewPackage();
      await settle();
      final bytes = await binding.takeScreenshot(name);
      expect(bytes.length, greaterThan(1000));
      await File('${output.path}/$name.png').writeAsBytes(bytes, flush: true);
      // PNGs stay in this Review cache, not in a large driver JSON response.
      binding.reportData?.remove('screenshots');
      captures.add('$name.png');
    }

    try {
      await tester.pumpWidget(
        app(
          HabitsPage(
            store: HabitStore(provided: db),
            access: access,
          ),
        ),
      );
      await settle();
      // Capture permission is scoped to this visible synthetic test UI. No
      // persistent setting, production window or owner content is accessed.
      await security.invokeMethod<void>('secure', false);
      await binding.convertFlutterSurfaceToImage();
      await tester.pump();
      await capture('habits-first-run');
      await tester.tap(find.byKey(const Key('habit-templates')));
      await settle();
      await tester.tap(find.byKey(const Key('habit-template-water')));
      await settle();
      await capture('habits-template-preview');
      await tester.binding.handlePopRoute();
      await settle();
      await tester.binding.handlePopRoute();
      await settle();
      await tester.tap(find.byKey(const Key('habit-help')));
      await settle();
      await tester.tap(find.byKey(const Key('habit-guide-start')));
      await settle();
      await capture('habit-guided-create');
      await tester.tap(find.byKey(const Key('guide-exit')));
      await settle();
      await tester.pumpWidget(const SizedBox());
      await settle();
      final records = RecordStore(database: db);
      for (final (title, status, current) in [
        ('DEMO — A personal reading project', 'reading', 42),
        ('DEMO — My next book', 'planned', 0),
      ]) {
        await records.save(
          'book',
          BookLibrary.update(
            {'title': title, 'characters': '', 'chapters': <dynamic>[]},
            {
              'status': status,
              'currentPage': current,
              'pages': 180,
              'shelves': ['DEMO shelf'],
            },
          ),
        );
      }
      await tester.pumpWidget(
        app(BookLibraryPage(records: records, access: access)),
      );
      await settle();
      await capture('books-library');
      binding.reportData = {
        ...?binding.reportData,
        'visualEvidence': {
          'files': captures,
          'syntheticFixturesOnly': true,
          'scope': 'Actual native tablet screenshots; intermediate product, not release acceptance',
        },
      };
      expect(tester.takeException(), isNull);
    } finally {
      await security.invokeMethod<void>(
        'secure',
        AppSettings.instance.appLock || AppSettings.instance.screenPrivacy,
      );
      await tester.pumpWidget(const SizedBox());
      await settle();
      await db.close();
      await fixture.delete(recursive: true);
    }
  });
}
