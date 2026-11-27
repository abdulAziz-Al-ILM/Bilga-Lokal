import 'dart:async';
import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// Opt-in Review measurements. Names are fixed labels, with no user content.
class ReviewPerformance {
  static const enabled = bool.fromEnvironment('BILGA_PROFILE_FRAMES');
  static final List<FrameTiming> _frames = [];
  static Timer? _timer;

  static void start() {
    if (!enabled) return;
    SchedulerBinding.instance.addTimingsCallback((batch) {
      _frames.addAll(batch);
      if (_frames.length > 2000) _frames.removeRange(0, _frames.length - 2000);
      _timer ??= Timer(const Duration(seconds: 12), _report);
    });
  }

  static void _report() {
    _timer = null;
    if (_frames.isEmpty) return;
    final frames = List<FrameTiming>.of(_frames);
    _frames.clear();
    String stats(Iterable<Duration> durations) {
      final times = durations.map((time) => time.inMicroseconds).toList()
        ..sort();
      String at(double percentile) =>
          (times[((times.length - 1) * percentile).round()] / 1000)
              .toStringAsFixed(2);
      return '${at(.5)}/${at(.95)}/${at(.99)}';
    }

    final slow = frames
        .where(
          (f) =>
              f.buildDuration.inMicroseconds > 16667 ||
              f.rasterDuration.inMicroseconds > 16667,
        )
        .length;
    debugPrint(
      'BilgaProfile frames=${frames.length} over60Hz=$slow '
      'buildMs=${stats(frames.map((f) => f.buildDuration))} '
      'rasterMs=${stats(frames.map((f) => f.rasterDuration))} '
      'totalMs=${stats(frames.map((f) => f.totalSpan))}',
    );
  }

  static Future<T> measure<T>(
    String name,
    Future<T> Function() operation,
  ) async {
    if (!enabled) return operation();
    final watch = Stopwatch()..start();
    final task = TimelineTask()..start(name);
    try {
      return await operation();
    } finally {
      task.finish();
      debugPrint('BilgaProfile $name ms=${watch.elapsedMicroseconds / 1000}');
    }
  }
}
