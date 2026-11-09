import 'package:flutter/material.dart';

import '../../core/strings.dart';
import 'agent_access.dart';
import 'purchase_panel.dart';

class AccessSummary extends StatelessWidget {
  const AccessSummary({super.key});
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: AgentAccess.instance,
    builder: (c, _) {
      final a = AgentAccess.instance, trial = AgentAccess.instance.trial;
      return Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(c.tr(a.corePurchased ? 'lifetimeActive' : 'trialAccess'), style: Theme.of(c).textTheme.titleLarge),
          if (!a.corePurchased && trial != null) ...[
            Text('${c.tr('trialStarted')}: ${MaterialLocalizations.of(c).formatMediumDate(DateTime.fromMillisecondsSinceEpoch(trial.started))}'),
            Text('${c.tr('trialRemaining')}: ${MaterialLocalizations.of(c).formatDecimal(trial.remainingDays)}'),
          ],
          Text(c.tr('lifetimeInfo')),
          if (!a.corePurchased) PurchasePanel(product: AgentAccess.core),
        ],
      )));
    },
  );
}
