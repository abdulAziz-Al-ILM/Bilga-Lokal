import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/start_strings.dart';
import '../settings/profile_page.dart';
import 'agent_access.dart';
import 'purchase_panel.dart';

/// Covers all routes including widget/share entry. Backup/export remain
/// accessible behind AppLock. Expiry never unmounts an editor or deletes data.
class CoreAccessGate extends StatefulWidget {
  final Widget child;
  final AgentAccess? access;
  const CoreAccessGate({super.key, required this.child, this.access});
  @override
  State<CoreAccessGate> createState() => _CoreAccessGateState();
}

class _CoreAccessGateState extends State<CoreAccessGate>
    with WidgetsBindingObserver {
  AgentAccess get access => widget.access ?? AgentAccess.instance;
  Timer? timer;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (access.initialized) unawaited(access.updateTrial());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && access.initialized) {
      unawaited(access.updateTrial());
      unawaited(access.refresh());
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: access,
    builder: (context, _) {
      final intro =
          access.initialized &&
          !access.corePurchased &&
          access.trialActive &&
          access.trial?.introduced == false;
      final blocked = access.initialized && !access.coreAllowed;
      return Stack(
        children: [
          ExcludeFocus(
            excluding: intro || blocked,
            child: ExcludeSemantics(
              excluding: intro || blocked,
              child: IgnorePointer(
                ignoring: intro || blocked,
                child: widget.child,
              ),
            ),
          ),
          if (intro || blocked)
            Positioned.fill(
              child: Navigator(
                key: ValueKey(intro),
                onGenerateRoute: (_) => MaterialPageRoute<void>(
                  builder: (c) => AnimatedBuilder(
                    animation: access,
                    builder: (c, _) => PopScope(
                      canPop: false,
                      child: Scaffold(
                        body: SafeArea(
                          child: Center(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.all(28),
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 480,
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      intro
                                          ? Icons.auto_awesome_rounded
                                          : Icons.verified_user_outlined,
                                      size: 64,
                                      color: Theme.of(c).colorScheme.primary,
                                    ),
                                    const SizedBox(height: 24),
                                    Text(
                                      'Bilga',
                                      style: Theme.of(c)
                                          .textTheme
                                          .headlineLarge,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      startText(
                                        'Bilga’dan 40 kun bepul foydalaning. Keyin bir martalik to‘lov bilan umrbod foydalanishingiz mumkin. Oylik obuna yo‘q.',
                                        'Use Bilga free for 40 days. Then unlock lifetime access with one payment. No monthly subscription.',
                                        'Пользуйтесь Bilga бесплатно 40 дней. Затем — пожизненный доступ за один платёж. Без ежемесячной подписки.',
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 20),
                                    if (intro)
                                      FilledButton.icon(
                                        onPressed: () => access.updateTrial(
                                          acknowledge: true,
                                        ),
                                        icon: const Icon(
                                          Icons.arrow_forward_rounded,
                                        ),
                                        label: Text(
                                          startText(
                                            'Boshlash',
                                            'Get started',
                                            'Начать',
                                          ),
                                        ),
                                      )
                                    else ...[
                                      Text(
                                        access.trialError != null
                                            ? startText(
                                                'Sinov holatini o‘qib bo‘lmadi. Qayta urinib ko‘ring. Ma’lumotlaringiz saqlangan.',
                                                'Trial status could not be read. Retry; your data is preserved.',
                                                'Не удалось прочитать срок пробного периода. Повторите; данные сохранены.',
                                              )
                                            : access.trial?.clockBlocked == true
                                            ? startText(
                                                'Telefon sanasi orqaga o‘zgargan. Avtomatik sana va vaqtni yoqing, keyin qayta tekshiring.',
                                                'The device date moved backwards. Enable automatic date and time, then retry.',
                                                'Дата устройства переведена назад. Включите автоматическую дату и время и повторите.',
                                              )
                                            : startText(
                                                '40 kunlik sinov tugadi.',
                                                'Your 40-day trial has ended.',
                                                'Пробный период 40 дней завершён.',
                                              ),
                                      ),
                                      PurchasePanel(
                                        product: AgentAccess.core,
                                        access: access,
                                      ),
                                      TextButton(
                                        onPressed: access.updateTrial,
                                        child: Text(
                                          startText(
                                            'Sinovni qayta tekshirish',
                                            'Recheck trial',
                                            'Проверить срок',
                                          ),
                                        ),
                                      ),
                                      TextButton.icon(
                                        onPressed: () => Navigator.of(c).push(
                                          MaterialPageRoute<void>(
                                            builder: (_) => const ProfilePage(),
                                          ),
                                        ),
                                        icon: const Icon(Icons.backup_outlined),
                                        label: Text(
                                          startText(
                                            'Ma’lumotlarim: zaxira va eksport',
                                            'My data: backup and export',
                                            'Мои данные: копия и экспорт',
                                          ),
                                        ),
                                      ),
                                    ],
                                    if (access.debugTest)
                                      const Text(
                                        'DEBUG · Trial scenario only · No paid entitlement',
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );
}
