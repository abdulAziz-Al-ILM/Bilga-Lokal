import 'dart:convert';

import 'account_ledger.dart';

/// Append-only local transaction snapshots. Storage validates the resulting
/// ledger and commits the snapshot and changed entry in the same record write.
class TransactionEdits {
  static const editable = {
    'amount',
    'date',
    'category',
    'description',
    'account',
  };
  static const actions = {'edit', 'void', 'restore'};
  static const maxVersions = 1000;

  static Map<String, dynamic> _snapshot(Map row) => {
    for (final key in row.keys)
      if (key != 'versions' && key != 'historyVersion') key as String: row[key],
  };

  static bool _same(Map a, Map b) =>
      a.length == b.length && a.keys.every((key) => a[key] == b[key]);

  static Map<String, dynamic> _change(
    Map<String, dynamic> source,
    String id,
    String action,
    Map<String, dynamic> Function(Map<String, dynamic>) change,
    DateTime? now,
  ) {
    final data = AccountLedger.normalize(source);
    final entries = data['entries'] as List;
    final index = entries.indexWhere((row) => row['id'] == id);
    if (index < 0) throw StateError('transaction_missing');
    final before = Map<String, dynamic>.from(entries[index] as Map);
    final next = change(before);
    if (_same(_snapshot(before), _snapshot(next))) return source;
    final history = List<dynamic>.from(before['versions'] as List? ?? []);
    if (history.length >= maxVersions) {
      throw StateError('transaction_history_full');
    }
    history.add({
      'at': (now ?? DateTime.now()).toUtc().toIso8601String(),
      'action': action,
      'before': _snapshot(before),
    });
    entries[index] = {...next, 'historyVersion': 1, 'versions': history};
    return data;
  }

  static Map<String, dynamic> edit(
    Map<String, dynamic> source, {
    required String id,
    required Map<String, dynamic> changes,
    DateTime? now,
  }) => _change(source, id, 'edit', (before) {
    if (before['void'] == true ||
        AccountLedger.specialTypes.contains(before['type']) ||
        changes.keys.any((key) => !editable.contains(key))) {
      throw const FormatException('transaction_edit');
    }
    return {...before, ...changes};
  }, now);

  static Map<String, dynamic> setVoided(
    Map<String, dynamic> source, {
    required String id,
    required bool voided,
    DateTime? now,
  }) => _change(
    source,
    id,
    voided ? 'void' : 'restore',
    (before) => {...before, 'void': voided},
    now,
  );

  static Map<String, dynamic> restore(
    Map<String, dynamic> source, {
    required String id,
    required int version,
    DateTime? now,
  }) => _change(source, id, 'restore', (before) {
    final versions = before['versions'] as List? ?? [];
    if (version < 0 || version >= versions.length) {
      throw const FormatException('transaction_version');
    }
    return Map<String, dynamic>.from(versions[version]['before'] as Map);
  }, now);

  static void validate(Map<String, dynamic> data, {required int maxMoney}) {
    final owners = {
      for (final account in AccountLedger.accounts(data))
        account['id']: account,
    };
    for (final current in data['entries'] as List) {
      if (!current.containsKey('historyVersion') &&
          !current.containsKey('versions')) {
        continue;
      }
      if (current['historyVersion'] is! int ||
          current['historyVersion'] != 1 ||
          current['versions'] is! List ||
          (current['versions'] as List).length > maxVersions ||
          data['accountsVersion'] != 1) {
        throw const FormatException('transaction_history');
      }
      for (final event in current['versions'] as List) {
        if (event is! Map ||
            event.length != 3 ||
            !event.keys.every({'at', 'action', 'before'}.contains) ||
            !actions.contains(event['action']) ||
            event['at'] is! String) {
          throw const FormatException('transaction_history');
        }
        final at = DateTime.tryParse(event['at'] as String);
        if (at == null || !at.isUtc || at.toIso8601String() != event['at']) {
          throw const FormatException('transaction_history_date');
        }
        final row = event['before'];
        if (row is! Map ||
            row.containsKey('versions') ||
            row.containsKey('historyVersion') ||
            row['id'] != current['id'] ||
            row['type'] != current['type'] ||
            row['parent'] != current['parent'] ||
            row['currency'] != data['currency'] ||
            row['amount'] is! int ||
            row['amount'] <= 0 ||
            row['amount'] > maxMoney ||
            !AccountLedger.validDate(row['date']) ||
            row['category'] is! String ||
            row['description'] is! String ||
            row['void'] is! bool) {
          throw const FormatException('transaction_history_snapshot');
        }
        final ids = row['type'] == 'transfer'
            ? [row['from'], row['to']]
            : [row['account']];
        if (ids.toSet().length != ids.length) {
          throw const FormatException('transfer');
        }
        for (final id in ids) {
          final owner = owners[id];
          if (owner == null ||
              (owner['openedOn'] != null &&
                  (row['date'] as String).compareTo(
                        owner['openedOn'] as String,
                      ) <
                      0)) {
            throw const FormatException('transaction_history_account');
          }
        }
      }
    }
  }

  static String exportHistory(Map entry) => const JsonEncoder.withIndent('  ')
      .convert({
        'format': 'bilga-transaction-history',
        'version': 1,
        'current': _snapshot(entry),
        'versions': entry['versions'] ?? [],
      });
}
