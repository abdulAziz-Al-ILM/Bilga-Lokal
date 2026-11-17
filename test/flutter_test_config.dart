import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:bilga/core/strings.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Catalogs now exceed AssetBundle's 50KiB compute threshold. Load public
  // strings before widget FakeAsync zones; retain real isolate decoding and
  // application behavior rather than replacing it with a mock or shortening data.
  await Strings.load();
  await testMain();
}
