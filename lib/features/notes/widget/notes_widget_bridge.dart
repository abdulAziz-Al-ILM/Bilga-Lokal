import 'package:flutter/services.dart';

class NotesWidgetBridge {
  static const channel = MethodChannel('bilga/notes_widget');
  static Future<List<Map<String, dynamic>>> configs() async =>
      (await channel.invokeListMethod<dynamic>('configs') ?? [])
          .map((v) => Map<String, dynamic>.from(v as Map))
          .toList();
}
