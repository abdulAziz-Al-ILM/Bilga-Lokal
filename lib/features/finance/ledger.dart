const maxMoney = 900000000000000;
const currencies = {
  'UZS': 2,
  'USD': 2,
  'EUR': 2,
  'RUB': 2,
  'KZT': 2,
  'KGS': 2,
  'TJS': 2,
  'TMT': 2,
  'GBP': 2,
  'TRY': 2,
  'AED': 2,
  'SAR': 2,
  'CNY': 2,
  'JPY': 0,
  'KRW': 0,
  'INR': 2,
  'PKR': 2,
  'BDT': 2,
  'CAD': 2,
  'AUD': 2,
  'CHF': 2,
  'IDR': 2,
  'MYR': 2,
  'VND': 0,
  'THB': 2,
  'UAH': 2,
  'PLN': 2,
  'SEK': 2,
  'NOK': 2,
  'DKK': 2,
  'CZK': 2,
  'HUF': 2,
  'RON': 2,
  'BRL': 2,
  'MXN': 2,
  'KWD': 3,
  'BHD': 3,
  'OMR': 3,
};
int parseMoney(String input, String currency) {
  final places = currencies[currency];
  if (places == null) throw const FormatException('currency');
  var s = input.trim();
  for (final start in [0x660, 0x6f0, 0x966, 0x9e6, 0xe50]) {
    for (var i = 0; i < 10; i++) {
      s = s.replaceAll(String.fromCharCode(start + i), '$i');
    }
  }
  s = s.replaceAll(',', '.').replaceAll('٫', '.');
  if (!RegExp(places == 0 ? r'^\d+$' : '^\\d+(?:\\.\\d{1,$places})?\$')
      .hasMatch(s)) {
    throw const FormatException('amount');
  }
  final parts = s.split('.');
  final scale = places == 0
      ? 1
      : places == 2
      ? 100
      : 1000;
  final n =
      BigInt.parse(parts.first) * BigInt.from(scale) +
      BigInt.parse(parts.length == 1 ? '0' : parts.last.padRight(places, '0'));
  if (n <= BigInt.zero || n > BigInt.from(maxMoney)) {
    throw const FormatException('amount');
  }
  return n.toInt();
}

String moneyText(int n, String code) {
  final p = currencies[code] ?? 2;
  final sign = n < 0 ? '-' : '';
  final s = n.abs().toString().padLeft(p + 1, '0');
  return '$sign${p == 0 ? s : '${s.substring(0, s.length - p)}.${s.substring(s.length - p)}'} $code';
}

class Ledger {
  static const types = [
    'income',
    'expense',
    'lent',
    'borrowed',
    'repaymentIn',
    'repaymentOut',
  ];
  static void validate(Map<String, dynamic> data) {
    if (data['currency'] is! String ||
        !currencies.containsKey(data['currency']) ||
        data['entries'] is! List ||
        (data['entries'] as List).length > 20000) {
      throw const FormatException('ledger');
    }
    final budgets = data['budgets'];
    if (budgets != null) {
      if (budgets is! Map || budgets.length > 1200) {
        throw const FormatException('budgets');
      }
      for (final e in budgets.entries) {
        if (e.key is! String ||
            !RegExp(r'^\d{4}-(0[1-9]|1[0-2])$').hasMatch(e.key) ||
            e.value is! int ||
            e.value < 0 ||
            e.value > maxMoney) {
          throw const FormatException('budget');
        }
      }
    }
    final ids = <String>{}, byId = <String, Map>{};
    var gross = 0;
    for (final e in data['entries']) {
      if (e is! Map ||
          e['id'] is! String ||
          !ids.add(e['id']) ||
          !types.contains(e['type']) ||
          e['amount'] is! int ||
          e['amount'] <= 0 ||
          e['amount'] > maxMoney ||
          e['date'] is! String ||
          !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(e['date']) ||
          DateTime.tryParse(e['date'])?.toIso8601String().substring(0, 10) !=
              e['date'] ||
          e['category'] is! String ||
          e['description'] is! String ||
          e['void'] is! bool) {
        throw const FormatException('entry');
      }
      if (gross > maxMoney - (e['amount'] as int)) {
        throw const FormatException('total');
      }
      gross += e['amount'] as int;
      byId[e['id']] = e;
    }
    final paid = <String, int>{};
    for (final e in byId.values) {
      if (e['void'] == true) continue;
      if (e['type'] == 'repaymentIn' || e['type'] == 'repaymentOut') {
        final parent = byId[e['parent']];
        if (parent == null ||
            parent['void'] == true ||
            parent['type'] !=
                (e['type'] == 'repaymentIn' ? 'lent' : 'borrowed')) {
          throw const FormatException('debt');
        }
        paid[parent['id']] = (paid[parent['id']] ?? 0) + (e['amount'] as int);
        if (paid[parent['id']]! > parent['amount']) {
          throw const FormatException('overpayment');
        }
      }
    }
    if (data['budget'] != null &&
        (data['budget'] is! int ||
            data['budget'] < 0 ||
            data['budget'] > maxMoney)) {
      throw const FormatException('budget');
    }
  }

  static int balance(Map<String, dynamic> d) => [
    for (final e in d['entries'])
      if (e['void'] != true)
        ({'income', 'borrowed', 'repaymentIn'}.contains(e['type']) ? 1 : -1) *
            (e['amount'] as int),
  ].fold(0, (a, b) => a + b);
  static Map<String, int> expenses(Map<String, dynamic> d, String month) {
    final r = <String, int>{};
    for (final e in d['entries']) {
      if (e['void'] != true &&
          e['type'] == 'expense' &&
          (e['date'] as String).startsWith(month)) {
        r[e['category']] = (r[e['category']] ?? 0) + (e['amount'] as int);
      }
    }
    return r;
  }

  static int outstanding(Map<String, dynamic> data, Map debt) =>
      (debt['amount'] as int) -
      (data['entries'] as List)
          .where((e) => e['void'] != true && e['parent'] == debt['id'])
          .fold<int>(0, (total, e) => total + (e['amount'] as int));
  static int income(Map<String, dynamic> data, String month) =>
      (data['entries'] as List)
          .where(
            (e) =>
                e['void'] != true &&
                e['type'] == 'income' &&
                (e['date'] as String).startsWith(month),
          )
          .fold<int>(0, (total, e) => total + (e['amount'] as int));

  static String csv(Map<String, dynamic> d) {
    String cell(Object? v) {
      var s = '$v';
      if (RegExp(r'^[\s]*[=+@-]').hasMatch(s)) s = "'$s";
      return '"${s.replaceAll('"', '""')}"';
    }

    return [
      ['Date', 'Type', 'Amount', 'Category', 'Description', 'Voided'],
      for (final e in d['entries'])
        [
          e['date'],
          e['type'],
          moneyText(e['amount'], d['currency']),
          e['category'],
          e['description'],
          e['void'],
        ],
    ].map((r) => r.map(cell).join(',')).join('\r\n');
  }
}
