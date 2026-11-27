import 'settle_io.dart';
import 'guide_preference_guard.dart';

import 'dart:io';

import 'package:bilga/core/strings.dart';
import 'package:bilga/features/agent/agent_access.dart';
import 'package:bilga/features/finance/finance_page.dart';
import 'package:bilga/features/finance/finance_planning.dart';
import 'package:bilga/features/finance/ledger.dart';
import 'package:bilga/features/guidance/guide_host.dart';
import 'package:bilga/features/reminders/module_reminder_sync.dart';
import 'package:bilga/features/notes/note_database.dart';
import 'package:bilga/features/private_space/record_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

class PlanningUiStore extends RecordStore {
  bool fail = false;
  PlanningUiStore(Database db) : super(database: db);
  @override
  Future<PrivateRecord> save(
    String kind,
    Map<String, dynamic> data, {
    PrivateRecord? previous,
  }) async {
    if (fail) throw StateError('synthetic_save_failure');
    return super.save(kind, data, previous: previous);
  }
}

void registerFinancePlanningUiCases({
  Future<Directory> Function()? createDirectory,
  bool secure = false,
  bool includeCompact = true,
}) {
  preserveGuidePreferences(secure, [
    'finance.journal',
    'finance.category',
    'finance.budget',
    'finance.goal',
    'finance.recurring',
    'finance.debt',
  ]);
  Future<void> settle(WidgetTester t) => settleIo(t);

  Future<void> tap(WidgetTester t, Finder f) async {
    if (f.evaluate().isEmpty) {
      await t.scrollUntilVisible(
        f,
        250,
        scrollable: find.byType(Scrollable).first,
        maxScrolls: 40,
      );
    } else {
      await t.ensureVisible(f);
    }
    await settle(t);
    await t.tap(f);
    await settle(t);
  }

  Future<void> key(WidgetTester t, String value) =>
      tap(t, find.byKey(Key(value)));
  Future<void> field(WidgetTester t, String label, String value) async {
    final f = find.byWidgetPredicate(
      (w) => w is TextField && w.decoration?.labelText == label,
    );
    await tap(t, f);
    await t.enterText(f, value);
    await settle(t);
  }

  Future<(Directory, Database, PlanningUiStore, AgentAccess, String)> setup(
    WidgetTester t, {
    bool compact = false,
  }) async {
    final r = (await t.runAsync(() async {
      await Strings.load();
      if (!secure) SharedPreferences.setMockInitialValues({});
      final dir =
          await (createDirectory?.call() ??
              Directory.systemTemp.createTemp('bilga-finance-planning-ui-'));
      final db = await NoteDatabase.openAt(
            '${dir.path}/notes.db',
            secure: secure,
          ),
          store = PlanningUiStore(db);
      final saved = await store.save('finance', {
        'title': 'Synthetic ledger',
        'currency': 'USD',
        'entries': <dynamic>[],
      });
      return (
        dir,
        db,
        store,
        AgentAccess()..owned.addAll([AgentAccess.finance, AgentAccess.core]),
        saved.id,
      );
    }))!;
    await t.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        builder: (c, child) => compact
            ? MediaQuery(
                data: MediaQuery.of(c)
                    .copyWith(textScaler: const TextScaler.linear(2)),
                child: Directionality(
                  textDirection: TextDirection.rtl,
                  child: child!,
                ),
              )
            : child!,
        home: FinancePage(store: r.$3, access: r.$4),
      ),
    );
    await settle(t);
    await key(t, 'finance-all-features');
    await key(t, 'finance-planning-open');
    return r;
  }

  Future<void> cleanup(
    WidgetTester t,
    (Directory, Database, PlanningUiStore, AgentAccess, String) r,
  ) async {
    await t.pumpWidget(const SizedBox.shrink());
    await settle(t);
    await t.runAsync(() async {
      await r.$2.close();
      await r.$1.delete(recursive: true);
    });
    r.$4.dispose();
  }

  testWidgets(
    'Real Finance planning guide waits for successful category Save, permits retry, and creates no personal examples',
    (t) async {
      final r = await setup(t);
      try {
        expect(
          FinancePlanning.plan(
            (await t.runAsync(() => r.$3.get(r.$5)))!.data,
          )['categories'],
          isEmpty,
        );
        await key(t, 'finance-planning-help');
        var guide = t
            .widget<GuideHost>(find.byType(GuideHost).first)
            .controller;
        await key(t, 'finance-add-category');
        await tap(t, find.text(Strings.get('en', 'fpNoParent')).last);
        expect(guide.step.id, 'name');
        expect(guide.canBack, isFalse);
        await field(t, Strings.get('en', 'title'), 'Home');
        await key(t, 'guide-next');
        expect(guide.step.id, 'save');
        r.$3.fail = true;
        await tap(t, find.text(Strings.get('en', 'save')).last);
        expect(guide.step.id, 'save');
        expect(
          FinancePlanning.plan(
            (await t.runAsync(() => r.$3.get(r.$5)))!.data,
          )['categories'],
          isEmpty,
        );
        r.$3.fail = false;
        await tap(t, find.text(Strings.get('en', 'save')).last);
        expect(guide.step.id, 'results');
        expect(guide.canBack, isFalse);
        expect(
          FinancePlanning.plan(
            (await t.runAsync(() => r.$3.get(r.$5)))!.data,
          )['categories'].single['name'],
          'Home',
        );
        expect(t.takeException(), isNull);
        await key(t, 'guide-next');
        expect(guide.active, isFalse);
      } finally {
        await cleanup(t, r);
      }
    },
  );
  testWidgets(
    'Real monthly budget and goal forms save exact amounts without creating transactions',
    (t) async {
      final r = await setup(t);
      try {
        await key(t, 'finance-guide-budget');
        await key(t, 'finance-add-budget');
        await tap(t, find.text(Strings.get('en', 'fpAllCategories')).last);
        await field(t, '${Strings.get('en', 'xAmount')} (USD)', '123.45');
        await key(t, 'guide-next');
        await tap(t, find.text(Strings.get('en', 'save')).last);
        var data = (await t.runAsync(() => r.$3.get(r.$5)))!.data;
        final month = DateTime.now().toIso8601String().substring(0, 7);
        expect(data['budgets'][month], 12345);
        expect(data['entries'], isEmpty);
        await key(t, 'guide-next');
        await key(t, 'finance-guide-goal');
        await key(t, 'finance-add-goal');
        await tap(t, find.text('Synthetic ledger').last);
        await field(t, Strings.get('en', 'title'), 'Emergency fund');
        await key(t, 'guide-next');
        await field(t, '${Strings.get('en', 'fpTarget')} (USD)', '500.00');
        await key(t, 'guide-next');
        await tap(t, find.text(Strings.get('en', 'save')).last);
        data = (await t.runAsync(() => r.$3.get(r.$5)))!.data;
        expect(FinancePlanning.plan(data)['goals'].single['target'], 50000);
        expect(Ledger.balance(data), 0);
        expect(data['entries'], isEmpty);
        await tap(
          t,
          find.byElementPredicate(
            (element) =>
                element.widget.key == const Key('guide-next') &&
                ModalRoute.isCurrentOf(element) != false,
          ),
        );
        await tap(t, find.text(Strings.get('en', 'archive')).last);
        expect(
          FinancePlanning.plan(
            (await t.runAsync(() => r.$3.get(r.$5)))!.data,
          )['goals'].single['archived'],
          isTrue,
        );
        await key(t, 'finance-show-archived-goals');
        await tap(t, find.text(Strings.get('en', 'restore')).last);
        expect(
          FinancePlanning.plan(
            (await t.runAsync(() => r.$3.get(r.$5)))!.data,
          )['goals'].single['archived'],
          isFalse,
        );
        expect(t.takeException(), isNull);
      } finally {
        await cleanup(t, r);
      }
    },
  );
  testWidgets(
    'Recurring plan opens editable draft, posts only after real confirmation, and cannot duplicate a date',
    (t) async {
      final r = await setup(t);
      try {
        await key(t, 'finance-section-recurring');
        await key(t, 'finance-add-recurring');
        await tap(t, find.text('Synthetic ledger').last);
        await tap(t, find.text(Strings.get('en', 'xexpense')).last);
        await tap(t, find.text(Strings.get('en', 'fpmonthly')).last);
        await tap(t, find.text(Strings.get('en', 'fpUncategorized')).last);
        await field(t, Strings.get('en', 'title'), 'Rent');
        await field(t, '${Strings.get('en', 'xAmount')} (USD)', '100.01');
        await tap(t, find.text(Strings.get('en', 'save')).last);
        var data = (await t.runAsync(() => r.$3.get(r.$5)))!.data;
        expect(data['entries'], isEmpty);
        final id = FinancePlanning.plan(data)['recurring'].single['id'];
        await key(t, 'finance-post-$id');
        expect(
          (await t.runAsync(() => r.$3.get(r.$5)))!.data['entries'],
          isEmpty,
        );
        await tap(t, find.text(Strings.get('en', 'continue')).last);
        data = (await t.runAsync(() => r.$3.get(r.$5)))!.data;
        expect((data['entries'] as List).length, 1);
        expect(Ledger.balance(data), -10001);
        expect(find.byKey(Key('finance-post-$id')), findsNothing);
        await tap(t, find.text(Strings.get('en', 'edit')).last);
        await field(t, '${Strings.get('en', 'xAmount')} (USD)', '101.02');
        await tap(t, find.text(Strings.get('en', 'save')).last);
        data = (await t.runAsync(() => r.$3.get(r.$5)))!.data;
        expect(FinancePlanning.plan(data)['recurring'], hasLength(1));
        expect(FinancePlanning.plan(data)['recurring'].single['cursor'], 1);
        expect((data['entries'] as List).single['amount'], 10001);
        expect(t.takeException(), isNull);
      } finally {
        await cleanup(t, r);
      }
    },
  );
  testWidgets(
    'Finance onboarding uses real journal controls, chosen currency and a successful Save, with no invented transactions',
    (t) async {
      final r = await setup(t);
      try {
        await t.pumpWidget(const SizedBox.shrink());
        await settle(t);
        await t.runAsync(() async {
          await r.$3.remove(await r.$3.get(r.$5));
        });
        await t.pumpWidget(
          MaterialApp(
            home: FinancePage(store: r.$3, access: r.$4, tutorial: true),
          ),
        );
        await settle(t);
        final guide = t
            .widget<GuideHost>(find.byType(GuideHost).first)
            .controller;
        expect(guide.step.id, 'create');
        expect((await t.runAsync(() => r.$3.all('finance')))!, isEmpty);
        await tap(t, find.byTooltip(Strings.get('en', 'fpCreateLedger')));
        await field(t, Strings.get('en', 'title'), 'My real journal');
        await key(t, 'guide-next');
        expect(guide.step.id, 'currency');
        await tap(t, find.byType(DropdownButton<String>).last);
        await tap(t, find.text('USD').last);
        await key(t, 'guide-next');
        r.$3.fail = true;
        await tap(t, find.text(Strings.get('en', 'save')).last);
        expect(guide.step.id, 'save');
        expect((await t.runAsync(() => r.$3.all('finance')))!, isEmpty);
        r.$3.fail = false;
        await tap(t, find.text(Strings.get('en', 'save')).last);
        final rows = (await t.runAsync(() => r.$3.all('finance')))!;
        expect(rows, hasLength(1));
        expect(rows.single.data['currency'], 'USD');
        expect(rows.single.data['entries'], isEmpty);
        expect(Ledger.balance(rows.single.data), 0);
        expect(guide.step.id, 'results');
        await key(t, 'guide-next');
        expect(guide.active, isFalse);
        expect(t.takeException(), isNull);
      } finally {
        await cleanup(t, r);
      }
    },
  );
  testWidgets(
    'Real debt deadline guide and optional reminder save only policy, then disabling removes the native mirror',
    (t) async {
      final r = await setup(t);
      try {
        final today = DateTime.now().toIso8601String().substring(0, 10);
        await t.runAsync(() async {
          final old = await r.$3.get(r.$5);
          await r.$3.save('finance', {
            ...old.data,
            'entries': [
              {
                'id': 'debt',
                'type': 'borrowed',
                'amount': 50000,
                'date': today,
                'category': '',
                'description': 'Synthetic loan',
                'void': false,
              },
            ],
          }, previous: old);
        });
        await tap(t, find.byTooltip(Strings.get('en', 'fpRefresh')));
        await key(t, 'finance-guide-debt');
        final guide = t
            .widget<GuideHost>(find.byType(GuideHost).first)
            .controller;
        await tap(t, find.text(Strings.get('en', 'fpDebtDeadline')).last);
        expect(guide.step.id, 'name');
        await key(t, 'guide-next');
        await tap(t, find.text(Strings.get('en', 'save')).last);
        expect(guide.step.id, 'results');
        await key(t, 'guide-next');
        var data = (await t.runAsync(() => r.$3.get(r.$5)))!.data;
        expect(FinancePlanning.plan(data)['debts']['debt']['date'], today);
        expect(Ledger.balance(data), 50000);
        expect(
          (await t.runAsync(() => ModuleReminderSync.financeRows(r.$2)))!,
          isEmpty,
        );
        await tap(t, find.text(Strings.get('en', 'haReminder')).last);
        expect(find.byType(TimePickerDialog), findsOneWidget);
        await tap(t, find.text('OK'));
        expect(
          (await t.runAsync(() => ModuleReminderSync.financeRows(r.$2)))!,
          hasLength(1),
        );
        await tap(t, find.text(Strings.get('en', 'fpDisableReminder')).last);
        expect(
          (await t.runAsync(() => ModuleReminderSync.financeRows(r.$2)))!,
          isEmpty,
        );
        data = (await t.runAsync(() => r.$3.get(r.$5)))!.data;
        expect((data['entries'] as List), hasLength(1));
        expect(Ledger.balance(data), 50000);
        expect(t.takeException(), isNull);
      } finally {
        await cleanup(t, r);
      }
    },
  );
  if (includeCompact) {
    testWidgets(
      'Finance plans are readable and actionable at 360px 2x RTL dark layout',
      (t) async {
        t.view.physicalSize = const Size(360, 800);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        final r = await setup(t, compact: true);
        try {
          await key(t, 'finance-section-budgets');
          await key(t, 'finance-add-budget');
          await tap(t, find.text(Strings.get('en', 'fpAllCategories')).last);
          await field(t, '${Strings.get('en', 'xAmount')} (USD)', '99.99');
          await tap(t, find.text(Strings.get('en', 'save')).last);
          expect(
            (await t.runAsync(() => r.$3.get(r.$5)))!
                .data['budgets']
                .values
                .single,
            9999,
          );
          expect(t.takeException(), isNull);
        } finally {
          await cleanup(t, r);
        }
      },
    );
  }
}
