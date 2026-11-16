import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

import '../test/support/experience_data_cases.dart';
import '../test/support/experience_ui_cases.dart';
import 'review_guard.dart';

Future<Directory> fixture() async {
  await requireReviewPackage();
  return (await getTemporaryDirectory()).createTemp('review-experiences-');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(requireReviewPackage);
  registerExperienceDataCases(createDirectory: fixture, secure: true);
  registerExperienceUiCases(
    createDirectory: fixture,
    secure: true,
    includeCompact: false,
  );
}
