import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

import '../test/support/task_template_cases.dart';
import '../test/support/task_template_ui_cases.dart';
import 'review_guard.dart';

Future<Directory> _directory() async {
  await requireReviewPackage();
  return (await getTemporaryDirectory()).createTemp('review-task-templates-');
}

void registerTaskTemplateCases(IntegrationTestWidgetsFlutterBinding binding) {
  group(
    'Encrypted custom task templates',
    () => registerTaskTemplateTests(createDirectory: _directory, secure: true),
  );
  registerTaskTemplateUiTests(
    createDirectory: _directory,
    secure: true,
    includeCompact: false,
    onUiVerified: () => binding.reportData = {
      ...?binding.reportData,
      'taskTemplates': {
        'encryptedFixtures': true,
        'realCreatePreviewApplyEditSnapshotDelete': true,
      },
    },
  );
}
