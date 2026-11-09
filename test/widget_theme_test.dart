import 'package:bilga/core/settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'All palettes publish readable widget and overlay colors in light/dark',
    () async {
      SharedPreferences.setMockInitialValues({});
      final sent = <Map<Object?, Object?>>[];
      const channel = MethodChannel('bilga/widget_theme');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            sent.add(Map<Object?, Object?>.from(call.arguments as Map));
            return null;
          });
      final settings = AppSettings.instance;
      await settings.load();
      double contrast(int a, int b) {
        final x = Color(a).computeLuminance(), y = Color(b).computeLuminance();
        return ((x > y ? x : y) + .05) / ((x > y ? y : x) + .05);
      }

      for (final palette in palettes.keys) {
        for (final mode in [ThemeMode.light, ThemeMode.dark]) {
          settings.palette = palette;
          settings.mode = mode;
          await settings.save();
          final colors = sent.last;
          for (final pair in [
            ('foreground', 'background'),
            ('foreground', 'container'),
            ('onAccent', 'accent'),
          ]) {
            expect(
              contrast(colors[pair.$1] as int, colors[pair.$2] as int),
              greaterThanOrEqualTo(4.5),
              reason: '$palette/$mode/$pair',
            );
          }
          expect(
            colors['accent'],
            bilgaTheme(
              palette,
              settings.brightness,
            ).colorScheme.primary.toARGB32(),
          );
        }
      }
      settings.palette = 'ruby';
      settings.mode = ThemeMode.light;
      TestWidgetsFlutterBinding.instance.channelBuffers.push(
        channel.name,
        const StandardMethodCodec().encodeMethodCall(
          const MethodCall('refresh'),
        ),
        (_) {},
      );
      await Future<void>.delayed(Duration.zero);
      expect(
        sent.last['accent'],
        bilgaTheme('ruby', Brightness.light).colorScheme.primary.toARGB32(),
      );
      settings.mode = ThemeMode.system;
      final dispatcher = TestWidgetsFlutterBinding.instance.platformDispatcher;
      dispatcher.platformBrightnessTestValue = Brightness.light;
      await settings.save();
      expect(settings.brightness, Brightness.light);
      dispatcher.platformBrightnessTestValue = Brightness.dark;
      await Future<void>.delayed(Duration.zero);
      expect(settings.brightness, Brightness.dark);
      dispatcher.clearPlatformBrightnessTestValue();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    },
  );
}
