import 'package:flutter/material.dart';

import '../../core/strings.dart';
import 'agent_access.dart';

class PurchasePanel extends StatelessWidget {
  final String product;
  final bool canBuy;
  const PurchasePanel({super.key, required this.product, this.canBuy = true});
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: AgentAccess.instance,
    builder: (c, _) {
      final a = AgentAccess.instance;
      final id =
          product == AgentAccess.turbo &&
              a.owned.contains(AgentAccess.productId)
          ? AgentAccess.upgrade
          : product;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(c.tr('xPaid'), style: Theme.of(c).textTheme.titleLarge),
              const SizedBox(height: 12),
              Text(c.tr('xPurchaseInfo')),
              if (a.error != null) Text(a.error!),
              FilledButton(
                onPressed: !canBuy || a.pending || a.products[id] == null
                    ? null
                    : () => a.buy(id),
                child: Text(a.products[id]?.price ?? c.tr('xUnavailable')),
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
