import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/strings.dart';
import '../books/book_library_store.dart';

/// Reuses the existing thin library query and paging; selecting never edits.
class VoiceBookPicker extends StatefulWidget {
  final BookLibraryStore store;
  final String query, sort;
  const VoiceBookPicker({
    super.key,
    required this.store,
    this.query = '',
    this.sort = 'title',
  });
  @override
  State<VoiceBookPicker> createState() => _PickerState();
}

class _PickerState extends State<VoiceBookPicker> {
  late final search = TextEditingController(text: widget.query);
  List<BookSummary> rows = [];
  bool busy = false, failed = false, more = false;
  int generation = 0;
  Timer? timer;
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    timer?.cancel();
    search.dispose();
    super.dispose();
  }

  Future<void> load({bool append = false}) async {
    final token = ++generation;
    setState(() => busy = true);
    try {
      final next = await widget.store.page(
        query: search.text,
        sort: widget.sort,
        offset: append ? rows.length : 0,
        limit: 51,
      );
      if (!mounted || token != generation) return;
      final ids = append ? rows.map((b) => b.id).toSet() : <String>{};
      setState(() {
        rows = [
          if (append) ...rows,
          ...next.take(50).where((b) => ids.add(b.id)),
        ];
        more = next.length > 50;
        failed = false;
      });
    } catch (_) {
      if (mounted && token == generation) setState(() => failed = true);
    } finally {
      if (mounted && token == generation) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: Text(c.tr('voiceChooseBook'))),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            key: const Key('voice-book-search'),
            controller: search,
            decoration: InputDecoration(labelText: c.tr('search')),
            onChanged: (_) {
              timer?.cancel();
              timer = Timer(const Duration(milliseconds: 250), load);
            },
          ),
        ),
        if (busy) const LinearProgressIndicator(),
        Expanded(
          child: failed
              ? Center(
                  child: TextButton(
                    onPressed: load,
                    child: Text(c.tr('retry')),
                  ),
                )
              : ListView(
                  children: [
                    if (!busy && rows.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(c.tr('voiceNoMatch')),
                      ),
                    for (final b in rows)
                      ListTile(
                        key: Key('voice-book-${b.id}'),
                        title: Text(b.title),
                        subtitle: b.author.isEmpty ? null : Text(b.author),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: busy ? null : () => Navigator.pop(c, b.id),
                      ),
                    if (more)
                      TextButton(
                        key: const Key('voice-book-more'),
                        onPressed: busy ? null : () => load(append: true),
                        child: Text(c.tr('continue')),
                      ),
                  ],
                ),
        ),
      ],
    ),
  );
}
