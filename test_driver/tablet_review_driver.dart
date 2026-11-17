import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver(
  // The consolidated secure six-module suite includes SQLCipher and native PDF
  // recovery; do not detach while its real device cases are still executing.
  timeout: const Duration(minutes: 25),
  responseDataCallback: (data) =>
      writeResponseData(data, destinationDirectory: 'build/review/evidence'),
);
