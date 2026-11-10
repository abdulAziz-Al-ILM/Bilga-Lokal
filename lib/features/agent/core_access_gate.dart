import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/strings.dart';
import '../search/library_page.dart';
import '../settings/profile_page.dart';
import 'agent_access.dart';
import 'purchase_panel.dart';

/// Covers mutation routes, preserving any mounted editor draft. Reading and
/// exporting stay reachable behind the same AppLock, without Play or a network.
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
              // The gate is a sibling of the app Navigator in MaterialApp.builder.
              // It must never acquire or detach the app's HeroController.
              child: HeroControllerScope.none(
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
                                        c.tr('trialIntroduction'),
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
                                          label: Text(c.tr('trialBegin')),
                                        )
                                      else ...[
                                        Text(
                                          c.tr(
                                            access.trialError != null
                                                ? 'trialUnavailable'
                                                : access.trial?.clockBlocked ==
                                                      true
                                                ? 'trialClock'
                                                : 'trialExpired',
                                          ),
                                        ),
                                        PurchasePanel(
                                          product: AgentAccess.core,
                                          access: access,
                                        ),
                                        TextButton(
                                          onPressed: access.updateTrial,
                                          child: Text(c.tr('trialRecheck')),
                                        ),
                                        Text(c.tr('readOnlyInfo')),
                                        TextButton.icon(
                                          onPressed: () => Navigator.of(c).push(
                                            MaterialPageRoute<void>(
                                              builder: (_) => const LibraryPage(
                                                readOnly: true,
                                              ),
                                            ),
                                          ),
                                          icon: const Icon(
                                            Icons.menu_book_outlined,
                                          ),
                                          label: Text(c.tr('browseMyData')),
                                        ),
                                        TextButton.icon(
                                          onPressed: () => Navigator.of(c).push(
                                            MaterialPageRoute<void>(
                                              builder: (_) =>
                                                  const ProfilePage(),
                                            ),
                                          ),
                                          icon: const Icon(
                                            Icons.backup_outlined,
                                          ),
                                          label: Text(c.tr('dataBackupExport')),
                                        ),
                                      ],
                                      if (access.debugTest)
                                        Text(c.tr('debugTrialInfo')),
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
            ),
        ],
      );
    },
  );
}
