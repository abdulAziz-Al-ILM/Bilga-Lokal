import 'package:flutter/material.dart';

import '../../core/strings.dart';
import '../../core/editor_form.dart';
import '../../core/dialogs.dart';
import '../agent/agent_access.dart';
import '../agent/purchase_panel.dart';
import '../guidance/guide_controller.dart';
import '../guidance/guide_host.dart';
import '../private_space/record_store.dart';
import '../reminders/module_reminder_status.dart';
import 'account_ledger.dart';
import 'ledger.dart';
import 'finance_planning.dart';

class FinancePlanningPage extends StatefulWidget {
  final PrivateRecord ledger;
  final RecordStore store;
  final AgentAccess access;
  final String? initialTutorial;
  final String initialSection;
  const FinancePlanningPage({
    super.key,
    required this.ledger,
    required this.store,
    required this.access,
    this.initialTutorial,
    this.initialSection = 'overview',
  });
  @override
  State<FinancePlanningPage> createState() => _PlanningState();
}

class _PlanningState extends State<FinancePlanningPage> {
  late PrivateRecord current = widget.ledger;
  late String section = widget.initialSection;
  String month = DateTime.now().toIso8601String().substring(0, 7);
  bool busy = false, stale = false, archivedGoals = false;
  String guideFlow = 'category';
  String? guidedDebt;
  final anchors = {
    for (final k in ['add', 'name', 'amount', 'save', 'results'])
      k: GlobalKey(),
  };
  late GuideController guide = GuideController(
    id: 'finance.plan',
    steps: const [
      GuideStep('add', 'add', 'fpGuideAdd', event: 'opened'),
      GuideStep(
        'name',
        'name',
        'fpGuideName',
        event: 'named',
        backBoundary: true,
      ),
      GuideStep('save', 'save', 'fpGuideSave', event: 'saved'),
      GuideStep('results', 'results', 'fpGuideResults', backBoundary: true),
    ],
  );
  @override
  void initState() {
    super.initState();
    if (widget.initialTutorial != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) beginGuide(widget.initialTutorial!);
      });
    }
  }

  void beginGuide(String flow) {
    if (flow == 'debt') {
      final debts = (current.data['entries'] as List)
          .where(
            (e) =>
                {'lent', 'borrowed'}.contains(e['type']) &&
                e['void'] != true &&
                Ledger.outstanding(current.data, e, throughDate: today) > 0,
          )
          .toList();
      if (debts.isEmpty) {
        showDialog<void>(
          context: context,
          builder: (c) => AlertDialog(
            content: Text(c.tr('fpDebtInfo')),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c),
                child: Text(c.tr('close')),
              ),
            ],
          ),
        );
        return;
      }
      guidedDebt = debts.first['id'];
    }
    guide.dispose();
    guideFlow = flow;
    guide = GuideController(
      id: 'finance.$flow',
      steps: [
        GuideStep('add', 'add', 'fpGuideAdd$flow', event: 'opened'),
        GuideStep(
          'name',
          'name',
          'fpGuideName$flow',
          event: 'named',
          backBoundary: true,
        ),
        if (flow == 'goal' || flow == 'recurring')
          const GuideStep(
            'amount',
            'amount',
            'fpGuideAmount',
            event: 'amountEntered',
          ),
        const GuideStep('save', 'save', 'fpGuideSavePlan', event: 'saved'),
        const GuideStep(
          'results',
          'results',
          'fpGuideResults',
          backBoundary: true,
        ),
      ],
    );
    setState(
      () => section = switch (flow) {
        'category' => 'categories',
        'budget' => 'budgets',
        'goal' => 'goals',
        'debt' => 'debts',
        _ => 'recurring',
      },
    );
    guide.start();
  }

  Future<void> planForm(
    String flow,
    String title,
    Map<String, String> labels, {
    Map<String, String> initial = const {},
    Set<String> requiredFields = const {},
    Set<String> numberFields = const {},
    Set<String> dateFields = const {},
    Set<String> multiline = const {},
    required Future<void> Function(Map<String, String>) onSave,
  }) async {
    final guided = guide.active && guideFlow == flow;
    final first = switch (flow) {
          'budget' => 'amount',
          'debt' => 'date',
          _ => 'name',
        },
        amount = flow == 'goal' ? 'target' : 'amount';
    bool valid(String field, String value) {
      if (field == 'date') return AccountLedger.validDate(value);
      if (field == 'amount' || field == 'target') {
        try {
          return parseMoney(value, currency) > 0;
        } catch (_) {
          return false;
        }
      }
      return value.trim().isNotEmpty;
    }

    if (guided) {
      guide.event('opened');
      guide.satisfy('named', valid: valid(first, initial[first] ?? ''));
    }
    await editFields(
      context,
      title,
      labels,
      initial: initial,
      requiredFields: requiredFields,
      numberFields: numberFields,
      dateFields: dateFields,
      multiline: multiline,
      fieldKeys: guided
          ? {
              first: anchors['name']!,
              if (first != amount && labels.containsKey(amount))
                amount: anchors['amount']!,
            }
          : {},
      saveKey: guided ? anchors['save'] : null,
      pageWrapper: (child) =>
          GuideHost(controller: guide, targets: anchors, child: child),
      onChanged: (field, value) {
        if (guided) {
          if (field == first) {
            guide.satisfy('named', valid: valid(field, value));
          }
          if (field == amount) {
            guide.satisfy('amountEntered', valid: valid(field, value));
          }
        }
      },
      onSave: (values) async {
        await onSave(values);
        if (guided) guide.event('saved');
      },
    );
  }

  Map<String, dynamic> get p => FinancePlanning.plan(current.data);
  String get currency => current.data['currency'];
  String get today => DateTime.now().toIso8601String().substring(0, 10);
  @override
  void dispose() {
    guide.dispose();
    super.dispose();
  }

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
      if (mounted) failure(context);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> save(Map<String, dynamic> data, PrivateRecord expected) async {
    if (!widget.access.has(AgentAccess.finance)) {
      throw StateError('access_expired');
    }
    try {
      final saved = await widget.store.save(
        'finance',
        data,
        previous: expected,
      );
      if (mounted) setState(() => current = saved);
    } on StateError catch (e) {
      if (e.message == 'record_changed' && mounted) {
        setState(() => stale = true);
      }
      rethrow;
    }
  }

  Future<void> reload() async {
    final saved = await widget.store.get(current.id);
    Ledger.validate(saved.data);
    if (mounted) {
      setState(() {
        current = saved;
        stale = false;
      });
    }
  }

  Future<String?> choose(String title, Map<String, String> options) =>
      showDialog<String>(
        context: context,
        builder: (c) => SimpleDialog(
          title: Text(title),
          children: [
            for (final e in options.entries)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(c, e.key),
                child: Text(e.value),
              ),
          ],
        ),
      );
  Map<String, String> get categories => {
    '': context.tr('fpAllCategories'),
    ...FinancePlanning.categoryLabels(current.data),
  };
  Map<String, String> get accounts => {
    for (final a in AccountLedger.accounts(current.data))
      if (a['archived'] != true) a['id'] as String: a['name'] as String,
  };
  Future<void> category({Map? existing}) async {
    if (!await permitted() || !mounted) return;
    final parent = await choose(context.tr('fpParent'), {
      '': context.tr('fpNoParent'),
      for (final c in p['categories'])
        if (c['name'] != existing?['name']) c['name']: c['name'],
    });
    if (parent == null || !mounted) return;
    final original = current;
    if (guide.active) guide.event('opened');
    await editFields(
      context,
      context.tr('fpCategory'),
      {'name': context.tr('title')},
      initial: {'name': existing?['label'] ?? existing?['name'] ?? ''},
      requiredFields: {'name'},
      fieldKeys: {'name': anchors['name']!},
      saveKey: anchors['save'],
      onChanged: (k, v) => guide.satisfy('named', valid: v.trim().isNotEmpty),
      pageWrapper: (child) =>
          GuideHost(controller: guide, targets: anchors, child: child),
      onSave: (v) async {
        final name = v['name']!.trim();
        await save(
          FinancePlanning.change(original.data, (p) {
            final rows = p['categories'] as List;
            if (rows.any(
              (row) =>
                  row['name'] != existing?['name'] &&
                  (row['label'] ?? row['name']).toString().toLowerCase() ==
                      name.toLowerCase(),
            )) {
              throw const FormatException('category_duplicate');
            }
            if (existing == null) {
              if (rows.any((row) => row['name'] == name)) {
                throw const FormatException('category_duplicate');
              }
              rows.add({'name': name, 'parent': parent});
            } else {
              final row = rows.firstWhere(
                (row) => row['name'] == existing['name'],
              ) as Map;
              row['label'] = name;
              row['parent'] = parent;
            }
          }),
          original,
        );
        guide.event('saved');
      },
    );
  }

  Future<void> removeCategory(Map row) async {
    if (!await permitted() || !mounted) return;
    final original = current;
    final key = row['name'];
    final referenced =
        (original.data['entries'] as List).any(
          (entry) =>
              entry['category'] == key ||
              (entry['versions'] as List? ?? []).any(
                (v) => v['before'] is Map && v['before']['category'] == key,
              ),
        ) ||
        [
          'budgets',
          'recurring',
        ].any((table) => (p[table] as List).any((r) => r['category'] == key)) ||
        (p['categories'] as List).any((r) => r['parent'] == key);
    final archived = row['archived'] == true;
    if (!archived &&
        !await consent(
          context,
          context.tr(
            referenced ? 'fxArchiveCategoryInfo' : 'fxDeleteCategoryInfo',
          ),
        )) {
      return;
    }
    if (!mounted) return;
    await save(
      FinancePlanning.change(original.data, (plan) {
        final rows = plan['categories'] as List;
        if (!referenced && !archived) {
          rows.removeWhere((r) => r['name'] == key);
        } else {
          rows.firstWhere((r) => r['name'] == key)['archived'] = !archived;
        }
      }),
      original,
    );
  }

  Future<void> budget({Map? old}) async {
    if (!await permitted() || !mounted) return;
    final category =
        old?['category'] as String? ??
        await choose(context.tr('xCategory'), categories);
    if (category == null || !mounted) return;
    final original = current;
    await planForm(
      'budget',
      context.tr('fpBudget'),
      {'month': 'YYYY-MM', 'amount': '${context.tr('xAmount')} ($currency)'},
      initial: {
        'month': old?['month'] ?? month,
        'amount': old == null
            ? ''
            : moneyText(old['amount'], currency).split(' ').first,
      },
      requiredFields: {'month', 'amount'},
      numberFields: {'amount'},
      onSave: (v) => save(
        FinancePlanning.setBudget(
          original.data,
          v['month']!.trim(),
          category,
          parseMoney(v['amount']!, currency),
        ),
        original,
      ),
    );
  }

  Future<void> goal({Map? old}) async {
    if (!await permitted() || !mounted) return;
    final account =
        old?['account'] as String? ??
        await choose(context.tr('fAccounts'), accounts);
    if (account == null || !mounted) return;
    final original = current;
    await planForm(
      'goal',
      context.tr('fpGoal'),
      {
        'name': context.tr('title'),
        'target': '${context.tr('fpTarget')} ($currency)',
        'deadline': context.tr('fpDeadlineOptional'),
      },
      initial: {
        'name': old?['name'] ?? '',
        'target': old == null
            ? ''
            : moneyText(old['target'], currency).split(' ').first,
        'deadline': old?['deadline'] ?? '',
      },
      requiredFields: {'name', 'target'},
      numberFields: {'target'},
      dateFields: {'deadline'},
      onSave: (v) => save(
        FinancePlanning.change(original.data, (p) {
          final rows = p['goals'] as List, id = old?['id'] ?? localId();
          rows.removeWhere((g) => g['id'] == id);
          rows.add({
            'id': id,
            'name': v['name']!.trim(),
            'target': parseMoney(v['target']!, currency),
            'account': account,
            'deadline': v['deadline']!.trim().isEmpty
                ? null
                : v['deadline']!.trim(),
            'archived': old?['archived'] ?? false,
          });
        }),
        original,
      ),
    );
  }

  Future<void> recurring({Map? old}) async {
    if (!await permitted() || !mounted) return;
    final account =
        old?['account'] as String? ??
        await choose(context.tr('fAccounts'), accounts);
    if (account == null || !mounted) return;
    final type =
        old?['type'] as String? ??
        await choose(context.tr('fpRecurring'), {
          for (final t in ['expense', 'income']) t: context.tr('x$t'),
        });
    if (type == null || !mounted) return;
    final frequency =
        old?['frequency'] as String? ??
        await choose(context.tr('fpFrequency'), {
          for (final t in ['weekly', 'monthly', 'yearly'])
            t: context.tr('fp$t'),
        });
    if (frequency == null || !mounted) return;
    final category =
        old?['category'] as String? ??
        await choose(context.tr('xCategory'), {
          ...categories,
          '': context.tr('fpUncategorized'),
        });
    if (category == null || !mounted) return;
    final original = current;
    await planForm(
      'recurring',
      context.tr('fpRecurring'),
      {
        'name': context.tr('title'),
        'amount': '${context.tr('xAmount')} ($currency)',
        if (old == null) 'start': context.tr('fpFirstDate'),
        if (old == null) 'every': context.tr('fpEvery'),
        'end': context.tr('fpDeadlineOptional'),
        'description': context.tr('description'),
      },
      initial: {
        'start': old?['start'] ?? today,
        'every': '${old?['every'] ?? 1}',
        'name': old?['name'] ?? '',
        'amount': old == null
            ? ''
            : moneyText(old['amount'], currency).split(' ').first,
        'end': old?['end'] ?? '',
        'description': old?['description'] ?? '',
      },
      requiredFields: {
        'name',
        'amount',
        if (old == null) ...['start', 'every'],
      },
      numberFields: {'amount', 'every'},
      dateFields: {'start', 'end'},
      multiline: {'description'},
      onSave: (v) => save(
        FinancePlanning.change(original.data, (p) {
          (p['recurring'] as List).removeWhere((r) => r['id'] == old?['id']);
          (p['recurring'] as List).add({
            'id': old?['id'] ?? localId(),
            'name': v['name']!.trim(),
            'type': type,
            'amount': parseMoney(v['amount']!, currency),
            'start': old?['start'] ?? v['start']!.trim(),
            'every': old?['every'] ?? int.parse(v['every']!.trim()),
            'end': v['end']!.trim().isEmpty ? null : v['end']!.trim(),
            'frequency': frequency,
            'account': account,
            'category': category,
            'description': v['description']!,
            'cursor': old?['cursor'] ?? 0,
            'active': old?['active'] ?? true,
          });
        }),
        original,
      ),
    );
  }

  Future<void> deadline(Map debt) async {
    if (!await permitted() || !mounted) return;
    final original = current, old = (p['debts'] as Map)[debt['id']] as Map?;
    await planForm(
      'debt',
      context.tr('fpDebtDeadline'),
      {'date': context.tr('fpDeadline')},
      initial: {'date': old?['date'] ?? today},
      requiredFields: {'date'},
      dateFields: {'date'},
      onSave: (v) => save(
        FinancePlanning.change(
          original.data,
          (p) => (p['debts'] as Map)[debt['id']] = {
            'date': v['date']!.trim(),
            'minute': old?['minute'],
          },
        ),
        original,
      ),
    );
  }

  Future<void> debtReminder(Map debt) async {
    if (!await permitted() || !mounted) return;
    final original = current, d = (p['debts'] as Map)[debt['id']] as Map?;
    if (d == null) {
      await deadline(debt);
      return;
    }
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: (d['minute'] as int? ?? 540) ~/ 60,
        minute: (d['minute'] as int? ?? 540) % 60,
      ),
    );
    if (time == null || !mounted) return;
    await save(
      FinancePlanning.change(
        original.data,
        (p) => (p['debts'] as Map)[debt['id']] = {
          ...d,
          'minute': time.hour * 60 + time.minute,
        },
      ),
      original,
    );
  }

  Future<void> post(Map rule, bool skip) async {
    if (!await permitted() || !mounted) return;
    final original = current, date = FinancePlanning.occurrence(rule);
    if (date == null) return;
    if (!await confirm(
          context,
          '${rule['name']} · $date\n${moneyText(rule['amount'], currency)}\n\n${context.tr(skip ? 'fpSkipExplain' : 'fpPostExplain')}',
          title: context.tr(skip ? 'fpSkipOccurrence' : 'fpConfirmOccurrence'),
        ) ||
        !mounted) {
      return;
    }
    await save(
      FinancePlanning.confirmOccurrence(
        original.data,
        rule['id'],
        date,
        today: today,
        skip: skip,
      ),
      original,
    );
  }

  Future<void> templates() async {
    final action = await showDialog<String>(
      context: context,
      builder: (c) => SimpleDialog(
        title: Text(c.tr('tpl_templates')),
        children: [
          for (final e in {
            'categories': 'fpStarterCategories',
            'budget': 'fpBudget',
            'goal': 'fpGoal',
            'recurring': 'fpRecurring',
          }.entries)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(c, e.key),
              child: Text(c.tr(e.value)),
            ),
        ],
      ),
    );
    if (!mounted || action == null) return;
    if (action == 'budget') {
      await budget();
      return;
    }
    if (action == 'goal') {
      await goal();
      return;
    }
    if (action == 'recurring') {
      await recurring();
      return;
    }
    final names = [
      for (final k in [
        'Housing',
        'Food',
        'Transport',
        'Health',
        'Learning',
        'Income',
      ])
        context.tr('fpCategory$k'),
    ];
    final children = [
      for (final k in ['Electricity', 'Water', 'Internet'])
        context.tr('fpCategory$k'),
    ];
    if (!await confirm(
          context,
          [...names, ...children.map((c) => '${names.first} → $c')].join('\n'),
          title: context.tr('fpStarterCategories'),
        ) ||
        !mounted ||
        !await permitted()) {
      return;
    }
    final original = current;
    await save(
      FinancePlanning.change(original.data, (p) {
        final rows = p['categories'] as List,
            existing = {for (final c in rows) c['name']};
        for (final n in names) {
          if (existing.add(n)) rows.add({'name': n, 'parent': ''});
        }
        for (final n in children) {
          if (existing.add(n)) rows.add({'name': n, 'parent': names.first});
        }
      }),
      original,
    );
  }

  Widget progress(
    String title,
    int amount,
    int target, {
    String? subtitle,
    bool budgetWarning = false,
  }) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          if (subtitle != null) Text(subtitle),
          Text(
            '${moneyText(amount, currency)} / ${moneyText(target, currency)} · ${FinancePlanning.percent(amount, target)}%',
          ),
          LinearProgressIndicator(
            value: target <= 0 ? 0 : (amount / target).clamp(0, 1),
          ),
          if (amount >= target)
            Text(context.tr(budgetWarning ? 'fpBudgetReached' : 'fpReached'))
          else if (budgetWarning &&
              FinancePlanning.percent(amount, target) >= 80)
            Text(context.tr('fpNearLimit')),
        ],
      ),
    ),
  );
  Widget action(String key, String text, VoidCallback onTap) =>
      FilledButton.tonalIcon(
        key: Key(key),
        onPressed: busy || stale ? null : onTap,
        icon: const Icon(Icons.add),
        label: Text(context.tr(text)),
      );
  Widget overview() {
    final income = Ledger.income(current.data, month, throughDate: today),
        spent = FinancePlanning.spent(current.data, month, '', today);
    final totals = FinancePlanning.plannedTotals(current.data, month, today);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.tr('fpActual')),
        Text(
          '${context.tr('xincome')}: ${moneyText(income, currency)}\n${context.tr('xexpense')}: ${moneyText(spent, currency)}',
        ),
        const SizedBox(height: 16),
        Text(context.tr('fpPlannedOnly')),
        Text(
          '${context.tr('xincome')}: ${FinancePlanning.plannedMoney(totals.income, currency)}\n${context.tr('xexpense')}: ${FinancePlanning.plannedMoney(totals.expense, currency)}',
        ),
        Text(context.tr('fpNoInventedBalances')),
      ],
    );
  }

  @override
  Widget build(BuildContext c) {
    final data = p;
    return GuideHost(
      controller: guide,
      targets: anchors,
      child: Scaffold(
        appBar: AppBar(
          title: Text(c.tr('fpPlanning')),
          actions: [
            IconButton(
              tooltip: c.tr('tpl_templates'),
              icon: const Icon(Icons.dashboard_customize_outlined),
              onPressed: busy ? null : () => run(templates),
            ),
            IconButton(
              key: const Key('finance-planning-help'),
              tooltip: c.tr('gShowMe'),
              icon: const Icon(Icons.help_outline),
              onPressed: () {
                beginGuide('category');
              },
            ),
            IconButton(
              tooltip: c.tr('fpRefresh'),
              icon: const Icon(Icons.refresh),
              onPressed: busy ? null : () => run(reload),
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(c.tr('fpPurpose')),
              Wrap(
                spacing: 8,
                children: [
                  for (final item in {
                    'budget': 'fpBudget',
                    'goal': 'fpGoal',
                    'recurring': 'fpRecurring',
                    'debt': 'fpDebtDeadline',
                  }.entries)
                    TextButton(
                      key: Key('finance-guide-${item.key}'),
                      onPressed: busy ? null : () => beginGuide(item.key),
                      child: Text('${c.tr('gShowMe')} · ${c.tr(item.value)}'),
                    ),
                ],
              ),
              if (busy)
                Semantics(liveRegion: true, child: Text(c.tr('saving'))),
              if (stale) Text(c.tr('fpStale')),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final name in [
                    'overview',
                    'categories',
                    'budgets',
                    'goals',
                    'recurring',
                    'debts',
                  ])
                    ChoiceChip(
                      key: Key('finance-section-$name'),
                      label: Text(c.tr('fpSection$name')),
                      selected: section == name,
                      onSelected: busy
                          ? null
                          : (_) => setState(() => section = name),
                    ),
                ],
              ),
              Row(
                children: [
                  IconButton(
                    tooltip: MaterialLocalizations.of(c).previousMonthTooltip,
                    onPressed: () => setState(() {
                      final d = DateTime.parse('$month-01');
                      month = DateTime(
                        d.year,
                        d.month - 1,
                      ).toIso8601String().substring(0, 7);
                    }),
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Expanded(child: Text(month, textAlign: TextAlign.center)),
                  IconButton(
                    tooltip: MaterialLocalizations.of(c).nextMonthTooltip,
                    onPressed: () => setState(() {
                      final d = DateTime.parse('$month-01');
                      month = DateTime(
                        d.year,
                        d.month + 1,
                      ).toIso8601String().substring(0, 7);
                    }),
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
              SizedBox(
                key: anchors['results'],
                child: Text(
                  c.tr('fpSavedPlans'),
                  style: Theme.of(c).textTheme.titleLarge,
                ),
              ),
              if (section == 'overview') overview(),
              if (section == 'categories') ...[
                SizedBox(
                  key: anchors['add'],
                  child: action(
                    'finance-add-category',
                    'fpCategory',
                    () => run(() => category()),
                  ),
                ),
                for (final row in data['categories'])
                  ListTile(
                    title: Text(row['label'] ?? row['name']),
                    subtitle: Text(
                      row['archived'] == true
                          ? c.tr('archive')
                          : (row['parent'] as String).isEmpty
                          ? c.tr('fpNoParent')
                          : categories[row['parent']] ?? row['parent'],
                    ),
                    onTap: busy
                        ? null
                        : () => run(() => category(existing: row)),
                    trailing: PopupMenuButton<String>(
                      enabled: !busy,
                      onSelected: (action) => run(
                        () => action == 'edit'
                            ? category(existing: row)
                            : removeCategory(row),
                      ),
                      itemBuilder: (c) => [
                        PopupMenuItem(value: 'edit', child: Text(c.tr('edit'))),
                        PopupMenuItem(
                          value: 'remove',
                          child: Text(
                            c.tr(
                              row['archived'] == true ? 'restore' : 'delete',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
              if (section == 'budgets') ...[
                SizedBox(
                  key: anchors['add'],
                  child: action(
                    'finance-add-budget',
                    'fpBudget',
                    () => run(() => budget()),
                  ),
                ),
                Text(c.tr('fpBudgetScope')),
                for (final row in FinancePlanning.budgets(current.data, month))
                  if (row['month'] == month)
                    InkWell(
                      onTap: busy ? null : () => run(() => budget(old: row)),
                      child: progress(
                        row['category'] == ''
                            ? c.tr('fpAllCategories')
                            : row['category'],
                        FinancePlanning.spent(
                          current.data,
                          month,
                          row['category'],
                          today,
                        ),
                        row['amount'],
                        budgetWarning: true,
                      ),
                    ),
              ],
              if (section == 'goals') ...[
                SizedBox(
                  key: anchors['add'],
                  child: action(
                    'finance-add-goal',
                    'fpGoal',
                    () => run(() => goal()),
                  ),
                ),
                Text(c.tr('fpGoalBalanceInfo')),
                SwitchListTile(
                  key: const Key('finance-show-archived-goals'),
                  title: Text(c.tr('fpShowArchivedGoals')),
                  value: archivedGoals,
                  onChanged: (v) => setState(() => archivedGoals = v),
                ),
                for (final g in data['goals'])
                  if (archivedGoals || g['archived'] != true)
                    Column(
                      children: [
                        InkWell(
                          onTap: busy ? null : () => run(() => goal(old: g)),
                          child: progress(
                            g['name'],
                            FinancePlanning.goalProgress(
                              current.data,
                              g,
                              today,
                            ),
                            g['target'],
                            subtitle: g['deadline'],
                          ),
                        ),
                        TextButton(
                          onPressed: busy
                              ? null
                              : () => run(() async {
                                  if (!await permitted()) return;
                                  final old = current;
                                  await save(
                                    FinancePlanning.change(old.data, (p) {
                                      for (final row in p['goals']) {
                                        if (row['id'] == g['id']) {
                                          row['archived'] =
                                              g['archived'] != true;
                                        }
                                      }
                                    }),
                                    old,
                                  );
                                }),
                          child: Text(
                            c.tr(g['archived'] == true ? 'restore' : 'archive'),
                          ),
                        ),
                      ],
                    ),
              ],
              if (section == 'recurring') ...[
                SizedBox(
                  key: anchors['add'],
                  child: action(
                    'finance-add-recurring',
                    'fpRecurring',
                    () => run(() => recurring()),
                  ),
                ),
                Text(c.tr('fpPostExplain')),
                for (final r in data['recurring'])
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(r['name']),
                          TextButton(
                            onPressed: busy
                                ? null
                                : () => run(() => recurring(old: r)),
                            child: Text(c.tr('edit')),
                          ),
                          Text(
                            '${moneyText(r['amount'], currency)} · ${c.tr('fp${r['frequency']}')}',
                          ),
                          Text(
                            FinancePlanning.occurrence(r) ??
                                c.tr('fpCompleted'),
                          ),
                          if (r['active'] == true &&
                              FinancePlanning.occurrence(r) != null &&
                              FinancePlanning.occurrence(r)!.compareTo(today) <=
                                  0)
                            Wrap(
                              spacing: 8,
                              children: [
                                FilledButton(
                                  key: Key('finance-post-${r['id']}'),
                                  onPressed: busy
                                      ? null
                                      : () => run(() => post(r, false)),
                                  child: Text(c.tr('fpConfirmOccurrence')),
                                ),
                                TextButton(
                                  onPressed: busy
                                      ? null
                                      : () => run(() => post(r, true)),
                                  child: Text(c.tr('fpSkipOccurrence')),
                                ),
                              ],
                            ),
                          TextButton(
                            onPressed:
                                busy || FinancePlanning.occurrence(r) == null
                                ? null
                                : () => run(() async {
                                    if (!await permitted()) return;
                                    final old = current;
                                    await save(
                                      FinancePlanning.change(old.data, (p) {
                                        for (final row in p['recurring']) {
                                          if (row['id'] == r['id']) {
                                            row['active'] = r['active'] != true;
                                          }
                                        }
                                      }),
                                      old,
                                    );
                                  }),
                            child: Text(
                              c.tr(
                                FinancePlanning.occurrence(r) == null
                                    ? 'fpCompleted'
                                    : r['active'] == true
                                    ? 'fpPause'
                                    : 'fpResume',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
              if (section == 'debts') ...[
                Text(c.tr('fpDebtInfo')),
                Text(c.tr('fpReminderOneTime')),
                for (final debt in current.data['entries'])
                  if ({'lent', 'borrowed'}.contains(debt['type']) &&
                      debt['void'] != true &&
                      Ledger.outstanding(
                            current.data,
                            debt,
                            throughDate: today,
                          ) >
                          0)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${debt['description']} · ${moneyText(Ledger.outstanding(current.data, debt, throughDate: today), currency)}',
                            ),
                            Text(
                              '${c.tr('fpDeadline')}: ${(data['debts'] as Map)[debt['id']]?['date'] ?? c.tr('fpNotSet')}',
                            ),
                            Wrap(
                              spacing: 8,
                              children: [
                                TextButton(
                                  key: debt['id'] == guidedDebt
                                      ? anchors['add']
                                      : null,
                                  onPressed: busy
                                      ? null
                                      : () => run(() => deadline(debt)),
                                  child: Text(c.tr('fpDebtDeadline')),
                                ),
                                TextButton(
                                  onPressed: busy
                                      ? null
                                      : () => run(() => debtReminder(debt)),
                                  child: Text(c.tr('haReminder')),
                                ),
                                if ((data['debts']
                                        as Map)[debt['id']]?['minute'] !=
                                    null)
                                  TextButton(
                                    onPressed: busy
                                        ? null
                                        : () => run(() async {
                                            if (!await permitted()) return;
                                            final old = current;
                                            await save(
                                              FinancePlanning.change(
                                                old.data,
                                                (p) =>
                                                    (p['debts']
                                                            as Map)[debt['id']]['minute'] =
                                                        null,
                                              ),
                                              old,
                                            );
                                          }),
                                    child: Text(c.tr('fpDisableReminder')),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                const ModuleReminderStatus(),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
