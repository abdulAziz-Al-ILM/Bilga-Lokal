import '../features/reminders/module_reminder_host.dart';
import '../features/todo/reminders/todo_host.dart';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../core/settings.dart';
import '../core/strings.dart';
import '../core/regional_localizations.dart';
import '../core/app_lock.dart';
import '../features/agent/core_access_gate.dart';
import '../features/notes/widget/notes_widget_host.dart';
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
        builder: (context, child) => AppLock(
          child: CoreAccessGate(child: child ?? const SizedBox.shrink()),
        ),
        home: const NotesWidgetHost(
          child: TodoHost(child: ModuleReminderHost(child: HomePage())),
        ),
      );
    },
  );
}
