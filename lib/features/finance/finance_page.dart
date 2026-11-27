import '../../core/review_performance.dart';

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../organization/folders_page.dart';
import '../organization/organization_store.dart';
import '../notes/note_database.dart';
import 'finance_planning.dart';
import '../guidance/guide_controller.dart';
import '../guidance/guide_host.dart';
import 'finance_planning_page.dart';

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
import 'finance_transaction_page.dart';
import 'finance_reports_page.dart';

class FinancePage extends StatefulWidget {
  final RecordStore? store;
  final AgentAccess? access;
  final String? initialLedgerId;
  final bool tutorial;
  const FinancePage({
    super.key,
    this.store,
    this.access,
    this.initialLedgerId,
    this.tutorial = false,
  });
  @override
  State<FinancePage> createState() => _FinanceState();
}

class _FinanceState extends State<FinancePage> {
  late final RecordStore store;
  List<PrivateRecord> ledgers = [];
  PrivateRecord? selected;
  bool busy = false, loadFailed = false;
  String query = "";
  int shown = 50;
  Timer? searchDelay;
  FinanceOverview? overview;
  BigInt? currencyTotal;
  String? activeId;
  final anchors = {
    for (final k in ['create', 'name', 'currency', 'save', 'results'])
      k: GlobalKey(),
  };
  late final guide = GuideController(
    id: 'finance.journal',
    steps: const [
      GuideStep('create', 'create', 'fpGuideJournalCreate', event: 'opened'),
      GuideStep(
        'name',
        'name',
        'fpGuideJournalName',
        event: 'named',
        backBoundary: true,
      ),
      GuideStep('currency', 'currency', 'fpGuideJournalCurrency'),
      GuideStep('save', 'save', 'fpGuideJournalSave', event: 'saved'),
      GuideStep(
        'results',
        'results',
        'fpGuideJournalResults',
        backBoundary: true,
      ),
    ],
  );
  Future<void> tutorial() async {
    final r = selected;
    if (r == null) {
      guide.start();
      return;
    }
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => FinancePlanningPage(
          ledger: r,
          store: store,
          access: access,
          initialTutorial: 'category',
        ),
      ),
    );
    if (mounted) await run(() async {});
  }

  @override
  void dispose() {
    guide.dispose();
    searchDelay?.cancel();
    super.dispose();
  }

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

  @override
  void initState() {
    super.initState();
    store = widget.store ?? RecordStore();
    run(() async {}).then((_) {
      if (mounted && widget.tutorial) tutorial();
    });
  }

  Future<void> load() async {
    try {
      final db = store.database ?? await NoteDatabase.database;
      final rows = await db.rawQuery("""
        SELECT id,revision,json_extract(payload,'\$.title') AS title,
          json_extract(payload,'\$.currency') AS currency
        FROM private_records WHERE kind='finance' ORDER BY updated_at DESC,id
      """);
      final list = [
        for (final row in rows)
          PrivateRecord(
            row['id'] as String,
            'finance',
            row['revision'] as int,
            {'title': row['title'], 'currency': row['currency']},
          ),
      ];
      final id =
          list.any(
            (r) => r.id == (activeId ?? selected?.id ?? widget.initialLedgerId),
          )
          ? (activeId ?? selected?.id ?? widget.initialLedgerId)
          : list.firstOrNull?.id;
      final record = id == null
          ? null
          : await ReviewPerformance.measure(
              'finance.loadLedger',
              () => store.get(id),
            );
      final today = DateTime.now().toIso8601String().substring(0, 10);
      final input = record == null ? null : (record.data, today);
      final summary = input == null
          ? null
          : (input.$1['entries'] as List).length > 500
          ? await compute(financeOverview, input)
          : financeOverview(input);
      final currency = record?.data['currency'] as String?;
      final total =
          currency == null ||
              list.where((row) => row.data['currency'] == currency).length < 2
          ? null
          : await totalForCurrency(db, currency, today);
      if (mounted) {
        setState(() {
          ledgers = list;
          loadFailed = false;
          activeId = id;
          selected = record;
          overview = summary;
          currencyTotal = total;
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
      guide.event('opened');
      await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (c) => GuideHost(
          controller: guide,
          targets: anchors,
          child: StatefulBuilder(
            builder: (c, update) => PopScope(
              canPop: !saving,
              child: AlertDialog(
                title: Text(c.tr('xFinance')),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        key: anchors['name'],
                        onChanged: (v) =>
                            guide.satisfy('named', valid: v.trim().isNotEmpty),
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
                        key: anchors['currency'],
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
                    key: anchors['save'],
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
                              activeId = selected!.id;
                              guide.event('saved');
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
        ),
      );
    } finally {
      await Future<void>.delayed(const Duration(milliseconds: 300));
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

  Future<void> openEntry(String id, {PrivateRecord? source}) async {
    final ledger = source ?? selected;
    if (ledger == null) return;
    final action = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => FinanceTransactionPage(
          ledger: ledger,
          entryId: id,
          store: store,
          access: access,
        ),
      ),
    );
    if (!mounted) return;
    await run(load);
    if (action == 'repay' &&
        mounted &&
        !loadFailed &&
        selected?.id == ledger.id) {
      final debt = (selected?.data['entries'] as List? ?? [])
          .where((row) => row['id'] == id)
          .firstOrNull;
      if (debt != null) await run(() => add(debt as Map));
    }
  }

  Future<void> quick(PrivateRecord ledger, String type) async {
    if (!await permitted() || !mounted) return;
    final currency = ledger.data['currency'] as String;
    final accounts = AccountLedger.accounts(ledger.data)
        .where((row) => row['archived'] == false)
        .toList();
    if (accounts.isEmpty) {
      showError(context, 'fAccountNeedActive');
      return;
    }
    final labels = FinancePlanning.categoryLabels(ledger.data);
    final categories = <String>{
      for (final category in FinancePlanning.plan(ledger.data)['categories'])
        if (category['archived'] != true) category['name'] as String,
      for (final entry in ledger.data['entries'])
        if (entry['type'] == type && entry['category'] != '')
          entry['category'] as String,
    };
    final retired = <String>{
      for (final row in FinancePlanning.plan(ledger.data)['categories'])
        if (row['archived'] == true) row['name'] as String,
    };
    categories.removeAll(retired);
    final created = <String>{};
    await editFields(
      context,
      context.tr(type == 'expense' ? 'fxAddExpense' : 'fxAddIncome'),
      {
        'amount': '${context.tr('xAmount')} ($currency)',
        'category': context.tr('xCategory'),
        'party': context.tr(type == 'expense' ? 'fxPaidTo' : 'fxReceivedFrom'),
        'description': context.tr('notes'),
        'account': context.tr('fAccounts'),
        'date': context.tr('xDate'),
      },
      initial: {
        'date': DateTime.now().toIso8601String().substring(0, 10),
        'account': accounts.first['id'] as String,
      },
      advancedFields: {'account', 'date'},
      dateFields: {'date'},
      numberFields: {'amount'},
      requiredFields: {'amount', 'date'},
      customFields: {
        'account': (c, field, saving) => ValueListenableBuilder(
          valueListenable: field,
          builder: (c, value, _) => DropdownButtonFormField<String>(
            initialValue: value.text,
            decoration: InputDecoration(labelText: c.tr('fAccounts')),
            isExpanded: true,
            items: [
              for (final account in accounts)
                DropdownMenuItem(
                  value: account['id'] as String,
                  child: Text(account['name'] as String),
                ),
            ],
            onChanged: saving ? null : (v) => field.text = v!,
          ),
        ),
        'category': (c, field, saving) => ValueListenableBuilder(
          valueListenable: field,
          builder: (c, value, _) => OutlinedButton.icon(
            key: const Key('finance-quick-category'),
            onPressed: saving
                ? null
                : () async {
                    final selection =
                        await showModalBottomSheet<(String, bool)>(
                          context: c,
                          builder: (sheet) => SafeArea(
                            child: ListView(
                              shrinkWrap: true,
                              children: [
                                ListTile(
                                  leading: const Icon(Icons.add),
                                  title: Text(sheet.tr('fxCreateCategory')),
                                  onTap: () => Navigator.pop(sheet, ('', true)),
                                ),
                                ListTile(
                                  title: Text(sheet.tr('fpUncategorized')),
                                  onTap: () =>
                                      Navigator.pop(sheet, ('', false)),
                                ),
                                for (final name in categories.toList()..sort())
                                  ListTile(
                                    title: Text(labels[name] ?? name),
                                    onTap: () =>
                                        Navigator.pop(sheet, (name, false)),
                                  ),
                              ],
                            ),
                          ),
                        );
                    if (selection == null || !c.mounted) return;
                    if (!selection.$2) {
                      field.text = selection.$1;
                      return;
                    }
                    final draft = await editFields(
                      c,
                      c.tr('fxCreateCategory'),
                      {'name': c.tr('title')},
                      requiredFields: {'name'},
                      onSave: (v) async {
                        final name = v['name']!.trim();
                        if (name.length > 100 || retired.contains(name)) {
                          throw const FormatException('category_name');
                        }
                      },
                    );
                    if (draft != null && c.mounted) {
                      final name = draft['name']!.trim();
                      if (categories.add(name)) created.add(name);
                      field.text = name;
                    }
                  },
            icon: const Icon(Icons.category_outlined),
            label: Text(
              value.text.isEmpty
                  ? c.tr('fxCategoryShort')
                  : labels[value.text] ?? value.text,
            ),
          ),
        ),
      },
      onSave: (values) async {
        final category = values['category']!;
        var data = ledger.data;
        if (created.contains(category)) {
          data = FinancePlanning.change(data, (plan) {
            (plan['categories'] as List).add({'name': category, 'parent': ''});
          });
        }
        final party = values['party']!.trim();
        selected = await save({
          ...data,
          'entries': [
            ...data['entries'],
            {
              'id': localId(),
              'type': type,
              'amount': parseMoney(values['amount']!, currency),
              'date': values['date'],
              'category': category,
              'description': values['description']!.trim(),
              if (party.isNotEmpty) 'party': party,
              'void': false,
              'account': values['account'],
              'currency': currency,
            },
          ],
        }, previous: ledger);
      },
    );
  }

  Future<void> planning(PrivateRecord ledger, String section) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => FinancePlanningPage(
          ledger: ledger,
          store: store,
          access: access,
          initialSection: section,
        ),
      ),
    );
    if (mounted) await run(() async {});
  }

  Future<void> accounts(PrivateRecord ledger, {bool transfer = false}) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => FinanceAccountsPage(
          ledger: ledger,
          store: store,
          access: access,
          startTransfer: transfer,
        ),
      ),
    );
    if (mounted) await run(() async {});
  }

  Future<void> folders(PrivateRecord ledger) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => FoldersPage(
          store: OrganizationStore('finance', provided: store.database),
          ledger: ledger.id,
          allowed: () => access.has(AgentAccess.finance),
          open: (item) async {
            final source = await store.get(item.id);
            if (mounted) await openEntry(item.entry, source: source);
          },
        ),
      ),
    );
  }

  Future<void> features(PrivateRecord ledger) async {
    final options = [
      ('accounts', 'fAccounts', Icons.account_balance_wallet_outlined),
      ('transfer', 'fAccountTransfer', Icons.swap_horiz),
      ('categories', 'fpSectioncategories', Icons.category_outlined),
      ('planning', 'fpPlanning', Icons.event_note_outlined),
      ('folders', 'orgFolders', Icons.folder_outlined),
      ('attachments', 'xAttach', Icons.attach_file),
      ('export', 'fxExport', Icons.download_outlined),
      ('entry', 'fxOtherEntry', Icons.add),
    ];
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (c) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final (id, label, icon) in options)
              ListTile(
                key: Key('finance-$id-open'),
                leading: Icon(icon),
                title: Text(c.tr(label)),
                onTap: () => Navigator.pop(c, id),
              ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    switch (choice) {
      case 'accounts':
        await accounts(ledger);
      case 'transfer':
        await accounts(ledger, transfer: true);
      case 'categories':
        await planning(ledger, 'categories');
      case 'planning':
        await planning(ledger, 'overview');
      case 'folders':
        await folders(ledger);
      case 'attachments':
        await Navigator.push<void>(
          context,
          MaterialPageRoute(
            builder: (_) => AttachmentsPage(
              kind: 'finance',
              owner: ledger.id,
              title: ledger.data['title'],
              store: store,
            ),
          ),
        );
      case 'export':
        if (await consent(context, context.tr('xPlainExport'))) {
          await Attachments.export(
            'Bilga-money.csv',
            'text/csv',
            Stream.value(utf8.encode(Ledger.csv(ledger.data))),
          );
        }
      case 'entry':
        await run(add);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ledger = selected;
    final summary = overview;
    final currency = ledger?.data['currency'] as String?;
    final theme = Theme.of(context);
    final labels = ledger == null
        ? const <String, String>{}
        : FinancePlanning.categoryLabels(ledger.data);
    final entries =
        summary?.entries
            .where(
              (entry) =>
                  query.isEmpty ||
                  '${entry['date']} ${entry['party'] ?? ''} ${entry['description']} ${entry['category']}'
                      .toLowerCase()
                      .contains(query),
            )
            .take(shown + 1)
            .toList() ??
        [];
    return GuideHost(
      controller: guide,
      targets: anchors,
      child: Scaffold(
        appBar: AppBar(
          title: Text(context.tr('xFinance')),
          actions: [
            IconButton(
              key: const Key('finance-module-help'),
              tooltip: context.tr('gShowMe'),
              icon: const Icon(Icons.help_outline),
              onPressed: busy ? null : tutorial,
            ),
            IconButton(
              key: anchors['create'],
              tooltip: context.tr('fpCreateLedger'),
              onPressed: busy ? null : () => run(create),
              icon: const Icon(Icons.add),
            ),
            if (ledger != null)
              IconButton(
                key: const Key('finance-all-features'),
                tooltip: context.tr('fxFeatures'),
                onPressed: busy ? null : () => features(ledger),
                icon: const Icon(Icons.apps_outlined),
              ),
          ],
        ),
        body: loadFailed
            ? Center(
                child: TextButton(
                  onPressed: busy ? null : () => run(() async {}),
                  child: Text(context.tr('retry')),
                ),
              )
            : ledger == null || summary == null || currency == null
            ? Center(
                child: busy
                    ? const CircularProgressIndicator()
                    : Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.account_balance_wallet_outlined,
                              size: 56,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              context.tr('xMoneyJournalInfo'),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            FilledButton.icon(
                              key: const Key('finance-create-ledger'),
                              onPressed: () => run(create),
                              icon: const Icon(Icons.add),
                              label: Text(context.tr('fpCreateLedger')),
                            ),
                          ],
                        ),
                      ),
              )
            : CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          DropdownButton<String>(
                            key: anchors['results'],
                            isExpanded: true,
                            value: ledger.id,
                            items: [
                              for (final row in ledgers)
                                DropdownMenuItem(
                                  value: row.id,
                                  child: Text(
                                    '${row.data['title']} · ${row.data['currency']}',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                            onChanged: busy
                                ? null
                                : (id) {
                                    activeId = id;
                                    run(() async {});
                                  },
                          ),
                          if (busy) const LinearProgressIndicator(),
                          Card(
                            color: theme.colorScheme.primaryContainer,
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    context.tr('fBalance'),
                                    style: theme.textTheme.labelLarge,
                                  ),
                                  Text(
                                    moneyText(summary.balance, currency),
                                    style: theme.textTheme.headlineLarge,
                                  ),
                                  if (currencyTotal != null)
                                    Text(
                                      '${context.tr('fxCurrencyTotal')} · ${FinancePlanning.plannedMoney(currencyTotal!, currency)}',
                                    ),
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 24,
                                    runSpacing: 10,
                                    children: [
                                      metric(
                                        'fxTodaySpent',
                                        summary.today,
                                        currency,
                                      ),
                                      metric(
                                        'fxMonthIncome',
                                        summary.income,
                                        currency,
                                      ),
                                      metric(
                                        'fxMonthExpense',
                                        summary.expense,
                                        currency,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              FilledButton.icon(
                                key: const Key('finance-add-expense'),
                                onPressed: busy
                                    ? null
                                    : () => run(() => quick(ledger, 'expense')),
                                icon: const Icon(Icons.remove),
                                label: Text(context.tr('fxAddExpense')),
                              ),
                              FilledButton.tonalIcon(
                                key: const Key('finance-add-income'),
                                onPressed: busy
                                    ? null
                                    : () => run(() => quick(ledger, 'income')),
                                icon: const Icon(Icons.add),
                                label: Text(context.tr('fxAddIncome')),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            children: [
                              ActionChip(
                                label: Text(context.tr('fAccountTransfer')),
                                avatar: const Icon(Icons.swap_horiz),
                                onPressed: busy
                                    ? null
                                    : () => accounts(ledger, transfer: true),
                              ),
                              for (final (section, label, icon) in [
                                (
                                  'debts',
                                  'fpSectiondebts',
                                  Icons.event_available_outlined,
                                ),
                                (
                                  'budgets',
                                  'fpSectionbudgets',
                                  Icons.pie_chart_outline,
                                ),
                                (
                                  'goals',
                                  'fpSectiongoals',
                                  Icons.savings_outlined,
                                ),
                              ])
                                ActionChip(
                                  avatar: Icon(icon),
                                  label: Text(context.tr(label)),
                                  onPressed: busy
                                      ? null
                                      : () => planning(ledger, section),
                                ),
                              ActionChip(
                                key: const Key('finance-reports-open'),
                                avatar: const Icon(Icons.bar_chart),
                                label: Text(context.tr('xReport')),
                                onPressed: busy
                                    ? null
                                    : () => Navigator.push<void>(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => FinanceReportsPage(
                                            ledger: ledger,
                                            store: store,
                                          ),
                                        ),
                                      ),
                              ),
                              ActionChip(
                                avatar: const Icon(Icons.apps_outlined),
                                label: Text(context.tr('fxFeatures')),
                                onPressed: busy ? null : () => features(ledger),
                              ),
                            ],
                          ),
                          if (summary.upcoming.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Text(
                              context.tr('fxUpcoming'),
                              style: theme.textTheme.titleMedium,
                            ),
                            for (final item in summary.upcoming)
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.event),
                                title: Text(item.label),
                                subtitle: Text(item.day),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: busy
                                    ? null
                                    : () => planning(ledger, item.section),
                              ),
                          ],
                          if (summary.categories.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Text(
                              context.tr('fxSpending'),
                              style: theme.textTheme.titleMedium,
                            ),
                            for (final entry in summary.categories)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${entry.key.isEmpty ? context.tr('fpUncategorized') : entry.key} · ${moneyText(entry.value, currency)}',
                                    ),
                                    LinearProgressIndicator(
                                      value: entry.value / summary.expense,
                                      minHeight: 6,
                                    ),
                                  ],
                                ),
                              ),
                          ],
                          const SizedBox(height: 16),
                          Text(
                            context.tr('fxRecent'),
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.search),
                              labelText: context.tr('search'),
                            ),
                            autocorrect: false,
                            enableSuggestions: false,
                            enableIMEPersonalizedLearning: false,
                            onChanged: (value) {
                              searchDelay?.cancel();
                              searchDelay = Timer(
                                const Duration(milliseconds: 220),
                                () {
                                  if (mounted) {
                                    setState(() {
                                      query = value.trim().toLowerCase();
                                      shown = 50;
                                    });
                                  }
                                },
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverList.builder(
                    itemCount: entries.length > shown ? shown : entries.length,
                    itemBuilder: (c, i) {
                      final entry = entries[i];
                      final type = entry['type'] as String;
                      return ListTile(
                        key: ValueKey('finance-entry-${entry['id']}'),
                        leading: Icon(
                          type == 'expense'
                              ? Icons.north_east
                              : type == 'income'
                              ? Icons.south_west
                              : Icons.swap_horiz,
                        ),
                        title: Text(
                          entry['party'] ??
                              ((entry['description'] as String).isEmpty
                                  ? c.tr('x$type')
                                  : entry['description']),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: entry['void'] == true
                              ? const TextStyle(
                                  decoration: TextDecoration.lineThrough,
                                )
                              : null,
                        ),
                        subtitle: Text(
                          [
                            entry['date'],
                            labels[entry['category']] ?? entry['category'],
                          ].where((s) => s != '').join(' · '),
                        ),
                        trailing: Text(moneyText(entry['amount'], currency)),
                        onTap: busy ? null : () => openEntry(entry['id']),
                      );
                    },
                  ),
                  if (entries.length > shown)
                    SliverToBoxAdapter(
                      child: TextButton(
                        onPressed: () => setState(() => shown += 50),
                        child: Text(context.tr('continue')),
                      ),
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 32)),
                ],
              ),
      ),
    );
  }

  Widget metric(String label, int value, String currency) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(context.tr(label)),
      Text(
        moneyText(value, currency),
        style: Theme.of(context).textTheme.titleMedium,
      ),
    ],
  );
}

typedef FinanceOverview = ({
  int balance,
  int today,
  int income,
  int expense,
  List<Map> entries,
  List<MapEntry<String, int>> categories,
  List<({String day, String label, String section})> upcoming,
});

FinanceOverview financeOverview((Map<String, dynamic>, String) input) {
  final (data, today) = input;
  Ledger.validate(data);
  final month = today.substring(0, 7);
  final entries = (data['entries'] as List).cast<Map>().reversed.toList()
    ..sort((a, b) => (b['date'] as String).compareTo(a['date'] as String));
  final report = Ledger.expenses(data, month, throughDate: today);
  final labels = FinancePlanning.categoryLabels(data);
  final categories =
      report.entries
          .map((entry) => MapEntry(labels[entry.key] ?? entry.key, entry.value))
          .toList()
        ..sort((a, b) => b.value.compareTo(a.value));
  final upcoming = <({String day, String label, String section})>[];
  final plans = FinancePlanning.plan(data);
  final byId = {for (final entry in entries) entry['id']: entry};
  final paid = <Object?, int>{};
  for (final entry in entries) {
    if (entry['void'] != true &&
        (entry['date'] as String).compareTo(today) <= 0 &&
        {'repaymentIn', 'repaymentOut'}.contains(entry['type'])) {
      paid.update(
        entry['parent'],
        (amount) => amount + (entry['amount'] as int),
        ifAbsent: () => entry['amount'] as int,
      );
    }
  }
  for (final plan in (plans['debts'] as Map).entries) {
    final entry = byId[plan.key];
    if (entry == null ||
        entry['void'] == true ||
        (paid[plan.key] ?? 0) >= (entry['amount'] as int)) {
      continue;
    }
    final day = plan.value['date'] as String?;
    if (day != null) {
      upcoming.add((
        day: day,
        label: [
          entry['description'],
          moneyText(entry['amount'] - (paid[plan.key] ?? 0), data['currency']),
        ].where((s) => s != '').join(' · '),
        section: 'debts',
      ));
    }
  }
  for (final rule in plans['recurring']) {
    if (rule['active'] != true || rule['type'] != 'expense') continue;
    final day = FinancePlanning.occurrence(rule);
    if (day != null) {
      upcoming.add((
        day: day,
        label: rule['name'] as String,
        section: 'recurring',
      ));
    }
  }
  upcoming.sort((a, b) => a.day.compareTo(b.day));
  return (
    balance: Ledger.balance(data, throughDate: today),
    today: Ledger.expenses(
      data,
      today,
      throughDate: today,
    ).values.fold(0, (a, b) => a + b),
    income: Ledger.income(data, month, throughDate: today),
    expense: report.values.fold(0, (a, b) => a + b),
    categories: categories.take(5).toList(),
    entries: entries,
    upcoming: upcoming.take(4).toList(),
  );
}

// One integer result per journal avoids overflowing SQLite's SUM across journals.
Future<BigInt> totalForCurrency(
  Database db,
  String currency,
  String today,
) async {
  final rows = await db.rawQuery(
    """
    SELECT
      coalesce((SELECT sum(json_extract(a.value,'\$.opening'))
        FROM json_each(r.payload,'\$.accounts') a
        WHERE coalesce(json_extract(a.value,'\$.openedOn'),'0001-01-01')<=?),0)
      + coalesce((SELECT sum(CASE
        WHEN json_extract(e.value,'\$.type') IN ('income','borrowed','repaymentIn','reconcileIn')
          THEN json_extract(e.value,'\$.amount')
        WHEN json_extract(e.value,'\$.type') IN ('expense','lent','repaymentOut','reconcileOut')
          THEN -json_extract(e.value,'\$.amount')
        ELSE 0 END)
        FROM json_each(r.payload,'\$.entries') e
        WHERE json_extract(e.value,'\$.date')<=? AND json_extract(e.value,'\$.void')=0),0) balance
    FROM private_records r WHERE r.kind='finance' AND json_extract(r.payload,'\$.currency')=?
  """,
    [today, today, currency],
  );
  return rows.fold<BigInt>(
    BigInt.zero,
    (value, row) => value + BigInt.from(row['balance'] as int),
  );
}
