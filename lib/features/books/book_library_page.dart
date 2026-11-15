import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/dialogs.dart';
import '../../core/strings.dart';
import '../agent/agent_access.dart';
import '../agent/purchase_panel.dart';
import '../private_space/record_store.dart';
import '../private_space/space_page.dart' show RecordPage;
import 'book_details_editor.dart';
import 'book_library.dart';
import 'book_library_store.dart';

class BookLibraryPage extends StatefulWidget {
  final RecordStore? records;
  final BookLibraryStore? library;
  final AgentAccess? access;
  const BookLibraryPage({super.key, this.records, this.library, this.access});
  @override
  State<BookLibraryPage> createState() => _LibraryState();
}

class _LibraryState extends State<BookLibraryPage> {
  late final BookLibraryStore store =
      widget.library ?? BookLibraryStore(records: widget.records);
  AgentAccess get access => widget.access ?? AgentAccess.instance;
  final search = TextEditingController();
  List<BookSummary> books = [];
  Map<String, List<String>> choices = {};
  String status = 'all', shelf = '', tag = '', category = '', sort = 'updated';
  bool favorites = false,
      loading = false,
      acting = false,
      failed = false,
      more = false;
  int generation = 0;
  Timer? debounce;
  @override
  void initState() {
    super.initState();
    load(refreshFilters: true);
  }

  @override
  void dispose() {
    debounce?.cancel();
    search.dispose();
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
          setState(() {
            choices = filters;
            if (!(filters['shelves'] ?? []).contains(shelf)) shelf = '';
            if (!(filters['tags'] ?? []).contains(tag)) tag = '';
            if (!(filters['categories'] ?? []).contains(category)) {
              category = '';
            }
          });
          unawaited(load());
        }
        return;
      }
      final chosenShelf = (filters['shelves'] ?? []).contains(shelf)
          ? shelf
          : '';
      final chosenTag = (filters['tags'] ?? []).contains(tag) ? tag : '';
      final chosenCategory = (filters['categories'] ?? []).contains(category)
          ? category
          : '';
      final rows = await store.page(
        query: search.text,
        status: status == 'all' ? null : status,
        favoritesOnly: favorites,
        shelf: chosenShelf.isEmpty ? null : chosenShelf,
        tag: chosenTag.isEmpty ? null : chosenTag,
        category: chosenCategory.isEmpty ? null : chosenCategory,
        sort: sort,
        offset: append ? books.length : 0,
        limit: 51,
      );
      if (!mounted || token != generation) return;
      final ids = append ? books.map((book) => book.id).toSet() : <String>{};
      setState(() {
        choices = filters;
        shelf = chosenShelf;
        tag = chosenTag;
        category = chosenCategory;
        books = [
          if (append) ...books,
          ...rows.take(50).where((book) => ids.add(book.id)),
        ];
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

  Future<void> action(Future<void> Function() work) async {
    if (acting || loading) return;
    setState(() => acting = true);
    try {
      await work();
    } catch (_) {
      if (mounted) showError(context);
    } finally {
      if (mounted) {
        setState(() => acting = false);
        await load(refreshFilters: true);
      }
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
    if (created != null && mounted) {
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) =>
              RecordPage(created!, store: store.records, access: access),
        ),
      );
    }
  }

  Future<void> open(BookSummary book) async {
    final record = await store.load(book.id);
    if (mounted) {
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) =>
              RecordPage(record, store: store.records, access: access),
        ),
      );
    }
  }

  Future<void> favorite(BookSummary book) async {
    if (!await allowed()) return;
    final record = await store.load(book.id);
    if (record.revision != book.revision) throw StateError('book_changed');
    if (!access.has(AgentAccess.core)) throw StateError('access_expired');
    await store.records.save(
      'book',
      BookLibrary.update(record.data, {'favorite': !book.favorite}),
      previous: record,
    );
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
        : (value) {
            setState(() => change(value!));
            load();
          },
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(context.tr('xBooks')),
      actions: [
        IconButton(
          tooltip: context.tr('retry'),
          onPressed: acting ? null : () => load(refreshFilters: true),
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    floatingActionButton: FloatingActionButton(
      key: const Key('book-library-add'),
      tooltip: context.tr('bAddBook'),
      onPressed: loading || acting ? null : () => action(create),
      child: const Icon(Icons.add),
    ),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
      children: [
        TextField(
          key: const Key('book-library-search'),
          controller: search,
          enabled: !acting,
          autocorrect: false,
          enableSuggestions: false,
          enableIMEPersonalizedLearning: false,
          decoration: InputDecoration(
            labelText: context.tr('search'),
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
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          key: ValueKey('book-filter-status-$status'),
          initialValue: status,
          isExpanded: true,
          decoration: InputDecoration(labelText: context.tr('bStatus')),
          items: [
            DropdownMenuItem(
              value: 'all',
              child: Text(context.tr('bAllBooks')),
            ),
            for (final value in BookLibrary.statuses)
              DropdownMenuItem(
                value: value,
                child: Text(context.tr('bStatus$value')),
              ),
          ],
          onChanged: acting
              ? null
              : (value) {
                  setState(() => status = value!);
                  load();
                },
        ),
        SwitchListTile(
          key: const Key('book-library-favorites'),
          title: Text(context.tr('favorites')),
          value: favorites,
          onChanged: acting
              ? null
              : (value) {
                  setState(() => favorites = value);
                  load();
                },
        ),
        DropdownButtonFormField<String>(
          key: ValueKey('book-library-sort-$sort'),
          initialValue: sort,
          isExpanded: true,
          decoration: InputDecoration(labelText: context.tr('bSort')),
          items: [
            for (final value in ['updated', 'title', 'author'])
              DropdownMenuItem(
                value: value,
                child: Text(
                  context.tr(switch (value) {
                    'title' => 'bSortTitle',
                    'author' => 'bSortAuthor',
                    _ => 'bSortUpdated',
                  }),
                ),
              ),
          ],
          onChanged: acting
              ? null
              : (value) {
                  setState(() => sort = value!);
                  load();
                },
        ),
        if ((choices['shelves'] ?? []).isNotEmpty) ...[
          const SizedBox(height: 16),
          filter('shelves', shelf, 'bShelves', (value) => shelf = value),
        ],
        if ((choices['tags'] ?? []).isNotEmpty) ...[
          const SizedBox(height: 16),
          filter('tags', tag, 'tags', (value) => tag = value),
        ],
        if ((choices['categories'] ?? []).isNotEmpty) ...[
          const SizedBox(height: 16),
          filter(
            'categories',
            category,
            'bCategories',
            (value) => category = value,
          ),
        ],
        const SizedBox(height: 16),
        if (loading) const LinearProgressIndicator(),
        if (failed)
          TextButton(
            onPressed: () => load(refreshFilters: true),
            child: Text(context.tr('retry')),
          )
        else if (!loading && books.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Center(child: Text(context.tr('empty'))),
          )
        else
          for (final book in books)
            Card(
              child: ListTile(
                key: ValueKey('book-library-row-${book.id}'),
                leading: const Icon(Icons.menu_book_outlined),
                title: Text(
                  book.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  [
                    if (book.author.isNotEmpty) book.author,
                    context.tr('bStatus${book.status}'),
                    if (book.pages != null || book.currentPage != 0)
                      '${context.tr('bCurrentPage')}: ${book.currentPage}${book.pages == null ? '' : ' / ${book.pages}'}',
                    if (book.rating != null)
                      '${context.tr('bRating')}: ${book.rating} / 5',
                    '${book.chapters} ${context.tr('xChapters')}',
                  ].join('\n'),
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: acting || loading
                    ? null
                    : () => action(() => open(book)),
                trailing: IconButton(
                  tooltip: context.tr('favorites'),
                  onPressed: acting || loading
                      ? null
                      : () => action(() => favorite(book)),
                  icon: Icon(book.favorite ? Icons.star : Icons.star_border),
                ),
              ),
            ),
        if (more)
          TextButton(
            key: const Key('book-library-more'),
            onPressed: loading || acting ? null : () => load(append: true),
            child: Text(context.tr('continue')),
          ),
      ],
    ),
  );
}
