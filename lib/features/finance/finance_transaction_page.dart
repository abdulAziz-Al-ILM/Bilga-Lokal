import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/dialogs.dart';
import '../../core/editor_form.dart';
import '../../core/strings.dart';
import '../agent/agent_access.dart';
import '../agent/purchase_panel.dart';
import '../attachments/attachment_store.dart';
import '../private_space/record_store.dart';
import 'account_ledger.dart';
import 'ledger.dart';
import 'transaction_edits.dart';

class FinanceTransactionPage extends StatefulWidget {
  final PrivateRecord ledger;
  final String entryId;
  final RecordStore store;
  final AgentAccess access;
  const FinanceTransactionPage({
    super.key,
    required this.ledger,
    required this.entryId,
    required this.store,
    required this.access,
  });
  @override
  State<FinanceTransactionPage> createState() => _TransactionState();
}

class _TransactionState extends State<FinanceTransactionPage> {
  late PrivateRecord current = widget.ledger;
  bool busy = false, stale = false;
  Map<String, dynamic> get entry => Map<String, dynamic>.from(
    (current.data['entries'] as List).firstWhere(
      (row) => row['id'] == widget.entryId,
    ) as Map,
  );
  String get currency => current.data['currency'] as String;
  String accountName(Object? id) =>
      AccountLedger.accounts(current.data)
              .where((row) => row['id'] == (id ?? AccountLedger.legacyId))
              .firstOrNull?['name']
          as String? ??
      '';
  String date(String raw) {
    final value = DateTime.parse(raw).toLocal();
    return '${MaterialLocalizations.of(context).formatFullDate(value)}${raw.contains('T') ? ' · ${TimeOfDay.fromDateTime(value).format(context)}' : ''}';
  }

  String text(Map row) => [
    '${context.tr('x${row['type']}')} · ${moneyText(row['amount'] as int, currency)}',
    date(row['date'] as String),
    row['type'] == 'transfer'
        ? '${accountName(row['from'])} → ${accountName(row['to'])}'
        : accountName(row['account']),
    if ((row['category'] as String).isNotEmpty) row['category'],
    if ((row['description'] as String).isNotEmpty) row['description'],
    if (row['void'] == true) context.tr('fEntryVoided'),
  ].join('\n\n');
  Future<bool> permitted() async {
    if (widget.access.has(AgentAccess.finance)) return true;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) =>
          PurchasePanel(product: AgentAccess.finance, access: widget.access),
    );
    return widget.access.has(AgentAccess.finance);
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
    if (!widget.access.has(AgentAccess.finance)) {
      throw StateError('access_expired');
    }
    if (identical(data, expected.data)) return;
    try {
      final saved = await widget.store.save(
        'finance',
        data,
        previous: expected,
      );
      if (mounted) setState(() => current = saved);
    } on StateError catch (error) {
      if (error.message == 'record_changed' && mounted) {
        setState(() => stale = true);
      }
      rethrow;
    }
  }

  Future<void> reload() async {
    final saved = (await widget.store.all('finance'))
        .where((row) => row.id == current.id)
        .first;
    Ledger.validate(saved.data);
    if (mounted) {
      setState(() {
        current = saved;
        stale = false;
      });
    }
  }

  Future<void> edit() async {
    if (!await permitted() || !mounted) return;
    final original = current, old = entry;
    final accounts = AccountLedger.accounts(original.data)
        .where((row) => row['archived'] == false || row['id'] == old['account'])
        .toList();
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
      '${context.tr('edit')} · ${accountName(account)}',
      {
        'amount': '${context.tr('xAmount')} ($currency)',
        'date': context.tr('xDate'),
        'category': context.tr('xCategory'),
        'description': context.tr('description'),
      },
      initial: {
        'amount': moneyText(old['amount'] as int, currency).split(' ').first,
        'date': old['date'] as String,
        'category': old['category'] as String,
        'description': old['description'] as String,
      },
      requiredFields: {'amount', 'date'},
      numberFields: {'amount'},
      dateFields: {'date'},
      multiline: {'description'},
      onSave: (values) => save(
        TransactionEdits.edit(
          original.data,
          id: widget.entryId,
          changes: {
            'amount': parseMoney(values['amount']!, currency),
            'date': values['date']!,
            'category': values['category']!,
            'description': values['description']!,
            'account': account,
          },
        ),
        original,
      ),
    );
  }

  Future<void> toggleVoid() async {
    if (!await permitted() || !mounted) return;
    final original = current, old = entry, voided = old['void'] != true;
    if (voided &&
        {'lent', 'borrowed'}.contains(old['type']) &&
        Ledger.outstanding(original.data, old) != old['amount']) {
      showError(context, 'fDebtHasRepayments');
      return;
    }
    if (!await confirm(
          context,
          context.tr('fTransactionUndoInfo'),
          title: context.tr(voided ? 'fTransactionVoid' : 'restore'),
        ) ||
        !mounted) {
      return;
    }
    await save(
      TransactionEdits.setVoided(
        original.data,
        id: widget.entryId,
        voided: voided,
      ),
      original,
    );
  }

  Future<void> inspect(int index) async {
    final original = current, event = (entry['versions'] as List)[index] as Map;
    final restore = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(c.tr('fTransactionHistory')),
        content: SingleChildScrollView(
          child: SelectableText(
            '${date(event['at'] as String)}\n\n${text(event['before'] as Map)}\n\n${c.tr('fTransactionRestoreInfo')}',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text(c.tr('close')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(c.tr('restore')),
          ),
        ],
      ),
    );
    if (restore != true || !mounted || !await permitted()) return;
    await save(
      TransactionEdits.restore(
        original.data,
        id: widget.entryId,
        version: index,
      ),
      original,
    );
  }

  Future<void> export() async {
    if (!await consent(context, context.tr('xPlainExport')) || !mounted) return;
    await Attachments.export(
      'Bilga-transaction-history.json',
      'application/json',
      Stream.value(utf8.encode(TransactionEdits.exportHistory(entry))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final row = entry, versions = row['versions'] as List? ?? [];
    final canEdit = row['void'] != true && Ledger.types.contains(row['type']);
    final canRepay =
        row['void'] != true &&
        {'lent', 'borrowed'}.contains(row['type']) &&
        Ledger.outstanding(current.data, row) > 0;
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('x${row['type']}')),
        actions: [
          IconButton(
            tooltip: context.tr('retry'),
            onPressed: busy ? null : () => run(reload),
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: context.tr('export'),
            onPressed: busy ? null : () => run(export),
            icon: const Icon(Icons.ios_share),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (stale)
            Text(
              context.tr('saveError'),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          SelectableText(
            text(row),
            key: const Key('finance-transaction-detail'),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (canEdit)
                FilledButton.icon(
                  key: const Key('finance-transaction-edit'),
                  onPressed: busy || stale ? null : () => run(edit),
                  icon: const Icon(Icons.edit_outlined),
                  label: Text(context.tr('edit')),
                ),
              OutlinedButton.icon(
                key: const Key('finance-transaction-void'),
                onPressed: busy || stale ? null : () => run(toggleVoid),
                icon: const Icon(Icons.undo),
                label: Text(
                  context.tr(
                    row['void'] == true ? 'restore' : 'fTransactionVoid',
                  ),
                ),
              ),
              if (canRepay)
                OutlinedButton(
                  key: const Key('finance-transaction-repay'),
                  onPressed: busy || stale
                      ? null
                      : () => Navigator.pop(context, 'repay'),
                  child: Text(context.tr('fRepayment')),
                ),
            ],
          ),
          const Divider(height: 40),
          Text(
            context.tr('fTransactionHistory'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          Text(context.tr('fTransactionCurrent')),
          if (versions.isEmpty) Text(context.tr('empty')),
          for (var index = versions.length - 1; index >= 0; index--)
            ListTile(
              key: ValueKey('finance-transaction-version-$index'),
              title: Text(
                '${moneyText(versions[index]['before']['amount'] as int, currency)} · ${versions[index]['before']['description']}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                '${date(versions[index]['at'] as String)} · ${context.tr(switch (versions[index]['action']) {
                  'void' => 'fTransactionVoided',
                  'restore' => 'fTransactionRestored',
                  _ => 'fTransactionEdited',
                })}',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: busy || stale ? null : () => run(() => inspect(index)),
            ),
        ],
      ),
    );
  }
}
