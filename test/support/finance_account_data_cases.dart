import 'dart:convert';
import 'dart:io';

import 'package:bilga/core/private_database.dart';
import 'package:bilga/features/backup/backup_store.dart';
import 'package:bilga/features/finance/account_ledger.dart';
import 'package:bilga/features/finance/ledger.dart';
import 'package:bilga/features/finance/transaction_edits.dart';
import 'package:bilga/features/notes/note_database.dart';
import 'package:bilga/features/private_space/record_store.dart';
import 'package:bilga/features/todo/todo_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

void registerFinanceAccountDataTests({
  Future<Directory> Function()? createDirectory,
  bool secure = false,
}) {
  late Directory directory;
  late Database db;
  late RecordStore store;
  final stamp = DateTime.utc(2020, 1, 1).toIso8601String();
  Map<String, dynamic> legacy() => {
    'title': 'Synthetic budget',
    'currency': 'USD',
    'entries': [
      {
        'id': 'income',
        'type': 'income',
        'amount': 50000,
        'date': '2020-01-01',
        'category': 'Work',
        'description': 'Synthetic',
        'void': false,
      },
    ],
  };
  Map<String, dynamic> withBank() => AccountLedger.addAccount(
    legacy(),
    id: 'bank',
    name: 'Bank',
    type: 'bank',
    opening: 100000,
    openedOn: '2020-01-01',
  );
  setUp(() async {
    directory =
        await (createDirectory?.call() ??
            Directory.systemTemp.createTemp('bilga-finance-data-'));
    db = await NoteDatabase.openAt(
      '${directory.path}/notes.db',
      secure: secure,
    );
    store = RecordStore(database: db);
  });
  tearDown(() async {
    if (db.isOpen) await db.close();
    await directory.delete(recursive: true);
  });
  test('Notes 15 upgrade preserves legacy finance and notes without materializing new accounts', () async {
    await store.save('finance', legacy());
    await db.insert('notes', {
      'id': 'keep',
      'title': 'Keep note',
      'body': 'Historical text',
      'created_at': stamp,
      'updated_at': stamp,
    });
    final records = await db.query('private_records'),
        notes = await db.query('notes');
    await db.execute('DROP TABLE module_data');
    await db.setVersion(15);
    await db.close();
    db = await NoteDatabase.openAt(
      '${directory.path}/notes.db',
      secure: secure,
    );
    store = RecordStore(database: db);
    expect(await db.getVersion(), 19);
    expect(await db.query('private_records'), records);
    expect(await db.query('notes'), notes);
    final restored = (await store.all('finance')).single;
    expect(restored.data.containsKey('accounts'), false);
    expect(Ledger.balance(restored.data), 50000);
  });
  test('One-row transfers are atomic; stale saves and simulated storage failure cannot move one side', () async {
    final first = await store.save('finance', withBank());
    final moved = await store.save(
      'finance',
      AccountLedger.transfer(
        first.data,
        id: 'move',
        from: AccountLedger.legacyId,
        to: 'bank',
        amount: 12550,
        date: '2020-01-02',
      ),
      previous: first,
    );
    expect(AccountLedger.balances(moved.data)[AccountLedger.legacyId], 37450);
    expect(AccountLedger.balances(moved.data)['bank'], 112550);
    expect(Ledger.balance(moved.data), 150000);
    await expectLater(
      store.save(
        'finance',
        AccountLedger.transfer(
          first.data,
          id: 'stale',
          from: 'bank',
          to: AccountLedger.legacyId,
          amount: 1,
          date: '2020-01-03',
        ),
        previous: first,
      ),
      throwsStateError,
    );
    await db.execute(
      "CREATE TRIGGER fail_finance BEFORE UPDATE ON private_records WHEN NEW.kind='finance' BEGIN SELECT RAISE(ABORT,'synthetic disk failure'); END",
    );
    await expectLater(
      store.save(
        'finance',
        AccountLedger.transfer(
          moved.data,
          id: 'fail',
          from: 'bank',
          to: AccountLedger.legacyId,
          amount: 100,
          date: '2020-01-03',
        ),
        previous: moved,
      ),
      throwsA(anything),
    );
    final after = (await store.all('finance')).single;
    expect(after.revision, moved.revision);
    expect(jsonEncode(after.data), jsonEncode(moved.data));
    await db.execute('DROP TRIGGER fail_finance');
  });
  test('Portable backup preserves explicit account currency, transfers and reconciliation audit without duplication', () async {
    var data = AccountLedger.transfer(
      withBank(),
      id: 'move',
      from: AccountLedger.legacyId,
      to: 'bank',
      amount: 12550,
      date: '2020-01-02',
    );
    data = AccountLedger.reconcile(
      data,
      id: 'statement',
      account: 'bank',
      observed: 110000,
      date: '2020-01-03',
      description: 'Statement checked',
      maxMoney: maxMoney,
    );
    data = TransactionEdits.setVoided(data, id: 'move', voided: true);
    data = TransactionEdits.setVoided(data, id: 'move', voided: false);
    await store.save('finance', data);
    final tasks = await TodoDatabase.openAt(
      '${directory.path}/tasks.db',
      secure: secure,
    );
    final targetNotes = await NoteDatabase.openAt(
      '${directory.path}/target-notes.db',
      secure: secure,
    );
    final targetTasks = await TodoDatabase.openAt(
      '${directory.path}/target-tasks.db',
      secure: secure,
    );
    try {
      final payload = await BackupStore(notesDb: db, todoDb: tasks).snapshot();
      expect(payload['notesSchema'], 14);
      final restore = BackupStore(notesDb: targetNotes, todoDb: targetTasks);
      expect(await restore.restore(payload, 'Imported'), true);
      final imported = (await RecordStore(database: targetNotes).all('finance'))
          .single;
      expect(Ledger.balance(imported.data), 147450);
      expect(imported.data['reconciliations'], hasLength(1));
      expect(
        imported.data['entries'].firstWhere(
          (row) => row['id'] == 'move',
        )['versions'],
        hasLength(2),
      );
      expect(
        imported.data['accounts'].every((row) => row['currency'] == 'USD'),
        true,
      );
      expect(await restore.restore(payload, 'Again'), false);
      for (final field in ['currency', 'accountsVersion', 'historyVersion']) {
        final bad = jsonDecode(jsonEncode(payload)) as Map<String, dynamic>;
        final row =
            ((bad['data'] as Map)['private_records'] as List).single as Map;
        final invalid =
            jsonDecode(row['payload'] as String) as Map<String, dynamic>;
        if (field == 'historyVersion') {
          (invalid['entries'] as List).firstWhere(
            (entry) => entry['id'] == 'move',
          )['historyVersion'] = 99;
        } else {
          invalid[field] = field == 'currency' ? 'EUR' : 99;
        }
        row['payload'] = jsonEncode(invalid);
        await expectLater(
          restore.restore(bad, 'Invalid'),
          throwsFormatException,
        );
      }
      expect(
        await RecordStore(database: targetNotes).all('finance'),
        hasLength(1),
      );
    } finally {
      await tasks.close();
      await targetNotes.close();
      await targetTasks.close();
    }
  });
  test('Guarded database opener refuses a lower configured version without rewriting finance', () async {
    await store.save('finance', withBank());
    final before = await db.query('private_records');
    await db.close();
    await expectLater(
      PrivateDatabase.open(
        '${directory.path}/notes.db',
        secure: secure,
        version: 15,
        onCreate: (_, _) async {},
        onUpgrade: (_, _, _) async {},
      ),
      throwsA(
        predicate(
          (error) => error.toString().toLowerCase().contains('downgrade'),
        ),
      ),
    );
    db = await NoteDatabase.openAt(
      '${directory.path}/notes.db',
      secure: secure,
    );
    store = RecordStore(database: db);
    expect(await db.getVersion(), 19);
    expect(await db.query('private_records'), before);
    expect(Ledger.balance((await store.all('finance')).single.data), 150000);
  });
  test('Transaction edit and its history commit together; failed and stale writes preserve the complete record', () async {
    final original = await store.save('finance', withBank());
    final changed = TransactionEdits.edit(
      original.data,
      id: 'income',
      changes: {'amount': 60000, 'description': 'Corrected income'},
    );
    await db.execute(
      "CREATE TRIGGER fail_history BEFORE UPDATE ON private_records BEGIN SELECT RAISE(ABORT,'synthetic history write failure'); END",
    );
    await expectLater(
      store.save('finance', changed, previous: original),
      throwsA(anything),
    );
    var stored = (await store.all('finance')).single;
    expect(stored.revision, original.revision);
    expect(jsonEncode(stored.data), jsonEncode(original.data));
    await db.execute('DROP TRIGGER fail_history');
    final saved = await store.save('finance', changed, previous: original);
    expect(
      saved.data['entries'].single['versions'].single['before']['amount'],
      50000,
    );
    await expectLater(
      store.save(
        'finance',
        TransactionEdits.edit(
          original.data,
          id: 'income',
          changes: {'amount': 1},
        ),
        previous: original,
      ),
      throwsStateError,
    );
    stored = (await store.all('finance')).single;
    expect(jsonEncode(stored.data), jsonEncode(saved.data));
    final restored = await store.save(
      'finance',
      TransactionEdits.restore(stored.data, id: 'income', version: 0),
      previous: stored,
    );
    expect(restored.data['entries'].single['amount'], 50000);
    expect(restored.data['entries'].single['versions'], hasLength(2));
    expect(Ledger.balance(restored.data), 150000);
  });
}
