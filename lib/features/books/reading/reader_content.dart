import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../../core/strings.dart';
import 'reading_store.dart';
import 'text_document.dart';

const markColors = {
  'yellow': Color(0xffffe082),
  'green': Color(0xffa5d6a7),
  'blue': Color(0xff90caf9),
  'pink': Color(0xfff48fb1),
};

class ReaderTextBlock extends StatelessWidget {
  const ReaderTextBlock({
    super.key,
    required this.blockIndex,
    required this.block,
    required this.sectionKey,
    required this.epubPath,
    required this.settings,
    required this.marks,
    required this.dark,
    required this.ink,
    required this.onSelection,
    required this.onAction,
  });

  final int blockIndex;
  final BookBlock block;
  final Object? sectionKey;
  final String? epubPath;
  final Map<String, dynamic> settings;
  final List<ReadingRow> marks;
  final bool dark;
  final Color ink;
  final ValueChanged<TextSelection> onSelection;
  final ValueChanged<String>? onAction;

  @override
  Widget build(BuildContext context) {
    if (block.image != null && epubPath != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: FutureBuilder(
          future: TextDocument.image(epubPath!, block.image!),
          builder: (c, s) => s.hasData
              ? Image.memory(
                  s.data!,
                  cacheWidth: 1000,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) =>
                      Text(block.text, style: TextStyle(color: ink)),
                )
              : Text(block.text, style: TextStyle(color: ink)),
        ),
      );
    }
    final applicable = marks
        .where(
          (m) =>
              m.kind == 'highlight' &&
              m.data['location']['kind'] == 'text' &&
              m.data['location']['section'] == sectionKey &&
              m.data['location']['block'] == blockIndex,
        )
        .toList();
    final cuts = {0, block.text.length};
    for (final m in applicable) {
      cuts.add(
        (m.data['location']['offset'] as int).clamp(0, block.text.length),
      );
      cuts.add(
        (m.data['end'] as int? ?? block.text.length).clamp(
          0,
          block.text.length,
        ),
      );
    }
    final positions = cuts.toList()..sort();
    final spans = <InlineSpan>[];
    for (var n = 0; n < positions.length - 1; n++) {
      final a = positions[n], z = positions[n + 1];
      final color = applicable
          .where(
            (m) =>
                (m.data['location']['offset'] as int) <= a &&
                (m.data['end'] as int? ?? block.text.length) >= z,
          )
          .lastOrNull
          ?.data['color'];
      spans.add(
        TextSpan(
          text: block.text.substring(a, z),
          style: TextStyle(
            backgroundColor: color == null
                ? null
                : markColors[color]?.withAlpha(dark ? 100 : 160),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: SelectableText.rich(
        TextSpan(children: spans),
        style: TextStyle(
          color: ink,
          fontSize:
              (settings['font'] as num).toDouble() * (block.heading ? 1.25 : 1),
          height: (settings['line'] as num).toDouble(),
          fontWeight: block.heading ? FontWeight.bold : FontWeight.normal,
          fontFamily: switch (settings['family']) {
            'serif' => 'serif',
            'mono' => 'monospace',
            _ => 'sans-serif',
          },
        ),
        textDirection:
            RegExp(r'^[^A-Za-z\u00c0-\u052f\u3400-\u9fff]*[\u0590-\u08ff]')
                .hasMatch(block.text)
            ? TextDirection.rtl
            : TextDirection.ltr,
        onSelectionChanged: (s, cause) {
          if (s.isValid && !s.isCollapsed) {
            onSelection(s);
          }
        },
        contextMenuBuilder: (c, state) =>
            AdaptiveTextSelectionToolbar.buttonItems(
              anchors: state.contextMenuAnchors,
              buttonItems: [
                ...state.contextMenuButtonItems,
                if (onAction != null) ...[
                  for (final action in ['highlight', 'annotation', 'card'])
                    ContextMenuButtonItem(
                      label: c.tr(
                        action == 'card' ? 'rSaveCard' : 'rKind_$action',
                      ),
                      onPressed: () {
                        ContextMenuController.removeAny();
                        onAction!(action);
                      },
                    ),
                ],
              ],
            ),
      ),
    );
  }
}

class ReaderPdfViewport extends StatelessWidget {
  const ReaderPdfViewport({
    super.key,
    required this.document,
    required this.pdf,
    required this.searcher,
    required this.page,
    required this.paged,
    required this.paper,
    required this.marks,
    required this.onReady,
    required this.onPositionChanged,
    required this.onAction,
  });

  final PdfDocument document;
  final PdfViewerController pdf;
  final PdfTextSearchSession searcher;
  final int page;
  final bool paged;
  final Color paper;
  final List<ReadingRow> marks;
  final ValueChanged<PdfViewerController> onReady;
  final VoidCallback onPositionChanged;
  final void Function(String, PdfTextSelection)? onAction;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      Offstage(
        offstage: paged,
        child: PdfViewer(
          PdfDocumentRefDirect(document, autoDispose: false),
          controller: pdf,
          initialPageNumber: page,
          params: PdfViewerParams(
            isVisible: !paged,
            backgroundColor: paper,
            maxImageBytesCachedOnMemory: 32 * 1024 * 1024,
            verticalCacheExtent: .5,
            horizontalCacheExtent: .3,
            textSelectionParams: PdfTextSelectionParams(
              enabled: document.permissions?.allowsCopying != false,
            ),
            onPageChanged: (_) => onPositionChanged(),
            onInteractionEnd: (_) => onPositionChanged(),
            onViewerReady: (_, controller) => onReady(controller),
            customizeContextMenuItems: (params, items) {
              if (onAction != null &&
                  params.textSelectionDelegate.isCopyAllowed &&
                  params.textSelectionDelegate.hasSelectedText) {
                for (final action in ['highlight', 'annotation', 'card']) {
                  items.add(
                    ContextMenuButtonItem(
                      label: context.tr(
                        action == 'card' ? 'rSaveCard' : 'rKind_$action',
                      ),
                      onPressed: () {
                        params.dismissContextMenu();
                        onAction!(action, params.textSelectionDelegate);
                      },
                    ),
                  );
                }
              }
            },
            pagePaintCallbacks: [
              searcher.pageTextMatchPaintCallback,
              (canvas, rect, page) {
                for (final m in marks.where((r) => r.kind == 'highlight')) {
                  for (final v in m.data['rects'] as List? ?? []) {
                    if (v[0] != page.pageNumber) continue;
                    final bound = PdfRect(
                      (v[1] as num).toDouble(),
                      (v[2] as num).toDouble(),
                      (v[3] as num).toDouble(),
                      (v[4] as num).toDouble(),
                    );
                    canvas.drawRect(
                      bound
                          .toRect(page: page, scaledPageSize: rect.size)
                          .translate(rect.left, rect.top),
                      Paint()
                        ..color = (markColors[m.data['color']] ?? Colors.yellow)
                            .withAlpha(110),
                    );
                  }
                }
              },
            ],
          ),
        ),
      ),
      if (paged)
        InteractiveViewer(
          key: ValueKey('pdf-single-$page'),
          minScale: 1,
          maxScale: 8,
          child: Center(
            child: PdfPageView(
              document: document,
              pageNumber: page,
              maximumDpi: 144,
            ),
          ),
        ),
    ],
  );
}
