import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/strings.dart';
import '../../core/editor_form.dart';
import '../../core/dialogs.dart' show showError;
import '../agent/agent_access.dart';
import '../agent/purchase_panel.dart';
import '../private_space/record_store.dart';
import '../attachments/attachment_store.dart';
import '../attachments/attachments_page.dart';
import 'ledger.dart';
import 'account_ledger.dart';
import 'finance_accounts_page.dart';

class FinancePage extends StatefulWidget {
  final RecordStore? store;
  final AgentAccess? access;
  const FinancePage({super.key, this.store, this.access});
  @override
  State<FinancePage> createState() => _FinanceState();
}

class _FinanceState extends State<FinancePage> {
  late final RecordStore store;
  List<PrivateRecord> ledgers = [];
  PrivateRecord? selected;
  bool busy = false, loadFailed = false;
  String query = "";
  int shown = 100;
  AgentAccess get access => widget.access ?? AgentAccess.instance;
  Future<bool> permitted() async {
    if (access.has(AgentAccess.finance)) return true;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) =>
          PurchasePanel(product: AgentAccess.finance, access: access),
    );
    return access.has(AgentAccess.finance);
  }

  Future<PrivateRecord> save(
    Map<String, dynamic> data, {
    PrivateRecord? previous,
  }) {
    if (!access.has(AgentAccess.finance)) throw StateError('access_expired');
    return store.save('finance', data, previous: previous);
  }

  String month = DateTime.now().toIso8601String().substring(0, 7);
  @override
  void initState() {
    super.initState();
    store = widget.store ?? RecordStore();
    run(load);
  }

  Future<void> load() async {
    try {
      final list = await store.all('finance');
      for (final record in list) {
        Ledger.validate(record.data);
      }
      if (mounted) {
        setState(() {
          ledgers = list;
          loadFailed = false;
          selected =
              list.where((row) => row.id == selected?.id).firstOrNull ??
              list.firstOrNull;
        });
      }
    } catch (_) {
      if (mounted) setState(() => loadFailed = true);
      rethrow;
    }
  }

  Future<void> run(Future<void> Function() f) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await f();
      await load();
    } catch (_) {
      if (mounted) failure(context);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> create() async {
    if (!await permitted() || !mounted) return;
    String currency = 'UZS';
    final name = TextEditingController();
    var saving = false;
    String? error;
    try {
      await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (c) => StatefulBuilder(
          builder: (c, update) => PopScope(
            canPop: !saving,
            child: AlertDialog(
              title: Text(c.tr('xFinance')),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      autocorrect: false,
                      enableSuggestions: false,
                      enableIMEPersonalizedLearning: false,
                      controller: name,
                      enabled: !saving,
                      maxLength: 200,
                      decoration: InputDecoration(
                        labelText: c.tr('title'),
                        errorText: error,
                      ),
                    ),
                    DropdownButton<String>(
                      value: currency,
                      items: [
                        for (final code in currencies.keys)
                          DropdownMenuItem(value: code, child: Text(code)),
                      ],
                      onChanged: saving
                          ? null
                          : (s) => update(() => currency = s!),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.pop(c),
                  child: Text(c.tr('cancel')),
                ),
                FilledButton(
                  onPressed: saving
                      ? null
                      : () async {
                          if (name.text.trim().isEmpty) return;
                          update(() => saving = true);
                          try {
                            selected = await save({
                              'title': name.text.trim(),
                              'currency': currency,
                              'budget': 0,
                              'entries': [],
                            });
                            if (c.mounted) {
                              update(() => saving = false);
                              Navigator.pop(c, true);
                            }
                          } catch (_) {
                            if (c.mounted) {
                              update(() {
                                saving = false;
                                error = c.tr('saveError');
                              });
                            }
                          }
                        },
                  child: Text(c.tr('save')),
                ),
              ],
            ),
          ),
        ),
      );
    } finally {
      name.dispose();
    }
  }

  Future<void> add([Map? debt]) async {
    final r = selected;
    if (r == null || !await permitted() || !mounted) {
      return;
    }
    String type = debt == null
        ? 'expense'
        : debt['type'] == 'lent'
        ? 'repaymentIn'
        : 'repaymentOut';
    if (debt == null) {
      final chosen = await showDialog<String>(
        context: context,
        builder: (c) => SimpleDialog(
          children: [
            for (final t in ['expense', 'income', 'lent', 'borrowed'])
              SimpleDialogOption(
                onPressed: () => Navigator.pop(c, t),
                child: Text(c.tr('x$t')),
              ),
          ],
        ),
      );
      if (chosen == null || !mounted) return;
      type = chosen;
    }
    final accounts = AccountLedger.accounts(r.data)
        .where((row) => row['archived'] == false)
        .toList();
    if (accounts.isEmpty) {
      showError(context, 'fAccountNeedActive');
      return;
    }
    final account = accounts.length == 1
        ? accounts.single['id'] as String
        : await showDialog<String>(
            context: context,
            builder: (c) => SimpleDialog(
              title: Text(c.tr('fAccounts')),
              children: [
                for (final row in accounts)
                  SimpleDialogOption(
                    onPressed: () => Navigator.pop(c, row['id'] as String),
                    child: Text(row['name'] as String),
                  ),
              ],
            ),
          );
    if (account == null || !mounted) return;
    await editFields(
      context,
      context.tr('x$type'),
      {
        'amount': '${context.tr('xAmount')} (${r.data['currency']})',
        'date': context.tr('xDate'),
        'category': context.tr('xCategory'),
        'description': context.tr('description'),
      },
      initial: {
        'date': DateTime.now().toIso8601String().substring(0, 10),
        'category': debt?['category'] ?? '',
      },
      multiline: {'description'},
      requiredFields: {'amount', 'date'},
      dateFields: {'date'},
      numberFields: {'amount'},
      onSave: (v) async {
        final data = {
          ...r.data,
          'entries': [
            ...r.data['entries'],
            {
              'id': localId(),
              'type': type,
              'amount': parseMoney(v['amount']!, r.data['currency']),
              'date': v['date']!,
              'category': v['category']!,
              'description': v['description']!,
              'void': false,
              'account': account,
              'currency': r.data['currency'],
              if (debt != null) 'parent': debt['id'],
            },
          ],
        };
        selected = await save(data, previous: r);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = selected;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final names = r == null
        ? <String, String>{}
        : {
            for (final account in AccountLedger.accounts(r.data))
              account['id'] as String: account['name'] as String,
          };
    final report = r == null
        ? <String, int>{}
        : Ledger.expenses(r.data, month, throughDate: today);
    final sum = report.values.fold(0, (a, b) => a + b);
    final budget = r?.data['budgets']?[month] ?? r?.data['budget'] ?? 0;
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('xFinance')),
        actions: [
          IconButton(
            onPressed: busy ? null : () => run(create),
            icon: const Icon(Icons.add),
          ),
          if (r != null)
            IconButton(
              icon: const Icon(Icons.attach_file),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AttachmentsPage(
                    kind: 'finance',
                    owner: r.id,
                    title: r.data['title'],
                  ),
                ),
              ),
            ),
          if (r != null)
            IconButton(
              icon: const Icon(Icons.file_download),
              onPressed: busy
                  ? null
                  : () => run(() async {
                      if (await consent(context, context.tr('xPlainExport'))) {
                        await Attachments.export(
                          'Bilga-money.csv',
                          'text/csv',
                          Stream.value(utf8.encode(Ledger.csv(r.data))),
                        );
                      }
                    }),
            ),
        ],
      ),
      floatingActionButton: r == null
          ? null
          : FloatingActionButton(
              onPressed: busy ? null : () => run(add),
              child: const Icon(Icons.add),
            ),
      body: loadFailed
          ? Center(
              child: TextButton(
                onPressed: busy ? null : () => run(load),
                child: Text(context.tr('retry')),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(context.tr('xMoneyJournalInfo')),
                if (ledgers.isNotEmpty)
                  DropdownButton<String>(
                    isExpanded: true,
                    value: r?.id,
                    items: [
                      for (final l in ledgers)
                        DropdownMenuItem(
                          value: l.id,
                          child: Text(
                            '${l.data['title']} · ${l.data['currency']}',
                          ),
                        ),
                    ],
                    onChanged: busy
                        ? null
                        : (id) => setState(
                            () => selected = ledgers.firstWhere(
                              (l) => l.id == id,
                            ),
                          ),
                  ),
                if (r != null) ...[
                  ListTile(
                    key: const Key('finance-accounts-open'),
                    leading: const Icon(Icons.account_balance_wallet_outlined),
                    title: Text(context.tr('fAccounts')),
                    subtitle: Text(context.tr('fAccountSummary')),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: busy
                        ? null
                        : () async {
                            await Navigator.push<void>(
                              context,
                              MaterialPageRoute(
                                builder: (_) => FinanceAccountsPage(
                                  ledger: r,
                                  store: store,
                                  access: access,
                                ),
                              ),
                            );
                            if (mounted) await run(load);
                          },
                  ),
                  Text(context.tr('fBalance')),
                  Text(
                    moneyText(
                      Ledger.balance(
                        r.data,
                        throughDate: DateTime.now().toIso8601String().substring(
                          0,
                          10,
                        ),
                      ),
                      r.data['currency'],
                    ),
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  ListTile(
                    title: Text('${context.tr('xReport')} · $month'),
                    subtitle: Text(
                      '${moneyText(sum, r.data['currency'])} / ${moneyText(r.data['budgets']?[month] ?? r.data['budget'] ?? 0, r.data['currency'])}',
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: busy
                          ? null
                          : () => run(() async {
                              if (!await permitted() || !context.mounted) {
                                return;
                              }
                              await editFields(
                                context,
                                context.tr('xBudget'),
                                {
                                  'month': 'YYYY-MM',
                                  'budget': context.tr('xBudget'),
                                },
                                initial: {'month': month},
                                onSave: (v) async {
                                  if (!RegExp(r'^\d{4}-(0[1-9]|1[0-2])$')
                                      .hasMatch(v['month']!)) {
                                    throw const FormatException('month');
                                  }
                                  final nextMonth = v['month']!;
                                  if (v['budget']!.trim().isNotEmpty) {
                                    selected = await save({
                                      ...r.data,
                                      'budgets': {
                                        ...?r.data['budgets'] as Map?,
                                        nextMonth: parseMoney(
                                          v['budget']!,
                                          r.data['currency'],
                                          allowZero: true,
                                        ),
                                      },
                                    }, previous: r);
                                  }
                                  month = nextMonth;
                                },
                              );
                            }),
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        tooltip: context.tr('previous'),
                        icon: const Icon(Icons.chevron_left),
                        onPressed: () => setState(
                          () => month = DateTime(
                            int.parse(month.substring(0, 4)),
                            int.parse(month.substring(5)) - 1,
                          ).toIso8601String().substring(0, 7),
                        ),
                      ),
                      Expanded(child: Text(month, textAlign: TextAlign.center)),
                      IconButton(
                        tooltip: context.tr('continue'),
                        icon: const Icon(Icons.chevron_right),
                        onPressed: () => setState(
                          () => month = DateTime(
                            int.parse(month.substring(0, 4)),
                            int.parse(month.substring(5)) + 1,
                          ).toIso8601String().substring(0, 7),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '${context.tr('xincome')}: ${moneyText(Ledger.income(r.data, month, throughDate: today), r.data['currency'])}',
                  ),
                  if (budget > 0) ...[
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: (sum / budget).clamp(0.0, 1.0),
                      color: sum > budget
                          ? Theme.of(context).colorScheme.error
                          : null,
                    ),
                    Text(
                      '${context.tr('fRemaining')}: ${moneyText(budget - sum, r.data['currency'])}',
                    ),
                  ],
                  for (final e in report.entries)
                    ListTile(
                      title: Text(e.key),
                      trailing: Text(moneyText(e.value, r.data['currency'])),
                    ),
                  const Divider(),
                  TextField(
                    autocorrect: false,
                    enableSuggestions: false,
                    enableIMEPersonalizedLearning: false,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      labelText: context.tr('search'),
                    ),
                    onChanged: (s) => setState(() {
                      query = s.toLowerCase();
                      shown = 100;
                    }),
                  ),
                  for (final e
                      in (r.data['entries'] as List).reversed
                          .where(
                            (e) =>
                                '${e['date']} ${e['description']} ${e['category']}'
                                    .toLowerCase()
                                    .contains(query),
                          )
                          .take(shown))
                    ListTile(
                      title: Text(
                        '${context.tr('x${e['type']}')} · ${moneyText(e['amount'], r.data['currency'])}',
                        style: e['void'] == true
                            ? const TextStyle(
                                decoration: TextDecoration.lineThrough,
                              )
                            : null,
                      ),
                      subtitle: Text(
                        '${e['date']} · ${e['category']}\n${e['description']}'
                        '\n${e['type'] == 'transfer' ? '${names[e['from']]} → ${names[e['to']]}' : names[e['account'] ?? AccountLedger.legacyId]}'
                        '${{'lent', 'borrowed'}.contains(e['type']) && e['void'] != true ? '\n${context.tr('fRemaining')}: ${moneyText(Ledger.outstanding(r.data, e), r.data['currency'])}' : ''}',
                      ),
                      onTap:
                          e['void'] == true ||
                              (!{'lent', 'borrowed'}.contains(e['type']) ||
                                  Ledger.outstanding(r.data, e) == 0)
                          ? null
                          : () => run(() => add(e)),
                      trailing: e['void'] == true
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.undo),
                              onPressed: busy
                                  ? null
                                  : () => run(() async {
                                      if (!await permitted() ||
                                          !context.mounted) {
                                        return;
                                      }
                                      if (!await consent(
                                        context,
                                        context.tr('undo'),
                                      )) {
                                        return;
                                      }
                                      selected = await save({
                                        ...r.data,
                                        'entries': [
                                          for (final item in r.data['entries'])
                                            if (item['id'] == e['id'])
                                              {...item, 'void': true}
                                            else
                                              item,
                                        ],
                                      }, previous: r);
                                    }),
                            ),
                    ),
                  if ((r.data['entries'] as List).length > shown)
                    TextButton(
                      onPressed: () => setState(() => shown += 100),
                      child: Text(context.tr('continue')),
                    ),
                ],
                const SizedBox(height: 90),
              ],
            ),
    );
  }
}
