import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'book_library_cases.dart';
import 'app_journey_cases.dart';
import 'review_guard.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(requireReviewPackage);
  registerAppJourney(binding);
  registerBookLibraryCases(binding);
}
