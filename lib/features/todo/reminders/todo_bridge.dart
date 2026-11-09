import 'package:flutter/services.dart';

class TodoBridge {
  static const channel = MethodChannel('bilga/todo');
  static Future<Map<String, dynamic>> state() async =>
      await channel.invokeMapMethod<String, dynamic>('state') ?? {};
}
