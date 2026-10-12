import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core_purchase_verifier.dart';
import 'trial_state.dart';
import 'trial_store.dart';

abstract interface class BillingGateway {
  Stream<List<PurchaseDetails>> get purchases;
  Future<bool> available();
  Future<ProductDetailsResponse> products(Set<String> ids);
  Future<QueryPurchaseDetailsResponse> past();
  Future<bool> buy(ProductDetails product);
  Future<void> complete(PurchaseDetails purchase);
}

class PlayBillingGateway implements BillingGateway {
  InAppPurchase get _play => InAppPurchase.instance;
  @override
  Stream<List<PurchaseDetails>> get purchases => _play.purchaseStream;
  @override
  Future<bool> available() =>
      _play.isAvailable().timeout(const Duration(seconds: 10));
  @override
  Future<ProductDetailsResponse> products(Set<String> ids) =>
      _play.queryProductDetails(ids);
  @override
  Future<QueryPurchaseDetailsResponse> past() => _play
      .getPlatformAddition<InAppPurchaseAndroidPlatformAddition>()
      .queryPastPurchases();
  @override
  Future<bool> buy(ProductDetails product) => _play.buyNonConsumable(
    purchaseParam: PurchaseParam(productDetails: product),
  );
  @override
  Future<void> complete(PurchaseDetails purchase) =>
      _play.completePurchase(purchase);
}

typedef ReceiptVerifier = Future<bool> Function(
  String json,
  String signature,
  String product,
);

class AgentAccess extends ChangeNotifier {
  static final instance = AgentAccess();
  // Retain legacy identifiers and receipt keys for upgrades/restores.
  static const productId = 'bilga_agent_start',
      turbo = 'bilga_agent_turbo',
      upgrade = 'bilga_agent_turbo_upgrade',
      finance = 'bilga_finance';
  static const core = String.fromEnvironment(
    'BILGA_CORE_PRODUCT_ID',
    defaultValue: 'bilga_core_lifetime',
  );
  static const ids = {core, productId, turbo, upgrade, finance};
  static const turboEnabled = bool.fromEnvironment('BILGA_TURBO_INCLUDED');
  static const saleIds = {core};
  static const licenseKey = String.fromEnvironment('BILGA_PLAY_LICENSE_KEY');
  static const channel = MethodChannel('bilga/purchase');
  static const _test = String.fromEnvironment('BILGA_TRIAL_TEST');
  final BillingGateway billing;
  final TrialStore trials;
  final CorePurchaseVerifier coreVerifier;
  final ReceiptVerifier receiptVerifier;
  AgentAccess({
    BillingGateway? billing,
    TrialStore? trials,
    CorePurchaseVerifier? coreVerifier,
    ReceiptVerifier? receiptVerifier,
  }) : billing = billing ?? PlayBillingGateway(),
       trials = trials ?? AndroidTrialStore(),
       coreVerifier = coreVerifier ?? CorePurchaseVerifier(),
       receiptVerifier = receiptVerifier ?? _verifyReceipt;

  final products = <String, ProductDetails>{}, owned = <String>{};
  bool loading = false, pending = false, initialized = false;
  bool _nativeDebug = false;
  String? error, trialError;
  TrialState? trial;
  Future<void>? _opening, _restoring;
  Future<void> _events = Future.value(), _trialEvents = Future.value();
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  static bool debugScenarioAllowed(
    bool debugBuild,
    bool nativeDebug,
    String scenario,
  ) =>
      debugBuild &&
      nativeDebug &&
      {'expired', 'billing_unavailable'}.contains(scenario);
  bool get debugTest => debugScenarioAllowed(kDebugMode, _nativeDebug, _test);
  bool get trialActive =>
      trial?.active == true && !(debugTest && _test == 'expired');
  // Grandfather genuine legacy customers into Core; an upgrade alone is not a purchase of Start.
  bool get corePurchased =>
      owned.any({core, productId, turbo, finance}.contains);
  bool get coreAllowed => corePurchased || trialActive;
  bool has(String id) {
    if (!ids.contains(id)) return false;
    if (id == turbo) {
      return owned.contains(turbo) ||
          (owned.contains(productId) && owned.contains(upgrade));
    }
    if (id == upgrade) return owned.contains(upgrade);
    return coreAllowed;
  }

  bool get allowed => has(productId);
  bool get entitled => corePurchased;
  bool get canPurchase => licenseKey.isNotEmpty && coreVerifier.configured;
  ProductDetails? get product => products[core];

  static Future<bool> _verifyReceipt(
    String json,
    String signature,
    String id,
  ) async =>
      licenseKey.isNotEmpty &&
      (await channel.invokeMethod<bool>('verify', {
            'json': json,
            'signature': signature,
            'key': licenseKey,
            'product': id,
          }) ??
          false);

  Future<void> updateTrial({bool acknowledge = false}) {
    final next = _trialEvents.then((_) async {
      try {
        final (state, debug) = await trials.load(acknowledge: acknowledge);
        trial = state;
        _nativeDebug = debug;
        trialError = null;
      } catch (_) {
        trial = null;
        trialError = 'trial_storage';
      }
      notifyListeners();
    });
    _trialEvents = next;
    return next;
  }

  Future<void> init() => _opening ??= _init();
  Future<void> _init() async {
    await updateTrial();
    final prefs = await SharedPreferences.getInstance();
    for (final id in ids) {
      final raw =
          prefs.getString('bilga.receipt.$id') ??
          (id == productId ? prefs.getString('bilga.agent.receipt') : null);
      if (raw == null) continue;
      try {
        final r = jsonDecode(raw) as Map<String, dynamic>;
        if (!await receiptVerifier(
          r['json'] as String,
          r['signature'] as String,
          id,
        )) {
          continue;
        }
        if (id == core &&
            (trial == null ||
                await coreVerifier.check(
                      Map<String, dynamic>.from(r['grant'] as Map),
                      receipt: r['json'] as String,
                      product: core,
                      installation: trial!.installation,
                    ) !=
                    'purchased')) {
          continue;
        }
        owned.add(id);
      } catch (_) {
        /* Keep evidence intact; unavailable verification is not revocation. */
      }
    }
    initialized = true;
    notifyListeners();
    // Billing connection is deliberately outside the startup/trial critical path.
    unawaited(_connect());
  }

  Future<void> _connect() async {
    loading = true;
    notifyListeners();
    try {
      if (debugTest && _test == 'billing_unavailable') {
        throw StateError('debug_billing');
      }
      _subscription ??= billing.purchases.listen(
        (list) {
          _events = _events
              .then((_) async {
                for (final p in list) {
                  await handle(p);
                }
              })
              .catchError((Object _) {
                error = 'verification';
                pending = false;
                notifyListeners();
              });
        },
        onError: (Object _) {
          error = 'unavailable';
          pending = false;
          notifyListeners();
        },
      );
      if (await billing.available()) {
        await restore();
      } else {
        error = 'unavailable';
      }
    } catch (_) {
      error = 'unavailable';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> handle(PurchaseDetails p) async {
    if (!ids.contains(p.productID)) return;
    pending = p.status == PurchaseStatus.pending;
    if (p.status == PurchaseStatus.pending) {
      notifyListeners();
      return;
    }
    if (p.status == PurchaseStatus.error ||
        p.status == PurchaseStatus.canceled) {
      error = p.status == PurchaseStatus.canceled ? 'cancelled' : 'unavailable';
      notifyListeners();
      return;
    }
    if (p.status != PurchaseStatus.purchased &&
        p.status != PurchaseStatus.restored) {
      return;
    }
    if (p is! GooglePlayPurchaseDetails) {
      error = 'verification';
      notifyListeners();
      return;
    }
    final receipt = p.billingClientPurchase.originalJson;
    final signature = p.billingClientPurchase.signature;
    if (!await receiptVerifier(receipt, signature, p.productID)) {
      error = 'verification';
      notifyListeners();
      return;
    }
    Map<String, dynamic>? grant;
    if (p.productID == core) {
      if (trial == null) {
        error = 'verification';
        notifyListeners();
        return;
      }
      try {
        grant = await coreVerifier.request(
          receipt: receipt,
          signature: signature,
          product: core,
          installation: trial!.installation,
        );
        final status = await coreVerifier.check(
          grant,
          receipt: receipt,
          product: core,
          installation: trial!.installation,
        );
        if (status == 'revoked') {
          // Only an explicit authenticated server revocation can remove Core.
          final prefs = await SharedPreferences.getInstance();
          if (!await prefs.setString(
            'bilga.receipt.$core',
            jsonEncode({
              'json': receipt,
              'signature': signature,
              'grant': grant,
            }),
          )) {
            throw StateError('receipt_write');
          }
          owned.remove(core);
          error = 'revoked';
          notifyListeners();
          return;
        }
        if (status != 'purchased') throw StateError('grant_invalid');
      } catch (_) {
        error = 'verification';
        notifyListeners();
        return;
      }
    }
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(
      'bilga.receipt.${p.productID}',
      jsonEncode({'json': receipt, 'signature': signature, 'grant': ?grant}),
    )) {
      throw StateError('receipt_write');
    }
    owned.add(p.productID);
    error = null;
    notifyListeners();
    // Persistence precedes acknowledgement. A retry is idempotent and doesn't
    // remove the granted purchase if acknowledgement temporarily fails.
    if (p.pendingCompletePurchase) {
      try {
        await billing.complete(p);
      } catch (_) {
        error = 'acknowledgement';
        notifyListeners();
      }
    }
  }

  Future<void> buy([String id = core]) async {
    final p = products[id];
    if (!saleIds.contains(id) || p == null || !canPurchase || pending) return;
    pending = true;
    error = null;
    notifyListeners();
    try {
      if (!await billing.buy(p)) pending = false;
    } catch (_) {
      pending = false;
      error = 'unavailable';
    }
    notifyListeners();
  }

  Future<void> refresh() => restore();
  Future<void> restore() =>
      _restoring ??= _restore().whenComplete(() => _restoring = null);
  Future<void> _restore() async {
    try {
      if (debugTest && _test == 'billing_unavailable') {
        throw StateError('debug_billing');
      }
      final q = await billing
          .products(saleIds)
          .timeout(const Duration(seconds: 15));
      products.clear();
      products.addEntries(q.productDetails.map((p) => MapEntry(p.id, p)));
      error = q.error == null ? null : 'unavailable';
      final r = await billing.past().timeout(const Duration(seconds: 15));
      if (r.error != null) {
        error = 'unavailable';
        return;
      }
      // Empty/partial lists, account switches and outages are NOT revocation.
      // Process on the same queue as live purchases to avoid duplicate writes.
      final work = _events.then((_) async {
        for (final p in r.pastPurchases) {
          await handle(p);
        }
      });
      _events = work.catchError((Object _) {
        error = 'verification';
      });
      await _events;
    } catch (_) {
      error = 'unavailable';
    } finally {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}
