import 'dart:io';

import 'package:bilga/core/strings.dart';
import 'package:bilga/features/finance/account_ledger.dart';
import 'package:bilga/features/finance/finance_page.dart';
import 'package:bilga/features/finance/finance_reports_page.dart';
import 'package:bilga/features/finance/ledger.dart';
import 'package:bilga/features/notes/note_database.dart';
import 'package:bilga/features/private_space/record_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

void registerFinanceReportsUiTests({
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

  Future<void> show(WidgetTester tester, Finder finder) async {
    tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position
        .jumpTo(0);
    await settle(tester);
    await tester.scrollUntilVisible(
      finder,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await settle(tester);
    await tester.ensureVisible(finder);
    await settle(tester);
  }

  Future<void> press(WidgetTester tester, Key key) async {
    await show(tester, find.byKey(key));
    await tester.tap(find.byKey(key));
    await settle(tester);
  }

  Map<String, dynamic> row(
    String id,
    String type,
    int amount,
    String date, {
    bool voided = false,
  }) => {
    'id': id,
    'type': type,
    'amount': amount,
    'date': date,
    'category': type == 'expense' ? 'Food' : 'Work',
    'description': 'Synthetic report',
    'void': voided,
  };
  String day(DateTime date) => date.toIso8601String().substring(0, 10);
  Future<(Directory, Database, RecordStore, PrivateRecord)> fixture(
    WidgetTester tester, {
    bool large = false,
  }) async => (await tester.runAsync(() async {
    await Strings.load(code: 'en');
    final directory =
        await (createDirectory?.call() ??
            Directory.systemTemp.createTemp('bilga-reports-ui-'));
    final db = await NoteDatabase.openAt(
      '${directory.path}/notes.db',
      secure: secure,
    );
    final store = RecordStore(database: db),
        now = DateUtils.dateOnly(DateTime.now());
    final data = AccountLedger.addAccount(
      {
        'title': 'Reports ledger',
        'currency': 'USD',
        'entries': large
            ? [
                row('large', 'income', maxMoney - 1, day(now)),
                row('fee', 'expense', 1, day(now)),
              ]
            : [
                row(
                  'prior',
                  'income',
                  1000,
                  day(DateTime(now.year, now.month - 1)),
                ),
                row('income', 'income', 6000, day(now)),
                row('food', 'expense', 2000, day(now)),
                row(
                  'future',
                  'expense',
                  9900,
                  day(DateTime(now.year, now.month, now.day + 1)),
                ),
                row('void', 'expense', 500, day(now), voided: true),
              ],
      },
      id: 'bank',
      name: 'Bank',
      type: 'bank',
      opening: large ? -maxMoney : 10000,
      openedOn: day(now),
    );
    return (directory, db, store, await store.save('finance', data));
  }))!;
  testWidgets(
    'Finance reports exclude future and voided spending, group/select charts and refresh without changing data',
    (tester) async {
      final (directory, db, store, record) = await fixture(tester);
      try {
        await tester.pumpWidget(MaterialApp(home: FinancePage(store: store)));
        await settle(tester);
        await press(tester, const Key('finance-reports-open'));
        expect(find.byType(FinanceReportsPage), findsOneWidget);
        await show(
          tester,
          find.byKey(const ValueKey('finance-report-total-fReportEndBalance')),
        );
        expect(find.text('150.00 USD'), findsOneWidget);
        expect(find.text('60.00 USD'), findsOneWidget);
        expect(find.text('20.00 USD'), findsOneWidget);
        expect(find.byType(TextField), findsNothing);
        await press(tester, const Key('finance-report-year'));
        await show(
          tester,
          find.byKey(const ValueKey('finance-report-total-xincome')),
        );
        expect(find.text('70.00 USD'), findsOneWidget);
        await press(tester, const Key('finance-report-group-monthly'));
        await press(tester, const Key('finance-report-chart'));
        expect(find.byType(SelectableText), findsOneWidget);
        final initial = (await tester.runAsync(
          () => db.query('private_records'),
        ))!.single;
        expect(initial['revision'], record.revision);
        final changed = (await tester.runAsync(
          () => store.save('finance', {
            ...record.data,
            'entries': [
              ...record.data['entries'],
              {
                ...row('extra', 'expense', 100, day(DateTime.now())),
                'currency': 'USD',
                'account': AccountLedger.legacyId,
              },
            ],
          }, previous: record),
        ))!;
        await tester.tap(find.byIcon(Icons.refresh));
        await settle(tester);
        await show(
          tester,
          find.byKey(const ValueKey('finance-report-total-fReportEndBalance')),
        );
        expect(find.text('149.00 USD'), findsOneWidget);
        final stored = (await tester.runAsync(() => store.all('finance')))!
            .single;
        expect(stored.revision, changed.revision);
        expect(stored.data, changed.data);
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
      'Compact RTL dark reports keep very large exact money readable at double text size',
      (tester) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final (directory, db, store, record) = await fixture(
          tester,
          large: true,
        );
        try {
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(brightness: Brightness.dark),
              builder: (c, child) => MediaQuery(
                data: MediaQuery.of(c)
                    .copyWith(textScaler: const TextScaler.linear(2)),
                child: Directionality(
                  textDirection: TextDirection.rtl,
                  child: child!,
                ),
              ),
              home: FinanceReportsPage(ledger: record, store: store),
            ),
          );
          await settle(tester);
          await show(
            tester,
            find.byKey(
              const ValueKey('finance-report-total-fReportEndBalance'),
            ),
          );
          expect(find.text('-0.02 USD'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await press(tester, const Key('finance-report-group-weekly'));
          await press(tester, const Key('finance-report-chart'));
          expect(find.byType(SelectableText), findsOneWidget);
          expect(tester.takeException(), isNull);
          expect(
            (await tester.runAsync(() => store.all('finance')))!
                .single
                .revision,
            record.revision,
          );
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.runAsync(() async {
            await db.close();
            await directory.delete(recursive: true);
          });
        }
      },
    );
  }
}
