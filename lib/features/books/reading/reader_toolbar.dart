import 'package:flutter/material.dart';

import '../../../core/strings.dart';

class ReaderToolbar extends StatelessWidget implements PreferredSizeWidget {
  const ReaderToolbar({
    super.key,
    required this.title,
    required this.paper,
    required this.ink,
    required this.isPdf,
    required this.paged,
    required this.ready,
    required this.hasPdfDocument,
    required this.writable,
    required this.paused,
    required this.appearanceAnchor,
    required this.bookmarkAnchor,
    required this.menuAnchor,
    required this.onSearch,
    required this.onAppearance,
    required this.onBookmark,
    required this.onMenu,
  });

  final String title;
  final Color paper, ink;
  final bool isPdf, paged, ready, hasPdfDocument, writable, paused;
  final GlobalKey appearanceAnchor, bookmarkAnchor, menuAnchor;
  final VoidCallback onSearch, onAppearance, onBookmark;
  final ValueChanged<String> onMenu;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) => AppBar(
    backgroundColor: paper,
    foregroundColor: ink,
    title: Text(title),
    actions: [
      IconButton(
        key: const Key('reader-search'),
        tooltip: context.tr('rSearchBook'),
        onPressed: ready && !(isPdf && paged) ? onSearch : null,
        icon: const Icon(Icons.search),
      ),
      IconButton(
        key: appearanceAnchor,
        tooltip: context.tr('rAppearance'),
        onPressed: ready ? onAppearance : null,
        icon: Icon(
          isPdf ? Icons.tune : Icons.text_fields,
          key: const Key('reader-appearance'),
        ),
      ),
      IconButton(
        key: bookmarkAnchor,
        tooltip: context.tr('rKind_bookmark'),
        onPressed: ready && writable ? onBookmark : null,
        icon: const Icon(
          Icons.bookmark_add_outlined,
          key: Key('reader-bookmark'),
        ),
      ),
      PopupMenuButton<String>(
        key: menuAnchor,
        onSelected: onMenu,
        itemBuilder: (context) => [
          PopupMenuItem(value: 'help', child: Text(context.tr('rHelp'))),
          if (isPdf && hasPdfDocument)
            PopupMenuItem(
              value: 'thumbnails',
              child: Text(context.tr('rThumbnails')),
            ),
          PopupMenuItem(value: 'hub', child: Text(context.tr('rReadingNotes'))),
          if (writable && ready) ...[
            PopupMenuItem(
              value: 'annotation',
              child: Text(context.tr('rPageNote')),
            ),
            PopupMenuItem(value: 'card', child: Text(context.tr('rAddCard'))),
            PopupMenuItem(
              value: 'finish',
              child: Text(context.tr('rMarkFinished')),
            ),
          ],
          PopupMenuItem(
            value: 'pause',
            child: Text(context.tr(paused ? 'rResumeTimer' : 'rPauseTimer')),
          ),
        ],
      ),
    ],
  );
}
