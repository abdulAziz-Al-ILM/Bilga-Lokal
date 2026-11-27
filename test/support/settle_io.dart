import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Yield actual I/O while a visible route saves/loads. Advancing fake frames
/// alone can starve SQLite workers on a busy CI runner. Never discard assertions
/// or wait forever for a real stuck operation. Modal confirmation stays usable.
Future<void> settleIo(WidgetTester tester) async {
  final watch = Stopwatch()..start();
  Future<void> frame() async {
    await tester.pump(const Duration(milliseconds: 40));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
  }

  for (var i = 0; i < 20; i++) {
    await frame();
  }
  bool loading() => find
      .byWidgetPredicate(
        (w) =>
            w is LinearProgressIndicator && w.value == null ||
            w is CircularProgressIndicator && w.value == null,
      )
      .evaluate()
      .any((e) => ModalRoute.of(e)?.isCurrent != false);
  while (loading()) {
    if (watch.elapsed > const Duration(seconds: 20)) {
      fail('Visible UI load/save did not finish within 20 real seconds');
    }
    await frame();
  }
  // Finish route/keyboard animations, including a spinner behind a confirmation.
  for (var i = 0; i < 8; i++) {
    await frame();
  }
}
