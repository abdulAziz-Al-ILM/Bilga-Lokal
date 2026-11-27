import 'package:bilga/core/settings.dart';
import 'package:bilga/core/strings.dart';
import 'package:bilga/core/regional_localizations.dart';
import 'package:bilga/app/bilga_app.dart';
import 'package:bilga/features/notes/create_folder_page.dart';
import 'package:bilga/features/todo/create_todo_folder_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    for (final code in languages.keys) {
      await Strings.load(code: code);
    }
  });
  test('Every language has the complete English key set', () {
    expect(languages.length, 43);
    final keys = Strings.catalogs['en']!.keys.toSet();
    for (final code in languages.keys) {
      expect(Strings.catalogs[code]!.keys.toSet(), keys, reason: code);
      expect(
        Strings.catalogs[code]!.values.every((s) => s.trim().isNotEmpty),
        isTrue,
        reason: code,
      );
    }
  });
  test('Only a missing language preference defaults to English', () async {
    SharedPreferences.setMockInitialValues({});
    final fresh = AppSettings();
    addTearDown(fresh.dispose);
    await fresh.load();
    expect(fresh.language, 'en');
    expect(
      (await SharedPreferences.getInstance()).containsKey('bilga.language'),
      isFalse,
    );

    SharedPreferences.setMockInitialValues({'bilga.language': 'uz'});
    final existing = AppSettings();
    addTearDown(existing.dispose);
    await existing.load();
    expect(existing.language, 'uz');
    expect(
      (await SharedPreferences.getInstance()).getString('bilga.language'),
      'uz',
    );
  });

  testWidgets('Both folder forms use the selected interface language', (
    tester,
  ) async {
    for (final language in ['en', 'uz']) {
      for (final form in const [CreateFolderPage(), CreateTodoFolderPage()]) {
        await tester.pumpWidget(
          MaterialApp(
            locale: Locale(language),
            supportedLocales: const [Locale('en'), Locale('uz')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            home: form,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text(Strings.get(language, 'newFolder')), findsWidgets);
        expect(find.text(Strings.get(language, 'folderName')), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    }
  });

  testWidgets('Every locale builds, including RTL; seven palettes render', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('bilga/security'),
          (_) async => null,
        );
    await tester.runAsync(AppSettings.instance.load);
    for (final code in languages.keys) {
      AppSettings.instance.language = code;
      await tester.runAsync(AppSettings.instance.save);
      await tester.pumpWidget(const BilgaApp());
      await tester.pumpAndSettle();
      expect(
        find.text(Strings.get(code, 'notes')),
        findsOneWidget,
        reason: code,
      );
      expect(tester.takeException(), isNull, reason: code);
      final context = tester.element(find.text(Strings.get(code, 'notes')));
      expect(
        Directionality.of(context),
        ['ar', 'fa', 'ur', 'he'].contains(code)
            ? TextDirection.rtl
            : TextDirection.ltr,
        reason: code,
      );
    }
    expect(palettes.length, 7);
    for (final palette in palettes.keys) {
      for (final mode in [ThemeMode.light, ThemeMode.dark]) {
        AppSettings.instance.palette = palette;
        AppSettings.instance.mode = mode;
        await tester.runAsync(AppSettings.instance.save);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    }
    AppSettings.instance.nickname = 'Abdulaziz';
    await tester.runAsync(AppSettings.instance.save);
    final loaded = AppSettings();
    addTearDown(loaded.dispose);
    await tester.runAsync(loaded.load);
    expect(loaded.nickname, 'Abdulaziz');
    expect(loaded.palette, 'mono');
    AppSettings.instance.language = 'uz';
    AppSettings.instance.appLock = false;
  });

  testWidgets('Profile exposes palettes, languages and backup controls', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('bilga/security'),
          (_) async => null,
        );
    await tester.runAsync(AppSettings.instance.load);
    await tester.pumpWidget(const BilgaApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip(Strings.get('en', 'profile')));
    await tester.pumpAndSettle();
    expect(find.byType(ChoiceChip), findsNWidgets(10));
    expect(find.text(Strings.get('en', 'language')), findsOneWidget);
    expect(find.text(Strings.get('en', 'connectGoogle')), findsOneWidget);
    expect(find.text(Strings.get('en', 'export')), findsOneWidget);
    expect(find.text(Strings.get('en', 'import')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Regional calendars and time pickers use the selected language', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('bilga/security'),
          (_) async => null,
        );
    await tester.runAsync(AppSettings.instance.load);
    for (final code in ['ky', 'tg', 'tk']) {
      AppSettings.instance.language = code;
      await tester.runAsync(AppSettings.instance.save);
      await tester.pumpWidget(const BilgaApp());
      await tester.pumpAndSettle();
      final context = tester.element(find.text(Strings.get(code, 'notes')));
      final labels = MaterialLocalizations.of(context);
      final picked = showDatePicker(
        context: context,
        initialDate: DateTime(2026, 9, 6),
        firstDate: DateTime(2020),
        lastDate: DateTime(2030),
      );
      await tester.pumpAndSettle();
      expect(find.text(labels.datePickerHelpText), findsOneWidget);
      expect(
        find.text(labels.formatMonthYear(DateTime(2026, 9, 6))),
        findsWidgets,
      );
      await tester.tap(find.text(labels.okButtonLabel));
      await tester.pumpAndSettle();
      expect(await picked, DateTime(2026, 9, 6));
      if (!context.mounted) throw StateError('Picker context was lost');
      final time = showTimePicker(
        context: context,
        initialTime: const TimeOfDay(hour: 14, minute: 25),
      );
      await tester.pumpAndSettle();
      expect(find.text(labels.timePickerDialHelpText), findsOneWidget);
      await tester.tap(find.text(labels.okButtonLabel));
      await tester.pumpAndSettle();
      expect(await time, const TimeOfDay(hour: 14, minute: 25));
      expect(tester.takeException(), isNull, reason: code);
    }
    AppSettings.instance.language = 'uz';
  });
  test('Regional date input preserves day/month order and rejects impossible dates', () {
    for (final code in ['tg', 'tk']) {
      final labels = RegionalMaterialLocalizations(code);
      final leap = DateTime(2024, 2, 29);
      expect(labels.parseCompactDate(labels.formatCompactDate(leap)), leap);
      expect(labels.parseCompactDate('29.02.2025'), isNull);
      expect(labels.parseCompactDate('31.04.2026'), isNull);
      expect(labels.parseCompactDate('13.12.2026'), DateTime(2026, 12, 13));
    }
  });
}
