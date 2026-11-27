import 'dart:async';
import 'dart:convert';

import 'package:bilga/features/agent/agent_access.dart';
import 'package:bilga/core/strings.dart';
import 'package:bilga/features/agent/core_access_gate.dart';
import 'package:bilga/features/agent/core_purchase_verifier.dart';
import 'package:bilga/features/agent/trial_state.dart';
import 'package:bilga/features/agent/trial_store.dart';
import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

const install = '0123456789abcdef0123456789abcdef';
const beginning = 1791705600000;

class FakeTrials implements TrialStore {
  TrialState state = TrialState.start(
    const TrialClock(beginning, 1000, 1),
    install,
  );
  bool broken = false;
  bool debug = false;
  @override
  Future<(TrialState, bool)> load({bool acknowledge = false}) async {
    if (broken) throw StateError('storage');
    if (acknowledge) {
      state = state.advance(
        TrialClock(state.wallHigh, state.elapsed, state.boot),
        introduced: true,
      );
    }
    return (state, debug);
  }

  void expire() => state = state.advance(
    const TrialClock(beginning + 40 * Duration.millisecondsPerDay, 2000, 1),
  );
}

class FakeBilling implements BillingGateway {
  final events = StreamController<List<PurchaseDetails>>.broadcast();
  Future<void> close() => events.close();
  bool online = false, pastFails = false, completeFails = false;
  int completes = 0, buys = 0;
  List<GooglePlayPurchaseDetails> restored = [];
  @override
  Stream<List<PurchaseDetails>> get purchases => events.stream;
  @override
  Future<bool> available() async => online;
  @override
  Future<ProductDetailsResponse> products(Set<String> ids) async {
    expect(ids, {AgentAccess.core});
    return ProductDetailsResponse(
      productDetails: [],
      notFoundIDs: ids.toList(),
    );
  }

  @override
  Future<QueryPurchaseDetailsResponse> past() async {
    if (pastFails) throw StateError('Play down');
    return QueryPurchaseDetailsResponse(pastPurchases: restored);
  }

  @override
  Future<bool> buy(ProductDetails product) async {
    buys++;
    return true;
  }

  @override
  Future<void> complete(PurchaseDetails purchase) async {
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('bilga.receipt.${purchase.productID}'), isNotNull);
    completes++;
    if (completeFails) throw StateError('ack unavailable');
  }
}

GooglePlayPurchaseDetails purchase(
  String product, {
  bool acknowledged = false,
}) => GooglePlayPurchaseDetails.fromPurchase(
  PurchaseWrapper(
    orderId: 'test-order',
    packageName: 'com.ilmmizan.bilga',
    purchaseTime: beginning,
    purchaseToken: 'token-$product',
    signature: 'Google-signature',
    products: [product],
    isAutoRenewing: false,
    originalJson: jsonEncode({
      'packageName': 'com.ilmmizan.bilga',
      'productId': product,
      'purchaseState': 0,
      'purchaseToken': 'token-$product',
    }),
    isAcknowledged: acknowledged,
    purchaseState: PurchaseStateWrapper.purchased,
  ),
).single;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(Strings.load);
  late FakeTrials trials;
  late FakeBilling billing;
  final controllers = <AgentAccess>[];
  AgentAccess make({ReceiptVerifier? verify, CorePurchaseVerifier? core}) {
    final access = AgentAccess(
      trials: trials,
      billing: billing,
      receiptVerifier: verify ?? (_, _, _) async => true,
      coreVerifier: core,
    );
    controllers.add(access);
    return access;
  }

  Future<void> ready(AgentAccess a) async {
    await a.init();
    await Future<void>.delayed(Duration.zero);
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    trials = FakeTrials();
    billing = FakeBilling();
  });
  test(
    'Release/profile and non-debug Android builds cannot enable test scenarios',
    () {
      for (final scenario in ['expired', 'billing_unavailable']) {
        expect(
          AgentAccess.debugScenarioAllowed(false, true, scenario),
          isFalse,
        );
        expect(
          AgentAccess.debugScenarioAllowed(true, false, scenario),
          isFalse,
        );
        expect(AgentAccess.debugScenarioAllowed(true, true, scenario), isTrue);
      }
      expect(
        AgentAccess.debugScenarioAllowed(true, true, 'unlimited'),
        isFalse,
      );
      expect(AgentAccess.debugScenarioAllowed(true, true, 'active'), isFalse);
    },
  );
  test('Configured debug scenario only restricts trial or simulates outage; never owns a product', () async {
    trials.debug = true;
    final a = make();
    await ready(a);
    const scenario = String.fromEnvironment('BILGA_TRIAL_TEST');
    expect(a.trialActive, scenario != 'expired');
    expect(a.entitled, isFalse);
    expect(a.owned, isEmpty);
    expect(a.trial!.started, beginning);
    expect(a.trial!.remainingDays, 40);
  });
  tearDown(() async {
    await Future<void>.delayed(Duration.zero);
    for (final a in controllers) {
      a.dispose();
    }
    controllers.clear();
    await billing.close();
  });

  test(
    'First launch works offline for Core and finance; never marks paid',
    () async {
      final a = make();
      await ready(a);
      expect(a.trialActive, isTrue);
      expect(a.allowed, isTrue);
      expect(a.has(AgentAccess.finance), isTrue);
      expect(a.entitled, isFalse);
      expect(a.owned, isEmpty);
      expect(a.has(AgentAccess.turbo), isFalse);
      expect(a.has('unknown-product'), isFalse);
      expect(a.error, 'unavailable');
    },
  );
  test(
    'Billing startup cannot hold local trial initialization hostage',
    () async {
      final a = make();
      await a.init();
      expect(a.initialized, isTrue);
      expect(a.coreAllowed, isTrue);
    },
  );
  test('Expiry and failed/empty restore never renew trial', () async {
    trials.expire();
    final a = make();
    await ready(a);
    billing.pastFails = true;
    await a.restore();
    expect(a.coreAllowed, isFalse);
    expect(a.owned, isEmpty);
    expect(a.trial!.started, beginning);
    billing.pastFails = false;
    await a.restore();
    expect(a.coreAllowed, isFalse);
  });
  test(
    'Legacy receipt migrates without deleting old key; empty Play preserves it',
    () async {
      final p = purchase(AgentAccess.productId);
      final old = jsonEncode({
        'json': p.billingClientPurchase.originalJson,
        'signature': 'Google-signature',
      });
      SharedPreferences.setMockInitialValues({
        'bilga.agent.receipt': old,
        'bilga.nickname': 'Kept',
      });
      trials.expire();
      final a = make();
      await ready(a);
      expect(a.corePurchased, isTrue);
      expect(a.allowed, isTrue);
      await a.restore();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('bilga.agent.receipt'), old);
      expect(prefs.getString('bilga.nickname'), 'Kept');
      expect(a.corePurchased, isTrue);
      billing.pastFails = true;
      await a.restore();
      expect(a.corePurchased, isTrue);
    },
  );
  test(
    'Invalid legacy proof is preserved but grants no permanent rights',
    () async {
      const raw = '{"json":"forged","signature":"forged"}';
      SharedPreferences.setMockInitialValues({
        'bilga.receipt.bilga_finance': raw,
      });
      trials.expire();
      final a = make(verify: (_, _, _) async => false);
      await ready(a);
      expect(a.coreAllowed, isFalse);
      expect(
        (await SharedPreferences.getInstance()).getString(
          'bilga.receipt.bilga_finance',
        ),
        raw,
      );
    },
  );
  test('Upgrade alone does not grandfather a full paid entitlement', () async {
    final a = make();
    await ready(a);
    trials.expire();
    await a.updateTrial();
    await a.handle(purchase(AgentAccess.upgrade));
    expect(a.entitled, isFalse);
    expect(a.allowed, isFalse);
  });
  test('Pending, cancelled and forged purchases grant nothing and are not acknowledged', () async {
    trials.expire();
    final a = make(verify: (_, _, _) async => false);
    await ready(a);
    for (final status in [
      PurchaseStatus.pending,
      PurchaseStatus.canceled,
      PurchaseStatus.error,
      PurchaseStatus.purchased,
    ]) {
      final p = purchase(AgentAccess.productId)..status = status;
      await a.handle(p);
      expect(a.owned, isEmpty);
      expect(a.coreAllowed, isFalse);
    }
    expect(billing.completes, 0);
  });
  test('Missing server configuration cannot turn genuine Core receipt into paid access', () async {
    trials.expire();
    final a = make();
    await ready(a);
    await a.handle(purchase(AgentAccess.core));
    expect(a.coreAllowed, isFalse);
    expect(a.error, 'verification');
    expect(billing.completes, 0);
  });
  test(
    'Acknowledge failure preserves verified legacy entitlement and receipt',
    () async {
      trials.expire();
      billing.completeFails = true;
      final a = make();
      await ready(a);
      await a.handle(purchase(AgentAccess.finance));
      expect(a.corePurchased, isTrue);
      expect(a.error, 'acknowledgement');
      expect(billing.completes, 1);
    },
  );
  test('Unreadable trial fails closed without replacing original state or verified rights', () async {
    trials.broken = true;
    final a = make();
    await ready(a);
    expect(a.trial, isNull);
    expect(a.coreAllowed, isFalse);
    expect(trials.state.started, beginning);
    await a.handle(purchase(AgentAccess.finance));
    expect(a.corePurchased, isTrue);
  });
  test('Server-confirmed Core grant persists offline; only signed revocation removes it', () async {
    trials.expire();
    final pair = await Ed25519().newKeyPair();
    var status = 'purchased';
    var offline = false;
    final service = CorePurchaseVerifier(
      endpoint: 'https://billing.example.org/verify',
      publicKey: base64Encode((await pair.extractPublicKey()).bytes),
      client: MockClient((request) async {
        if (offline) return http.Response('{}', 503);
        final req = jsonDecode(request.body);
        final payload = jsonEncode({
          'version': 1,
          'packageName': 'com.ilmmizan.bilga',
          'productId': AgentAccess.core,
          'installation': install,
          'entitlement': 'lifetime',
          'status': status,
          'receiptSha256': sha256
              .convert(utf8.encode(req['receipt'] as String))
              .toString(),
        });
        return http.Response(
          jsonEncode({
            'payload': payload,
            'signature': base64Encode(
              (await Ed25519().sign(utf8.encode(payload), keyPair: pair)).bytes,
            ),
          }),
          200,
        );
      }),
    );
    final a = make(core: service);
    await ready(a);
    await a.handle(purchase(AgentAccess.core));
    expect(a.entitled, isTrue);
    expect(billing.completes, 1);
    offline = true;
    final restarted = make(core: service);
    await ready(restarted);
    expect(restarted.entitled, isTrue);
    await restarted.handle(purchase(AgentAccess.core));
    expect(restarted.entitled, isTrue);
    await restarted.restore();
    expect(restarted.entitled, isTrue);
    offline = false;
    status = 'revoked';
    await restarted.handle(purchase(AgentAccess.core));
    expect(restarted.entitled, isFalse);
    expect(restarted.coreAllowed, isFalse);
    final afterRevoked = make(core: service);
    await ready(afterRevoked);
    expect(afterRevoked.entitled, isFalse);
  });

  testWidgets('First-open explanation, acknowledgement and preserved editor', (
    tester,
  ) async {
    final a = make();
    await tester.runAsync(() => ready(a));
    await tester.pumpWidget(
      MaterialApp(
        home: CoreAccessGate(
          access: a,
          child: const Scaffold(body: Text('Existing editor')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Use Bilga free for 40 days'), findsOneWidget);
    await tester.runAsync(() async {
      await tester.tap(find.text('Get started'));
      await Future<void>.delayed(Duration.zero);
    });
    await tester.pumpAndSettle();
    expect(a.trial!.introduced, isTrue);
    expect(find.textContaining('Use Bilga free for 40 days'), findsNothing);
    expect(find.text('Existing editor'), findsOneWidget);
    trials.expire();
    await tester.runAsync(a.updateTrial);
    await tester.pumpAndSettle();
    expect(find.text('Your 40-day trial has ended.'), findsOneWidget);
    expect(find.text('My data: backup and export'), findsOneWidget);
    expect(find.text('Existing editor'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('Root navigation works after the trial overlay is dismissed', (
    tester,
  ) async {
    final a = make();
    await tester.runAsync(() => ready(a));
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => CoreAccessGate(access: a, child: child!),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const Scaffold(body: Text('Opened module')),
                ),
              ),
              child: const Text('Open module'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(find.text('Get started'));
      await Future<void>.delayed(Duration.zero);
    });
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open module'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Opened module'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Open module'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Paywall fits small screen with large text', (tester) async {
    trials.expire();
    final a = make();
    await tester.runAsync(() => ready(a));
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        builder: (c, child) => MediaQuery(
          data: MediaQuery.of(c)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: CoreAccessGate(access: a, child: const SizedBox()),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
