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
