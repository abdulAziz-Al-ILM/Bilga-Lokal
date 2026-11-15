import 'package:flutter/material.dart';

import '../../../core/editor_form.dart';
import '../../../core/strings.dart';
import '../../attachments/attachment_store.dart';
import 'reading_data.dart';
import 'reading_store.dart';
import 'reading_links.dart';
import 'reading_templates.dart';
import '../../guidance/guide_controller.dart';
import '../../guidance/guide_host.dart';
import '../../habits/habit_templates.dart';
import '../../search/library_page.dart';
import '../../search/search_repository.dart';

String locationLabel(Map<String, dynamic>? l) => l == null
    ? ''
    : l['kind'] == 'pdf'
    ? '${l['page']}'
    : '${l['label'] ?? l['section']} · ${l['block'] + 1}';

Future<void> editReadingCard(
  BuildContext context,
  ReadingStore store,
  String book,
  bool Function() allowed, {
  ReadingRow? previous,
  String text = '',
  Map<String, dynamic>? location,
  String type = 'idea',
  VoidCallback? onSaved,
}) async {
  final chosen = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (c) => SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final t in ReadingData.cardTypes)
              ListTile(
                title: Text(c.tr('rCard_$t')),
                onTap: () => Navigator.pop(c, t),
              ),
          ],
        ),
      ),
    ),
  );
  if (chosen == null || !context.mounted) return;
  final old = previous?.data;
  await editFields(
    context,
    context.tr('rCard_$chosen'),
    {
      'front': context.tr(chosen == 'question' ? 'rQuestion' : 'title'),
      'back': context.tr(chosen == 'question' ? 'rAnswer' : 'rContent'),
      'explanation': context.tr('rExplanation'),
      'tags': context.tr('tags'),
    },
    initial: {
      'front': old?['front'] ?? '',
      'back': old?['back'] ?? text,
      'explanation': old?['explanation'] ?? '',
      'tags': (old?['tags'] as List? ?? []).join(', '),
    },
    multiline: {'back', 'explanation'},
    requiredFields: {'front', if (chosen == 'question') 'back'},
    onSave: (v) async {
      if (!allowed()) throw StateError('access_expired');
      await store.put(book, 'card', {
        'v': 1,
        'type': chosen,
        'front': v['front']!,
        'back': v['back']!,
        'explanation': v['explanation']!,
        'tags': v['tags']!
            .split(RegExp(r'[,،，\n]'))
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toSet()
            .toList(),
        if (old?['location'] ?? location case final Map<String, dynamic> l)
          'location': l,
        'box': old?['box'] ?? 0,
        'reviews': old?['reviews'] ?? 0,
        'due': old?['due'] ?? DateTime.now().toUtc().toIso8601String(),
      }, previous: previous);
      onSaved?.call();
    },
  );
}

class ReadingHub extends StatefulWidget {
  final ReadingStore store;
  final String book, title;
  final bool Function() allowed;
  final void Function(Map<String, dynamic>)? jump;
  const ReadingHub({
    super.key,
    required this.store,
    required this.book,
    required this.title,
    required this.allowed,
    this.jump,
  });
  @override
  State<ReadingHub> createState() => _HubState();
}

class _HubState extends State<ReadingHub> {
  String kind = 'bookmark', query = '';
  List<ReadingRow> rows = [];
  bool busy = false, failed = false, more = false;
  int generation = 0;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load({bool append = false}) async {
    final token = ++generation;
    try {
      final list = await widget.store.rows(
        widget.book,
        kind,
        limit: 50,
        offset: append ? rows.length : 0,
        query: query,
      );
      if (mounted && token == generation) {
        setState(() {
          rows = append ? [...rows, ...list] : list;
          more = list.length == 50;
          failed = false;
        });
      }
    } catch (_) {
      if (mounted && token == generation) setState(() => failed = true);
    }
  }

  Future<void> run(Future<void> Function() f) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await f();
    } catch (_) {
      if (mounted) failure(context);
    } finally {
      if (mounted) {
        setState(() => busy = false);
        await load();
      }
    }
  }

  Future<void> review() async {
    final cards = await widget.store.due(widget.book);
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FlashcardPage(
          store: widget.store,
          cards: cards,
          allowed: widget.allowed,
        ),
      ),
    );
  }

  Future<void> connect(ReadingRow row, String targetKind) async {
    final links = ReadingLinks(widget.store);
    var saved = await links.existing(widget.book, row.id, targetKind);
    if (saved == null || saved.data['state'] == 'pending') {
      if (!mounted || !widget.allowed()) return;
      final text =
          '${widget.title}\n${locationLabel(row.data['location'] is Map ? Map<String, dynamic>.from(row.data['location']) : null)}\n\n${row.data['back'] ?? row.data['text'] ?? ''}\n${row.data['note'] ?? ''}';
      await editFields(
        context,
        context.tr('rConnect_$targetKind'),
        {
          'title': context.tr('title'),
          'body': context.tr(
            targetKind == 'habit' ? 'rHabitReason' : 'rContent',
          ),
          if (targetKind == 'todo') 'due': context.tr('rGoalDate'),
        },
        initial: {
          'title': '${row.data['front'] ?? widget.title}',
          'body': targetKind == 'habit' ? widget.title : text,
        },
        multiline: {'body'},
        requiredFields: {'title'},
        dateFields: {if (targetKind == 'todo') 'due'},
        onSave: (v) async {
          saved = await links.create(
            book: widget.book,
            origin: row.id,
            kind: targetKind,
            title: v['title']!,
            body: v['body']!,
            due: DateTime.tryParse(v['due'] ?? ''),
            plan: targetKind == 'habit'
                ? habitTemplates
                      .firstWhere((t) => t.id == 'read')
                      .plan(context.tr)
                : null,
            allowed: widget.allowed,
          );
        },
      );
    }
    if (!mounted || saved == null) return;
    final s = saved!;
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => DocumentPage(
          hit: SearchHit(
            s.data['target'],
            targetKind,
            widget.title,
            '',
            s.updated,
            false,
          ),
          repository: SearchRepository(notesDb: widget.store.records.database),
          readOnly: !widget.allowed(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(
      title: Text(c.tr('rReadingNotes')),
      actions: [
        IconButton(
          key: const Key('reading-export'),
          tooltip: c.tr('xExport'),
          onPressed: busy
              ? null
              : () => run(() async {
                  await Attachments.export(
                    '${widget.title}.reading.json',
                    'application/json',
                    widget.store.export(widget.book, widget.title),
                  );
                }),
          icon: const Icon(Icons.ios_share),
        ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(c.tr('rNotesPurpose')),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final value in [
              'bookmark',
              'highlight',
              'annotation',
              'card',
              'review',
            ])
              ChoiceChip(
                key: ValueKey('reading-kind-$value'),
                label: Text(c.tr('rKind_$value')),
                selected: kind == value,
                onSelected: busy
                    ? null
                    : (_) {
                        setState(() {
                          kind = value;
                          rows = [];
                          more = false;
                        });
                        load();
                      },
              ),
          ],
        ),
        TextField(
          key: const Key('reading-notes-search'),
          autocorrect: false,
          enableSuggestions: false,
          enableIMEPersonalizedLearning: false,
          decoration: InputDecoration(labelText: c.tr('search')),
          onChanged: (s) {
            query = s;
            load();
          },
        ),
        if (kind == 'card') ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                key: const Key('reading-add-card'),
                onPressed: !widget.allowed() || busy
                    ? null
                    : () => run(
                        () => editReadingCard(
                          c,
                          widget.store,
                          widget.book,
                          widget.allowed,
                        ),
                      ),
                icon: const Icon(Icons.add),
                label: Text(c.tr('rAddCard')),
              ),
              OutlinedButton(
                key: const Key('reading-templates'),
                onPressed: busy || !widget.allowed()
                    ? null
                    : () => run(
                        () => useReadingTemplate(
                          c,
                          widget.store,
                          widget.book,
                          widget.title,
                          widget.allowed,
                        ),
                      ),
                child: Text(c.tr('rTemplates')),
              ),
              OutlinedButton(
                key: const Key('reading-review-due'),
                onPressed: busy ? null : () => run(review),
                child: Text(c.tr('rReviewDue')),
              ),
            ],
          ),
        ],
        if (failed) TextButton(onPressed: load, child: Text(c.tr('retry'))),
        if (rows.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(c.tr('rNoReadingNotes')),
          ),
        for (final r in rows)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${r.data['front'] ?? r.data['text'] ?? (kind == 'review' ? c.tr('rReviewDone') : '')}',
                    style: Theme.of(c).textTheme.titleMedium,
                  ),
                  if (r.data['back'] is String) Text(r.data['back']),
                  if (r.data['note'] is String && r.data['note'].isNotEmpty)
                    Text(r.data['note']),
                  if (r.data['explanation'] is String &&
                      r.data['explanation'].isNotEmpty)
                    Text(r.data['explanation']),
                  Text(
                    MaterialLocalizations.of(c)
                        .formatMediumDate(DateTime.parse(r.created).toLocal()),
                  ),
                  if (kind == 'card')
                    Text(
                      '${c.tr('rDue')}: ${MaterialLocalizations.of(c).formatShortDate(DateTime.parse(r.data['due']).toLocal())} · ${c.tr('rReviews')}: ${r.data['reviews']}',
                    ),
                  if (kind == 'review')
                    Text(
                      '${c.tr(['rAgain', 'rHard', 'rGood', 'rEasy'][r.data['rating'] as int])} · ${MaterialLocalizations.of(c).formatShortDate(DateTime.parse(r.data['at']).toLocal())} · ${c.tr('rNextReview')}: ${MaterialLocalizations.of(c).formatShortDate(DateTime.parse(r.data['next']).toLocal())}',
                    ),
                  if (r.data['location'] is Map)
                    Text(
                      locationLabel(
                        Map<String, dynamic>.from(r.data['location']),
                      ),
                    ),
                  Wrap(
                    spacing: 8,
                    children: [
                      if (r.data['location'] is Map && widget.jump != null)
                        TextButton(
                          key: ValueKey('reading-jump-${r.id}'),
                          onPressed: () {
                            Navigator.pop(c);
                            widget.jump!(
                              Map<String, dynamic>.from(r.data['location']),
                            );
                          },
                          child: Text(c.tr('rGoToSource')),
                        ),
                      if ({'card', 'highlight', 'annotation'}.contains(kind))
                        PopupMenuButton<String>(
                          tooltip: c.tr('rConnect'),
                          onSelected: (k) => run(() => connect(r, k)),
                          itemBuilder: (c) => [
                            for (final k in [
                              'note',
                              'todo',
                              'habit',
                              'experience',
                            ])
                              PopupMenuItem(
                                value: k,
                                child: Text(c.tr('rConnect_$k')),
                              ),
                          ],
                        ),
                      if (kind != 'review')
                        TextButton(
                          onPressed: busy || !widget.allowed()
                              ? null
                              : () => run(() async {
                                  if (kind == 'card') {
                                    await editReadingCard(
                                      c,
                                      widget.store,
                                      widget.book,
                                      widget.allowed,
                                      previous: r,
                                    );
                                  } else {
                                    await editFields(
                                      c,
                                      c.tr('rKind_$kind'),
                                      {'note': c.tr('notes')},
                                      initial: {'note': r.data['note']},
                                      multiline: {'note'},
                                      onSave: (v) async {
                                        if (!widget.allowed()) {
                                          throw StateError('access_expired');
                                        }
                                        await widget.store.put(
                                          widget.book,
                                          kind,
                                          {...r.data, 'note': v['note']!},
                                          previous: r,
                                        );
                                      },
                                    );
                                  }
                                }),
                          child: Text(c.tr('edit')),
                        ),
                      if (kind != 'review')
                        TextButton(
                          onPressed: busy || !widget.allowed()
                              ? null
                              : () => run(() async {
                                  if (await consent(c, c.tr('delete')) &&
                                      widget.allowed()) {
                                    await widget.store.remove(r);
                                  }
                                }),
                          child: Text(c.tr('delete')),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        if (more)
          TextButton(
            onPressed: busy ? null : () => load(append: true),
            child: Text(c.tr('rLoadMore')),
          ),
      ],
    ),
  );
}

class FlashcardPage extends StatefulWidget {
  final ReadingStore store;
  final List<ReadingRow> cards;
  final bool Function() allowed;
  const FlashcardPage({
    super.key,
    required this.store,
    required this.cards,
    required this.allowed,
  });
  @override
  State<FlashcardPage> createState() => _FlashState();
}

class _FlashState extends State<FlashcardPage> {
  final flipAnchor = GlobalKey(), ratingsAnchor = GlobalKey();
  final guide = GuideController(
    id: 'book.review',
    steps: const [
      GuideStep('flip', 'flip', 'rGuideFlip', event: 'flipped'),
      GuideStep('rate', 'rating', 'rGuideRate', event: 'rated'),
    ],
  );
  void guideChanged() {
    if (mounted && guide.active && guide.step.id == 'flip' && flipped) {
      setState(() => flipped = false);
    }
  }

  @override
  void initState() {
    super.initState();
    guide.addListener(guideChanged);
  }

  @override
  void dispose() {
    guide.removeListener(guideChanged);
    guide.dispose();
    super.dispose();
  }

  int index = 0;
  bool flipped = false, busy = false;
  Future<void> rate(int n) async {
    if (busy || !widget.allowed()) return;
    setState(() => busy = true);
    try {
      await widget.store.review(widget.cards[index], n);
      guide.event('rated');
      if (mounted) {
        setState(() {
          index++;
          flipped = false;
        });
      }
    } catch (_) {
      if (mounted) failure(context);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext c) => GuideHost(
    controller: guide,
    targets: {'flip': flipAnchor, 'rating': ratingsAnchor},
    child: Scaffold(
      appBar: AppBar(
        title: Text(c.tr('rReviewDue')),
        actions: [
          IconButton(
            tooltip: c.tr('rHelp'),
            onPressed: index >= widget.cards.length
                ? null
                : () {
                    setState(() => flipped = false);
                    guide.start();
                  },
            icon: const Icon(Icons.help_outline),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(c.tr('rScheduleExplanation')),
          const SizedBox(height: 20),
          if (index >= widget.cards.length)
            Text(c.tr('rReviewFinished'))
          else ...[
            Text('${index + 1} / ${widget.cards.length}'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: SelectableText(
                  flipped
                      ? widget.cards[index].data['back']
                      : widget.cards[index].data['front'],
                  style: Theme.of(c).textTheme.headlineSmall,
                ),
              ),
            ),
            if (!flipped)
              FilledButton(
                key: flipAnchor,
                onPressed: () {
                  setState(() => flipped = true);
                  guide.event('flipped');
                },
                child: Text(
                  c.tr('rShowAnswer'),
                  key: const Key('flashcard-flip'),
                ),
              ),
            if (flipped)
              Wrap(
                key: ratingsAnchor,
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var i = 0; i < 4; i++)
                    FilledButton(
                      key: ValueKey('flashcard-rate-$i'),
                      onPressed: busy || !widget.allowed()
                          ? null
                          : () => rate(i),
                      child: Text(
                        c.tr(['rAgain', 'rHard', 'rGood', 'rEasy'][i]),
                      ),
                    ),
                ],
              ),
          ],
        ],
      ),
    ),
  );
}
