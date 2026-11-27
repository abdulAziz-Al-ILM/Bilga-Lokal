import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Refuse device tests before opening any database outside the isolated app.
Future<void> requireReviewPackage() async {
  final path = (await getTemporaryDirectory()).path;
  if (!kDebugMode || !path.contains('/com.ilmmizan.bilga.review/')) {
    throw StateError(
      'Device tests require the debug-only Bilga Review package',
    );
  }
}
