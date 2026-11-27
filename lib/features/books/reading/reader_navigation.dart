import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../../core/strings.dart';

class ReaderNavigation extends StatelessWidget {
  const ReaderNavigation({
    super.key,
    required this.anchor,
    required this.progress,
    required this.isPdf,
    required this.position,
    required this.count,
    required this.onChoose,
    required this.onMove,
  });

  final GlobalKey anchor;
  final double progress;
  final bool isPdf;
  final int position, count;
  final VoidCallback onChoose;
  final ValueChanged<int> onMove;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      LinearProgressIndicator(value: progress.clamp(0, 1)),
      Wrap(
        key: anchor,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        children: [
          IconButton(
            key: isPdf ? const Key('reader-previous') : null,
            onPressed: position > 1 ? () => onMove(-1) : null,
            icon: const Icon(Icons.chevron_left),
          ),
          TextButton(
            key: const Key('reader-location'),
            onPressed: onChoose,
            child: Text('$position / $count'),
          ),
          Text('${(progress * 100).toStringAsFixed(1)}%'),
          IconButton(
            key: isPdf ? const Key('reader-next') : null,
            onPressed: position < count ? () => onMove(1) : null,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    ],
  );
}

class ReaderPdfSearchControls extends StatelessWidget {
  const ReaderPdfSearchControls({super.key, required this.searcher});

  final PdfTextSearchSession searcher;

  @override
  Widget build(BuildContext context) {
    final hasMatches = searcher.matches.isNotEmpty;
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (searcher.isSearching)
          Text(
            '${context.tr('rSearching')} ${((searcher.searchProgress ?? 0) * 100).round()}%',
          ),
        if (hasMatches)
          Text(
            '${(searcher.currentIndex ?? -1) + 1}/${searcher.matches.length}',
          ),
        if (!searcher.isSearching && !hasMatches)
          Text(context.tr('rNoMatches')),
        IconButton(
          onPressed: hasMatches
              ? () => unawaited(searcher.goToPrevMatch())
              : null,
          icon: const Icon(Icons.arrow_upward),
        ),
        IconButton(
          key: const Key('reader-search-next'),
          onPressed: hasMatches
              ? () => unawaited(searcher.goToNextMatch())
              : null,
          icon: const Icon(Icons.arrow_downward),
        ),
      ],
    );
  }
}
