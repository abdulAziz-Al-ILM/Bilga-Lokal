import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/strings.dart';
import '../../core/editor_form.dart';
import '../agent/agent_access.dart';
import '../agent/purchase_panel.dart';
import '../attachments/attachment_store.dart';
import '../guidance/guide_controller.dart';
import '../guidance/guide_host.dart';
import '../private_space/record_store.dart';
import '../private_space/space_page.dart' show RecordPage;
import 'book_details_editor.dart';
import 'book_library.dart';
import 'book_library_store.dart';
import 'reading/book_cover.dart';
import 'reading/book_importer.dart';
import 'reading/reading_errors.dart';
import 'reading/book_reading_page.dart';
import 'reading/reading_hub.dart';
import 'reading/reading_store.dart';
import 'reading/reading_statistics_page.dart';

class BookLibraryPage extends StatefulWidget {
  final RecordStore? records;
  final BookLibraryStore? library;
  final AgentAccess? access;
  final bool tutorial;
  final ReadingStore? reading;
  final Future<List<Map<String, dynamic>>> Function()? picker;
  final Future<ImportCandidate> Function(Map<String, dynamic>)? prepareImport;
  const BookLibraryPage({
    super.key,
    this.records,
    this.library,
    this.access,
    this.tutorial = false,
    this.reading,
    this.picker,
    this.prepareImport,
  });
  @override
  State<BookLibraryPage> createState() => _LibraryState();
}

class _LibraryState extends State<BookLibraryPage> {
  late final BookLibraryStore store =
      widget.library ?? BookLibraryStore(records: widget.records);
  late final ReadingStore reading =
      widget.reading ?? ReadingStore(records: store.records);
  AgentAccess get access => widget.access ?? AgentAccess.instance;
  final search = TextEditingController();
  List<BookSummary> books = [], current = [];
  Map<String, List<String>> choices = {};
  String status = 'all', shelf = '', tag = '', category = '', sort = 'opened';
  bool favorites = false,
      loading = false,
      acting = false,
      failed = false,
      more = false,
      grid = false;
  String? importError, guidedBook;
  int generation = 0;
  Timer? debounce;
  final addKey = GlobalKey(), readKey = GlobalKey(), organizeKey = GlobalKey();
  GuideController guide = GuideController(
    id: 'book.import',
    steps: const [
      GuideStep('add', 'add', 'rGuideImport', event: 'pickerOpened'),
      GuideStep('choose', 'add', 'rGuideChoose', event: 'imported'),
      GuideStep(
        'read',
        'read',
        'rGuideRead',
        event: 'readerOpened',
        backBoundary: true,
      ),
    ],
  );
  @override
  void initState() {
    super.initState();
    load(refreshFilters: true);
    if (widget.tutorial) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) guide.start();
      });
    }
  }

  @override
  void dispose() {
    debounce?.cancel();
    search.dispose();
    guide.dispose();
    super.dispose();
  }

  Future<void> load({bool append = false, bool refreshFilters = false}) async {
    final token = ++generation;
    setState(() => loading = true);
    try {
      final filters = refreshFilters ? await store.filters() : choices;
      if (!mounted) return;
      if (token != generation) {
        if (refreshFilters) {
          setState(() => choices = filters);
          unawaited(load());
        }
        return;
      }
      final sh = (filters['shelves'] ?? []).contains(shelf) ? shelf : '';
      final tg = (filters['tags'] ?? []).contains(tag) ? tag : '';
      final cat = (filters['categories'] ?? []).contains(category)
          ? category
          : '';
      final rows = await store.page(
        query: search.text,
        status: status == 'all' ? null : status,
        favoritesOnly: favorites,
        shelf: sh.isEmpty ? null : sh,
        tag: tg.isEmpty ? null : tg,
        category: cat.isEmpty ? null : cat,
        sort: sort,
        offset: append ? books.length : 0,
        limit: 51,
      );
      final ongoing = await store.page(
        status: 'reading',
        sort: 'opened',
        limit: 6,
      );
      if (!mounted || token != generation) return;
      final ids = append ? books.map((b) => b.id).toSet() : <String>{};
      setState(() {
        choices = filters;
        shelf = sh;
        tag = tg;
        category = cat;
        books = [
          if (append) ...books,
          ...rows.take(50).where((b) => ids.add(b.id)),
        ];
        current = ongoing;
        more = rows.length > 50;
        loading = false;
        failed = false;
      });
    } catch (_) {
      if (mounted && token == generation) {
        setState(() {
          failed = true;
          loading = false;
        });
      }
    }
  }

  Future<bool> allowed() async {
    if (access.has(AgentAccess.core)) return true;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => PurchasePanel(product: AgentAccess.core, access: access),
    );
    return access.has(AgentAccess.core);
  }

  Future<void> action(Future<void> Function() task) async {
    if (acting || loading) return;
    setState(() => acting = true);
    try {
      await task();
    } catch (e) {
      if (mounted) {
        setState(
          () => importError =
              '${context.tr('rImportFailed')}\n${readingError(context, e)}',
        );
      }
    } finally {
      if (mounted) {
        setState(() => acting = false);
        await load(refreshFilters: true);
      }
    }
  }

  Future<void> importBook({bool reference = false, bool sample = false}) async {
    if (!await allowed() || !mounted) return;
    final importer = BookImporter(reading);
    ImportCandidate? candidate;
    String? uri;
    try {
      if (sample) {
        final confirm = await consent(context, context.tr('rSamplePreview'));
        if (!confirm || !mounted) return;
        candidate = await importer.prepare(
          Stream.value(utf8.encode(context.tr('rSampleBody'))),
          '${context.tr('rSampleTitle')}.txt',
        );
      } else {
        guide.event('pickerOpened');
        final items = await (widget.picker?.call() ?? BookImporter.pick());
        if (items.isEmpty) {
          guide.exit();
          return;
        }
        uri = items.first['uri'];
        candidate =
            await (widget.prepareImport?.call(items.first) ??
                importer.prepare(
                  Attachments.uriStream(uri!),
                  items.first['name'] ?? 'Book',
                ));
      }
      if (!mounted) return;
      if ({'fb2', 'html'}.contains(candidate.format)) {
        if (!await consent(context, context.tr('rPartialFormat')) || !mounted) {
          return;
        }
      }
      final duplicates = await reading.duplicates(candidate.hash);
      if (!mounted) return;
      if (duplicates.isNotEmpty) {
        final result = await showDialog<String>(
          context: context,
          builder: (c) => AlertDialog(
            title: Text(c.tr('rDuplicate')),
            content: Text(
              '${duplicates.first['title']}\n\n${c.tr('rDuplicateExplain')}',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c, 'cancel'),
                child: Text(c.tr('cancel')),
              ),
              TextButton(
                key: const Key('book-import-another'),
                onPressed: () => Navigator.pop(c, 'another'),
                child: Text(c.tr('rAnotherCopy')),
              ),
              FilledButton(
                key: const Key('book-import-existing'),
                onPressed: () => Navigator.pop(c, 'open'),
                child: Text(c.tr('rOpenExisting')),
              ),
            ],
          ),
        );
        if (result == null || result == 'cancel') {
          guide.exit();
          return;
        }
        if (result == 'open') {
          final existing = await store.records.get(
            duplicates.first['id'] as String,
          );
          guide.exit();
          await openRecord(existing);
          return;
        }
      }
      final book = await importer.commit(
        candidate,
        referenceUri: reference ? uri : null,
        allowed: () => access.has(AgentAccess.core),
      );
      if (!mounted) return;
      if (guide.active) {
        guidedBook = book.id;
        search.clear();
        status = 'all';
        favorites = false;
        shelf = tag = category = '';
        sort = 'updated';
        await load(refreshFilters: true);
        guide.event('imported');
      } else {
        await openRecord(book);
      }
    } finally {
      await candidate?.close();
    }
  }

  Future<void> create() async {
    if (!await allowed() || !mounted) return;
    PrivateRecord? created;
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => BookDetailsEditor(
          initial: BookLibrary.update(
            {'title': '', 'chapters': <dynamic>[], 'characters': ''},
            {'status': 'planned'},
          ),
          onSave: (data) async {
            if (!access.has(AgentAccess.core)) {
              throw StateError('access_expired');
            }
            created = await store.records.save('book', data);
          },
        ),
      ),
    );
    if (created != null && mounted) await details(created!);
  }

  Future<void> details(PrivateRecord book) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => RecordPage(book, store: store.records, access: access),
      ),
    );
  }

  Future<void> openRecord(PrivateRecord record) async {
    if (!mounted) return;
    final source = await reading.one(record.id, 'source');
    if (!mounted) return;
    if (source != null) {
      guide.event('readerOpened');
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) =>
              BookReadingPage(book: record, store: reading, access: access),
        ),
      );
    } else {
      await details(record);
    }
  }

  Future<void> open(BookSummary book) async =>
      openRecord(await store.load(book.id));
  Future<void> favorite(BookSummary book) async {
    if (!await allowed()) return;
    final record = await store.load(book.id);
    if (record.revision != book.revision || !access.has(AgentAccess.core)) {
      throw StateError('book_changed');
    }
    await store.records.save(
      'book',
      BookLibrary.update(record.data, {'favorite': !book.favorite}),
      previous: record,
    );
  }

  Future<void> help() async {
    final result = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(c.tr('rHelp')),
        content: SingleChildScrollView(
          child: Text('${c.tr('rLibraryPurpose')}\n\n${c.tr('rHelpText')}'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: Text(c.tr('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, 'organize'),
            child: Text(c.tr('rOrganize')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, 'continue'),
            child: Text(c.tr('rContinue')),
          ),
          FilledButton(
            key: const Key('book-guide-start'),
            onPressed: () => Navigator.pop(c, 'start'),
            child: Text(c.tr('gShowMe')),
          ),
        ],
      ),
    );
    if (result == null || !mounted) return;
    guide.dispose();
    setState(() {
      guidedBook = null;
      final steps = result == 'organize'
          ? const [
              GuideStep(
                'open',
                'organize',
                'rGuideOrganize',
                event: 'organizeOpened',
              ),
              GuideStep('choose', 'organize', 'rGuideOrganize'),
            ]
          : result == 'continue'
          ? const [
              GuideStep('read', 'read', 'rContinueHelp', event: 'readerOpened'),
            ]
          : const [
              GuideStep('add', 'add', 'rGuideImport', event: 'pickerOpened'),
              GuideStep('choose', 'add', 'rGuideChoose', event: 'imported'),
              GuideStep(
                'read',
                'read',
                'rGuideRead',
                event: 'readerOpened',
                backBoundary: true,
              ),
            ];
      if (result == 'continue') {
        guidedBook =
            current.where((b) => b.format != null).firstOrNull?.id ??
            books.where((b) => b.format != null).firstOrNull?.id;
      }
      guide = GuideController(id: 'book.$result', steps: steps);
      guide.start();
    });
  }

  Widget filter(
    String field,
    String selected,
    String label,
    ValueChanged<String> change,
  ) => DropdownButtonFormField<String>(
    key: ValueKey('book-filter-$field-$selected'),
    initialValue: selected,
    isExpanded: true,
    decoration: InputDecoration(labelText: context.tr(label)),
    items: [
      DropdownMenuItem(value: '', child: Text(context.tr('bAllBooks'))),
      for (final value in choices[field] ?? [])
        DropdownMenuItem(
          value: value,
          child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
    ],
    onChanged: acting
        ? null
        : (v) {
            setState(() => change(v!));
            load();
          },
  );
  Widget tile(BookSummary book, {bool compact = false}) {
    final color = Theme.of(context).colorScheme;
    final progress =
        book.progress ??
        (book.pages == null || book.pages == 0
            ? 0
            : book.currentPage / book.pages!);
    final label = book.format == null
        ? context.tr('rDetails')
        : context.tr(book.opened == null ? 'rRead' : 'rContinue');
    final read = FilledButton.tonal(
      key: ValueKey(
        '${compact ? 'book-current-read' : 'book-library-read'}-${book.id}',
      ),
      onPressed: acting || loading ? null : () => action(() => open(book)),
      child: Text(label),
    );
    return Card(
      child: InkWell(
        key: ValueKey(
          '${compact ? 'book-current-row' : 'book-library-row'}-${book.id}',
        ),
        onTap: acting || loading ? null : () => action(() => open(book)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  BookCover(
                    key: ValueKey('cover-${book.id}'),
                    blob: book.cover,
                    vault: reading.vault,
                    width: compact ? 48 : 64,
                    height: compact ? 68 : 90,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          book.title,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        if (book.author.isNotEmpty)
                          Text(
                            book.author,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        Text(
                          [
                            context.tr('bStatus${book.status}'),
                            if (book.format != null) book.format!.toUpperCase(),
                          ].join(' · '),
                          style: TextStyle(color: color.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  if (!compact)
                    PopupMenuButton<String>(
                      onSelected: (v) => action(() async {
                        if (v == 'details') {
                          await details(await store.load(book.id));
                        }
                        if (v == 'notes' && mounted) {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ReadingHub(
                                store: reading,
                                book: book.id,
                                title: book.title,
                                allowed: () => access.has(AgentAccess.core),
                              ),
                            ),
                          );
                        }
                        if (v == 'favorite') await favorite(book);
                      }),
                      itemBuilder: (c) => [
                        PopupMenuItem(
                          value: 'details',
                          child: Text(c.tr('rAdvancedDetails')),
                        ),
                        PopupMenuItem(
                          value: 'notes',
                          child: Text(c.tr('rReadingNotes')),
                        ),
                        PopupMenuItem(
                          value: 'favorite',
                          child: Text(c.tr('favorites')),
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 10),
              if (book.format != null || book.pages != null) ...[
                LinearProgressIndicator(value: progress.clamp(0, 1)),
                const SizedBox(height: 6),
                Text(
                  book.format == 'pdf'
                      ? '${context.tr('rPage')} ${book.currentPage} / ${book.pages ?? '?'} · ${(progress * 100).toStringAsFixed(1)}%'
                      : '${(progress * 100).toStringAsFixed(1)}%',
                ),
              ],
              if (book.opened != null)
                Text(
                  '${context.tr('rLastOpened')}: ${MaterialLocalizations.of(context).formatShortDate(DateTime.parse(book.opened!).toLocal())}',
                ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (guidedBook == book.id)
                    Container(key: readKey, child: read)
                  else
                    read,
                  if (!compact)
                    IconButton(
                      tooltip: context.tr('favorites'),
                      onPressed: acting || loading
                          ? null
                          : () => action(() => favorite(book)),
                      icon: Icon(
                        book.favorite ? Icons.star : Icons.star_border,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext c) => GuideHost(
    controller: guide,
    targets: {'add': addKey, 'read': readKey, 'organize': organizeKey},
    child: Scaffold(
      appBar: AppBar(
        title: Text(c.tr('xBooks')),
        actions: [
          IconButton(
            key: const Key('book-help'),
            tooltip: c.tr('rHelp'),
            onPressed: acting ? null : help,
            icon: const Icon(Icons.help_outline),
          ),
          IconButton(
            key: const Key('book-statistics'),
            tooltip: c.tr('rStatistics'),
            onPressed: acting
                ? null
                : () => action(() async {
                    await Navigator.push(
                      c,
                      MaterialPageRoute(
                        builder: (_) => ReadingStatisticsPage(store: reading),
                      ),
                    );
                  }),
            icon: const Icon(Icons.insights_outlined),
          ),
          IconButton(
            key: const Key('book-view-toggle'),
            tooltip: c.tr('rViewToggle'),
            onPressed: () => setState(() => grid = !grid),
            icon: Icon(
              grid ? Icons.view_list_outlined : Icons.grid_view_outlined,
            ),
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    c.tr('rLibraryPurpose'),
                    style: Theme.of(c).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Container(
                        key: addKey,
                        child: FilledButton.icon(
                          key: const Key('book-library-add'),
                          onPressed: acting || loading
                              ? null
                              : () => action(() => importBook()),
                          icon: const Icon(Icons.file_open_outlined),
                          label: Text(c.tr('rImportBook')),
                        ),
                      ),
                      if (books.isEmpty && !loading)
                        OutlinedButton(
                          key: const Key('book-library-sample'),
                          onPressed: acting
                              ? null
                              : () => action(() => importBook(sample: true)),
                          child: Text(c.tr('rTrySample')),
                        ),
                      OutlinedButton(
                        key: const Key('book-library-learn'),
                        onPressed: acting ? null : help,
                        child: Text(c.tr('rHowRead')),
                      ),
                    ],
                  ),
                  if (importError != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        importError!,
                        style: TextStyle(color: Theme.of(c).colorScheme.error),
                      ),
                    ),
                  if (acting || loading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: LinearProgressIndicator(),
                    ),
                ],
              ),
            ),
          ),
          if (current.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.tr('rCurrentlyReading'),
                      style: Theme.of(c).textTheme.titleLarge,
                    ),
                    for (final book in current.take(3))
                      if (guidedBook != book.id) tile(book, compact: true),
                  ],
                ),
              ),
            ),
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    c.tr('rMyLibrary'),
                    style: Theme.of(c).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    key: const Key('book-library-search'),
                    controller: search,
                    enabled: !acting,
                    autocorrect: false,
                    enableSuggestions: false,
                    enableIMEPersonalizedLearning: false,
                    decoration: InputDecoration(
                      labelText: c.tr('search'),
                      prefixIcon: const Icon(Icons.search),
                    ),
                    onChanged: (_) {
                      debounce?.cancel();
                      generation++;
                      setState(() => loading = true);
                      debounce = Timer(const Duration(milliseconds: 300), () {
                        if (mounted) load();
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      for (final value in [
                        'all',
                        'reading',
                        'planned',
                        'completed',
                      ])
                        ChoiceChip(
                          label: Text(
                            c.tr(
                              value == 'all' ? 'bAllBooks' : 'bStatus$value',
                            ),
                          ),
                          selected: status == value,
                          onSelected: acting
                              ? null
                              : (_) {
                                  setState(() => status = value);
                                  load();
                                },
                        ),
                      FilterChip(
                        key: const Key('book-library-favorites'),
                        label: Text(c.tr('favorites')),
                        selected: favorites,
                        onSelected: acting
                            ? null
                            : (v) {
                                setState(() => favorites = v);
                                load();
                              },
                      ),
                    ],
                  ),
                  ExpansionTile(
                    key: organizeKey,
                    onExpansionChanged: (v) {
                      if (v) guide.event('organizeOpened');
                    },
                    title: Text(
                      c.tr('rOrganize'),
                      key: const Key('book-library-organize'),
                    ),
                    children: [
                      DropdownButtonFormField<String>(
                        key: ValueKey('book-filter-status-$status'),
                        initialValue: status,
                        isExpanded: true,
                        decoration: InputDecoration(labelText: c.tr('bStatus')),
                        items: [
                          DropdownMenuItem(
                            value: 'all',
                            child: Text(c.tr('bAllBooks')),
                          ),
                          for (final value in BookLibrary.statuses)
                            DropdownMenuItem(
                              value: value,
                              child: Text(c.tr('bStatus$value')),
                            ),
                        ],
                        onChanged: acting
                            ? null
                            : (v) {
                                setState(() => status = v!);
                                load();
                              },
                      ),
                      DropdownButtonFormField<String>(
                        key: ValueKey('book-library-sort-$sort'),
                        initialValue: sort,
                        isExpanded: true,
                        decoration: InputDecoration(labelText: c.tr('bSort')),
                        items: [
                          for (final value in [
                            'opened',
                            'added',
                            'updated',
                            'title',
                            'author',
                          ])
                            DropdownMenuItem(
                              value: value,
                              child: Text(
                                c.tr(switch (value) {
                                  'opened' => 'rRecentlyOpened',
                                  'added' => 'rRecentlyAdded',
                                  'title' => 'bSortTitle',
                                  'author' => 'bSortAuthor',
                                  _ => 'bSortUpdated',
                                }),
                              ),
                            ),
                        ],
                        onChanged: acting
                            ? null
                            : (v) {
                                setState(() => sort = v!);
                                load();
                              },
                      ),
                      if ((choices['shelves'] ?? []).isNotEmpty)
                        filter('shelves', shelf, 'bShelves', (v) => shelf = v),
                      if ((choices['tags'] ?? []).isNotEmpty)
                        filter('tags', tag, 'tags', (v) => tag = v),
                      if ((choices['categories'] ?? []).isNotEmpty)
                        filter(
                          'categories',
                          category,
                          'bCategories',
                          (v) => category = v,
                        ),
                      Text(c.tr('rStorageChoice')),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          TextButton(
                            onPressed: acting || loading
                                ? null
                                : () =>
                                      action(() => importBook(reference: true)),
                            key: const Key('book-library-link'),
                            child: Text(c.tr('rLinkFile')),
                          ),
                          TextButton(
                            key: const Key('book-library-manual'),
                            onPressed: acting || loading
                                ? null
                                : () => action(create),
                            child: Text(c.tr('rManualBook')),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (failed)
            SliverToBoxAdapter(
              child: TextButton(
                onPressed: () => load(refreshFilters: true),
                child: Text(c.tr('retry')),
              ),
            )
          else if (!loading && books.isEmpty)
            SliverPadding(
              padding: const EdgeInsets.all(24),
              sliver: SliverToBoxAdapter(child: Text(c.tr('rEmptyLibrary'))),
            )
          else if (grid)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverGrid.builder(
                gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 360,
                  mainAxisExtent:
                      330 +
                      180 *
                          (MediaQuery.textScalerOf(c).scale(16) / 16 - 1).clamp(
                            0,
                            2,
                          ),
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: books.length,
                itemBuilder: (c, i) => tile(books[i]),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList.builder(
                itemCount: books.length,
                itemBuilder: (c, i) => tile(books[i]),
              ),
            ),
          if (more)
            SliverToBoxAdapter(
              child: TextButton(
                key: const Key('book-library-more'),
                onPressed: loading || acting ? null : () => load(append: true),
                child: Text(c.tr('continue')),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    ),
  );
}
