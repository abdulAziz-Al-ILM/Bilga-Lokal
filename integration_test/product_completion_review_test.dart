import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

import '../test/support/finance_planning_data_cases.dart';
import '../test/support/finance_planning_ui_cases.dart';
import '../test/support/help_hub_ui_cases.dart';
import '../test/support/voice_ui_cases.dart';
import '../test/support/experience_data_cases.dart';
import '../test/support/experience_ui_cases.dart';
import '../test/support/reading_ui_cases.dart';
import '../test/support/reading_data_cases.dart';
import '../test/support/reading_pdf_ui_cases.dart';
import '../test/support/habit_advanced_data_cases.dart';
import '../test/support/habit_advanced_ui_cases.dart';
import '../test/support/habit_guidance_ui_cases.dart';
import 'review_guard.dart';

Future<Directory> fixture() async {
  await requireReviewPackage();
  return (await getTemporaryDirectory()).createTemp(
    'review-nonvoice-completion-',
  );
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(requireReviewPackage);
  group(
    'Advanced Habit data',
    () =>
        registerAdvancedHabitDataCases(createDirectory: fixture, secure: true),
  );
  group(
    'Habit creation guides',
    () => registerHabitGuidanceUiCases(
      createDirectory: fixture,
      secure: true,
      includeCompact: false,
    ),
  );
  group(
    'Advanced Habit UI',
    () => registerAdvancedHabitUiCases(
      createDirectory: fixture,
      secure: true,
      includeCompact: false,
    ),
  );
  group(
    'Finance planning data',
    () => registerFinancePlanningDataCases(
      createDirectory: fixture,
      secure: true,
    ),
  );
  group(
    'Finance planning UI',
    () => registerFinancePlanningUiCases(
      createDirectory: fixture,
      secure: true,
      includeCompact: false,
    ),
  );
  group(
    'Help Hub and Notes/Tasks guides',
    () => registerHelpHubUiCases(
      createDirectory: fixture,
      secure: true,
      includeCompact: false,
    ),
  );
  group(
    'Voice preview and actual module actions',
    () => registerVoiceUiCases(
      createDirectory: fixture,
      secure: true,
      includeCompact: false,
    ),
  );
  group(
    'Experience data',
    () => registerExperienceDataCases(createDirectory: fixture, secure: true),
  );
  group(
    'Experience UI',
    () => registerExperienceUiCases(
      createDirectory: fixture,
      secure: true,
      includeCompact: false,
    ),
  );
  group(
    'Book reading UI',
    () => registerReadingUiCases(createDirectory: fixture, secure: true),
  );
  group(
    'Native PDF reader',
    () => registerReadingPdfUiCases(createDirectory: fixture, secure: true),
  );
  group(
    'Encrypted reading recovery data',
    () => registerReadingDataCases(createDirectory: fixture, secure: true),
  );
}
