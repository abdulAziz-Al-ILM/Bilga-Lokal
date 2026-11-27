import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

import '../test/support/finance_account_data_cases.dart';
import '../test/support/finance_account_ui_cases.dart';
import '../test/support/finance_transaction_ui_cases.dart';
import '../test/support/finance_reports_ui_cases.dart';
import 'review_guard.dart';

Future<Directory> _directory() async {
  await requireReviewPackage();
  return (await getTemporaryDirectory()).createTemp('review-finance-');
}

void registerFinanceAccountCases(IntegrationTestWidgetsFlutterBinding binding) {
  group(
    'Encrypted finance accounts',
    () => registerFinanceAccountDataTests(
      createDirectory: _directory,
      secure: true,
    ),
  );
  registerFinanceAccountUiTests(
    createDirectory: _directory,
    secure: true,
    includeCompact: false,
    onUiVerified: () => binding.reportData = {
      ...?binding.reportData,
      'financeAccounts': {
        'encryptedFixtures': true,
        'createTransferReconcileArchiveRestore': true,
        'immutableAuditAndConservedTransferTotal': true,
        'syntheticEntitlementOnly': true,
      },
    },
  );
  registerFinanceTransactionUiTests(
    createDirectory: _directory,
    secure: true,
    includeCompact: false,
    onUiVerified: () => binding.reportData = {
      ...?binding.reportData,
      'financeTransactionHistory': {
        'encryptedFixtures': true,
        'realEditRestoreVoidRestore': true,
        'otherTransactionsPreserved': true,
        'syntheticEntitlementOnly': true,
      },
    },
  );
  registerFinanceReportsUiTests(
    createDirectory: _directory,
    secure: true,
    includeCompact: false,
    onUiVerified: () => binding.reportData = {
      ...?binding.reportData,
      'financeReports': {
        'encryptedFixtures': true,
        'realMainRouteFiltersChartAndRefresh': true,
        'futureAndVoidedEntriesExcluded': true,
        'noReportWrites': true,
      },
    },
  );
}
