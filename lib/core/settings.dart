import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings extends ChangeNotifier with WidgetsBindingObserver {
  static final instance = AppSettings();
  SharedPreferences? _prefs;
  String language = 'uz';
  String palette = 'forest';
  ThemeMode mode = ThemeMode.dark;
  String nickname = '';
  String avatar = '🌿';
  bool appLock = false;
  bool screenPrivacy = true;
  bool voiceScreenControls = false;
  String voiceLanguage = 'uz-UZ';
  String? backupOwner;
  String? lastBackup;
  bool _observing = false;

  Brightness get brightness => mode == ThemeMode.system
      ? WidgetsBinding.instance.platformDispatcher.platformBrightness
      : mode == ThemeMode.light
      ? Brightness.light
      : Brightness.dark;
  @override
  void didChangePlatformBrightness() {
    unawaited(_widgetTheme());
    notifyListeners();
  }

  Future<void> _widgetTheme() async {
    final s = bilgaTheme(palette, brightness).colorScheme;
    try {
      await const MethodChannel('bilga/widget_theme')
          .invokeMethod<void>('publish', {
            'background': s.surface.toARGB32(),
            'foreground': s.onSurface.toARGB32(),
            'accent': s.primary.toARGB32(),
            'onAccent': s.onPrimary.toARGB32(),
            'container': s.surfaceContainerHigh.toARGB32(),
            'outline': s.outline.toARGB32(),
          });
    } on MissingPluginException {
      /* No Android widget. */
    }
  }

  Future<void> load() async {
    // audio_service may start Dart before MainActivity binds native channels.
    const MethodChannel('bilga/widget_theme')
        .setMethodCallHandler((call) async {
          if (call.method == 'refresh') await _widgetTheme();
        });
    if (!_observing) {
      WidgetsBinding.instance.addObserver(this);
      _observing = true;
    }
    _prefs = await SharedPreferences.getInstance();
    language = _prefs!.getString('bilga.language') ?? 'uz';
    palette = _prefs!.getString('bilga.palette') ?? 'forest';
    mode = ThemeMode.values.firstWhere(
      (m) => m.name == _prefs!.getString('bilga.themeMode'),
      orElse: () => ThemeMode.dark,
    );
    nickname = _prefs!.getString('bilga.nickname') ?? '';
    avatar = _prefs!.getString('bilga.avatar') ?? '🌿';
    appLock = _prefs!.getBool('bilga.appLock') ?? false;
    screenPrivacy = _prefs!.getBool('bilga.screenPrivacy') ?? true;
    voiceScreenControls = _prefs!.getBool('bilga.voiceScreenControls') ?? false;
    final speech = _prefs!.getString('bilga.voiceLanguage');
    voiceLanguage = const {'uz-UZ', 'en-US', 'ru-RU'}.contains(speech)
        ? speech!
        : 'uz-UZ';
    backupOwner = _prefs!.getString('bilga.backupOwner');
    lastBackup = _prefs!.getString('bilga.lastBackup');
    await _secureWindow();
    await _widgetTheme();
    notifyListeners();
  }

  Future<void> _secureWindow() async {
    try {
      await const MethodChannel('bilga/security')
          .invokeMethod<void>('secure', appLock || screenPrivacy);
    } on MissingPluginException {
      /* Non-Android tests do not provide a window. */
    }
  }

  Future<void> save() async {
    final prefs = _prefs ??= await SharedPreferences.getInstance();
    final results = await Future.wait([
      prefs.setString('bilga.language', language),
      prefs.setString('bilga.palette', palette),
      prefs.setString('bilga.themeMode', mode.name),
      prefs.setString('bilga.nickname', nickname),
      prefs.setString('bilga.avatar', avatar),
      prefs.setBool('bilga.appLock', appLock),
      prefs.setBool('bilga.screenPrivacy', screenPrivacy),
      prefs.setBool('bilga.voiceScreenControls', voiceScreenControls),
      prefs.setString('bilga.voiceLanguage', voiceLanguage),
      if (backupOwner != null)
        prefs.setString('bilga.backupOwner', backupOwner!),
      if (lastBackup != null) prefs.setString('bilga.lastBackup', lastBackup!),
    ]);
    if (results.any((ok) => !ok)) throw StateError('settings_write');
    await _secureWindow();
    await _widgetTheme();
    notifyListeners();
  }
}

const palettes = <String, Color>{
  'forest': Color(0xFF24553E),
  'emerald': Color(0xFF00856A),
  'ruby': Color(0xFFA72F49),
  'ocean': Color(0xFF2267A0),
  'amethyst': Color(0xFF7654A3),
  'amber': Color(0xFF96651D),
  'mono': Color(0xFF626262),
};

ThemeData bilgaTheme(String palette, Brightness brightness) {
  var scheme = ColorScheme.fromSeed(
    seedColor: palettes[palette] ?? palettes['forest']!,
    brightness: brightness,
  );
  if (palette == 'mono') {
    Color gray(Color c) {
      final y = (c.r * .2126 + c.g * .7152 + c.b * .0722);
      return Color.from(alpha: c.a, red: y, green: y, blue: y);
    }

    scheme = scheme.copyWith(
      primary: gray(scheme.primary),
      onPrimary: gray(scheme.onPrimary),
      primaryContainer: gray(scheme.primaryContainer),
      onPrimaryContainer: gray(scheme.onPrimaryContainer),
      secondary: gray(scheme.secondary),
      onSecondary: gray(scheme.onSecondary),
      secondaryContainer: gray(scheme.secondaryContainer),
      onSecondaryContainer: gray(scheme.onSecondaryContainer),
      surface: gray(scheme.surface),
      onSurface: gray(scheme.onSurface),
      surfaceContainerLow: gray(scheme.surfaceContainerLow),
      surfaceContainer: gray(scheme.surfaceContainer),
      surfaceContainerHigh: gray(scheme.surfaceContainerHigh),
      surfaceContainerHighest: gray(scheme.surfaceContainerHighest),
      onSurfaceVariant: gray(scheme.onSurfaceVariant),
      outline: gray(scheme.outline),
      outlineVariant: gray(scheme.outlineVariant),
    );
  }
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
    ),
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(),
    ),
    visualDensity: VisualDensity.standard,
  );
}
