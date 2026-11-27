import 'package:flutter/services.dart';

import 'todo_bridge.dart';

enum TodoNotificationPermission {
  allowed,
  blocked,
  unavailable;

  static Future<TodoNotificationPermission> request() async {
    try {
      final granted = await TodoBridge.channel.invokeMethod<bool>(
        'requestNotificationPermission',
      );
      return switch (granted) {
        true => allowed,
        false => blocked,
        null => unavailable,
      };
    } on MissingPluginException {
      // Desktop and other hosts may have no Android notification channel.
      return unavailable;
    } on PlatformException {
      return unavailable;
    }
  }
}
