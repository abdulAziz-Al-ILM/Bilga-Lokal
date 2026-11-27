import 'dart:convert';

import 'package:bilga/features/finance/account_ledger.dart';
import 'package:bilga/features/finance/ledger.dart';
import 'package:bilga/features/finance/transaction_edits.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 11, 11, 12, 30);
  Map<String, dynamic> original() => {
    'title': 'History ledger',
    'currency': 'USD',
    'entries': [
      {
        'id': 'pay',
        'type': 'income',
        'amount': 10000,
        'date': '2020-01-01',
        'category': 'Work',
        'description': 'Original income',
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
  };
  test('Editing legacy transactions preserves input and all prior fields without recursive history', () {
    final source = original(), encoded = jsonEncode(original());
    final data = TransactionEdits.edit(
      source,
      id: 'food',
      changes: {'amount': 1500, 'description': 'Corrected lunch'},
      now: now,
    );
    Ledger.validate(data);
    expect(jsonEncode(source), encoded);
    expect(Ledger.balance(data), 8500);
    expect(data['entries'].last['id'], 'food');
    expect(data['entries'].last['versions'].single['before']['amount'], 1200);
    expect(
      data['entries'].last['versions'].single['before']['currency'],
      'USD',
    );
    expect(
      data['entries'].last['versions'].single['before']['account'],
      AccountLedger.legacyId,
    );
    expect(
      data['entries'].last['versions'].single['at'],
      '2026-11-11T12:30:00.000Z',
    );
    final next = TransactionEdits.edit(
      data,
      id: 'food',
      changes: {'category': 'Meals'},
      now: now,
    );
    Ledger.validate(next);
    expect(next['entries'].last['versions'], hasLength(2));
    expect(
      next['entries'].last['versions'].last['before'].containsKey('versions'),
      false,
    );
    expect(next['entries'].first, data['entries'].first);
  });
  test('Unchanged edit is a no-op; invalid identity/type/parent changes and void edits are refused', () {
    final source = original();
    expect(
      identical(
        TransactionEdits.edit(source, id: 'food', changes: {'amount': 1200}),
        source,
      ),
      true,
    );
    for (final field in ['id', 'type', 'parent', 'currency', 'versions']) {
      expect(
        () => TransactionEdits.edit(
          source,
          id: 'food',
          changes: {field: 'changed'},
        ),
        throwsFormatException,
      );
    }
    final voided = TransactionEdits.setVoided(
      source,
      id: 'food',
      voided: true,
      now: now,
    );
    Ledger.validate(voided);
    expect(
      () => TransactionEdits.edit(voided, id: 'food', changes: {'amount': 1}),
      throwsFormatException,
    );
    expect(
      identical(
        TransactionEdits.setVoided(voided, id: 'food', voided: true),
        voided,
      ),
      true,
    );
  });
  test('Version restore changes only its transaction and preserves unrelated later work', () {
    var data = TransactionEdits.edit(
      original(),
      id: 'food',
      changes: {'amount': 1500, 'description': 'New lunch'},
      now: now,
    );
    data = TransactionEdits.edit(
      data,
      id: 'pay',
      changes: {'amount': 11000},
      now: now,
    );
    final income = jsonEncode(data['entries'].first);
    data = TransactionEdits.restore(data, id: 'food', version: 0, now: now);
    Ledger.validate(data);
    expect(data['entries'].last['amount'], 1200);
    expect(data['entries'].last['description'], 'Original lunch');
    expect(jsonEncode(data['entries'].first), income);
    expect(data['entries'].last['versions'], hasLength(2));
    expect(data['entries'].last['versions'].last['action'], 'restore');
    expect(Ledger.balance(data), 9800);
    expect(
      () => TransactionEdits.restore(data, id: 'food', version: 99),
      throwsFormatException,
    );
  });
  test('Voiding and restoring a transfer preserve both account sides and the original audit', () {
    var data = AccountLedger.addAccount(
      original(),
      id: 'bank',
      name: 'Bank',
      type: 'bank',
      opening: 5000,
      openedOn: '2020-01-01',
    );
    data = AccountLedger.transfer(
      data,
      id: 'move',
      from: AccountLedger.legacyId,
      to: 'bank',
      amount: 2000,
      date: '2020-01-03',
    );
    final before = AccountLedger.balances(data);
    data = TransactionEdits.setVoided(data, id: 'move', voided: true, now: now);
    Ledger.validate(data);
    expect(AccountLedger.balances(data), {
      AccountLedger.legacyId: 8800,
      'bank': 5000,
    });
    expect(Ledger.balance(data), 13800);
    expect(
      () => TransactionEdits.edit(data, id: 'move', changes: {'amount': 1}),
      throwsFormatException,
    );
    data = TransactionEdits.setVoided(
      data,
      id: 'move',
      voided: false,
      now: now,
    );
    Ledger.validate(data);
    expect(AccountLedger.balances(data), before);
    expect(data['entries'].last['versions'], hasLength(2));
    expect(
      data['entries'].last['versions'].first['before']['from'],
      AccountLedger.legacyId,
    );
  });
  test('Editing and history restoration still enforce debt overpayment and repayment ownership', () {
    var data = AccountLedger.normalize(original());
    data['entries'].addAll([
      {
        'id': 'loan',
        'type': 'lent',
        'amount': 1000,
        'date': '2020-01-03',
        'category': 'Friend',
        'description': 'Loan',
        'void': false,
        'currency': 'USD',
        'account': AccountLedger.legacyId,
      },
      {
        'id': 'repay',
        'type': 'repaymentIn',
        'parent': 'loan',
        'amount': 400,
        'date': '2020-01-04',
        'category': 'Friend',
        'description': 'Partial',
        'void': false,
        'currency': 'USD',
        'account': AccountLedger.legacyId,
      },
    ]);
    Ledger.validate(data);
    final invalid = TransactionEdits.edit(
      data,
      id: 'loan',
      changes: {'amount': 300},
      now: now,
    );
    expect(() => Ledger.validate(invalid), throwsFormatException);
    expect(
      () => Ledger.validate(
        TransactionEdits.setVoided(data, id: 'loan', voided: true),
      ),
      throwsFormatException,
    );
    data = TransactionEdits.edit(
      data,
      id: 'repay',
      changes: {'amount': 600},
      now: now,
    );
    Ledger.validate(data);
    expect(Ledger.outstanding(data, data['entries'][2]), 400);
    data = TransactionEdits.restore(data, id: 'repay', version: 0, now: now);
    Ledger.validate(data);
    expect(Ledger.outstanding(data, data['entries'][2]), 600);
  });
  test('Malformed and future history payloads fail validation and complete export retains snapshots', () {
    final valid = TransactionEdits.edit(
      original(),
      id: 'food',
      changes: {'amount': 1400},
      now: now,
    );
    for (final kind in [
      'version',
      'recursive',
      'currency',
      'account',
      'date',
      'type',
      'amount',
      'action',
    ]) {
      final data = jsonDecode(jsonEncode(valid)) as Map<String, dynamic>;
      final entry = data['entries'].last as Map;
      final event = entry['versions'].single as Map;
      final before = event['before'] as Map;
      switch (kind) {
        case 'version':
          entry['historyVersion'] = 2;
        case 'recursive':
          before['versions'] = [];
        case 'currency':
          before['currency'] = 'EUR';
        case 'account':
          before['account'] = 'missing';
        case 'date':
          event['at'] = 'not-a-date';
        case 'type':
          before['type'] = 'borrowed';
        case 'amount':
          before['amount'] = 0;
        case 'action':
          event['action'] = 'delete_everything';
      }
      expect(() => Ledger.validate(data), throwsFormatException, reason: kind);
    }
    final exported = jsonDecode(
      TransactionEdits.exportHistory(valid['entries'].last as Map),
    ) as Map;
    expect(exported['current']['amount'], 1400);
    expect(exported['versions'].single['before']['amount'], 1200);
  });
}
