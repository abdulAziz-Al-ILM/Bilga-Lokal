import 'package:flutter/material.dart';

import '../../core/strings.dart';
import 'agent_access.dart';

class PurchasePanel extends StatelessWidget {
  final String product;
  final bool canBuy;
  final AgentAccess? access;
  const PurchasePanel({
    super.key,
    required this.product,
    this.canBuy = true,
    this.access,
  });
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: access ?? AgentAccess.instance,
    builder: (c, _) {
      final a = access ?? AgentAccess.instance;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                c.tr('lifetimeTitle'),
                style: Theme.of(c).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              Text(c.tr('xPurchaseInfo')),
              if (!a.canPurchase) Text(c.tr('purchaseNotConfigured')),
              if (a.pending) Text(c.tr('purchasePending')),
              if (a.error != null)
                Text(
                  c.tr(switch (a.error) {
                    'revoked' => 'purchaseRevoked',
                    'verification' => 'purchaseVerification',
                    'cancelled' => 'purchaseCancelled',
                    'acknowledgement' => 'purchaseAcknowledgement',
                    _ => 'purchaseUnavailable',
                  }),
                ),
              FilledButton(
                onPressed:
                    !canBuy || !a.canPurchase || a.pending || a.product == null
                    ? null
                    : () => a.buy(),
                child: Text(a.product?.price ?? c.tr('xUnavailable')),
              ),
              TextButton(
                onPressed: a.pending ? null : a.restore,
                child: Text(c.tr('xRestorePurchases')),
              ),
            ],
          ),
        ),
      );
    },
  );
}

Future<bool> paid(BuildContext c, String id) async {
  final a = AgentAccess.instance;
  if (a.has(id)) return true;
  await showModalBottomSheet(
    context: c,
    isScrollControlled: true,
    builder: (_) => PurchasePanel(product: id),
  );
  return a.has(id);
}
