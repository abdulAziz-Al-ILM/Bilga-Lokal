import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../core/settings.dart';
import '../core/strings.dart';
import '../core/regional_localizations.dart';
import '../core/app_lock.dart';
import 'home_page.dart';

class BilgaApp extends StatelessWidget {
  const BilgaApp({super.key});
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: AppSettings.instance,
    builder: (context, _) {
      final settings = AppSettings.instance;
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Bilga',
        locale: Locale(
          languages.containsKey(settings.language) ? settings.language : 'en',
        ),
        supportedLocales: languages.keys.map((code) => Locale(code)).toList(),
        localizationsDelegates: const [
          RegionalMaterialDelegate(),
          RegionalWidgetsDelegate(),
          RegionalCupertinoDelegate(),
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: bilgaTheme(settings.palette, Brightness.light),
        darkTheme: bilgaTheme(settings.palette, Brightness.dark),
        themeMode: settings.mode,
        builder: (context, child) =>
            AppLock(child: child ?? const SizedBox.shrink()),
        home: const HomePage(),
      );
    },
  );
}
