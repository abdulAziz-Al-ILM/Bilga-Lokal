import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AgentAccess extends ChangeNotifier {
  static final instance = AgentAccess();
  static const productId = 'bilga_agent_start',
      turbo = 'bilga_agent_turbo',
      upgrade = 'bilga_agent_turbo_upgrade',
      finance = 'bilga_finance';
  static const ids = {productId, turbo, upgrade, finance};
  static const turboEnabled = bool.fromEnvironment('BILGA_TURBO_INCLUDED');
  static const saleIds = {
    productId,
    finance,
    if (turboEnabled) turbo,
    if (turboEnabled) upgrade,
  };
  static const licenseKey = String.fromEnvironment('BILGA_PLAY_LICENSE_KEY');
  static const preview =
      kDebugMode && bool.fromEnvironment('BILGA_AGENT_PREVIEW');
  static const channel = MethodChannel('bilga/purchase');
  final products = <String, ProductDetails>{}, owned = <String>{};
  bool loading = false, pending = false;
  String? error;
  Future<void>? _opening;
  Future<void> _events = Future.value();
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  bool has(String id) {
    if (preview) return true;
    final t =
        owned.contains(turbo) ||
        (owned.contains(productId) && owned.contains(upgrade));
    return id == turbo
        ? t
        : id == productId
        ? (t || owned.contains(productId))
        : owned.contains(id);
  }

  bool get allowed => has(productId);
  bool get entitled => allowed;
  ProductDetails? get product => products[productId];
  Future<bool> verify(String json, String signature, String id) async =>
      licenseKey.isNotEmpty &&
      (await channel.invokeMethod<bool>('verify', {
            'json': json,
            'signature': signature,
            'key': licenseKey,
            'product': id,
          }) ??
          false);
  Future<void> init() => _opening ??= _init();
  Future<void> _init() async {
    loading = true;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final id in ids) {
        final raw =
            prefs.getString('bilga.receipt.$id') ??
            (id == productId ? prefs.getString('bilga.agent.receipt') : null);
        if (raw != null) {
          try {
            final r = jsonDecode(raw);
            if (await verify(r['json'], r['signature'], id)) owned.add(id);
          } catch (_) {}
        }
      }
      _subscription ??= InAppPurchase.instance.purchaseStream.listen(
        (list) {
          _events = _events
              .then((_) async {
                for (final p in list) {
                  await handle(p);
                }
              })
              .catchError((Object _) {
                error = 'Purchase verification failed';
                pending = false;
                notifyListeners();
              });
        },
        onError: (Object _) {
          error = 'Google Play unavailable';
          pending = false;
          notifyListeners();
        },
      );
      if (await InAppPurchase.instance.isAvailable()) await restore();
    } catch (_) {
      error = 'Google Play unavailable';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> handle(PurchaseDetails p) async {
    if (!ids.contains(p.productID)) return;
    pending = p.status == PurchaseStatus.pending;
    if (p.status == PurchaseStatus.error ||
        p.status == PurchaseStatus.canceled) {
      error = 'Purchase cancelled or unavailable';
      notifyListeners();
      return;
    }
    if (p.status == PurchaseStatus.purchased ||
        p.status == PurchaseStatus.restored) {
      if (p is! GooglePlayPurchaseDetails ||
          !await verify(
            p.billingClientPurchase.originalJson,
            p.billingClientPurchase.signature,
            p.productID,
          )) {
        error = 'Purchase verification failed';
        notifyListeners();
        return;
      }
      final prefs = await SharedPreferences.getInstance();
      if (!await prefs.setString(
        'bilga.receipt.${p.productID}',
        jsonEncode({
          'json': p.billingClientPurchase.originalJson,
          'signature': p.billingClientPurchase.signature,
        }),
      )) {
        throw StateError('receipt_write');
      }
      owned.add(p.productID);
      error = null;
      if (p.pendingCompletePurchase) {
        await InAppPurchase.instance.completePurchase(p);
      }
    }
    notifyListeners();
  }

  Future<void> buy([String id = productId]) async {
    final p = products[id];
    if (!saleIds.contains(id) ||
        p == null ||
        licenseKey.isEmpty ||
        pending ||
        (id == upgrade && !owned.contains(productId))) {
      return;
    }
    pending = true;
    error = null;
    notifyListeners();
    try {
      if (!await InAppPurchase.instance.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: p),
      )) {
        pending = false;
      }
    } catch (_) {
      pending = false;
      error = 'Purchase could not start';
    }
    notifyListeners();
  }

  Future<void> refresh() => restore();
  Future<void> restore() async {
    try {
      if (defaultTargetPlatform != TargetPlatform.android) return;
      final q = await InAppPurchase.instance.queryProductDetails(saleIds);
      products.addEntries(q.productDetails.map((p) => MapEntry(p.id, p)));
      final r = await InAppPurchase.instance
          .getPlatformAddition<InAppPurchaseAndroidPlatformAddition>()
          .queryPastPurchases();
      if (r.error != null) {
        error = 'Restore unavailable';
        return;
      }
      final valid = <String>{};
      for (final p in r.pastPurchases) {
        if (ids.contains(p.productID) &&
            (p.status == PurchaseStatus.purchased ||
                p.status == PurchaseStatus.restored) &&
            await verify(
              p.billingClientPurchase.originalJson,
              p.billingClientPurchase.signature,
              p.productID,
            )) {
          await handle(p);
          valid.add(p.productID);
        }
      }
      final prefs = await SharedPreferences.getInstance();
      for (final id in ids.difference(valid)) {
        owned.remove(id);
        await prefs.remove('bilga.receipt.$id');
        if (id == productId) await prefs.remove('bilga.agent.receipt');
      }
      error = null;
    } catch (_) {
      error = 'Restore unavailable';
    } finally {
      notifyListeners();
    }
  }
}
