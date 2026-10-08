import 'package:flutter/material.dart';

import '../../core/strings.dart';
import '../../core/editor_form.dart';

/// Read the actual saved chapters; reading does not change their contents.
class BookReader extends StatefulWidget {
  final String title;
  final List<Map<String, dynamic>> chapters;
  final int bookmark;
  final Future<void> Function(int) saveBookmark;
  const BookReader({
    super.key,
    required this.title,
    required this.chapters,
    required this.bookmark,
    required this.saveBookmark,
  });
  @override
  State<BookReader> createState() => _ReaderState();
}

class _ReaderState extends State<BookReader> {
  late final PageController pages;
  late int chapter;
  double fontSize = 20;
  bool saving = false;
  @override
  void initState() {
    super.initState();
    chapter = widget.chapters.isEmpty
        ? 0
        : widget.bookmark.clamp(0, widget.chapters.length - 1);
    pages = PageController(initialPage: chapter);
  }

  @override
  void dispose() {
    pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(
      title: Text(widget.title),
      actions: [
        IconButton(
          tooltip: c.tr('save'),
          icon: const Icon(Icons.bookmark_add_outlined),
          onPressed: widget.chapters.isEmpty || saving
              ? null
              : () async {
                  setState(() => saving = true);
                  try {
                    await widget.saveBookmark(chapter);
                    if (c.mounted) {
                      ScaffoldMessenger.of(c)
                          .showSnackBar(SnackBar(content: Text(c.tr('saved'))));
                    }
                  } catch (_) {
                    if (c.mounted) failure(c);
                  } finally {
                    if (mounted) setState(() => saving = false);
                  }
                },
        ),
      ],
    ),
    body: Column(
      children: [
        Row(
          children: [
            const SizedBox(width: 16),
            const Icon(Icons.text_fields),
            Expanded(
              child: Slider(
                value: fontSize,
                min: 14,
                max: 32,
                divisions: 18,
                onChanged: (v) => setState(() => fontSize = v),
              ),
            ),
            Text('${fontSize.round()}'),
            const SizedBox(width: 16),
          ],
        ),
        if (saving) const LinearProgressIndicator(),
        Expanded(
          child: PageView.builder(
            controller: pages,
            itemCount: widget.chapters.length,
            onPageChanged: (i) => setState(() => chapter = i),
            itemBuilder: (c, i) => SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SelectableText(
                        widget.chapters[i]['title'],
                        style: Theme.of(c).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 24),
                      SelectableText(
                        widget.chapters[i]['body'],
                        style: TextStyle(fontSize: fontSize, height: 1.65),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: chapter <= 0
                    ? null
                    : () => pages.previousPage(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOut,
                      ),
                icon: const Icon(Icons.chevron_left),
              ),
              Text(
                '${widget.chapters.isEmpty ? 0 : chapter + 1} / ${widget.chapters.length}',
              ),
              IconButton(
                onPressed: chapter + 1 >= widget.chapters.length
                    ? null
                    : () => pages.nextPage(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOut,
                      ),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
