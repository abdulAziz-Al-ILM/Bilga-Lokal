import 'dart:io';

import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

import '../test/support/habit_guidance_ui_cases.dart';
import 'review_guard.dart';

Future<Directory> _directory() async {
  await requireReviewPackage();
  return (await getTemporaryDirectory()).createTemp('review-habit-guidance-');
}

void registerHabitGuidanceCases(IntegrationTestWidgetsFlutterBinding binding) {
  registerHabitGuidanceUiCases(
    createDirectory: _directory,
    secure: true,
    includeCompact: false,
  );
}
