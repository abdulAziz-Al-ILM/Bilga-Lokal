import 'package:flutter/material.dart';

import '../../core/strings.dart';
import '../../core/start_strings.dart';
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
      const id = AgentAccess.core;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                startText(
                  'Umrbod Bilga Core',
                  'Lifetime Bilga Core',
                  'Bilga Core навсегда',
                ),
                style: Theme.of(c).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              Text(c.tr('xPurchaseInfo')),
              if (!a.canPurchase)
                Text(
                  startText(
                    'Xavfsiz Google Play xaridi bu build’da hali sozlanmagan. Sinov davomida ilovadan foydalanishingiz mumkin.',
                    'Secure Google Play purchase is not configured in this build. You can use the app during your trial.',
                    'Безопасная покупка Google Play в этой сборке ещё не настроена. Пробный доступ работает.',
                  ),
                ),
              if (a.error != null) Text(purchaseError(a.error!)),
              FilledButton(
                onPressed:
                    !canBuy ||
                        !a.canPurchase ||
                        a.pending ||
                        a.products[id] == null
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

String purchaseError(String error) => error == 'revoked'
    ? startText(
        'Google Play xarid bekor qilinganini tasdiqladi. Ma’lumotlaringiz saqlangan.',
        'Google Play confirmed this purchase was revoked. Your data is preserved.',
        'Google Play подтвердил отмену покупки. Ваши данные сохранены.',
      )
    : error == 'verification'
    ? startText(
        'Xaridni xavfsiz tasdiqlab bo‘lmadi. Keyinroq “Xaridni tiklash”ni bosing. Faol sinov davom etadi.',
        'Purchase could not be securely verified. Try Restore purchases later. An active trial continues.',
        'Не удалось безопасно проверить покупку. Повторите восстановление позже. Пробный доступ продолжается.',
      )
    : error == 'cancelled'
    ? startText(
        'Xarid bekor qilindi.',
        'Purchase cancelled.',
        'Покупка отменена.',
      )
    : startText(
        'Google Play hozir javob bermayapti. Keyinroq qayta urinib ko‘ring. Faol sinov va tasdiqlangan huquqlar saqlanadi.',
        'Google Play is temporarily unavailable. Try again later. Your active trial and verified access are preserved.',
        'Google Play временно недоступен. Повторите позже. Пробный срок и подтверждённый доступ сохраняются.',
      );

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
