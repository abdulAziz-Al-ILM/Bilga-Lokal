import 'dart:async';

import 'package:flutter/foundation.dart';

/// Fixed technical phase names only. Never pass exceptions, SQL, IDs or content.
class NotesWidgetLoading {
  static const timeout = Duration(seconds: 15);

  static void trace(String phase) {
    if (kDebugMode) debugPrint('NotesWidgetLoading $phase');
  }

  static Future<T> step<T>(
    String phase,
    Future<T> Function() action, {
    Duration limit = timeout,
  }) async {
    trace('$phase.begin');
    try {
      final result = await action().timeout(limit);
      trace('$phase.ready');
      return result;
    } on TimeoutException {
      trace('$phase.timeout');
      rethrow;
    } catch (_) {
      trace('$phase.unavailable');
      rethrow;
    }
  }
}

/// Stop observing an in-flight read when its owner leaves. The underlying
/// singleton DB open is not cancelled/reset, and its late result stays handled.
class NotesWidgetLoadScope {
  final _closed = Completer<void>();

  Future<T> step<T>(String phase, Future<T> Function() action) =>
      NotesWidgetLoading.step(
        phase,
        () => Future.any<T>([
          if (_closed.isCompleted)
            Future<T>.error(StateError('disposed'))
          else
            action(),
          _closed.future.then<T>((_) => throw StateError('disposed')),
        ]),
      );

  void dispose() {
    if (!_closed.isCompleted) _closed.complete();
  }
}
