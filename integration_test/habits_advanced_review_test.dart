import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

import '../test/support/habit_advanced_data_cases.dart';
import '../test/support/habit_advanced_ui_cases.dart';
import '../test/support/habit_guidance_ui_cases.dart';
import 'review_guard.dart';

Future<Directory> fixture() async {
  await requireReviewPackage();
  return (await getTemporaryDirectory()).createTemp('review-advanced-habits-');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(requireReviewPackage);
  registerAdvancedHabitDataCases(createDirectory: fixture, secure: true);
  registerHabitGuidanceUiCases(
    createDirectory: fixture,
    secure: true,
    includeCompact: false,
  );
  registerAdvancedHabitUiCases(
    createDirectory: fixture,
    secure: true,
    includeCompact: false,
  );
}
