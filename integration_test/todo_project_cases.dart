import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

import '../test/support/todo_project_cases.dart';
import '../test/support/todo_project_ui_cases.dart';
import 'review_guard.dart';

Future<Directory> _directory() async {
  await requireReviewPackage();
  return (await getTemporaryDirectory()).createTemp('review-projects-');
}

void registerTodoProjectCases(IntegrationTestWidgetsFlutterBinding binding) {
  group(
    'Encrypted projects',
    () => registerTodoProjectTests(createDirectory: _directory, secure: true),
  );
  registerTodoProjectUiTests(
    createDirectory: _directory,
    secure: true,
    includeCompact: false,
    onUiVerified: () => binding.reportData = {
      ...?binding.reportData,
      'projects': {
        'encryptedFixtures': true,
        'realNestedListsAndTaskProgress': true,
        'statusEditAndConvertPreserveTasks': true,
      },
    },
  );
}
