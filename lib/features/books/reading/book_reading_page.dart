import '../../../core/review_performance.dart';

import 'dart:async';

import 'package:flutter/foundation.dart' show mapEquals;

import 'dart:io';

import 'package:flutter/services.dart';

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../../../core/editor_form.dart';
import '../../../core/strings.dart';
import '../../agent/agent_access.dart';
import '../../private_space/record_store.dart';
import '../book_library.dart';
import 'book_importer.dart';
import 'reading_store.dart';
import 'reading_hub.dart';
import 'text_document.dart';
import 'reading_errors.dart';
import 'reading_clock.dart';
import 'reader_appearance_sheet.dart';
import 'reader_content.dart';
import 'reader_navigation.dart';
import 'reader_toolbar.dart';
import '../../attachments/attachment_store.dart';
import '../../guidance/guide_controller.dart';
import '../../guidance/guide_host.dart';
import '../../voice/voice_screen_host.dart';

class BookReadingPage extends StatefulWidget {
  final PrivateRecord book;
  final ReadingStore store;
  final AgentAccess access;
  final Map<String, dynamic>? initialLocation;
  final bool readOnly;
  const BookReadingPage({
    super.key,
    required this.book,
    required this.store,
    required this.access,
    this.initialLocation,
    this.readOnly = false,
  });
  @override
  State<BookReadingPage> createState() => _ReadingState();
}

class _ReadingState extends State<BookReadingPage> with WidgetsBindingObserver {
  final pdf = PdfViewerController();
  final contentAnchor = GlobalKey(),
      bookmarkAnchor = GlobalKey(),
      appearanceAnchor = GlobalKey(),
      menuAnchor = GlobalKey(),
      navigationAnchor = GlobalKey();
  GuideController guide = GuideController(
    id: 'book.reader.bookmark',
    steps: const [
      GuideStep(
        'bookmark',
        'bookmark',
        'rGuideBookmark',
        event: 'bookmarkSaved',
      ),
      GuideStep('saved', 'menu', 'rGuideSaved', backBoundary: true),
    ],
  );
  Future<void> help() async {
    final topic = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (c) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final item in [
              ('navigate', isPdf ? 'PDF' : 'EPUB / TXT'),
              ('appearance', c.tr('rAppearance')),
              ('bookmark', c.tr('rKind_bookmark')),
              ('highlight', c.tr('rKind_highlight')),
              ('card', c.tr('rAddCard')),
            ])
              ListTile(
                title: Text(item.$2),
                onTap: () => Navigator.pop(c, item.$1),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(c.tr('rHelpText')),
            ),
          ],
        ),
      ),
    );
    if (topic == null || !mounted) return;
    final step = switch (topic) {
      'navigate' => GuideStep(
        'navigate',
        (isPdf ? (document?.pages.length ?? 0) > 1 : sections.length > 1)
            ? 'navigation'
            : 'content',
        'rGuideNavigate',
        event: 'navigated',
      ),
      'appearance' => const GuideStep(
        'appearance',
        'appearance',
        'rGuideAppearance',
        event: 'appearanceSaved',
      ),
      'highlight' => const GuideStep(
        'highlight',
        'content',
        'rGuideHighlight',
        event: 'highlightSaved',
      ),
      'card' => const GuideStep(
        'card',
        'menu',
        'rGuideCard',
        event: 'cardSaved',
      ),
      _ => const GuideStep(
        'bookmark',
        'bookmark',
        'rGuideBookmark',
        event: 'bookmarkSaved',
      ),
    };
    guide.dispose();
    setState(() {
      controls = true;
      guide = GuideController(
        id: 'book.reader.$topic',
        steps: [
          step,
          GuideStep(
            'saved',
            'menu',
            topic == 'appearance'
                ? 'rGuideAppearanceDone'
                : topic == 'navigate'
                ? 'rGuideNavigationDone'
                : 'rGuideSaved',
            backBoundary: true,
          ),
        ],
      );
      guide.start();
    });
  }

  final itemScroll = ItemScrollController();
  final positions = ItemPositionsListener.create();
  int sectionGeneration = 0;
  late final searcher = PdfTextSearchSession(pdf)..addListener(refresh);

  File? file;
  PdfDocument? document;
  ReadingRow? source, settingsRow;
  Map<String, dynamic> index = {},
      location = {'kind': 'text', 'section': 'text', 'block': 0, 'offset': 0};
  Map<String, dynamic>? initialPdfLocation;
  bool pdfRestored = false, navigationGesture = false;
  Map<String, dynamic> settings = {
    'v': 1,
    'font': 20.0,
    'line': 1.65,
    'margin': 24.0,
    'theme': 'light',
    'family': 'serif',
  };
  List<BookBlock> blocks = [];
  List<ReadingRow> marks = [];
  int sectionIndex = 0, page = 1;
  bool loading = true,
      controls = true,
      busy = false,
      paged = false,
      paused = false;
  String? error, saveError;
  String selected = '';
  Map<String, dynamic>? selectionLocation;
  int? selectionEnd;
  double fraction = 0;
  Timer? tick, debounce;
  DateTime lastTouch = DateTime.now(), start = DateTime.now();
  final stopwatch = Stopwatch();
  late ReadingClock readingClock;
  final sessionToken = localId();
  final sessions = <String, ReadingRow>{};
  final savedSeconds = <String, int>{};
  int lastSessionFlush = 0;
  Future<void> writes = Future.value();
  bool foreground = true, closed = false;
  bool get writable => !widget.readOnly && widget.access.has(AgentAccess.core);
  bool get isPdf => source?.data['format'] == 'pdf';
  bool get dark => settings['theme'] == 'dark';
  Color get paper => dark
      ? const Color(0xff1b1d20)
      : settings['theme'] == 'sepia'
      ? const Color(0xfff3e5c4)
      : const Color(0xfffaf9f6);
  Color get ink => dark ? const Color(0xffeeeeee) : const Color(0xff202124);
  List<dynamic> get sections => index['sections'] as List? ?? [];
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    positions.itemPositions.addListener(changed);
    load();
  }

  void refresh() {
    if (mounted) setState(() {});
  }

  Future<void> load({ImportCandidate? relinked}) async {
    try {
      final src = await widget.store.one(widget.book.id, 'source');
      if (src == null) throw const FormatException('book_missing');
      final old = await widget.store.one(widget.book.id, 'progress');
      final pref = await widget.store.one(widget.book.id, 'settings');
      source = src;
      final f =
          relinked?.file ??
          await ReviewPerformance.measure<File>(
            'book.materialize',
            () => BookImporter(widget.store).materialize(src),
          );
      if (!mounted) {
        await f.parent.delete(recursive: true);
        return;
      }
      source = src;
      file = f;
      if (pref != null) {
        settingsRow = pref;
        settings = {...pref.data};
        paged = settings['paged'] == true;
      }
      final saved = widget.initialLocation ?? old?.data['location'];
      if (saved is Map) location = Map<String, dynamic>.from(saved);
      initialPdfLocation = Map<String, dynamic>.from(location);
      fraction = (old?.data['fraction'] as num?)?.toDouble() ?? 0;
      if (src.data['format'] == 'pdf') {
        await pdfrxFlutterInitialize();
        final doc = await ReviewPerformance.measure(
          'pdf.open',
          () => PdfDocument.openFile(f.path, passwordProvider: () => null),
        );
        if (!mounted) {
          await doc.dispose();
          await f.parent.delete(recursive: true);
          return;
        }
        document = doc;
        page = (location['kind'] == 'pdf' ? location['page'] as int : 1).clamp(
          1,
          doc.pages.length,
        );
        location = {'kind': 'pdf', 'page': page};
      } else {
        index =
            relinked?.index ?? await BookImporter(widget.store).index(src, f);
        sectionIndex = sections.indexWhere(
          (s) => s['key'] == location['section'],
        );
        if (sectionIndex < 0) sectionIndex = 0;
        await loadSection(
          sectionIndex,
          restore: location['kind'] == 'text' ? location['block'] as int : 0,
        );
      }
      await loadMarks();
      if (!mounted) return;
      setState(() => loading = false);
      start = DateTime.now();
      readingClock = ReadingClock(start);
      stopwatch.start();
      tick = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        sampleClock();
        final active =
            !busy &&
            foreground &&
            !paused &&
            ModalRoute.of(context)?.isCurrent != false &&
            DateTime.now().difference(lastTouch).inSeconds < 120;
        if (active) {
          stopwatch.start();
        } else {
          pauseTracking();
        }
        if (++lastSessionFlush >= 15) {
          lastSessionFlush = 0;
          queue(saveSession);
        }
      });
      if (writable) {
        final meta = BookLibrary.metadata(widget.book.data);
        if ({'planned', 'unspecified'}.contains(meta['status'])) {
          queue(() async {
            await widget.store.records.save(
              'book',
              BookLibrary.update(widget.book.data, {'status': 'reading'}),
              previous: widget.book,
            );
          });
        }
        queue(savePosition);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          loading = false;
          error = readingError(context, e);
        });
      }
    }
  }

  Future<void> relink() async {
    if (source == null) return;
    final choices = await BookImporter.pick();
    if (choices.isEmpty) return;
    final importer = BookImporter(widget.store);
    final c = await importer.prepare(
      Attachments.uriStream(choices.first['uri']),
      choices.first['name'] ?? 'book',
    );
    var retained = false;
    try {
      if (c.hash != source!.data['hash'] ||
          c.format != source!.data['format']) {
        throw const FormatException('book_changed');
      }
      if (writable) {
        await importer.commit(
          c,
          referenceUri: source!.data['mode'] == 'reference'
              ? choices.first['uri']
              : null,
          replacing: source,
          allowed: () => writable,
        );
      }
      await document?.dispose();
      document = null;
      if (file != null && await file!.parent.exists()) {
        await file!.parent.delete(recursive: true);
      }
      file = null;
      if (!mounted) return;
      setState(() {
        loading = true;
        error = null;
      });
      retained = !writable;
      await load(relinked: retained ? c : null);
    } finally {
      if (!retained) await c.close();
    }
  }

  Future<void> loadMarks() async {
    final list = <ReadingRow>[];
    for (final kind in ['highlight', 'bookmark', 'annotation']) {
      list.addAll(await widget.store.rows(widget.book.id, kind));
    }
    if (mounted) setState(() => marks = list);
  }

  Future<void> loadSection(int i, {int restore = 0}) async {
    final previous = sectionIndex;
    final rows = await TextDocument.section(
      file!.path,
      source!.data['format'],
      sections[i]['key'],
    );
    if (!mounted) return;
    setState(() {
      sectionIndex = i;
      blocks = rows;

      location = {
        'kind': 'text',
        'section': sections[i]['key'],
        'label': sections[i]['title'],
        'block': restore.clamp(0, math.max(0, rows.length - 1)),
        'offset': 0,
      };
    });
    sectionGeneration++;
    if (i != previous) navigationDone();
  }

  int visibleBlock() {
    final visible =
        positions.itemPositions.value
            .where((p) => p.itemTrailingEdge > 0 && p.itemLeadingEdge < 1)
            .toList()
          ..sort((a, b) => a.index.compareTo(b.index));
    return visible.firstOrNull?.index ?? (location['block'] as int? ?? 0);
  }

  void sampleClock() {
    if (loading || error != null || source == null) return;
    readingClock.sample(
      DateTime.now(),
      Duration(microseconds: math.min(stopwatch.elapsedMicroseconds, 2000000)),
    );
    stopwatch.reset();
  }

  void pauseTracking() {
    sampleClock();
    stopwatch.stop();
  }

  void touch() {
    lastTouch = DateTime.now();
    if (foreground && !paused) {
      if (!stopwatch.isRunning) sampleClock();
      stopwatch.start();
    }
  }

  void queue(Future<void> Function() task) {
    writes = writes.then((_) async {
      try {
        await task();
        if (mounted && saveError != null) setState(() => saveError = null);
      } catch (_) {
        if (mounted) setState(() => saveError = context.tr('rSaveRetry'));
      }
    });
  }

  Future<void> savePosition() async {
    if (!writable || source == null || error != null) return;
    await widget.store.progress(
      widget.book.id,
      Map<String, dynamic>.from(location),
      fraction,
    );
  }

  Future<void> saveSession() async {
    if (!writable || loading || error != null) return;
    sampleClock();
    for (final entry in readingClock.days.entries) {
      final day = entry.value;
      if (day.seconds < 1 || savedSeconds[entry.key] == day.seconds) continue;
      sessions[entry.key] = await widget.store.put(
        widget.book.id,
        'session',
        day.data,
        previous: sessions[entry.key],
        id: '${widget.book.id}-$sessionToken-${entry.key}',
      );
      savedSeconds[entry.key] = day.seconds;
    }
  }

  void changed() {
    if (!mounted || loading || error != null) return;
    final previousLocation = location;
    final previousFraction = fraction;
    if (isPdf) {
      if (!pdf.isReady) return;
      page = pdf.pageNumber ?? page;
      final r = pdf.layout.pageLayouts[page - 1];
      location = {
        'kind': 'pdf',
        'page': page,
        'zoom': pdf.currentZoom,
        'y': ((pdf.visibleRect.top - r.top) / r.height).clamp(0.0, 1.0),
      };
      fraction = page / pdf.pageCount;
    } else if (blocks.isNotEmpty) {
      final b = visibleBlock();
      location = {
        'kind': 'text',
        'section': sections[sectionIndex]['key'],
        'label': sections[sectionIndex]['title'],
        'block': b,
        'offset': 0,
      };
      final before = sections
          .take(sectionIndex)
          .fold<int>(0, (sum, s) => sum + (s['chars'] as int));
      final within = blocks
          .take(b)
          .fold<int>(0, (sum, s) => sum + s.text.length);
      fraction = (before + within) / math.max(1, index['chars'] as int? ?? 1);
    }
    if (mapEquals(previousLocation, location) &&
        (fraction - previousFraction).abs() < 0.000001) {
      return;
    }
    if (navigationGesture) {
      navigationGesture = false;
      navigationDone();
    }
    debounce?.cancel();
    debounce = Timer(
      const Duration(milliseconds: 400),
      () => queue(savePosition),
    );
    refresh();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    foreground = state == AppLifecycleState.resumed;
    if (!foreground) {
      pauseTracking();
      debounce?.cancel();
      queue(savePosition);
      queue(saveSession);
    } else {
      sampleClock();
      lastTouch = DateTime.now();
      if (!paused) stopwatch.start();
    }
  }

  @override
  void dispose() {
    closed = true;
    guide.dispose();
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
    tick?.cancel();
    debounce?.cancel();
    pauseTracking();
    WidgetsBinding.instance.removeObserver(this);
    searcher.dispose();
    positions.itemPositions.removeListener(changed);
    queue(savePosition);
    queue(saveSession);
    unawaited(close());
    super.dispose();
  }

  Future<void> close() async {
    await writes;
    await document?.dispose();
    if (file != null && await file!.parent.exists()) {
      await file!.parent.delete(recursive: true);
    }
  }

  Future<void> run(Future<void> Function() task) async {
    if (busy) return;
    touch();
    pauseTracking();
    setState(() => busy = true);
    try {
      await task();
    } catch (_) {
      if (mounted) failure(context);
    } finally {
      if (mounted) {
        setState(() => busy = false);
        touch();
      }
    }
  }

  Future<void> mark(
    String kind, {
    String text = '',
    Map<String, dynamic>? at,
    int? end,
    List<List<num>>? rects,
  }) async {
    if (!writable) return;
    var color = 'yellow';
    if (kind == 'highlight') {
      final result = await showDialog<String>(
        context: context,
        builder: (c) => SimpleDialog(
          title: Text(c.tr('rHighlightColor')),
          children: [
            for (final k in markColors.keys)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(c, k),
                child: Row(
                  children: [
                    Icon(Icons.circle, color: markColors[k]),
                    const SizedBox(width: 12),
                    Text(c.tr('rColor_$k')),
                  ],
                ),
              ),
          ],
        ),
      );
      if (result == null) return;
      color = result;
    }
    if (!mounted) return;
    final target = Map<String, dynamic>.from(at ?? location);
    await editFields(
      context,
      context.tr('rKind_$kind'),
      {'note': context.tr(kind == 'bookmark' ? 'rBookmarkLabel' : 'notes')},
      initial: {'note': ''},
      multiline: kind == 'bookmark' ? {} : {'note'},
      onSave: (v) async {
        if (!writable) throw StateError('access_expired');
        await widget.store.put(widget.book.id, kind, {
          'v': 1,
          'location': target,
          'text': text,
          'note': v['note']!,
          'color': color,
          'end': ?end,
          'rects': ?rects,
        });
        guide.event('${kind}Saved');
      },
    );
    await loadMarks();
  }

  Future<void> fromPdf(String action, PdfTextSelection selection) async {
    if (!selection.isCopyAllowed || !selection.hasSelectedText) return;
    final range = selection.textSelectionPointRange;
    if (range != null &&
        (range.end.text.pageNumber - range.start.text.pageNumber).abs() > 10) {
      failure(context);
      return;
    }
    final ranges = await selection.getSelectedTextRanges();
    final text = await selection.getSelectedText();
    if (text.length > 64000) {
      if (mounted) failure(context);
      return;
    }
    if (!mounted || ranges.isEmpty) return;
    final loc = {'kind': 'pdf', 'page': ranges.first.pageNumber};
    if (action == 'card') {
      await editReadingCard(
        context,
        widget.store,
        widget.book.id,
        () => writable,
        text: text,
        location: loc,
      );
    } else {
      await mark(
        action,
        text: text,
        at: loc,
        rects: [
          for (final r in ranges)
            for (final box in r.enumerateFragmentBoundingRects())
              [
                r.pageNumber,
                box.bounds.left,
                box.bounds.top,
                box.bounds.right,
                box.bounds.bottom,
              ],
        ],
      );
    }
  }

  Future<void> jump(Map<String, dynamic> target) async {
    if (isPdf) {
      await navigatePdf(target['page'] as int, duration: Duration.zero);
    } else {
      final i = sections.indexWhere((s) => s['key'] == target['section']);
      if (i >= 0) await loadSection(i, restore: target['block'] as int);
    }
    location = target;
    queue(savePosition);
  }

  Future<void> chapters() async {
    if (isPdf) {
      await editFields(
        context,
        context.tr('rJumpPage'),
        {'page': context.tr('rPage')},
        initial: {'page': '$page'},
        numberFields: {'page'},
        onSave: (v) async {
          final n = int.parse(v['page']!);
          if (n < 1 || n > document!.pages.length) {
            throw const FormatException('page');
          }
          final before = page;
          await navigatePdf(n, duration: Duration.zero);
          if (n != before) navigationDone();
        },
      );
    } else {
      final toc = (index['toc'] as List? ?? []).isNotEmpty
          ? index['toc'] as List
          : sections;
      final choice = await showModalBottomSheet<int>(
        context: context,
        isScrollControlled: true,
        builder: (c) => SafeArea(
          child: ListView.builder(
            itemCount: toc.length,
            itemBuilder: (c, i) => ListTile(
              title: Text('${i + 1}. ${toc[i]['title']}'),
              onTap: () => Navigator.pop(c, i),
            ),
          ),
        ),
      );
      if (choice != null) {
        final item = toc[choice];
        final i = sections.indexWhere((s) => s['key'] == item['key']);
        if (i >= 0) await loadSection(i, restore: item['block'] as int? ?? 0);
      }
    }
  }

  Future<void> search() async {
    final value = await editFields(
      context,
      context.tr('rSearchBook'),
      {'query': context.tr('search')},
      requiredFields: {'query'},
    );
    if (value == null || !mounted) return;
    if (isPdf) {
      searcher.startTextSearch(
        value['query']!,
        searchImmediately: true,
        goToFirstMatch: false,
        startPageNumber: page,
      );
      return;
    }
    final q = value['query']!.toLowerCase();
    final hits = <({int section, int block, String text})>[];
    for (var i = 0; i < sections.length && hits.length < 500; i++) {
      final list = await TextDocument.section(
        file!.path,
        source!.data['format'],
        sections[i]['key'],
      );
      for (var b = 0; b < list.length && hits.length < 500; b++) {
        if (list[b].text.toLowerCase().contains(q)) {
          hits.add((section: i, block: b, text: list[b].text));
        }
      }
    }
    if (!mounted) return;
    final choice = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      builder: (c) => SafeArea(
        child: ListView.builder(
          itemCount: math.max(1, hits.length),
          itemBuilder: (c, i) => hits.isEmpty
              ? ListTile(title: Text(c.tr('rNoMatches')))
              : ListTile(
                  title: Text(
                    hits[i].text,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => Navigator.pop(c, i),
                ),
        ),
      ),
    );
    if (choice != null) {
      await loadSection(hits[choice].section, restore: hits[choice].block);
    }
  }

  Future<void> appearance() async {
    final before = Map<String, dynamic>.from(settings);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => ReaderAppearanceSheet(
        isPdf: isPdf,
        settings: settings,
        paged: paged,
        onChange: (key, value) {
          settings[key] = value;
          if (key == 'paged') paged = value as bool;
          refresh();
          if (key == 'paged' && !paged) {
            final target = page;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && pdf.isReady) {
                unawaited(
                  pdf.goToPage(pageNumber: target, duration: Duration.zero),
                );
              }
            });
          }
        },
      ),
    );
    if (mapEquals(before, settings)) return;
    if (writable) {
      queue(() async {
        settingsRow = await widget.store.put(
          widget.book.id,
          'settings',
          settings,
          previous: settingsRow,
          id: '${widget.book.id}-settings',
        );
        guide.event('appearanceSaved');
      });
    } else {
      guide.event('appearanceSaved');
    }
  }

  void navigationDone() {
    if (!guide.active || guide.step.event != 'navigated') return;
    queue(() async {
      await savePosition();
      guide.event('navigated');
    });
  }

  Future<void> navigatePdf(
    int number, {
    Duration duration = const Duration(milliseconds: 200),
  }) async {
    touch();
    final target = number.clamp(1, document!.pages.length);
    if (paged) {
      if (pdf.isReady) {
        await pdf.goToPage(pageNumber: target, duration: Duration.zero);
      }
      if (!mounted) return;
      setState(() {
        page = target;
        location = {'kind': 'pdf', 'page': target};
        fraction = target / document!.pages.length;
      });
      queue(savePosition);
    } else {
      await pdf.goToPage(pageNumber: target, duration: duration);
    }
    navigationDone();
  }

  Future<void> thumbnails() async {
    final chosen = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      builder: (c) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(c).height * .8,
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 180,
              mainAxisExtent: 220,
            ),
            itemCount: document!.pages.length,
            itemBuilder: (c, i) => InkWell(
              onTap: () => Navigator.pop(c, i + 1),
              child: Column(
                children: [
                  Expanded(
                    child: PdfPageView(
                      document: document,
                      pageNumber: i + 1,
                      maximumDpi: 40,
                    ),
                  ),
                  Text('${i + 1}'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (chosen != null) await navigatePdf(chosen);
  }

  Widget textBlock(int index) {
    final block = blocks[index];
    final section = sections[sectionIndex];
    return ReaderTextBlock(
      key: ValueKey('reader-block-$sectionIndex-$index'),
      blockIndex: index,
      block: block,
      sectionKey: section['key'],
      epubPath: source!.data['format'] == 'epub' ? file!.path : null,
      settings: settings,
      marks: marks,
      dark: dark,
      ink: ink,
      onSelection: (selection) {
        selected = selection.textInside(block.text);
        selectionLocation = {
          'kind': 'text',
          'section': section['key'],
          'label': section['title'],
          'block': index,
          'offset': selection.start,
        };
        selectionEnd = selection.end;
      },
      onAction: writable && !loading && error == null
          ? (action) {
              final text = selected, at = selectionLocation, end = selectionEnd;
              if (action == 'card') {
                unawaited(
                  run(
                    () => editReadingCard(
                      context,
                      widget.store,
                      widget.book.id,
                      () => writable,
                      text: text,
                      location: at,
                    ),
                  ),
                );
              } else {
                unawaited(
                  run(() => mark(action, text: text, at: at, end: end)),
                );
              }
            }
          : null,
    );
  }

  void restorePdfPosition(PdfViewerController controller) {
    if (pdfRestored) return;
    pdfRestored = true;
    final saved = initialPdfLocation;
    if (saved?['y'] is! num) return;
    final rect = controller.layout.pageLayouts[page - 1];
    unawaited(
      controller.goToPosition(
        documentOffset: Offset(
          rect.left,
          rect.top + rect.height * (saved!['y'] as num),
        ),
        zoom: saved['zoom'] is num
            ? (saved['zoom'] as num).toDouble().clamp(
                controller.minScale,
                controller.maxScale,
              )
            : null,
      ),
    );
  }

  Future<void> handleMenu(BuildContext c, String v) async {
    if (v == 'help') {
      await help();
      return;
    }
    if (v == 'thumbnails') {
      await thumbnails();
      return;
    }
    if (v == 'hub') {
      await Navigator.push(
        c,
        MaterialPageRoute(
          builder: (_) => ReadingHub(
            store: widget.store,
            book: widget.book.id,
            title: widget.book.data['title'],
            allowed: () => writable,
            jump: jump,
          ),
        ),
      );
      return;
    }
    if (v == 'annotation') {
      await mark('annotation');
      return;
    }
    if (v == 'card' && c.mounted) {
      await editReadingCard(
        c,
        widget.store,
        widget.book.id,
        () => writable,
        location: location,
        onSaved: () => guide.event('cardSaved'),
      );
    }
    if (v == 'finish' && writable) {
      final current = await widget.store.records.get(widget.book.id);
      await widget.store.records.save(
        'book',
        BookLibrary.update(current.data, {
          'status': 'completed',
          'finishedOn': DateTime.now().toIso8601String().substring(0, 10),
        }),
        previous: current,
      );
    }
    if (v == 'pause') {
      paused = !paused;
      if (paused) {
        pauseTracking();
      } else {
        touch();
      }
      refresh();
      queue(saveSession);
    }
  }

  Future<String> _textForReading() async {
    if (loading || error != null) return '';
    if (!isPdf) return blocks.map((block) => block.text).join('\n');
    final pages = document?.pages;
    final current = pdf.isReady ? (pdf.pageNumber ?? page) : page;
    if (pages == null || current < 1 || current > pages.length) return '';
    return (await pages[current - 1].loadText())?.fullText ?? '';
  }

  @override
  Widget build(BuildContext c) =>
      VoiceReadRegion(read: _textForReading, child: _reader(c));

  Widget _reader(BuildContext c) => GuideHost(
    controller: guide,
    targets: {
      'content': contentAnchor,
      'bookmark': bookmarkAnchor,
      'appearance': appearanceAnchor,
      'menu': menuAnchor,
      'navigation': navigationAnchor,
    },
    child: Scaffold(
      backgroundColor: paper,
      appBar: controls
          ? ReaderToolbar(
              title: widget.book.data['title'] as String,
              paper: paper,
              ink: ink,
              isPdf: isPdf,
              paged: paged,
              ready: !loading && error == null,
              hasPdfDocument: document != null,
              writable: writable,
              paused: paused,
              appearanceAnchor: appearanceAnchor,
              bookmarkAnchor: bookmarkAnchor,
              menuAnchor: menuAnchor,
              onSearch: () => unawaited(run(search)),
              onAppearance: () => unawaited(run(appearance)),
              onBookmark: () => unawaited(run(() => mark('bookmark'))),
              onMenu: (value) => unawaited(run(() => handleMenu(c, value))),
            )
          : null,
      body: SafeArea(
        top: !controls,
        child: Column(
          children: [
            if (saveError != null)
              MaterialBanner(
                content: Text(saveError!),
                actions: [
                  TextButton(
                    onPressed: () {
                      queue(savePosition);
                      queue(saveSession);
                    },
                    child: Text(c.tr('retry')),
                  ),
                ],
              ),
            if (error != null)
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('${c.tr('rOpenFailed')}\n\n$error'),
                        const SizedBox(height: 16),
                        if (source != null)
                          FilledButton.icon(
                            key: const Key('reader-relink'),
                            onPressed: busy ? null : () => run(relink),
                            icon: const Icon(Icons.link),
                            label: Text(c.tr('rRelink')),
                          ),
                      ],
                    ),
                  ),
                ),
              )
            else if (loading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else
              Expanded(
                child: Listener(
                  key: contentAnchor,
                  onPointerDown: (_) {
                    navigationGesture =
                        guide.active && guide.step.id == 'navigate';
                    touch();
                  },
                  onPointerSignal: (_) => touch(),
                  child: isPdf
                      ? ReaderPdfViewport(
                          document: document!,
                          pdf: pdf,
                          searcher: searcher,
                          page: page,
                          paged: paged,
                          paper: paper,
                          marks: marks,
                          onReady: restorePdfPosition,
                          onPositionChanged: changed,
                          onAction: writable
                              ? (action, selection) => unawaited(
                                  run(() => fromPdf(action, selection)),
                                )
                              : null,
                        )
                      : NotificationListener<ScrollNotification>(
                          onNotification: (n) {
                            if (n is ScrollUpdateNotification) changed();
                            return false;
                          },
                          child: ScrollablePositionedList.builder(
                            key: ValueKey(
                              'text-section-$sectionIndex-$sectionGeneration',
                            ),
                            itemScrollController: itemScroll,
                            itemPositionsListener: positions,
                            initialScrollIndex: (location['block'] as int? ?? 0)
                                .clamp(0, math.max(0, blocks.length - 1)),
                            padding: EdgeInsets.symmetric(
                              horizontal: (settings['margin'] as num)
                                  .toDouble(),
                              vertical: 20,
                            ),
                            itemCount: blocks.length,
                            itemBuilder: (c, i) => Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 900,
                                ),
                                child: textBlock(i),
                              ),
                            ),
                          ),
                        ),
                ),
              ),
            if (!loading && error == null && isPdf && searcher.pattern != null)
              ReaderPdfSearchControls(searcher: searcher),
            if (!loading && error == null && paged)
              Text(c.tr('rPagedHint'), style: TextStyle(color: ink)),
            if (!loading && error == null && controls)
              ReaderNavigation(
                anchor: navigationAnchor,
                progress: fraction,
                isPdf: isPdf,
                position: isPdf ? page : sectionIndex + 1,
                count: isPdf ? document!.pages.length : sections.length,
                onChoose: () => unawaited(run(chapters)),
                onMove: (delta) {
                  if (isPdf) {
                    unawaited(navigatePdf(page + delta));
                  } else {
                    unawaited(run(() => loadSection(sectionIndex + delta)));
                  }
                },
              ),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: IconButton(
                key: const Key('reader-controls'),
                tooltip: c.tr('rToggleControls'),
                onPressed: () {
                  setState(() => controls = !controls);
                  unawaited(
                    SystemChrome.setEnabledSystemUIMode(
                      controls
                          ? SystemUiMode.edgeToEdge
                          : SystemUiMode.immersiveSticky,
                    ),
                  );
                },
                icon: Icon(
                  controls ? Icons.fullscreen : Icons.fullscreen_exit,
                  color: ink,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
