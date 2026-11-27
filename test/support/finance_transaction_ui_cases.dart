import 'settle_io.dart';

import 'dart:io';

import 'package:bilga/core/strings.dart';
import 'package:bilga/features/agent/agent_access.dart';
import 'package:bilga/features/finance/account_ledger.dart';
import 'package:bilga/features/finance/finance_page.dart';
import 'package:bilga/features/finance/finance_transaction_page.dart';
import 'package:bilga/features/finance/ledger.dart';
import 'package:bilga/features/notes/note_database.dart';
import 'package:bilga/features/private_space/record_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

void registerFinanceTransactionUiTests({
  Future<Directory> Function()? createDirectory,
  bool secure = false,
  bool includeCompact = true,
  VoidCallback? onUiVerified,
}) {
  Future<void> settle(WidgetTester tester) => settleIo(tester);

  Finder field(String label) => find.byWidgetPredicate(
    (widget) => widget is TextField && widget.decoration?.labelText == label,
  );
  Future<void> fill(WidgetTester tester, String label, String value) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await settle(tester);
    await tester.ensureVisible(field(label));
    await settle(tester);
    await tester.enterText(field(label), value);
    await tester.pump();
  }

  Future<void> save(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(TextButton, 'Save'));
    await settle(tester);
  }

  Future<void> press(WidgetTester tester, Key key) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await settle(tester);
    await tester.ensureVisible(find.byKey(key));
    await settle(tester);
    await tester.tap(find.byKey(key));
    await settle(tester);
  }

  Future<(Directory, Database, RecordStore, PrivateRecord)> fixture(
    WidgetTester tester,
  ) async => (await tester.runAsync(() async {
    await Strings.load(code: 'en');
    final directory =
        await (createDirectory?.call() ??
            Directory.systemTemp.createTemp('bilga-transaction-ui-'));
    final db = await NoteDatabase.openAt(
      '${directory.path}/notes.db',
      secure: secure,
    );
    final store = RecordStore(database: db);
    final data = AccountLedger.addAccount(
      {
        'title': 'History ledger',
        'currency': 'USD',
        'entries': [
          {
            'id': 'pay',
            'type': 'income',
            'amount': 10000,
            'date': '2020-01-01',
            'category': 'Work',
            'description': 'Synthetic income',
            'void': false,
          },
          {
            'id': 'food',
            'type': 'expense',
            'amount': 1200,
            'date': '2020-01-02',
            'category': 'Food',
            'description': 'Original lunch',
            'void': false,
          },
        ],
      },
      id: 'bank',
      name: 'Bank',
      type: 'bank',
      opening: 5000,
      openedOn: '2020-01-01',
    );
    return (directory, db, store, await store.save('finance', data));
  }))!;
  Future<PrivateRecord> read(WidgetTester tester, RecordStore store) async =>
      (await tester.runAsync(() async => (await store.all('finance')).single))!;
  testWidgets(
    'Finance transaction UI edits account and amount, restores history and reversibly voids without affecting other entries',
    (tester) async {
      final (directory, db, store, _) = await fixture(tester);
      final access = AgentAccess()..owned.add(AgentAccess.core);
      try {
        await tester.pumpWidget(
          MaterialApp(
            home: FinancePage(store: store, access: access),
          ),
        );
        await settle(tester);
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('finance-entry-food')),
          250,
          scrollable: find.byType(Scrollable).first,
        );
        await settle(tester);
        await tester.tap(find.byKey(const ValueKey('finance-entry-food')));
        await settle(tester);
        await press(tester, const Key('finance-transaction-edit'));
        await tester.tap(
          find.descendant(
            of: find.byType(SimpleDialog),
            matching: find.text('Bank'),
          ),
        );
        await settle(tester);
        await fill(tester, 'Amount (USD)', '15.25');
        await fill(tester, 'Description', 'Corrected lunch');
        await save(tester);
        var saved = await read(tester, store);
        final changed = saved.data['entries'].last as Map;
        expect(changed['amount'], 1525);
        expect(changed['account'], 'bank');
        expect(changed['versions'], hasLength(1));
        expect(Ledger.balance(saved.data), 13475);
        await press(tester, const ValueKey('finance-transaction-version-0'));
        expect(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.textContaining('Original lunch'),
          ),
          findsOneWidget,
        );
        await tester.tap(find.widgetWithText(FilledButton, 'Restore'));
        await settle(tester);
        saved = await read(tester, store);
        expect(saved.data['entries'].last['amount'], 1200);
        expect(saved.data['entries'].last['account'], AccountLedger.legacyId);
        expect(saved.data['entries'].first['amount'], 10000);
        expect(saved.data['entries'].last['versions'], hasLength(2));
        await press(tester, const Key('finance-transaction-void'));
        await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
        await settle(tester);
        saved = await read(tester, store);
        expect(saved.data['entries'].last['void'], true);
        expect(Ledger.balance(saved.data), 15000);
        await press(tester, const Key('finance-transaction-void'));
        await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
        await settle(tester);
        saved = await read(tester, store);
        expect(saved.data['entries'].last['void'], false);
        expect(saved.data['entries'].last['versions'], hasLength(4));
        expect(Ledger.balance(saved.data), 13800);
        await tester.pageBack();
        await settle(tester);
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('finance-entry-food')),
          250,
          scrollable: find.byType(Scrollable).first,
        );
        expect(tester.takeException(), isNull);
        onUiVerified?.call();
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(() async {
          await db.close();
          await directory.delete(recursive: true);
        });
        access.dispose();
      }
    },
  );
  if (includeCompact) {
    testWidgets(
      'Compact RTL transaction draft survives entitlement expiry and saves exactly once after access returns',
      (tester) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final (directory, db, store, record) = await fixture(tester);
        final access = AgentAccess()..owned.add(AgentAccess.core);
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
              home: FinanceTransactionPage(
                ledger: record,
                entryId: 'food',
                store: store,
                access: access,
              ),
            ),
          );
          await settle(tester);
          await press(tester, const Key('finance-transaction-edit'));
          await tester.tap(
            find.descendant(
              of: find.byType(SimpleDialog),
              matching: find.text('Bank'),
            ),
          );
          await settle(tester);
          await fill(
            tester,
            'Description',
            'Keep this draft after access expires',
          );
          access.owned.clear();
          await save(tester);
          expect(field('Description'), findsOneWidget);
          expect(
            tester.widget<TextField>(field('Description')).controller!.text,
            'Keep this draft after access expires',
          );
          expect((await read(tester, store)).revision, record.revision);
          access.owned.add(AgentAccess.core);
          await save(tester);
          final saved = await read(tester, store);
          expect(saved.revision, record.revision + 1);
          expect(saved.data['entries'].last['versions'], hasLength(1));
          expect(
            saved.data['entries'].last['description'],
            'Keep this draft after access expires',
          );
          expect(tester.takeException(), isNull);
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.runAsync(() async {
            await db.close();
            await directory.delete(recursive: true);
          });
          access.dispose();
        }
      },
    );
  }
}
