import 'package:bilga/features/finance/account_ledger.dart';
import 'package:bilga/features/finance/finance_analytics.dart';
import 'package:bilga/features/finance/ledger.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Map<String, dynamic> entry(
    String id,
    String type,
    int amount,
    String date, {
    String category = 'Food',
    bool voided = false,
  }) => {
    'id': id,
    'type': type,
    'amount': amount,
    'date': date,
    'category': category,
    'description': 'Synthetic',
    'void': voided,
  };
  Map<String, dynamic> legacy(List<Map<String, dynamic>> entries) => {
    'title': 'Reports',
    'currency': 'USD',
    'entries': entries,
  };
  test('Reports reconcile opening/closing balances while separating debt and adjustments from income/expenses', () {
    var data = AccountLedger.addAccount(
      legacy([
        entry('before', 'income', 10000, '2026-02-28'),
        entry('pay', 'income', 5000, '2026-03-01', category: 'Work'),
        entry('meal', 'expense', 1200, '2026-03-02'),
        entry('borrow', 'borrowed', 2000, '2026-03-02'),
        entry('future', 'expense', 1000, '2026-04-01'),
        entry('void', 'expense', 999, '2026-03-01', voided: true),
      ]),
      id: 'bank',
      name: 'Bank',
      type: 'bank',
      opening: 3000,
      openedOn: '2026-03-01',
    );
    data = AccountLedger.transfer(
      data,
      id: 'move',
      from: AccountLedger.legacyId,
      to: 'bank',
      amount: 1000,
      date: '2026-03-02',
    );
    data = AccountLedger.reconcile(
      data,
      id: 'adjust',
      account: 'bank',
      observed: 3500,
      date: '2026-03-03',
      description: 'Statement',
      maxMoney: maxMoney,
    );
    final report = FinanceAnalytics.calculate(
      data,
      from: '2026-03-01',
      through: '2026-03-03',
    );
    expect(report.openingBalance, 10000);
    expect(report.closingBalance, 18300);
    expect(report.income, 5000);
    expect(report.expenses, 1200);
    expect(report.surplus, 3800);
    expect(report.otherCashChange, 1500);
    expect(report.recognizedOpenings, 3000);
    expect(report.cashChange, 5300);
    expect(report.categories, {'Food': 1200});
    expect(report.daily.map((row) => row.cashChange), [5000, 800, -500]);
  });
  test('Daily zero buckets and Monday weeks use calendar dates across leap day, DST and year boundary', () {
    final data = legacy([entry('one', 'expense', 100, '2024-02-29')]);
    var report = FinanceAnalytics.calculate(
      data,
      from: '2024-02-28',
      through: '2024-03-02',
    );
    expect(report.daily.map((row) => row.date), [
      '2024-02-28',
      '2024-02-29',
      '2024-03-01',
      '2024-03-02',
    ]);
    expect(report.daily.map((row) => row.expenses), [0, 100, 0, 0]);
    expect(report.grouped(weekly: false).map((row) => row.date), [
      '2024-02',
      '2024-03',
    ]);
    expect(report.grouped(weekly: false).map((row) => row.expenses), [100, 0]);
    report = FinanceAnalytics.calculate(
      data,
      from: '2026-03-07',
      through: '2026-03-10',
    );
    expect(report.daily.length, 4);
    report = FinanceAnalytics.calculate(
      data,
      from: '2026-12-28',
      through: '2027-01-03',
    );
    expect(report.grouped(weekly: true).single.date, '2026-12-28');
    expect(report.daily.length, 7);
  });
  test('Exact large monetary totals retain minor units and signed opening movements', () {
    final data = AccountLedger.addAccount(
      legacy([
        entry('pay', 'income', maxMoney - 1, '2026-01-01'),
        entry('fee', 'expense', 1, '2026-01-01'),
      ]),
      id: 'card',
      name: 'Card',
      type: 'card',
      opening: -maxMoney,
      openedOn: '2026-01-01',
    );
    final report = FinanceAnalytics.calculate(
      data,
      from: '2026-01-01',
      through: '2026-01-01',
    );
    expect(report.income, maxMoney - 1);
    expect(report.expenses, 1);
    expect(report.cashChange, maxMoney - 2);
    expect(report.recognizedOpenings, -maxMoney);
    expect(report.balanceChange, -2);
    expect(report.closingBalance, -2);
    expect(report.grouped(weekly: false).single.cashChange, maxMoney - 2);
  });
  test('Future opening balances remain outside an earlier report and empty periods are explicit zeros', () {
    final data = AccountLedger.addAccount(
      legacy([]),
      id: 'future',
      name: 'Future',
      type: 'savings',
      opening: 10000,
      openedOn: '2030-01-01',
    );
    final report = FinanceAnalytics.calculate(
      data,
      from: '2026-01-01',
      through: '2026-01-31',
    );
    expect(report.daily.length, 31);
    expect(report.income, 0);
    expect(report.expenses, 0);
    expect(report.openingBalance, 0);
    expect(report.closingBalance, 0);
    expect(report.recognizedOpenings, 0);
    expect(report.categories, isEmpty);
  });
  test('Report validation rejects invalid or excessive date ranges before building buckets', () {
    final data = legacy([]);
    for (final pair in [
      ('2026-02-30', '2026-03-01'),
      ('2026-03-02', '2026-03-01'),
      ('0000-01-01', '2026-01-01'),
      ('2000-01-01', '2026-01-01'),
    ]) {
      expect(
        () => FinanceAnalytics.calculate(data, from: pair.$1, through: pair.$2),
        throwsFormatException,
      );
    }
  });
}
