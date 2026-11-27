import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/strings.dart';
import 'guide_controller.dart';

/// Spots actual render objects. Only the highlighted control and help panel
/// receive touches. A missing/off-screen target falls back to unobstructed help.
class GuideHost extends StatefulWidget {
  final GuideController controller;
  final Map<String, GlobalKey> targets;
  final Widget child;
  const GuideHost({
    super.key,
    required this.controller,
    required this.targets,
    required this.child,
  });
  @override
  State<GuideHost> createState() => _GuideHostState();
}

class _GuideHostState extends State<GuideHost> with WidgetsBindingObserver {
  final hostKey = GlobalKey();
  Rect? target;
  Timer? timer;
  String? requested;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.controller.addListener(changed);
    changed();
  }

  @override
  void didUpdateWidget(GuideHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(changed);
      widget.controller.addListener(changed);
      changed();
    }
  }

  void changed() {
    requested = null;
    timer?.cancel();
    if (widget.controller.active) {
      timer = Timer.periodic(
        const Duration(milliseconds: 180),
        (_) => locate(),
      );
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => locate());
    if (mounted) setState(() => target = null);
  }

  @override
  void didChangeMetrics() {
    WidgetsBinding.instance.addPostFrameCallback((_) => locate());
  }

  void locate() {
    if (!mounted ||
        !widget.controller.active ||
        ModalRoute.of(context)?.isCurrent == false) {
      return;
    }
    final step = widget.controller.step;
    final candidate = widget.targets[step.target]?.currentContext;
    final anchor =
        candidate != null && ModalRoute.of(candidate) == ModalRoute.of(context)
        ? candidate
        : null;
    if (anchor != null && requested != step.id) {
      requested = step.id;
      unawaited(
        Scrollable.ensureVisible(
          anchor,
          alignment: .25,
          duration: const Duration(milliseconds: 180),
        ),
      );
    }
    final box = anchor?.findRenderObject();
    final host = hostKey.currentContext?.findRenderObject();
    Rect? rect;
    if (box is RenderBox &&
        box.attached &&
        box.hasSize &&
        host is RenderBox &&
        host.hasSize) {
      final raw = box.localToGlobal(Offset.zero, ancestor: host) & box.size;
      final visible = raw.intersect(Offset.zero & host.size);
      if (!visible.isEmpty && visible.height >= math.min(40, raw.height)) {
        rect = visible;
      }
    }
    if (rect != target) setState(() => target = rect);
  }

  @override
  void dispose() {
    timer?.cancel();
    widget.controller.removeListener(changed);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final guide = widget.controller;
    final visible = guide.active && ModalRoute.of(context)?.isCurrent != false;
    return Stack(
      key: hostKey,
      fit: StackFit.expand,
      children: [
        widget.child,
        if (visible)
          LayoutBuilder(
            builder: (context, constraints) {
              final view = MediaQuery.of(context);
              final available = constraints.maxHeight - view.viewInsets.bottom;
              final rect = target;
              final top = rect != null && rect.center.dy > available / 2;
              return Stack(
                children: [
                  if (rect != null) ...[
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: _Spotlight(
                            rect,
                            Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                    ),
                    // Independent barriers leave a real hit-test hole for the control.
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: rect.top,
                      child: const _Block(),
                    ),
                    Positioned(
                      top: rect.bottom,
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: const _Block(),
                    ),
                    Positioned(
                      top: rect.top,
                      height: rect.height,
                      left: 0,
                      width: rect.left,
                      child: const _Block(),
                    ),
                    Positioned(
                      top: rect.top,
                      height: rect.height,
                      right: 0,
                      width: math.max(0, constraints.maxWidth - rect.right),
                      child: const _Block(),
                    ),
                  ],
                  Positioned(
                    top: top ? view.padding.top + 8 : null,
                    bottom: top
                        ? null
                        : view.viewInsets.bottom + view.padding.bottom + 8,
                    left: 12,
                    right: 12,
                    child: Align(
                      alignment: Alignment.center,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: 560,
                          maxHeight: math.max(100, available * .43),
                        ),
                        child: Material(
                          elevation: 12,
                          borderRadius: BorderRadius.circular(16),
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHigh,
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Semantics(
                                  liveRegion: true,
                                  child: Text(
                                    '${context.tr('gStep')} ${guide.index + 1} / ${guide.steps.length}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(context.tr(guide.step.text)),
                                if (rect == null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(context.tr('gMissing')),
                                  ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 4,
                                  children: [
                                    if (guide.canBack)
                                      TextButton(
                                        key: const Key('guide-back'),
                                        onPressed: guide.back,
                                        child: Text(context.tr('gBack')),
                                      ),
                                    if (guide.canNext)
                                      FilledButton(
                                        key: const Key('guide-next'),
                                        onPressed: guide.next,
                                        child: Text(
                                          context.tr(
                                            guide.index ==
                                                    guide.steps.length - 1
                                                ? 'gFinish'
                                                : 'gNext',
                                          ),
                                        ),
                                      ),
                                    TextButton(
                                      key: const Key('guide-skip'),
                                      onPressed: guide.exit,
                                      child: Text(context.tr('gSkip')),
                                    ),
                                    TextButton(
                                      key: const Key('guide-exit'),
                                      onPressed: guide.exit,
                                      child: Text(context.tr('gExit')),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
      ],
    );
  }
}

class _Block extends StatelessWidget {
  const _Block();
  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: () {},
    child: const SizedBox.expand(),
  );
}

class _Spotlight extends CustomPainter {
  final Rect rect;
  final Color accent;
  _Spotlight(this.rect, this.accent);
  @override
  void paint(Canvas canvas, Size size) {
    final hole = RRect.fromRectAndRadius(rect, const Radius.circular(8));
    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRRect(hole);
    canvas.drawPath(path, Paint()..color = Colors.black54);
    canvas.drawRRect(
      hole,
      Paint()
        ..color = accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  @override
  bool shouldRepaint(_Spotlight oldDelegate) =>
      rect != oldDelegate.rect || accent != oldDelegate.accent;
}
