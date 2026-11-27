import 'package:integration_test/integration_test.dart';

import '../test/support/data_safety_cases.dart';
import 'review_guard.dart';

import 'package:flutter_test/flutter_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(requireReviewPackage);
  registerDataSafetyTests();
}
