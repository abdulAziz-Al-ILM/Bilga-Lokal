import 'dart:convert';

import 'account_ledger.dart';
import 'ledger.dart';

/// Plans describe intentions. Only explicit confirmation posts a transaction.
class FinancePlanning {
  static Map<String, dynamic> plan(Map<String, dynamic> data) =>
      Map<String, dynamic>.from(
        data['planning'] as Map? ??
            {
              'v': 1,
              'categories': [],
              'budgets': [],
              'goals': [],
              'recurring': [],
              'debts': {},
            },
      );
  static bool _text(Object? value, {int max = 200}) =>
      value is String && value.trim().isNotEmpty && value.length <= max;
  static bool _money(Object? value) =>
      value is int && value > 0 && value <= maxMoney;
  static bool _month(Object? value) =>
      value is String &&
      RegExp(r'^[0-9]{4}-(0[1-9]|1[0-2])$').hasMatch(value) &&
      !value.startsWith('0000');
  static void validate(Map<String, dynamic> data) {
    if (!data.containsKey('planning')) return;
    final p = data['planning'];
    if (p is! Map ||
        p['v'] != 1 ||
        p.keys.any(
          (k) => !{
            'v',
            'categories',
            'budgets',
            'goals',
            'recurring',
            'debts',
          }.contains(k),
        )) {
      throw const FormatException('finance_planning');
    }
    for (final name in ['categories', 'budgets', 'goals', 'recurring']) {
      if (p[name] is! List || (p[name] as List).length > 2000) {
        throw const FormatException('finance_planning_limit');
      }
    }
    final categories = <String, Map>{};
    for (final c in p['categories']) {
      if (c is! Map ||
          !_text(c['name'], max: 100) ||
          categories.containsKey(c['name']) ||
          c['parent'] is! String ||
          (c['parent'] as String).length > 100 ||
          c['label'] != null && !_text(c['label'], max: 100) ||
          c['archived'] != null && c['archived'] is! bool ||
          c.keys.any(
            (k) => !{'name', 'parent', 'label', 'archived'}.contains(k),
          )) {
        throw const FormatException('finance_category');
      }
      categories[c['name']] = c;
    }
    for (final c in categories.values) {
      final seen = <String>{c['name']};
      var parent = c['parent'] as String;
      while (parent.isNotEmpty) {
        if (!seen.add(parent) || !categories.containsKey(parent)) {
          throw const FormatException('finance_category_cycle');
        }
        parent = categories[parent]!['parent'] as String;
      }
    }
    final budgets = <String>{};
    for (final b in p['budgets']) {
      if (b is! Map ||
          !_month(b['month']) ||
          b['category'] is! String ||
          !categories.containsKey(b['category']) ||
          !_money(b['amount']) ||
          !budgets.add('${b['month']}/${b['category']}')) {
        throw const FormatException('finance_budget');
      }
    }
    final accounts = {for (final a in AccountLedger.accounts(data)) a['id']: a},
        ids = <String>{};
    for (final g in p['goals']) {
      if (g is! Map ||
          !_text(g['id']) ||
          !ids.add(g['id']) ||
          !_text(g['name']) ||
          !_money(g['target']) ||
          !accounts.containsKey(g['account']) ||
          g['deadline'] != null && !AccountLedger.validDate(g['deadline']) ||
          g['archived'] is! bool) {
        throw const FormatException('finance_goal');
      }
    }
    ids.clear();
    for (final r in p['recurring']) {
      if (r is! Map ||
          !_text(r['id']) ||
          !ids.add(r['id']) ||
          !_text(r['name']) ||
          !{'income', 'expense'}.contains(r['type']) ||
          !_money(r['amount']) ||
          !accounts.containsKey(r['account']) ||
          r['category'] is! String ||
          r['description'] is! String ||
          (r['description'] as String).length > 10000 ||
          !AccountLedger.validDate(r['start']) ||
          !{'weekly', 'monthly', 'yearly'}.contains(r['frequency']) ||
          r['every'] is! int ||
          r['every'] < 1 ||
          r['every'] > 120 ||
          r['cursor'] is! int ||
          r['cursor'] < 0 ||
          r['cursor'] > 20000 ||
          r['end'] != null &&
              (!AccountLedger.validDate(r['end']) ||
                  (r['end'] as String).compareTo(r['start']) < 0) ||
          r['active'] is! bool) {
        throw const FormatException('finance_recurring');
      }
      final account = accounts[r['account']]!;
      if (account['openedOn'] != null &&
          (r['start'] as String).compareTo(account['openedOn']) < 0) {
        throw const FormatException('finance_recurring_account');
      }
    }
    if (p['debts'] is! Map || (p['debts'] as Map).length > 20000) {
      throw const FormatException('finance_debts');
    }
    final entries = {for (final e in data['entries']) e['id']: e};
    for (final e in (p['debts'] as Map).entries) {
      final debt = entries[e.key], d = e.value;
      if (debt == null ||
          !{'lent', 'borrowed'}.contains(debt['type']) ||
          d is! Map ||
          !AccountLedger.validDate(d['date']) ||
          (d['date'] as String).compareTo(debt['date']) < 0 ||
          d['minute'] != null &&
              (d['minute'] is! int || d['minute'] < 0 || d['minute'] > 1439)) {
        throw const FormatException('finance_deadline');
      }
    }
  }

  static Map<String, String> categoryLabels(Map<String, dynamic> source) => {
    for (final row in plan(source)['categories'])
      row['name'] as String: (row['label'] ?? row['name']) as String,
  };

  static bool hasCategoryManagement(Map<String, dynamic> source) =>
      (plan(source)['categories'] as List).any(
        (row) => row.containsKey('label') || row.containsKey('archived'),
      );

  static Set<String> descendants(Map<String, dynamic> data, String name) {
    final result = <String>{}, children = <String, List<String>>{};
    for (final c in plan(data)['categories']) {
      (children[c['parent']] ??= []).add(c['name']);
    }
    final pending = [name];
    while (pending.isNotEmpty) {
      final key = pending.removeLast();
      if (result.add(key)) pending.addAll(children[key] ?? const []);
    }
    return result;
  }

  static int spent(
    Map<String, dynamic> data,
    String month,
    String category,
    String through,
  ) {
    final names = category.isEmpty ? null : descendants(data, category);
    return (data['entries'] as List)
        .where(
          (e) =>
              e['void'] != true &&
              e['type'] == 'expense' &&
              (e['date'] as String).startsWith(month) &&
              (e['date'] as String).compareTo(through) <= 0 &&
              (names == null || names.contains(e['category'])),
        )
        .fold(0, (sum, e) => sum + (e['amount'] as int));
  }

  static int goalProgress(
    Map<String, dynamic> data,
    Map goal,
    String through,
  ) =>
      (AccountLedger.balances(data, throughDate: through)[goal['account']] ?? 0)
          .clamp(0, maxMoney);
  static int percent(int amount, int target) => target <= 0
      ? 0
      : ((BigInt.from(amount) * BigInt.from(100)) ~/ BigInt.from(target))
            .toInt();

  /// Existing whole-ledger monthly budgets keep their original representation.
  static List<Map<String, dynamic>> budgets(
    Map<String, dynamic> data,
    String month,
  ) => [
    if ((data['budgets']?[month] ?? data['budget'] ?? 0) > 0)
      {
        'month': month,
        'category': '',
        'amount': data['budgets']?[month] ?? data['budget'],
      },
    for (final b in plan(data)['budgets'])
      if (b['month'] == month) Map<String, dynamic>.from(b),
  ];
  static Map<String, dynamic> setBudget(
    Map<String, dynamic> source,
    String month,
    String category,
    int amount,
  ) {
    if (!_month(month) || !_money(amount)) {
      throw const FormatException('finance_budget');
    }
    final next = jsonDecode(jsonEncode(source)) as Map<String, dynamic>;
    if (category.isEmpty) {
      next['budgets'] = {...?next['budgets'] as Map?, month: amount};
      Ledger.validate(next);
      return next;
    }
    return change(next, (p) {
      final rows = p['budgets'] as List;
      rows.removeWhere((b) => b['month'] == month && b['category'] == category);
      rows.add({'month': month, 'category': category, 'amount': amount});
    });
  }

  static ({BigInt income, BigInt expense}) plannedTotals(
    Map<String, dynamic> data,
    String month,
    String from,
  ) {
    if (!_month(month) || !AccountLedger.validDate(from)) {
      throw const FormatException('finance_range');
    }
    final first = DateTime.parse('$month-01'),
        until = DateTime.utc(first.year, first.month + 1);
    var income = BigInt.zero, expense = BigInt.zero;
    for (final r in plan(data)['recurring']) {
      if (r['active'] != true) continue;
      final start = DateTime.parse(r['start']), every = r['every'] as int;
      final distance = switch (r['frequency']) {
        'weekly' =>
          DateTime.utc(first.year, first.month)
                  .difference(DateTime.utc(start.year, start.month, start.day))
                  .inDays ~/
              (7 * every),
        'monthly' =>
          ((first.year - start.year) * 12 + first.month - start.month) ~/ every,
        _ => (first.year - start.year) ~/ every,
      };
      var index = (distance - 1).clamp(r['cursor'] as int, 20000);
      for (; index <= 20000; index++) {
        final date = occurrence(r, cursor: index);
        if (date == null || !DateTime.parse(date).isBefore(until)) break;
        if (date.compareTo(from) < 0 || !date.startsWith(month)) continue;
        if (r['type'] == 'income') {
          income += BigInt.from(r['amount']);
        } else {
          expense += BigInt.from(r['amount']);
        }
      }
    }
    return (income: income, expense: expense);
  }

  static String plannedMoney(BigInt value, String currency) {
    final places = currencies[currency];
    if (places == null) throw const FormatException('currency');
    final digits = value.abs().toString().padLeft(places + 1, '0');
    return '${value.isNegative ? '-' : ''}${places == 0 ? digits : '${digits.substring(0, digits.length - places)}.${digits.substring(digits.length - places)}'} $currency';
  }

  /// Complete readable plans remain available through read-only access/export.
  static String readable(
    Map<String, dynamic> data, {
    required String Function(String) label,
    required String Function(String) date,
    required String through,
  }) {
    if (!data.containsKey('planning') &&
        data['budgets'] == null &&
        data['budget'] == null) {
      return '';
    }
    final p = plan(data), currency = data['currency'] as String;
    final accounts = {
      for (final a in AccountLedger.accounts(data)) a['id']: a['name'],
    };
    final entries = {for (final e in data['entries']) e['id']: e};
    final months = <String>{
      ...((data['budgets'] as Map?)?.keys.cast<String>() ??
          const Iterable<String>.empty()),
      for (final b in p['budgets']) b['month'] as String,
    }.toList()..sort();
    return [
      label('fpPlanning'),
      for (final c in p['categories'])
        '${label('xCategory')}: ${c['parent'] == '' ? '' : '${c['parent']} → '}${c['name']}',
      if ((data['budget'] ?? 0) > 0)
        '${label('xBudget')}: ${moneyText(data['budget'], currency)}',
      for (final month in months)
        for (final b in budgets(data, month))
          '${label('fpBudget')} · $month · ${b['category'] == '' ? label('fpAllCategories') : b['category']}\n${moneyText(spent(data, month, b['category'], through), currency)} / ${moneyText(b['amount'], currency)}',
      label('fpGoalBalanceInfo'),
      for (final g in p['goals'])
        '${label('fpGoal')}: ${g['name']} · ${accounts[g['account']]}\n${moneyText(goalProgress(data, g, through), currency)} / ${moneyText(g['target'], currency)}${g['deadline'] == null ? '' : '\n${label('fpDeadline')}: ${date(g['deadline'])}'}${g['archived'] == true ? '\n${label('archive')}' : ''}',
      label('fpPostExplain'),
      for (final r in p['recurring'])
        '${label('fpRecurring')}: ${r['name']}\n${moneyText(r['amount'], currency)} · ${label('x${r['type']}')} · ${accounts[r['account']]}\n${label('fp${r['frequency']}')} × ${r['every']}\n${occurrence(r) == null ? label('fpCompleted') : date(occurrence(r)!)}${r['active'] == true ? '' : '\n${label('fpPause')}'}\n${r['description']}',
      for (final item in (p['debts'] as Map).entries)
        '${label('fpDebtDeadline')}: ${entries[item.key]['description']}\n${date(item.value['date'])} · ${moneyText(Ledger.outstanding(data, entries[item.key], throughDate: through), currency)}${item.value['minute'] == null ? '' : '\n${label('haReminder')}: ${(item.value['minute'] ~/ 60).toString().padLeft(2, '0')}:${(item.value['minute'] % 60).toString().padLeft(2, '0')}'}',
    ].join('\n\n');
  }

  static String? occurrence(Map rule, {int? cursor}) {
    final start = DateTime.parse(rule['start'] as String),
        n = (cursor ?? rule['cursor'] as int) * (rule['every'] as int);
    DateTime at;
    if (rule['frequency'] == 'weekly') {
      at = DateTime.utc(start.year, start.month, start.day + n * 7);
    } else {
      final month = rule['frequency'] == 'yearly'
          ? start.month
          : start.month + n;
      final year = rule['frequency'] == 'yearly' ? start.year + n : start.year;
      final first = DateTime.utc(year, month),
          last = DateTime.utc(year, month + 1, 0).day;
      at = DateTime.utc(
        first.year,
        first.month,
        start.day > last ? last : start.day,
      );
    }
    if (at.year < 1 || at.year > 9999) return null;
    final key = at.toIso8601String().substring(0, 10);
    return rule['end'] != null && key.compareTo(rule['end'] as String) > 0
        ? null
        : key;
  }

  static Map<String, dynamic> change(
    Map<String, dynamic> source,
    void Function(Map<String, dynamic>) edit,
  ) {
    final next = jsonDecode(jsonEncode(source)) as Map<String, dynamic>,
        p = plan(next);
    edit(p);
    next['planning'] = p;
    Ledger.validate(next);
    return next;
  }

  static Map<String, dynamic> confirmOccurrence(
    Map<String, dynamic> source,
    String ruleId,
    String expectedDate, {
    required String today,
    required bool skip,
  }) {
    final next = AccountLedger.normalize(source),
        p = plan(next),
        rules = p['recurring'] as List;
    final i = rules.indexWhere((r) => r['id'] == ruleId);
    if (i < 0) throw StateError('recurring_missing');
    final rule = Map<String, dynamic>.from(rules[i]), date = occurrence(rule);
    if (rule['active'] != true ||
        date != expectedDate ||
        date == null ||
        date.compareTo(today) > 0) {
      throw StateError('recurring_changed');
    }
    final id = 'recurring:$ruleId:$date', entries = next['entries'] as List;
    if (!skip && entries.any((e) => e['id'] == id)) {
      throw StateError('recurring_already_posted');
    }
    if (!skip) {
      final account = AccountLedger.accounts(next)
          .singleWhere((a) => a['id'] == rule['account']);
      if (account['archived'] == true) throw StateError('account_archived');
      entries.add({
        'id': id,
        'type': rule['type'],
        'amount': rule['amount'],
        'currency': next['currency'],
        'account': rule['account'],
        'category': rule['category'],
        'description': rule['description'],
        'date': date,
        'void': false,
        'sourceRule': ruleId,
        'sourceDate': date,
      });
    }
    rule['cursor'] = (rule['cursor'] as int) + 1;
    if (rule['cursor'] > 20000) throw StateError('recurring_limit');
    if (occurrence(rule) == null) rule['active'] = false;
    rules[i] = rule;
    next['planning'] = p;
    Ledger.validate(next);
    return next;
  }
}
