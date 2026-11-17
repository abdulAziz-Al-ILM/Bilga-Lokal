import 'dart:io';

import 'package:bilga/core/strings.dart';
import 'package:bilga/features/agent/agent_access.dart';
import 'package:bilga/features/finance/account_ledger.dart';
import 'package:bilga/features/finance/finance_accounts_page.dart';
import 'package:bilga/features/finance/ledger.dart';
import 'package:bilga/features/finance/finance_page.dart';
import 'package:bilga/features/notes/note_database.dart';
import 'package:bilga/features/private_space/record_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import 'settle_io.dart';

void registerFinanceAccountUiTests({
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

  Future<void> menu(WidgetTester tester, String id, String action) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await settle(tester);
    await tester.ensureVisible(
      find.byKey(ValueKey('finance-account-menu-$id')),
    );
    await settle(tester);
    await tester.tap(find.byKey(ValueKey('finance-account-menu-$id')));
    await settle(tester);
    await tester.tap(find.text(action).last);
    await settle(tester);
  }

  Future<(Directory, Database, RecordStore, PrivateRecord)> fixture(
    WidgetTester tester,
  ) async => (await tester.runAsync(() async {
    await Strings.load(code: 'en');
    final directory =
        await (createDirectory?.call() ??
            Directory.systemTemp.createTemp('bilga-finance-ui-'));
    final db = await NoteDatabase.openAt(
      '${directory.path}/notes.db',
      secure: secure,
    );
    final store = RecordStore(database: db);
    final record = await store.save('finance', {
      'title': 'Household',
      'currency': 'USD',
      'entries': [
        {
          'id': 'pay',
          'type': 'income',
          'amount': 50000,
          'date': '2020-01-01',
          'category': 'Work',
          'description': '',
          'void': false,
        },
      ],
    });
    return (directory, db, store, record);
  }))!;
  Future<PrivateRecord> read(WidgetTester tester, RecordStore store) async =>
      (await tester.runAsync(() async => (await store.all('finance')).single))!;

  testWidgets(
    'Account UI creates, transfers, reconciles, inspects history and archives without losing money',
    (tester) async {
      final (directory, db, store, _) = await fixture(tester);
      // Injected entitlement only for synthetic form testing, never purchase acceptance.
      final access = AgentAccess()..owned.add(AgentAccess.core);
      try {
        await tester.pumpWidget(
          MaterialApp(
            home: FinancePage(store: store, access: access),
          ),
        );
        await settle(tester);
        await tester.tap(find.byKey(const Key('finance-accounts-open')));
        await settle(tester);
        await tester.tap(find.byKey(const Key('finance-account-add')));
        await settle(tester);
        await tester.tap(
          find.descendant(
            of: find.byType(SimpleDialog),
            matching: find.text('Bank'),
          ),
        );
        await settle(tester);
        await fill(tester, 'Title', 'Everyday bank');
        await fill(tester, 'Opening balance (USD)', '1000.00');
        await save(tester);
        var saved = await read(tester, store);
        final bank = AccountLedger.accounts(saved.data).last['id'] as String;
        expect(Ledger.balance(saved.data), 150000);
        await tester.ensureVisible(
          find.byKey(const Key('finance-account-transfer')),
        );
        await settle(tester);
        await tester.tap(find.byKey(const Key('finance-account-transfer')));
        await settle(tester);
        await tester.tap(
          find.descendant(
            of: find.byType(SimpleDialog),
            matching: find.text('Household'),
          ),
        );
        await settle(tester);
        await tester.tap(
          find.descendant(
            of: find.byType(SimpleDialog),
            matching: find.text('Everyday bank'),
          ),
        );
        await settle(tester);
        await fill(tester, 'Amount (USD)', '125.50');
        await fill(tester, 'Description', 'Move cash once');
        await save(tester);
        saved = await read(tester, store);
        expect(AccountLedger.balances(saved.data), {
          AccountLedger.legacyId: 37450,
          bank: 112550,
        });
        expect(Ledger.balance(saved.data), 150000);
        await menu(tester, bank, 'Reconcile balance');
        await fill(tester, 'Observed balance (USD)', '1100.00');
        await fill(
          tester,
          'Reason for adjustment',
          'Statement checked in person',
        );
        await save(tester);
        saved = await read(tester, store);
        expect(Ledger.balance(saved.data), 147450);
        expect(saved.data['entries'].last['type'], 'reconcileOut');
        expect(saved.data['entries'].last['amount'], 2550);
        expect(Ledger.income(saved.data, '2020-01'), 50000);
        expect(
          Ledger.expenses(
            saved.data,
            DateTime.now().toIso8601String().substring(0, 7),
          ),
          isEmpty,
        );
        await menu(tester, bank, 'Reconciliation history');
        expect(
          find.textContaining('Statement checked in person'),
          findsOneWidget,
        );
        await tester.pageBack();
        await settle(tester);
        await menu(tester, bank, 'Rename account');
        await fill(tester, 'Title', 'Renamed bank');
        await save(tester);
        await menu(tester, bank, 'Archive');
        await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
        await settle(tester);
        saved = await read(tester, store);
        expect(AccountLedger.accounts(saved.data).last['archived'], true);
        expect(Ledger.balance(saved.data), 147450);
        expect(saved.data['reconciliations'], hasLength(1));
        await menu(tester, bank, 'Restore');
        await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
        await settle(tester);
        saved = await read(tester, store);
        expect(AccountLedger.accounts(saved.data).last['archived'], false);
        expect(AccountLedger.accounts(saved.data).last['name'], 'Renamed bank');
        expect(Ledger.balance(saved.data), 147450);
        await tester.pageBack();
        await settle(tester);
        await tester.tap(find.byType(FloatingActionButton));
        await settle(tester);
        await tester.tap(
          find.descendant(
            of: find.byType(SimpleDialog),
            matching: find.text('Expense'),
          ),
        );
        await settle(tester);
        await tester.tap(
          find.descendant(
            of: find.byType(SimpleDialog),
            matching: find.text('Renamed bank'),
          ),
        );
        await settle(tester);
        await fill(tester, 'Amount (USD)', '1.23');
        await fill(tester, 'Description', 'Selected account expense');
        await save(tester);
        saved = await read(tester, store);
        expect(saved.data['entries'].last['account'], bank);
        expect(saved.data['entries'].last['currency'], 'USD');
        expect(Ledger.balance(saved.data), 147327);
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
      'Compact RTL account form accepts signed localized zero and retains draft on failed storage',
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
              home: FinanceAccountsPage(
                ledger: record,
                store: store,
                access: access,
              ),
            ),
          );
          await settle(tester);
          await tester.ensureVisible(
            find.byKey(const Key('finance-account-add')),
          );
          await settle(tester);
          await tester.tap(find.byKey(const Key('finance-account-add')));
          await settle(tester);
          await tester.tap(
            find.descendant(
              of: find.byType(SimpleDialog),
              matching: find.text('Bank'),
            ),
          );
          await settle(tester);
          await fill(tester, 'Title', 'Retain draft');
          await fill(tester, 'Opening balance (USD)', '−٠٫٠٠');
          final input = tester.widget<TextField>(
            field('Opening balance (USD)'),
          );
          expect(input.keyboardType.signed, true);
          expect(input.enableIMEPersonalizedLearning, false);
          await tester.runAsync(
            () => db.execute(
              "CREATE TRIGGER fail_account BEFORE UPDATE ON private_records BEGIN SELECT RAISE(ABORT,'synthetic disk failure'); END",
            ),
          );
          await save(tester);
          expect(field('Opening balance (USD)'), findsOneWidget);
          expect(
            tester.widget<TextField>(field('Title')).controller!.text,
            'Retain draft',
          );
          expect(
            (await read(tester, store)).data.containsKey('accounts'),
            false,
          );
          await tester.runAsync(() => db.execute('DROP TRIGGER fail_account'));
          await save(tester);
          final saved = await read(tester, store);
          expect(AccountLedger.accounts(saved.data).last['opening'], 0);
          expect(Ledger.balance(saved.data), 50000);
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
