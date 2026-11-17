import 'dart:convert';
import 'dart:io';

import 'package:bilga/core/private_database.dart';
import 'package:bilga/features/backup/backup_store.dart';
import 'package:bilga/features/finance/finance_planning.dart';
import 'package:bilga/features/finance/ledger.dart';
import 'package:bilga/features/finance/transaction_edits.dart';
import 'package:bilga/features/notes/note_database.dart';
import 'package:bilga/features/private_space/record_store.dart';
import 'package:bilga/features/reminders/module_reminder_sync.dart';
import 'package:bilga/features/todo/todo_database.dart';
import 'package:bilga/features/search/search_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

void registerFinancePlanningDataCases({
  Future<Directory> Function()? createDirectory,
  bool secure = false,
}) {
  late Directory dir;
  late Database notes, tasks;
  late RecordStore store;
  Map<String, dynamic> ledger() => {
    'title': 'Synthetic private ledger',
    'currency': 'USD',
    'entries': <dynamic>[],
  };
  Map<String, dynamic> rule({
    String start = '2024-01-31',
    String frequency = 'monthly',
    int amount = 12345,
  }) => {
    'id': 'rule',
    'name': 'PRIVATE recurring',
    'type': 'expense',
    'amount': amount,
    'account': 'legacy-cash',
    'category': 'Home',
    'description': 'PRIVATE description',
    'start': start,
    'frequency': frequency,
    'every': 1,
    'cursor': 0,
    'end': null,
    'active': true,
  };
  Map<String, dynamic> planned() => FinancePlanning.change(ledger(), (p) {
    (p['categories'] as List).addAll([
      {'name': 'Home', 'parent': ''},
      {'name': 'Electricity', 'parent': 'Home'},
    ]);
    (p['recurring'] as List).add(rule());
  });
  setUp(() async {
    dir =
        await (createDirectory?.call() ??
            Directory.systemTemp.createTemp('bilga-finance-planning-'));
    notes = await NoteDatabase.openAt('${dir.path}/notes.db', secure: secure);
    tasks = await TodoDatabase.openAt('${dir.path}/tasks.db', secure: secure);
    store = RecordStore(database: notes);
  });
  tearDown(() async {
    if (notes.isOpen) await notes.close();
    await tasks.close();
    await dir.delete(recursive: true);
  });
  test('Plans are intentions: exact category rollups ignore void/future/debt/transfer and preserve legacy monthly budgets', () {
    var data = planned();
    data = FinancePlanning.setBudget(data, '2024-02', '', 100000);
    data = FinancePlanning.setBudget(data, '2024-02', 'Home', 90000);
    expect(data['budgets']['2024-02'], 100000);
    expect(FinancePlanning.budgets(data, '2024-02').length, 2);
    expect(Ledger.balance(data), 0);
    for (final entry in [
      {
        'id': 'a',
        'type': 'expense',
        'amount': 12345,
        'date': '2024-02-01',
        'category': 'Electricity',
        'void': false,
      },
      {
        'id': 'future',
        'type': 'expense',
        'amount': 9900,
        'date': '2024-02-29',
        'category': 'Electricity',
        'void': false,
      },
      {
        'id': 'void',
        'type': 'expense',
        'amount': 8800,
        'date': '2024-02-01',
        'category': 'Home',
        'void': true,
      },
      {
        'id': 'debt',
        'type': 'lent',
        'amount': 7700,
        'date': '2024-02-01',
        'category': 'Home',
        'void': false,
      },
    ]) {
      (data['entries'] as List).add({...entry, 'description': ''});
    }
    Ledger.validate(data);
    expect(FinancePlanning.spent(data, '2024-02', 'Home', '2024-02-15'), 12345);
    expect(
      FinancePlanning.spent(data, '2024-02', 'Electricity', '2024-02-15'),
      12345,
    );
    expect(FinancePlanning.percent(900000000000000, 899999999999999), 100);
    expect(
      () => FinancePlanning.change(data, (p) {
        p['categories'][0]['parent'] = 'Electricity';
      }),
      throwsFormatException,
    );
    expect(
      () => FinancePlanning.setBudget(data, '2024-02', 'Missing', 10),
      throwsFormatException,
    );
    expect(
      () => FinancePlanning.setBudget(data, '0000-02', '', 10),
      throwsFormatException,
    );
  });
  test('Monthly/yearly anchors retain leap/end-of-month dates; plans and skip never invent money', () {
    final monthly = rule(),
        yearly = rule(start: '2024-02-29', frequency: 'yearly');
    expect(FinancePlanning.occurrence(monthly, cursor: 1), '2024-02-29');
    expect(FinancePlanning.occurrence(monthly, cursor: 2), '2024-03-31');
    expect(FinancePlanning.occurrence(yearly, cursor: 1), '2025-02-28');
    expect(FinancePlanning.occurrence(yearly, cursor: 4), '2028-02-29');
    var data = planned();
    expect(Ledger.balance(data), 0);
    expect(
      () => FinancePlanning.confirmOccurrence(
        data,
        'rule',
        '2024-01-31',
        today: '2024-01-30',
        skip: false,
      ),
      throwsStateError,
    );
    data = FinancePlanning.confirmOccurrence(
      data,
      'rule',
      '2024-01-31',
      today: '2024-03-01',
      skip: false,
    );
    expect(Ledger.balance(data), -12345);
    expect((data['entries'] as List).length, 1);
    expect(
      () => FinancePlanning.confirmOccurrence(
        data,
        'rule',
        '2024-01-31',
        today: '2024-03-01',
        skip: false,
      ),
      throwsStateError,
    );
    data = FinancePlanning.confirmOccurrence(
      data,
      'rule',
      '2024-02-29',
      today: '2024-03-01',
      skip: true,
    );
    expect(Ledger.balance(data), -12345);
    expect((data['entries'] as List).length, 1);
    expect(
      FinancePlanning.occurrence(FinancePlanning.plan(data)['recurring'][0]),
      '2024-03-31',
    );
  });
  test('Planning totals use exact arbitrary precision and jump decades of pending dates without silent truncation', () {
    final data = FinancePlanning.change(ledger(), (p) {
      for (var i = 0; i < 2000; i++) {
        (p['recurring'] as List).add({
          ...rule(start: '1900-01-01', frequency: 'weekly', amount: maxMoney),
          'id': 'rule$i',
        });
      }
    });
    final totals = FinancePlanning.plannedTotals(data, '2026-11', '2026-11-01');
    expect(
      totals.expense,
      BigInt.from(maxMoney) * BigInt.from(2000) * BigInt.from(5),
    );
    expect(totals.income, BigInt.zero);
    expect(
      FinancePlanning.plannedMoney(totals.expense, 'USD'),
      '90000000000000000.00 USD',
    );
    expect(Ledger.balance(data), 0);
  });
  test('Goal progress uses real account balances through today; debt mirror excludes private text and completed/disabled debts', () async {
    var data = ledger();
    data['entries'] = [
      {
        'id': 'income',
        'type': 'income',
        'amount': 50000,
        'date': '2026-11-01',
        'category': '',
        'description': 'PRIVATE income',
        'void': false,
      },
      {
        'id': 'debt',
        'type': 'lent',
        'amount': 10000,
        'date': '2026-11-02',
        'category': '',
        'description': 'PRIVATE debtor',
        'void': false,
      },
      {
        'id': 'future',
        'type': 'income',
        'amount': 90000,
        'date': '2026-12-01',
        'category': '',
        'description': 'PRIVATE future',
        'void': false,
      },
    ];
    data = FinancePlanning.change(data, (p) {
      (p['goals'] as List).add({
        'id': 'goal',
        'name': 'PRIVATE goalmarker',
        'target': 60000,
        'account': 'legacy-cash',
        'deadline': null,
        'archived': false,
      });
      p['debts']['debt'] = {'date': '2026-12-31', 'minute': 540};
    });
    var r = await store.save('finance', data);
    expect(
      FinancePlanning.goalProgress(
        r.data,
        FinancePlanning.plan(r.data)['goals'][0],
        '2026-11-16',
      ),
      40000,
    );
    expect(
      await SearchRepository(
        notesDb: notes,
        todoDb: tasks,
      ).search('goalmarker', kind: 'finance'),
      hasLength(1),
    );
    final readable = FinancePlanning.readable(
      r.data,
      label: (key) => key,
      date: (raw) => raw,
      through: '2026-11-16',
    );
    expect(readable, contains('PRIVATE goalmarker'));
    expect(readable, contains('400.00 USD / 600.00 USD'));
    var rows = await ModuleReminderSync.financeRows(notes);
    expect(rows.length, 1);
    expect(rows.single['target'], r.id);
    expect(rows.single['date'], '2026-12-31');
    expect(jsonEncode(rows), isNot(contains('PRIVATE')));
    expect(
      rows.single.keys,
      unorderedEquals(['id', 'target', 'kind', 'date', 'minute', 'config']),
    );
    expect(jsonDecode(rows.single['config'] as String), ['2026-12-31', 540]);
    r = await store.save(
      'finance',
      FinancePlanning.change(
        r.data,
        (p) => p['debts']['debt']['minute'] = null,
      ),
      previous: r,
    );
    expect(await ModuleReminderSync.financeRows(notes), isEmpty);
    data = FinancePlanning.change(
      r.data,
      (p) => p['debts']['debt']['minute'] = 540,
    );
    data['entries'].add({
      'id': 'repaid',
      'type': 'repaymentIn',
      'amount': 10000,
      'date': '2026-11-15',
      'parent': 'debt',
      'category': '',
      'description': '',
      'void': false,
    });
    await store.save('finance', data, previous: r);
    expect(await ModuleReminderSync.financeRows(notes), isEmpty);
  });
  test('Finance planning backup18 preserves nested references, legacy payload bytes and retry idempotence; stale writes cannot double-post', () async {
    final legacy = await store.save('finance', ledger()),
        before = (await notes.query(
          'private_records',
          where: 'id=?',
          whereArgs: [legacy.id],
        )).single['payload'];
    final r = await store.save('finance', planned());
    final posted = FinancePlanning.confirmOccurrence(
      r.data,
      'rule',
      '2024-01-31',
      today: '2024-03-01',
      skip: false,
    );
    final saved = await store.save('finance', posted, previous: r);
    await expectLater(
      store.save('finance', posted, previous: r),
      throwsStateError,
    );
    expect((await store.get(saved.id)).data, saved.data);
    final backup = BackupStore(notesDb: notes, todoDb: tasks),
        snapshot = await BackupStore(notesDb: notes, todoDb: tasks).snapshot();
    expect(snapshot['notesSchema'], 18);
    final invalid = jsonDecode(jsonEncode(snapshot)) as Map<String, dynamic>;
    invalid['notesSchema'] = 17;
    expect(() => BackupStore.validate(invalid), throwsFormatException);
    expect(await backup.restore(snapshot, 'Imported'), isTrue);
    expect(await backup.restore(snapshot, 'Imported'), isFalse);
    final copies = (await store.all('finance'))
        .where((e) => e.id != saved.id && e.data.containsKey('planning'))
        .toList();
    expect(copies.length, 1);
    expect(copies.single.data, saved.data);
    expect(
      (await notes.query(
        'private_records',
        where: 'id=?',
        whereArgs: [legacy.id],
      )).single['payload'],
      before,
    );
  });
  test('Debt deadline policy counts only matching repayments through its deadline, not later payments or unrelated legacy parent metadata', () async {
    final data = FinancePlanning.change({
      'title': 'Deadline fixture',
      'currency': 'USD',
      'entries': [
        {
          'id': 'debt',
          'type': 'borrowed',
          'amount': 10000,
          'date': '2026-11-01',
          'category': '',
          'description': 'Actual debt',
          'void': false,
        },
        {
          'id': 'payment',
          'type': 'repaymentOut',
          'amount': 10000,
          'date': '2027-01-10',
          'category': '',
          'description': 'Recorded later payment',
          'parent': 'debt',
          'void': false,
        },
        {
          'id': 'unrelated',
          'type': 'income',
          'amount': 10000,
          'date': '2026-11-02',
          'category': '',
          'description': 'Unrelated legacy metadata',
          'parent': 'debt',
          'void': false,
        },
      ],
    }, (p) => p['debts']['debt'] = {'date': '2026-12-31', 'minute': 540});
    final debt = (data['entries'] as List).first;
    expect(Ledger.outstanding(data, debt, throughDate: '2026-12-31'), 10000);
    var record = await store.save('finance', data);
    expect(await ModuleReminderSync.financeRows(notes), hasLength(1));
    record = await store.save(
      'finance',
      TransactionEdits.edit(
        record.data,
        id: 'payment',
        changes: {'date': '2026-12-01'},
      ),
      previous: record,
    );
    expect(
      Ledger.outstanding(
        record.data,
        (record.data['entries'] as List).first,
        throughDate: '2026-11-17',
      ),
      10000,
    );
    expect(await ModuleReminderSync.financeRows(notes), isEmpty);
  });
  test('Notes20 refuses older Notes19 executable without rewriting financial plans', () async {
    final r = await store.save('finance', planned()),
        before = await notes.query('private_records');
    final path = notes.path;
    await notes.close();
    await expectLater(
      PrivateDatabase.open(
        path,
        secure: secure,
        version: 19,
        onCreate: (d, v) async {},
        onUpgrade: (d, a, b) async {},
      ),
      throwsStateError,
    );
    notes = await NoteDatabase.openAt(path, secure: secure);
    expect(await notes.getVersion(), 20);
    expect(await notes.query('private_records'), before);
    expect((await RecordStore(database: notes).get(r.id)).data, r.data);
  });
}
