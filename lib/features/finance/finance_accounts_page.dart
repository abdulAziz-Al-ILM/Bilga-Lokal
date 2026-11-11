import 'package:flutter/material.dart';

import '../../core/dialogs.dart';
import '../../core/editor_form.dart';
import '../../core/strings.dart';
import '../agent/agent_access.dart';
import '../agent/purchase_panel.dart';
import '../private_space/record_store.dart';
import '../attachments/attachment_store.dart';

import 'dart:convert';

import 'account_ledger.dart';
import 'ledger.dart';

int parseSignedMoney(String raw, String currency) {
  final text = raw.trim().replaceAll('−', '-');
  return text.startsWith('-')
      ? -parseMoney(text.substring(1), currency, allowZero: true)
      : parseMoney(text, currency, allowZero: true);
}

String accountTypeKey(String type) => switch (type) {
  'bank' => 'fAccountBank',
  'card' => 'fAccountCard',
  'savings' => 'fAccountSavings',
  _ => 'fAccountCash',
};

class FinanceAccountsPage extends StatefulWidget {
  final PrivateRecord ledger;
  final RecordStore? store;
  final AgentAccess? access;
  const FinanceAccountsPage({
    super.key,
    required this.ledger,
    this.store,
    this.access,
  });
  @override
  State<FinanceAccountsPage> createState() => _FinanceAccountsPageState();
}

class _FinanceAccountsPageState extends State<FinanceAccountsPage> {
  late PrivateRecord current;
  late final RecordStore store;
  bool busy = false, failed = false;
  AgentAccess get access => widget.access ?? AgentAccess.instance;
  String get currency => current.data['currency'] as String;
  String get today => DateTime.now().toIso8601String().substring(0, 10);
  @override
  void initState() {
    super.initState();
    current = widget.ledger;
    store = widget.store ?? RecordStore();
    try {
      Ledger.validate(current.data);
    } catch (_) {
      failed = true;
    }
  }

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

  Future<void> run(Future<void> Function() action) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await action();
    } catch (_) {
      if (mounted) showError(context);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> save(Map<String, dynamic> data, PrivateRecord expected) async {
    if (!access.has(AgentAccess.finance)) throw StateError('access_expired');
    Ledger.validate(data);
    late final PrivateRecord saved;
    try {
      saved = await store.save('finance', data, previous: expected);
    } on StateError {
      if (mounted) setState(() => failed = true);
      rethrow;
    }
    if (mounted) setState(() => current = saved);
  }

  Future<void> reload() async {
    try {
      final rows = await store.all('finance');
      final value = rows.where((row) => row.id == current.id).firstOrNull;
      if (value == null) throw StateError('record_missing');
      Ledger.validate(value.data);
      if (mounted) {
        setState(() {
          current = value;
          failed = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => failed = true);
    }
  }

  Future<String?> choose(
    String title,
    List<Map<String, dynamic>> accounts,
  ) async => showDialog<String>(
    context: context,
    builder: (c) => SimpleDialog(
      title: Text(title),
      children: [
        for (final account in accounts)
          SimpleDialogOption(
            onPressed: () => Navigator.pop(c, account['id'] as String),
            child: Text(account['name'] as String),
          ),
      ],
    ),
  );
  Future<void> create() async {
    if (!await permitted() || !mounted) return;
    final type = await showDialog<String>(
      context: context,
      builder: (c) => SimpleDialog(
        title: Text(c.tr('fAccountType')),
        children: [
          for (final kind in AccountLedger.accountTypes)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(c, kind),
              child: Text(c.tr(accountTypeKey(kind))),
            ),
        ],
      ),
    );
    if (type == null || !mounted) return;
    final original = current;
    await editFields(
      context,
      context.tr('fAccountNew'),
      {
        'name': context.tr('title'),
        'opening': '${context.tr('fAccountOpening')} ($currency)',
        'openedOn': context.tr('fAccountOpeningDate'),
      },
      initial: {'opening': '0', 'openedOn': today},
      requiredFields: {'name', 'opening', 'openedOn'},
      dateFields: {'openedOn'},
      numberFields: {'opening'},
      signedNumberFields: {'opening'},
      onSave: (values) => save(
        AccountLedger.addAccount(
          original.data,
          id: localId(),
          name: values['name']!,
          type: type,
          opening: parseSignedMoney(values['opening']!, currency),
          openedOn: values['openedOn']!,
        ),
        original,
      ),
    );
  }

  Future<void> transfer() async {
    if (!await permitted() || !mounted) return;
    final active = AccountLedger.accounts(current.data)
        .where((row) => row['archived'] == false)
        .toList();
    if (active.length < 2) {
      showError(context, 'fAccountTwoRequired');
      return;
    }
    final from = await choose(context.tr('fAccountFrom'), active);
    if (from == null || !mounted) return;
    final to = await choose(
      context.tr('fAccountTo'),
      active.where((row) => row['id'] != from).toList(),
    );
    if (to == null || !mounted) return;
    final original = current;
    await editFields(
      context,
      context.tr('fAccountTransfer'),
      {
        'amount': '${context.tr('xAmount')} ($currency)',
        'date': context.tr('xDate'),
        'description': context.tr('description'),
      },
      initial: {'date': today},
      requiredFields: {'amount', 'date'},
      dateFields: {'date'},
      numberFields: {'amount'},
      multiline: {'description'},
      onSave: (values) => save(
        AccountLedger.transfer(
          original.data,
          id: localId(),
          from: from,
          to: to,
          amount: parseMoney(values['amount']!, currency),
          date: values['date']!,
          description: values['description']!,
        ),
        original,
      ),
    );
  }

  Future<void> reconcile(Map<String, dynamic> account) async {
    if (!await permitted() || !mounted) return;
    final original = current;
    final balance = AccountLedger.balances(
      original.data,
      throughDate: today,
    )[account['id']]!;
    await editFields(
      context,
      context.tr('fAccountReconcile'),
      {
        'observed': '${context.tr('fAccountObserved')} ($currency)',
        'date': context.tr('xDate'),
        'description': context.tr('fAccountReason'),
      },
      initial: {
        'observed': moneyText(balance, currency).split(' ').first,
        'date': today,
      },
      requiredFields: {'observed', 'date', 'description'},
      dateFields: {'date'},
      numberFields: {'observed'},
      signedNumberFields: {'observed'},
      multiline: {'description'},
      onSave: (values) => save(
        AccountLedger.reconcile(
          original.data,
          id: localId(),
          account: account['id'] as String,
          observed: parseSignedMoney(values['observed']!, currency),
          date: values['date']!,
          description: values['description']!,
          maxMoney: maxMoney,
        ),
        original,
      ),
    );
  }

  Future<void> rename(Map<String, dynamic> account) async {
    if (!await permitted() || !mounted) return;
    final original = current;
    await editFields(
      context,
      context.tr('fAccountRename'),
      {'name': context.tr('title')},
      initial: {'name': account['name'] as String},
      requiredFields: {'name'},
      onSave: (values) async {
        final data = AccountLedger.normalize(original.data);
        for (final row in data['accounts'] as List) {
          if (row['id'] == account['id']) row['name'] = values['name']!.trim();
        }
        await save(data, original);
      },
    );
  }

  Future<void> archive(Map<String, dynamic> account) async {
    if (!await permitted() || !mounted) return;
    if (!await confirm(
          context,
          context.tr('fAccountArchiveInfo'),
          title: context.tr(
            account['archived'] == true ? 'restore' : 'archive',
          ),
        ) ||
        !mounted) {
      return;
    }
    final original = current, data = AccountLedger.normalize(current.data);
    for (final row in data['accounts'] as List) {
      if (row['id'] == account['id']) {
        row['archived'] = account['archived'] != true;
      }
    }
    await save(data, original);
  }

  Future<void> export() async {
    final kind = await showDialog<String>(
      context: context,
      builder: (c) => SimpleDialog(
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(c, 'accounts'),
            child: Text(c.tr('fAccounts')),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(c, 'history'),
            child: Text(c.tr('fAccountReconciliationHistory')),
          ),
        ],
      ),
    );
    if (kind == null || !mounted) return;
    if (!await consent(context, context.tr('xPlainExport')) || !mounted) return;
    await Attachments.export(
      kind == 'accounts' ? 'Bilga-accounts.csv' : 'Bilga-reconciliations.csv',
      'text/csv',
      Stream.value(
        utf8.encode(
          kind == 'accounts'
              ? Ledger.accountsCsv(current.data, throughDate: today)
              : Ledger.reconciliationsCsv(current.data),
        ),
      ),
    );
  }

  Future<void> history(Map<String, dynamic> account) async {
    final events = (current.data['reconciliations'] as List? ?? [])
        .where((event) => event['account'] == account['id'])
        .toList()
        .reversed
        .toList();
    final entries = {
      for (final entry in current.data['entries'] as List) entry['id']: entry,
    };
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (c) => Scaffold(
          appBar: AppBar(title: Text(c.tr('fAccountReconciliationHistory'))),
          body: events.isEmpty
              ? Center(child: Text(c.tr('empty')))
              : ListView.builder(
                  itemCount: events.length,
                  itemBuilder: (c, index) {
                    final event = events[index];
                    final text =
                        '${MaterialLocalizations.of(c).formatFullDate(DateTime.parse(event['date'] as String))}\n${event['description']}'
                        '${event['adjustment'] == null
                            ? '\n${c.tr('fAccountMatched')}'
                            : entries[event['adjustment']]?['void'] == true
                            ? '\n${c.tr('fEntryVoided')}'
                            : ''}';
                    return ListTile(
                      title: Text(
                        '${c.tr('fAccountObserved')}: ${moneyText(event['observed'] as int, currency)}',
                      ),
                      subtitle: Text(
                        text,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => showDialog<void>(
                        context: c,
                        builder: (dialog) => AlertDialog(
                          title: Text(account['name'] as String),
                          content: SingleChildScrollView(
                            child: SelectableText(text),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(dialog),
                              child: Text(dialog.tr('close')),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (failed) {
      return Scaffold(
        appBar: AppBar(title: Text(context.tr('fAccounts'))),
        body: Center(
          child: TextButton(
            onPressed: () => run(reload),
            child: Text(context.tr('retry')),
          ),
        ),
      );
    }
    final rows = AccountLedger.accounts(current.data),
        balances = AccountLedger.balances(current.data, throughDate: today);
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('fAccounts')),
        actions: [
          IconButton(
            tooltip: context.tr('export'),
            onPressed: busy ? null : () => run(export),
            icon: const Icon(Icons.ios_share),
          ),
          IconButton(
            tooltip: context.tr('retry'),
            onPressed: busy ? null : () => run(reload),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: failed
          ? Center(
              child: TextButton(
                onPressed: () => run(reload),
                child: Text(context.tr('retry')),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  '${current.data['title']} · $currency',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text(
                  '${context.tr('fAccountCurrent')}: ${moneyText(Ledger.balance(current.data, throughDate: today), currency)}',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      key: const Key('finance-account-add'),
                      onPressed: busy ? null : () => run(create),
                      icon: const Icon(Icons.add),
                      label: Text(context.tr('fAccountNew')),
                    ),
                    OutlinedButton.icon(
                      key: const Key('finance-account-transfer'),
                      onPressed: busy ? null : () => run(transfer),
                      icon: const Icon(Icons.swap_horiz),
                      label: Text(context.tr('fAccountTransfer')),
                    ),
                  ],
                ),
                for (final account in rows)
                  Card(
                    child: ListTile(
                      title: Text(account['name'] as String),
                      subtitle: Text(
                        '${context.tr(accountTypeKey(account['type'] as String))} · ${moneyText(balances[account['id']]!, currency)}'
                        '${account['archived'] == true ? '\n${context.tr('fAccountArchived')}' : ''}'
                        '${account['openedOn'] == null ? '' : '\n${context.tr('fAccountOpeningDate')}: ${MaterialLocalizations.of(context).formatFullDate(DateTime.parse(account['openedOn'] as String))}'}',
                      ),
                      trailing: PopupMenuButton<String>(
                        key: ValueKey('finance-account-menu-${account['id']}'),
                        enabled: !busy,
                        onSelected: (action) => run(
                          () => switch (action) {
                            'rename' => rename(account),
                            'reconcile' => reconcile(account),
                            'history' => history(account),
                            _ => archive(account),
                          },
                        ),
                        itemBuilder: (c) => [
                          PopupMenuItem(
                            value: 'rename',
                            child: Text(c.tr('fAccountRename')),
                          ),
                          PopupMenuItem(
                            value: 'history',
                            child: Text(c.tr('fAccountReconciliationHistory')),
                          ),
                          if (account['archived'] != true)
                            PopupMenuItem(
                              value: 'reconcile',
                              child: Text(c.tr('fAccountReconcile')),
                            ),
                          PopupMenuItem(
                            value: 'archive',
                            child: Text(
                              c.tr(
                                account['archived'] == true
                                    ? 'restore'
                                    : 'archive',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                Text(context.tr('fAccountLocalInfo')),
                Text(context.tr('fAccountReconcileInfo')),
              ],
            ),
    );
  }
}
