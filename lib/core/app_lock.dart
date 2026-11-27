import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';

import 'diagnostics.dart';
import 'settings.dart';
import 'strings.dart';

class AppLockScope extends InheritedWidget {
  final bool locked;
  const AppLockScope({super.key, required this.locked, required super.child});
  static bool isLocked(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppLockScope>()?.locked ??
      false;
  @override
  bool updateShouldNotify(AppLockScope oldWidget) => oldWidget.locked != locked;
}

class AppLock extends StatefulWidget {
  final Widget child;
  const AppLock({super.key, required this.child});
  @override
  State<AppLock> createState() => _AppLockState();
}

class _AppLockState extends State<AppLock> with WidgetsBindingObserver {
  late bool locked;
  bool checking = false;
  @override
  void initState() {
    super.initState();
    locked = AppSettings.instance.appLock;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused &&
        AppSettings.instance.appLock &&
        !checking) {
      setState(() => locked = true);
    }
  }

  Future<void> unlock() async {
    if (checking) return;
    setState(() => checking = true);
    try {
      final ok = await LocalAuthentication().authenticate(
        localizedReason: context.tr('unlock'),
        options: const AuthenticationOptions(stickyAuth: true),
      );
      if (mounted && ok) setState(() => locked = false);
    } catch (error) {
      // Authentication errors must leave the app locked.
      logFailure('Could not unlock the app', error);
    } finally {
      if (mounted) setState(() => checking = false);
    }
  }

  @override
  Widget build(BuildContext context) => AppLockScope(
    locked: locked,
    child: Stack(
      children: [
        ExcludeSemantics(
          excluding: locked,
          child: TickerMode(
            enabled: !locked,
            child: Offstage(offstage: locked, child: widget.child),
          ),
        ),
        if (locked)
          Positioned.fill(
            child: Material(
              color: Theme.of(context).colorScheme.surface,
              child: SafeArea(
                child: Center(
                  child: FilledButton.icon(
                    onPressed: checking ? null : unlock,
                    icon: const Icon(Icons.lock_outline),
                    label: Text(context.tr('unlock')),
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}
