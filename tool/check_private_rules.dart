// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:bilga/core/chunk_vault.dart';
import 'package:bilga/features/finance/ledger.dart';

int checks = 0;
void check(bool value, String label) {
  if (!value) throw StateError(label);
  checks++;
}

void rejects(void Function() action) {
  bool rejected = false;
  try {
    action();
  } catch (_) {
    rejected = true;
  }
  check(rejected, 'expected rejection');
}

Map<String, dynamic> entry(
  String id,
  String type,
  int amount, {
  String? parent,
  bool voided = false,
  String date = '2026-10-01',
}) => {
  'id': id,
  'type': type,
  'amount': amount,
  'date': date,
  'category': 'Food',
  'description': 'Lunch',
  'void': voided,
  'parent': ?parent,
};
Map<String, dynamic> ledger(List<Map<String, dynamic>> rows) => {
  'title': 'Test',
  'currency': 'USD',
  'budget': 20000,
  'entries': rows,
};
Future<Uint8List> collect(Stream<List<int>> stream) async {
  final b = BytesBuilder();
  await for (final x in stream) {
    b.add(x);
  }
  return b.takeBytes();
}

Future<void> main() async {
  check(parseMoney('0.01', 'USD') == 1, 'cents');
  check(parseMoney('12,34', 'USD') == 1234, 'comma');
  check(parseMoney('١٢٫٣٤', 'USD') == 1234, 'Arabic');
  check(parseMoney('१२.३४', 'USD') == 1234, 'Devanagari');
  check(parseMoney('12', 'JPY') == 12, 'JPY');
  check(parseMoney('1.234', 'KWD') == 1234, 'KWD');
  for (final s in [
    '-1',
    '0',
    'NaN',
    '1e4',
    '1.234',
    '1,234.00',
    '999999999999999999999',
  ]) {
    rejects(() => parseMoney(s, 'USD'));
  }
  rejects(() => parseMoney('1.1', 'JPY'));
  final d = ledger([
    entry('a', 'income', 20000),
    entry('b', 'expense', 1500),
    entry('c', 'lent', 5000),
    entry('d', 'repaymentIn', 2000, parent: 'c'),
  ]);
  Ledger.validate(d);
  check(Ledger.balance(d) == 15500, 'balance');
  check(
    Ledger.expenses(d, '2026-10')['Food'] == 1500,
    'expenses excludes loans',
  );
  check(Ledger.expenses(d, '2026-09').isEmpty, 'month');
  rejects(
    () => Ledger.validate(
      ledger([entry('a', 'income', 1), entry('a', 'expense', 1)]),
    ),
  );
  rejects(
    () => Ledger.validate(
      ledger([
        entry('a', 'lent', 100),
        entry('b', 'repaymentIn', 101, parent: 'a'),
      ]),
    ),
  );
  rejects(
    () => Ledger.validate(
      ledger([entry('a', 'income', 100, date: '2026-02-31')]),
    ),
  );
  rejects(
    () => Ledger.validate(
      ledger([entry('a', 'income', maxMoney), entry('b', 'income', 1)]),
    ),
  );
  rejects(
    () => Ledger.validate(
      ledger([
        entry('a', 'lent', 100, voided: true),
        entry('b', 'repaymentIn', 10, parent: 'a'),
      ]),
    ),
  );
  final csv = Ledger.csv(
    ledger([
      {...entry('a', 'income', 100), 'description': '=HYPERLINK("bad")'},
    ]),
  );
  check(csv.contains("'=HYPERLINK"), 'CSV formula escaped');
  final key = SecretKey(List.generate(32, (i) => i)),
      wrong = SecretKey(List.filled(32, 0));
  final clear = Uint8List.fromList(
    utf8.encode(List.filled(90000, 'Salom 🌿 Привет').join()),
  );
  final sealed = await collect(ChunkVault.encrypt(Stream.value(clear), key));
  Stream<List<int>> chunks(List<int> b) async* {
    for (var i = 0; i < b.length; i += 17) {
      yield b.sublist(i, (i + 17).clamp(0, b.length));
    }
  }

  final restored = await collect(ChunkVault.decrypt(chunks(sealed), key));
  check(base64Encode(restored) == base64Encode(clear), 'stream roundtrip');
  Future<void> bad(List<int> b, SecretKey k) async {
    bool fail = false;
    try {
      await collect(ChunkVault.decrypt(Stream.value(b), k));
    } catch (_) {
      fail = true;
    }
    check(fail, 'authenticated rejection');
  }

  await bad(sealed, wrong);
  final corrupt = Uint8List.fromList(sealed);
  corrupt[40] ^= 1;
  await bad(corrupt, key);
  await bad(sealed.sublist(0, sealed.length - 20), key);
  await bad([...sealed, 0], key);
  await bad(sealed.sublist(0, 20), key);
  final empty = await collect(ChunkVault.encrypt(Stream.value([]), key));
  check(
    (await collect(ChunkVault.decrypt(Stream.value(empty), key))).isEmpty,
    'empty authenticated',
  );
  print('PASS $checks finance and streaming encryption checks');
}
