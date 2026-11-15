import 'package:flutter/material.dart';

import '../../../core/strings.dart';
import 'reading_store.dart';

class ReadingStatisticsPage extends StatefulWidget {
  final ReadingStore store;
  const ReadingStatisticsPage({super.key, required this.store});
  @override
  State<ReadingStatisticsPage> createState() => _StatsState();
}

class _StatsState extends State<ReadingStatisticsPage> {
  late Future<List<Map<String, Object?>>> data = widget.store.activity();
  String period = 'month';
  late final completed = completedBooks();
  Future<List<String>> completedBooks() async =>
      (await (await widget.store.db).rawQuery(
            "SELECT json_extract(payload,'\$.library.finishedOn') AS day FROM private_records WHERE kind='book' AND json_extract(payload,'\$.library.status')='completed'",
          ))
          .map((r) => r['day'] as String? ?? '')
          .where((d) => DateTime.tryParse(d) != null)
          .toList();
  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: Text(c.tr('rStatistics'))),
    body: FutureBuilder(
      future: data,
      builder: (c, s) {
        if (s.hasError) {
          return Center(
            child: TextButton(
              onPressed: () => setState(() => data = widget.store.activity()),
              child: Text(c.tr('retry')),
            ),
          );
        }
        if (!s.hasData) return const Center(child: CircularProgressIndicator());
        final now = DateTime.now(),
            start = period == 'week'
                ? DateTime(now.year, now.month, now.day - 6)
                : period == 'month'
                ? DateTime(now.year, now.month, 1)
                : DateTime(now.year, 1, 1);
        final rows = s.data!
            .where((r) => !DateTime.parse(r['day'] as String).isBefore(start))
            .toList();
        final seconds = rows.fold<int>(
          0,
          (n, r) => n + (r['seconds'] as num).toInt(),
        );
        final sessions = rows.fold<int>(
          0,
          (n, r) => n + (r['sessions'] as num).toInt(),
        );
        final days = s.data!.map((r) => r['day']).toSet();
        var streak = 0;
        var day = DateTime(now.year, now.month, now.day);
        String key(DateTime d) => d.toIso8601String().substring(0, 10);
        if (!days.contains(key(day))) {
          day = DateTime(day.year, day.month, day.day - 1);
        }
        while (days.contains(key(day))) {
          streak++;
          day = DateTime(day.year, day.month, day.day - 1);
        }
        final max = rows.fold<int>(
          1,
          (n, r) => n > (r['seconds'] as int) ? n : r['seconds'] as int,
        );
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(c.tr('rSessionExplanation')),
            Wrap(
              spacing: 8,
              children: [
                for (final p in ['week', 'month', 'year'])
                  ChoiceChip(
                    label: Text(c.tr('rPeriod_$p')),
                    selected: period == p,
                    onSelected: (_) => setState(() => period = p),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              '${c.tr('rReadingTime')}: ${seconds ~/ 60} ${c.tr('htMinutes')}',
              style: Theme.of(c).textTheme.headlineSmall,
            ),
            Text(
              '${c.tr('rSessions')}: $sessions · ${c.tr('rReadingDays')}: ${rows.length} · ${c.tr('hStreak')}: $streak',
            ),
            FutureBuilder(
              future: completed,
              builder: (c, s) => Text(
                '${c.tr('rBooksCompleted')}: ${s.data?.where((d) => !DateTime.parse(d).isBefore(start)).length ?? 0}',
              ),
            ),
            if (rows.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(c.tr('rNoActivity')),
              ),
            for (final r in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${r['day']} · ${(r['seconds'] as int) ~/ 60} ${c.tr('htMinutes')} · ${r['sessions']} ${c.tr('rSessions')}',
                    ),
                    const SizedBox(height: 6),
                    LinearProgressIndicator(value: (r['seconds'] as int) / max),
                  ],
                ),
              ),
          ],
        );
      },
    ),
  );
}
