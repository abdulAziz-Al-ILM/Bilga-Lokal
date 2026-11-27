import 'package:flutter/material.dart';

import '../../core/dialogs.dart';
import '../../core/strings.dart';
import '../private_space/record_store.dart';
import 'finance_analytics.dart';
import 'ledger.dart';

class FinanceReportsPage extends StatefulWidget {
  final PrivateRecord ledger;
  final RecordStore? store;
  const FinanceReportsPage({super.key, required this.ledger, this.store});
  @override
  State<FinanceReportsPage> createState() => _ReportsState();
}

class _ReportsState extends State<FinanceReportsPage> {
  late PrivateRecord ledger = widget.ledger;
  late DateTimeRange range;
  late FinanceAnalytics report;
  String grouping = 'daily';
  int? selected;
  bool busy = false;
  String get currency => ledger.data['currency'] as String;
  String day(DateTime value) => value.toIso8601String().substring(0, 10);
  @override
  void initState() {
    super.initState();
    final now = DateUtils.dateOnly(DateTime.now());
    range = DateTimeRange(start: DateTime(now.year, now.month), end: now);
    calculate();
  }

  void calculate() {
    report = FinanceAnalytics.calculate(
      ledger.data,
      from: day(range.start),
      through: day(range.end),
    );
    selected = null;
  }

  void preset(String value) {
    final today = DateUtils.dateOnly(DateTime.now());
    final first = switch (value) {
      'week' => DateTime(
        today.year,
        today.month,
        today.day - today.weekday + 1,
      ),
      'year' => DateTime(today.year, today.month - 11),
      _ => DateTime(today.year, today.month),
    };
    setState(() {
      range = DateTimeRange(start: first, end: today);
      calculate();
    });
  }

  Future<void> custom() async {
    final next = await showDateRangePicker(
      context: context,
      firstDate: DateTime(1),
      lastDate: DateUtils.dateOnly(DateTime.now()),
      initialDateRange: range,
    );
    if (next == null || !mounted) return;
    try {
      final computed = FinanceAnalytics.calculate(
        ledger.data,
        from: day(next.start),
        through: day(next.end),
      );
      setState(() {
        range = next;
        report = computed;
        selected = null;
      });
    } catch (_) {
      if (mounted) showError(context, 'fReportRangeError');
    }
  }

  Future<void> reload() async {
    setState(() => busy = true);
    try {
      final current = (await (widget.store ?? RecordStore()).all('finance'))
          .where((row) => row.id == ledger.id)
          .first;
      final computed = FinanceAnalytics.calculate(
        current.data,
        from: day(range.start),
        through: day(range.end),
      );
      if (mounted) {
        setState(() {
          ledger = current;
          report = computed;
          selected = null;
        });
      }
    } catch (_) {
      if (mounted) showError(context);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  String bucketTitle(FinanceBucket bucket) => bucket.date.length == 7
      ? MaterialLocalizations.of(context)
            .formatMonthYear(DateTime.parse('${bucket.date}-01'))
      : MaterialLocalizations.of(context)
            .formatFullDate(DateTime.parse(bucket.date));
  Widget total(String key, int amount) => Padding(
    key: ValueKey('finance-report-total-$key'),
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.tr(key)),
        Text(
          moneyText(amount, currency),
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ],
    ),
  );
  String bucketText(FinanceBucket value) => [
    '${context.tr('xincome')}: ${moneyText(value.income, currency)}',
    '${context.tr('xexpense')}: ${moneyText(value.expenses, currency)}',
    '${context.tr('fReportCashFlow')}: ${moneyText(value.cashChange, currency)}',
    '${context.tr('fReportOtherCash')}: ${moneyText(value.cashChange - value.surplus, currency)}',
    if (value.openings != 0)
      '${context.tr('fReportOpeningChanges')}: ${moneyText(value.openings, currency)}',
  ].join('\n');
  @override
  Widget build(BuildContext context) {
    final buckets = switch (grouping) {
      'weekly' => report.grouped(weekly: true),
      'monthly' => report.grouped(weekly: false),
      _ => report.daily,
    };
    final categories = report.categories.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('xReport')),
        actions: [
          IconButton(
            tooltip: context.tr('retry'),
            onPressed: busy ? null : reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            '${ledger.data['title']} · $currency',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          Text(
            '${MaterialLocalizations.of(context).formatFullDate(range.start)} – ${MaterialLocalizations.of(context).formatFullDate(range.end)}',
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final value in ['week', 'month', 'year'])
                OutlinedButton(
                  key: ValueKey('finance-report-$value'),
                  onPressed: busy ? null : () => preset(value),
                  child: Text(
                    context.tr(switch (value) {
                      'week' => 'fReportThisWeek',
                      'year' => 'fReportLastYear',
                      _ => 'fReportThisMonth',
                    }),
                  ),
                ),
              OutlinedButton(
                key: const Key('finance-report-custom'),
                onPressed: busy ? null : custom,
                child: Text(context.tr('fReportCustom')),
              ),
            ],
          ),
          total('fReportStartBalance', report.openingBalance),
          total('fReportEndBalance', report.closingBalance),
          total('xincome', report.income),
          total('xexpense', report.expenses),
          total('fReportSurplus', report.surplus),
          total('fReportCashFlow', report.cashChange),
          total('fReportOtherCash', report.otherCashChange),
          total('fReportOpeningChanges', report.recognizedOpenings),
          Text(context.tr('fReportInfo')),
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final value in ['daily', 'weekly', 'monthly'])
                ChoiceChip(
                  key: ValueKey('finance-report-group-$value'),
                  label: Text(
                    context.tr(switch (value) {
                      'weekly' => 'fReportWeekly',
                      'monthly' => 'fReportMonthly',
                      _ => 'fReportDaily',
                    }),
                  ),
                  selected: grouping == value,
                  onSelected: busy
                      ? null
                      : (_) => setState(() {
                          grouping = value;
                          selected = null;
                        }),
                ),
            ],
          ),
          Semantics(
            key: const Key('finance-report-chart'),
            label: context.tr('fReportCashFlow'),
            child: SizedBox(
              height: 180,
              child: LayoutBuilder(
                builder: (c, size) => GestureDetector(
                  onTapDown: (event) => setState(
                    () => selected = buckets.length == 1
                        ? 0
                        : ((event.localPosition.dx - 8) /
                                  (size.maxWidth - 16) *
                                  (buckets.length - 1))
                              .round()
                              .clamp(0, buckets.length - 1),
                  ),
                  child: CustomPaint(
                    painter: _CashPainter(
                      buckets,
                      Theme.of(c).colorScheme.primary,
                      Theme.of(c).colorScheme.outlineVariant,
                      selected,
                    ),
                    size: Size.infinite,
                  ),
                ),
              ),
            ),
          ),
          if (selected != null && selected! < buckets.length)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SelectableText(
                  '${bucketTitle(buckets[selected!])}\n${bucketText(buckets[selected!])}',
                ),
              ),
            ),
          Text(
            context.tr('xCategory'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          if (categories.isEmpty) Text(context.tr('empty')),
          for (final item in categories)
            ListTile(
              title: Text(
                item.key.isEmpty
                    ? context.tr('fReportUncategorized')
                    : item.key,
              ),
              subtitle: Text(moneyText(item.value, currency)),
            ),
          const Divider(),
          for (var index = 0; index < buckets.length; index++)
            ListTile(
              key: ValueKey('finance-report-bucket-$index'),
              title: Text(bucketTitle(buckets[index])),
              subtitle: Text(bucketText(buckets[index])),
              selected: selected == index,
              onTap: () => setState(() => selected = index),
            ),
        ],
      ),
    );
  }
}

class _CashPainter extends CustomPainter {
  final List<FinanceBucket> values;
  final Color color, axis;
  final int? selected;
  _CashPainter(this.values, this.color, this.axis, this.selected);
  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty || size.width <= 16 || size.height <= 16) return;
    var maximum = 1;
    for (final value in values) {
      if (value.cashChange.abs() > maximum) maximum = value.cashChange.abs();
    }
    final middle = size.height / 2;
    canvas.drawLine(
      Offset(8, middle),
      Offset(size.width - 8, middle),
      Paint()
        ..color = axis
        ..strokeWidth = 1,
    );
    final points = [
      for (var index = 0; index < values.length; index++)
        Offset(
          values.length == 1
              ? size.width / 2
              : 8 + (size.width - 16) * index / (values.length - 1),
          middle - values[index].cashChange / maximum * (middle - 8),
        ),
    ];
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke,
    );
    if (points.length < 40) {
      for (final point in points) {
        canvas.drawCircle(point, 2, Paint()..color = color);
      }
    }
    if (selected != null && selected! < points.length) {
      canvas.drawCircle(points[selected!], 5, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(_CashPainter old) =>
      old.values != values ||
      old.color != color ||
      old.axis != axis ||
      old.selected != selected;
}
