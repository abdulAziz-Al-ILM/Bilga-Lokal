import 'dart:convert';

import 'package:bilga/features/finance/account_ledger.dart';
import 'package:bilga/features/finance/ledger.dart';
import 'package:bilga/features/finance/finance_accounts_page.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Map<String, dynamic> legacy() => {
    'title': 'Personal',
    'currency': 'USD',
    'entries': <dynamic>[],
  };
  Map<String, dynamic> setup() {
    var data = AccountLedger.addAccount(
      legacy(),
      id: 'cash',
      name: 'Cash',
      type: 'cash',
      opening: 10000,
      openedOn: '2030-01-01',
    );
    data = AccountLedger.addAccount(
      data,
      id: 'bank',
      name: 'Bank',
      type: 'bank',
      opening: 50000,
      openedOn: '2030-01-01',
    );
    Ledger.validate(data);
    return data;
  }

  Map<String, dynamic> entry(
    String id,
    String type,
    int amount,
    String account,
    String date,
  ) => {
    'id': id,
    'type': type,
    'amount': amount,
    'account': account,
    'currency': 'USD',
    'date': date,
    'category': 'Food',
    'description': 'Synthetic',
    'void': false,
  };
  test(
    'Money uses exact currency minor units and rejects rounding and overflow',
    () {
      expect(parseMoney('0.10', 'USD') + parseMoney('0.20', 'USD'), 30);
      expect(parseMoney('123', 'JPY'), 123);
      expect(parseMoney('1.234', 'KWD'), 1234);
      expect(parseMoney('١٢٫٣٤', 'USD'), 1234);
      expect(() => parseMoney('1.001', 'USD'), throwsFormatException);
      expect(() => parseMoney('0.5', 'JPY'), throwsFormatException);
      expect(
        () => parseMoney('99999999999999999999999', 'USD'),
        throwsFormatException,
      );
    },
  );
  test('Legacy normalization preserves amounts, identity and original input while adding explicit ownership', () {
    final data = legacy();
    (data['entries'] as List).add({
      'id': 'old',
      'type': 'income',
      'amount': 12345,
      'date': '2020-02-29',
      'category': '',
      'description': 'Legacy',
      'void': false,
    });
    final original = jsonEncode(data);
    Ledger.validate(data);
    expect(Ledger.balance(data), 12345);
    final normalized = AccountLedger.normalize(data);
    Ledger.validate(normalized);
    expect(Ledger.balance(normalized), 12345);
    expect(jsonEncode(data), original);
    expect(normalized['entries'].single['id'], 'old');
    expect(normalized['entries'].single['amount'], 12345);
    expect(normalized['entries'].single['currency'], 'USD');
    expect(normalized['entries'].single['account'], AccountLedger.legacyId);
  });
  test('Transfers conserve total balance and never become income or expense; void reverses both sides', () {
    final data = AccountLedger.transfer(
      setup(),
      id: 'move',
      from: 'cash',
      to: 'bank',
      amount: 1500,
      date: '2030-01-10',
    );
    (data['entries'] as List).add(
      entry('food', 'expense', 500, 'bank', '2030-01-11'),
    );
    Ledger.validate(data);
    expect(AccountLedger.balances(data)['cash'], 8500);
    expect(AccountLedger.balances(data)['bank'], 51000);
    expect(Ledger.balance(data), 59500);
    expect(Ledger.income(data, '2030-01'), 0);
    expect(Ledger.expenses(data, '2030-01'), {'Food': 500});
    data['entries'].first['void'] = true;
    Ledger.validate(data);
    expect(AccountLedger.balances(data)['cash'], 10000);
    expect(AccountLedger.balances(data)['bank'], 49500);
    expect(Ledger.balance(data), 59500);
  });
  test(
    'As-of balances exclude future transactions and future opening balances',
    () {
      final data = setup();
      (data['entries'] as List).add(
        entry('future', 'expense', 1000, 'cash', '2030-02-01'),
      );
      Ledger.validate(data);
      expect(Ledger.balance(data, throughDate: '2029-12-31'), 0);
      expect(Ledger.balance(data, throughDate: '2030-01-31'), 60000);
      expect(Ledger.balance(data, throughDate: '2030-02-01'), 59000);
    },
  );
  test('Historical reconciliation uses that date and stays separate from income and spending', () {
    var data = AccountLedger.transfer(
      setup(),
      id: 'move',
      from: 'cash',
      to: 'bank',
      amount: 1000,
      date: '2030-01-10',
    );
    (data['entries'] as List).add(
      entry('later', 'expense', 10000, 'bank', '2030-01-20'),
    );
    data = AccountLedger.reconcile(
      data,
      id: 'observed',
      account: 'bank',
      observed: 40000,
      date: '2030-01-15',
      description: 'Statement checked',
      maxMoney: maxMoney,
    );
    Ledger.validate(data);
    expect(
      AccountLedger.balances(data, throughDate: '2030-01-15')['bank'],
      40000,
    );
    expect(
      AccountLedger.balances(data, throughDate: '2030-01-20')['bank'],
      30000,
    );
    expect(Ledger.expenses(data, '2030-01'), {'Food': 10000});
    expect(Ledger.income(data, '2030-01'), 0);
    expect(data['entries'].last['type'], 'reconcileOut');
    expect(data['entries'].last['amount'], 11000);
    final unchanged = AccountLedger.reconcile(
      data,
      id: 'none',
      account: 'bank',
      observed: 40000,
      date: '2030-01-15',
      description: 'Same statement',
      maxMoney: maxMoney,
    );
    expect(unchanged['entries'].length, data['entries'].length);
  });
  test(
    'Account ownership, currency, archival and opening dates fail closed',
    () {
      for (final change in ['currency', 'id', 'openedOn']) {
        final data = setup();
        final account = (data['accounts'] as List).last as Map;
        account[change] = switch (change) {
          'currency' => 'EUR',
          'id' => 'cash',
          _ => '2030-02-31',
        };
        expect(() => Ledger.validate(data), throwsFormatException);
      }
      final data = setup();
      data['accounts'].last['archived'] = true;
      expect(
        () => AccountLedger.transfer(
          data,
          id: 'bad',
          from: 'cash',
          to: 'bank',
          amount: 1,
          date: '2030-01-10',
        ),
        throwsFormatException,
      );
      expect(
        () => AccountLedger.transfer(
          setup(),
          id: 'bad',
          from: 'cash',
          to: 'cash',
          amount: 1,
          date: '2030-01-10',
        ),
        throwsFormatException,
      );
      final before = setup();
      before['entries'].add(entry('early', 'expense', 1, 'cash', '2029-12-31'));
      expect(() => Ledger.validate(before), throwsFormatException);
      final foreign = setup();
      foreign['entries'].add({
        ...entry('foreign', 'income', 1, 'cash', '2030-01-01'),
        'currency': 'EUR',
      });
      expect(() => Ledger.validate(foreign), throwsFormatException);
    },
  );
  test('Future account versions and monetary boundary violations never silently normalize', () {
    final future = setup();
    future['accountsVersion'] = 2;
    final original = jsonEncode(future);
    expect(() => AccountLedger.normalize(future), throwsFormatException);
    expect(jsonEncode(future), original);
    future['accountsVersion'] = 1.0;
    expect(() => Ledger.validate(future), throwsFormatException);
    final overflow = AccountLedger.addAccount(
      legacy(),
      id: 'cash',
      name: 'Cash',
      type: 'cash',
      opening: maxMoney,
      openedOn: '2030-01-01',
    );
    overflow['entries'].add(
      entry('overflow', 'income', 1, 'cash', '2030-01-01'),
    );
    expect(() => Ledger.validate(overflow), throwsFormatException);
    expect(
      () => AccountLedger.reconcile(
        setup(),
        id: 'huge',
        account: 'cash',
        observed: maxMoney + 1,
        date: '2030-01-01',
        description: 'Invalid',
        maxMoney: maxMoney,
      ),
      throwsFormatException,
    );
  });
  test('Debt repayments retain outstanding arithmetic across accounts and reject overpayment', () {
    final data = setup();
    data['entries'].addAll([
      entry('loan', 'lent', 1000, 'cash', '2030-01-01'),
      {
        ...entry('repay', 'repaymentIn', 400, 'bank', '2030-01-02'),
        'parent': 'loan',
      },
    ]);
    Ledger.validate(data);
    expect(Ledger.outstanding(data, data['entries'].first), 600);
    expect(AccountLedger.balances(data)['cash'], 9000);
    expect(AccountLedger.balances(data)['bank'], 50400);
    data['entries'].last['amount'] = 1001;
    expect(() => Ledger.validate(data), throwsFormatException);
  });
  test('Signed localized money and CSV preserve currency, audit and safe text cells', () {
    expect(parseSignedMoney('−٠٫٠٠', 'USD'), 0);
    expect(parseSignedMoney('-12,34', 'USD'), -1234);
    expect(parseSignedMoney('0', 'JPY'), 0);
    expect(() => parseSignedMoney('-0.001', 'USD'), throwsFormatException);
    var data = AccountLedger.transfer(
      setup(),
      id: 'move',
      from: 'cash',
      to: 'bank',
      amount: 1500,
      date: '2030-01-10',
      description: '=SUM(1,2)',
    );
    data = AccountLedger.reconcile(
      data,
      id: 'matched',
      account: 'bank',
      observed: 51500,
      date: '2030-01-10',
      description: 'Checked "statement", unchanged',
      maxMoney: maxMoney,
    );
    Ledger.validate(data);
    expect(data['entries'], hasLength(1));
    expect(data['reconciliations'], hasLength(1));
    expect(data['reconciliations'].single['adjustment'], isNull);
    final csv = Ledger.csv(data);
    expect(csv, contains('"15.00","USD"'));
    expect(csv, contains('"\'=SUM(1,2)"'));
    expect(csv, contains('"Cash","Bank"'));
    expect(
      Ledger.accountsCsv(data, throughDate: '2030-01-10'),
      contains('"515.00"'),
    );
    expect(
      Ledger.reconciliationsCsv(data),
      contains('"Checked ""statement"", unchanged"'),
    );
  });
  test('Audit rejects missing ownership, foreign accounts, duplicate observations and mismatched adjustments', () {
    final valid = AccountLedger.reconcile(
      setup(),
      id: 'audit',
      account: 'bank',
      observed: 49000,
      date: '2030-01-10',
      description: 'Checked',
      maxMoney: maxMoney,
    );
    Ledger.validate(valid);
    for (final kind in [
      'owner',
      'account',
      'duplicate',
      'adjustment',
      'date',
      'reason',
    ]) {
      final data = jsonDecode(jsonEncode(valid)) as Map<String, dynamic>;
      final audit = data['reconciliations'].single as Map;
      switch (kind) {
        case 'owner':
          (data['entries'].single as Map).remove('account');
        case 'account':
          audit['account'] = 'missing';
        case 'duplicate':
          data['reconciliations'].add(Map.from(audit));
        case 'adjustment':
          audit['adjustment'] = 'missing';
        case 'date':
          audit['date'] = '2029-12-31';
        case 'reason':
          audit['description'] = ' ';
      }
      expect(() => Ledger.validate(data), throwsFormatException, reason: kind);
    }
    valid['entries'].single['void'] = true;
    Ledger.validate(valid);
    expect(Ledger.reconciliationsCsv(valid), contains('"audit","true"'));
  });
}
