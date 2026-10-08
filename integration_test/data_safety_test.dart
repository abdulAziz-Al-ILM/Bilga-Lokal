import 'package:integration_test/integration_test.dart';

import '../test/support/data_safety_cases.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  registerDataSafetyTests();
}
