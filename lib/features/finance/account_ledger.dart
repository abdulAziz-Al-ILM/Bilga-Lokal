import 'dart:convert';

/// Local account records only. Amounts are integer minor units in the selected
/// ledger currency. A transfer is one durable entry affecting both accounts.
class AccountLedger {
  static const legacyId = 'legacy-cash';
  static const accountTypes = {'cash', 'bank', 'card', 'savings'};
  static const specialTypes = {'transfer', 'reconcileIn', 'reconcileOut'};

  static List<Map<String, dynamic>> accounts(Map<String, dynamic> data) =>
      data['accounts'] == null
      ? [
          {
            'id': legacyId,
            'name': data['title'] ?? legacyId,
            'type': 'cash',
            'currency': data['currency'],
            'opening': 0,
            'archived': false,
            'openedOn': null,
          },
        ]
      : (data['accounts'] as List)
            .map((row) => Map<String, dynamic>.from(row as Map))
            .toList();

  /// Explicitly materialize the legacy cash account; preserve original entries
  /// and amounts while making account and currency ownership durable.
  static Map<String, dynamic> normalize(Map<String, dynamic> source) {
    if ((source['accounts'] != null || source.containsKey('accountsVersion')) &&
        (source['accountsVersion'] is! int ||
            source['accountsVersion'] != 1 ||
            source['accounts'] == null)) {
      throw const FormatException('account_version');
    }
    final data = jsonDecode(jsonEncode(source)) as Map<String, dynamic>;
    data['accounts'] = accounts(data);
    data['accountsVersion'] = 1;
    data['entries'] = [
      for (final raw in data['entries'] as List)
        {
          ...Map<String, dynamic>.from(raw as Map),
          'currency': raw['currency'] ?? data['currency'],
          if (raw['type'] != 'transfer') 'account': raw['account'] ?? legacyId,
        },
    ];
    return data;
  }

  static int delta(Map entry) => switch (entry['type']) {
    'transfer' => 0,
    'income' ||
    'borrowed' ||
    'repaymentIn' ||
    'reconcileIn' => entry['amount'] as int,
    'expense' ||
    'lent' ||
    'repaymentOut' ||
    'reconcileOut' => -(entry['amount'] as int),
    _ => throw const FormatException('entry_type'),
  };

  static Map<String, int> balances(
    Map<String, dynamic> data, {
    String? throughDate,
  }) {
    final result = {
      for (final account in accounts(data))
        account['id'] as String:
            throughDate != null &&
                account['openedOn'] != null &&
                (account['openedOn'] as String).compareTo(throughDate) > 0
            ? 0
            : account['opening'] as int,
    };
    for (final raw in data['entries'] as List) {
      final entry = raw as Map;
      if (specialTypes.contains(entry['type']) && data['accounts'] == null) {
        throw const FormatException('account_version');
      }
      if (entry['void'] == true) continue;
      if (throughDate != null &&
          (entry['date'] as String).compareTo(throughDate) > 0) {
        continue;
      }
      if (entry['type'] == 'transfer') {
        final from = entry['from'] as String,
            to = entry['to'] as String,
            amount = entry['amount'] as int;
        result[from] = (result[from] ?? 0) - amount;
        result[to] = (result[to] ?? 0) + amount;
      } else {
        final id = entry['account'] as String? ?? legacyId;
        result[id] = (result[id] ?? 0) + delta(entry);
      }
    }
    return result;
  }

  static int total(Map<String, dynamic> data, {String? throughDate}) =>
      balances(
        data,
        throughDate: throughDate,
      ).values.fold(0, (sum, value) => sum + value);

  static bool validDate(Object? value) =>
      value is String &&
      RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value) &&
      DateTime.tryParse(value) != null &&
      DateTime.parse(value).year >= 1 &&
      DateTime.parse(value).year <= 9999 &&
      DateTime.parse(value).toIso8601String().substring(0, 10) == value;

  static void validate(Map<String, dynamic> data, {required int maxMoney}) {
    if ((data.containsKey('accountsVersion') || data['accounts'] != null) &&
        (data['accountsVersion'] is! int ||
            data['accountsVersion'] != 1 ||
            data['accounts'] == null)) {
      throw const FormatException('account_version');
    }
    final raw = data['accounts'];
    if (raw != null &&
        (raw is! List ||
            raw.isEmpty ||
            raw.length > 1000 ||
            raw.any((row) => row is! Map))) {
      throw const FormatException('accounts');
    }
    final rows = accounts(data), ids = <String>{};
    var openingMagnitude = BigInt.zero;
    for (final row in rows) {
      if (row['id'] is! String ||
          (row['id'] as String).isEmpty ||
          (row['id'] as String).length > 128 ||
          !ids.add(row['id'] as String) ||
          row['name'] is! String ||
          (row['name'] as String).trim().isEmpty ||
          (row['name'] as String).length > 200 ||
          !accountTypes.contains(row['type']) ||
          row['currency'] != data['currency'] ||
          (row['openedOn'] != null && !validDate(row['openedOn'])) ||
          row.keys.any(
            (key) => !{
              'id',
              'name',
              'type',
              'currency',
              'opening',
              'archived',
              'openedOn',
            }.contains(key),
          ) ||
          row['opening'] is! int ||
          (row['opening'] as int).abs() > maxMoney ||
          row['archived'] is! bool) {
        throw const FormatException('account');
      }
      openingMagnitude += BigInt.from(row['opening'] as int).abs();
    }
    if (openingMagnitude > BigInt.from(maxMoney)) {
      throw const FormatException('account_total');
    }
    final byId = {for (final row in rows) row['id']: row};
    for (final raw in data['entries'] as List) {
      final entry = raw as Map;
      if (data['accounts'] != null && entry['currency'] != data['currency']) {
        throw const FormatException('account_currency');
      }
      if (data['accounts'] != null &&
          entry['type'] != 'transfer' &&
          entry['account'] is! String) {
        throw const FormatException('account_missing');
      }
      if (entry['currency'] != null && entry['currency'] != data['currency']) {
        throw const FormatException('account_currency');
      }
      if (entry['type'] == 'transfer') {
        if (entry['currency'] != data['currency'] ||
            entry['from'] is! String ||
            entry['to'] is! String ||
            entry['from'] == entry['to'] ||
            !ids.contains(entry['from']) ||
            !ids.contains(entry['to'])) {
          throw const FormatException('transfer');
        }
      } else if (!ids.contains(entry['account'] ?? legacyId)) {
        throw const FormatException('account_missing');
      }
      final owners = entry['type'] == 'transfer'
          ? [entry['from'], entry['to']]
          : [entry['account'] ?? legacyId];
      for (final id in owners) {
        final account = byId[id]!;
        if (account['openedOn'] != null &&
            (entry['date'] as String).compareTo(account['openedOn'] as String) <
                0) {
          throw const FormatException('account_date');
        }
      }
    }
    final result = balances(data);
    if (result.values.any((value) => value.abs() > maxMoney) ||
        result.values
                .fold<BigInt>(
                  BigInt.zero,
                  (sum, value) => sum + BigInt.from(value),
                )
                .abs() >
            BigInt.from(maxMoney)) {
      throw const FormatException('account_balance');
    }
    final observations = data['reconciliations'];
    if (observations != null) {
      if (data['accounts'] == null) {
        throw const FormatException('account_version');
      }
      final entries = {
        for (final entry in data['entries'] as List) entry['id']: entry,
      };
      final seen = <String>{};
      if (observations is! List || observations.length > 20000) {
        throw const FormatException('reconciliation');
      }
      for (final observation in observations) {
        if (observation is! Map ||
            observation['id'] is! String ||
            (observation['id'] as String).isEmpty ||
            (observation['id'] as String).length > 128 ||
            !seen.add(observation['id'] as String) ||
            !ids.contains(observation['account']) ||
            !validDate(observation['date']) ||
            observation['observed'] is! int ||
            (observation['observed'] as int).abs() > maxMoney ||
            observation['description'] is! String ||
            (observation['description'] as String).trim().isEmpty ||
            (observation['description'] as String).length > 100000 ||
            observation.keys.any(
              (key) => !{
                'id',
                'account',
                'date',
                'observed',
                'description',
                'adjustment',
              }.contains(key),
            )) {
          throw const FormatException('reconciliation');
        }
        final opened = byId[observation['account']]!['openedOn'];
        if (opened != null &&
            (observation['date'] as String).compareTo(opened as String) < 0) {
          throw const FormatException('account_date');
        }
        final adjustment = observation['adjustment'];
        if (adjustment != null) {
          final entry = entries[adjustment];
          if (entry == null ||
              !{'reconcileIn', 'reconcileOut'}.contains(entry['type']) ||
              entry['account'] != observation['account'] ||
              entry['date'] != observation['date']) {
            throw const FormatException('reconciliation');
          }
        }
      }
    }
  }

  static Map<String, dynamic> addAccount(
    Map<String, dynamic> source, {
    required String id,
    required String name,
    required String type,
    required int opening,
    required String openedOn,
  }) {
    final data = normalize(source);
    (data['accounts'] as List).add({
      'id': id,
      'name': name.trim(),
      'type': type,
      'currency': data['currency'],
      'opening': opening,
      'archived': false,
      'openedOn': openedOn,
    });
    return data;
  }

  static Map<String, dynamic> transfer(
    Map<String, dynamic> source, {
    required String id,
    required String from,
    required String to,
    required int amount,
    required String date,
    String description = '',
  }) {
    final data = normalize(source);
    final active = {
      for (final row in accounts(data))
        if (row['archived'] == false) row['id'],
    };
    if (!active.contains(from) ||
        !active.contains(to) ||
        from == to ||
        amount <= 0) {
      throw const FormatException('transfer');
    }
    (data['entries'] as List).add({
      'id': id,
      'type': 'transfer',
      'amount': amount,
      'date': date,
      'category': '',
      'description': description,
      'void': false,
      'from': from,
      'to': to,
      'currency': data['currency'],
    });
    return data;
  }

  /// Record an explicit observed balance adjustment, never invented income or
  /// expense. Existing transactions remain intact and the adjustment is dated.
  static Map<String, dynamic> reconcile(
    Map<String, dynamic> source, {
    required String id,
    required String account,
    required int observed,
    required String date,
    required String description,
    required int maxMoney,
  }) {
    final data = normalize(source), rows = accounts(source);
    if (!rows.any((row) => row['id'] == account && row['archived'] == false)) {
      throw const FormatException('account_missing');
    }
    if (observed.abs() > maxMoney || !validDate(date)) {
      throw const FormatException('account_balance');
    }
    final exactDifference =
        BigInt.from(observed) -
        BigInt.from(balances(data, throughDate: date)[account]!);
    if (exactDifference.abs() > BigInt.from(maxMoney)) {
      throw const FormatException('account_balance');
    }
    final difference = exactDifference.toInt();
    data['reconciliations'] = [
      ...?data['reconciliations'] as List?,
      {
        'id': id,
        'account': account,
        'date': date,
        'observed': observed,
        'description': description,
        'adjustment': difference == 0 ? null : id,
      },
    ];
    if (difference == 0) return data;
    (data['entries'] as List).add({
      'id': id,
      'type': difference > 0 ? 'reconcileIn' : 'reconcileOut',
      'amount': difference.abs(),
      'date': date,
      'category': '',
      'description': description,
      'void': false,
      'account': account,
      'currency': data['currency'],
    });
    return data;
  }
}
