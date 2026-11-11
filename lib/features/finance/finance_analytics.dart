import 'account_ledger.dart';
import 'ledger.dart';

class FinanceBucket {
  final String date;
  final int income, expenses, cashChange, openings;
  const FinanceBucket(
    this.date,
    this.income,
    this.expenses,
    this.cashChange,
    this.openings,
  );
  int get surplus => income - expenses;
}

/// Integer amounts throughout; floating point is reserved for chart geometry.
/// Whole-ledger transfers cancel out. Debt and reconciliation cash movements
/// remain distinct from ordinary income and expense.
class FinanceAnalytics {
  final String from, through;
  final int openingBalance,
      closingBalance,
      income,
      expenses,
      cashChange,
      recognizedOpenings;
  final Map<String, int> categories;
  final List<FinanceBucket> daily;
  const FinanceAnalytics._(
    this.from,
    this.through,
    this.openingBalance,
    this.closingBalance,
    this.income,
    this.expenses,
    this.cashChange,
    this.recognizedOpenings,
    this.categories,
    this.daily,
  );
  int get surplus => income - expenses;
  int get otherCashChange => cashChange - surplus;
  int get balanceChange => closingBalance - openingBalance;

  static DateTime _utc(String day) {
    final parts = day.split('-').map(int.parse).toList();
    return DateTime.utc(parts[0], parts[1], parts[2]);
  }

  static String _day(DateTime value) =>
      value.toIso8601String().substring(0, 10);

  factory FinanceAnalytics.calculate(
    Map<String, dynamic> data, {
    required String from,
    required String through,
  }) {
    Ledger.validate(data);
    if (!AccountLedger.validDate(from) ||
        !AccountLedger.validDate(through) ||
        from.compareTo(through) > 0) {
      throw const FormatException('report_range');
    }
    final first = _utc(from), last = _utc(through);
    final count = last.difference(first).inDays + 1;
    if (count > 3660) throw const FormatException('report_range');
    final amounts = <String, List<int>>{};
    for (var offset = 0; offset < count; offset++) {
      amounts[_day(first.add(Duration(days: offset)))] = [0, 0, 0, 0];
    }
    final categories = <String, int>{};
    var income = 0, expenses = 0, cash = 0, openings = 0;
    for (final row in data['entries'] as List) {
      if (row['void'] == true) continue;
      final target = amounts[row['date']];
      if (target == null) continue;
      final amount = row['amount'] as int;
      final delta = AccountLedger.delta(row as Map);
      target[2] += delta;
      cash += delta;
      if (row['type'] == 'income') {
        target[0] += amount;
        income += amount;
      }
      if (row['type'] == 'expense') {
        target[1] += amount;
        expenses += amount;
        final name = row['category'] as String;
        categories[name] = (categories[name] ?? 0) + amount;
      }
    }
    for (final account in AccountLedger.accounts(data)) {
      final target = amounts[account['openedOn']];
      if (target != null) {
        final amount = account['opening'] as int;
        target[3] += amount;
        openings += amount;
      }
    }
    final before = _day(first.subtract(const Duration(days: 1)));
    final result = FinanceAnalytics._(
      from,
      through,
      Ledger.balance(data, throughDate: before),
      Ledger.balance(data, throughDate: through),
      income,
      expenses,
      cash,
      openings,
      Map.unmodifiable(categories),
      List.unmodifiable([
        for (final item in amounts.entries)
          FinanceBucket(
            item.key,
            item.value[0],
            item.value[1],
            item.value[2],
            item.value[3],
          ),
      ]),
    );
    if (result.balanceChange != result.cashChange + result.recognizedOpenings) {
      throw StateError('report_balance');
    }
    return result;
  }

  List<FinanceBucket> grouped({required bool weekly}) {
    final groups = <String, List<int>>{};
    for (final day in daily) {
      final date = _utc(day.date);
      final key = weekly
          ? _day(date.subtract(Duration(days: date.weekday - 1)))
          : day.date.substring(0, 7);
      final target = groups.putIfAbsent(key, () => [0, 0, 0, 0]);
      target[0] += day.income;
      target[1] += day.expenses;
      target[2] += day.cashChange;
      target[3] += day.openings;
    }
    return List.unmodifiable([
      for (final entry in groups.entries)
        FinanceBucket(
          entry.key,
          entry.value[0],
          entry.value[1],
          entry.value[2],
          entry.value[3],
        ),
    ]);
  }
}
