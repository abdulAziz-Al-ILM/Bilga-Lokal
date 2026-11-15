import 'package:bilga/app/home_page.dart';
import 'package:bilga/core/loop_carousel.dart';
import 'package:bilga/core/settings.dart';
import 'package:bilga/core/strings.dart';
import 'package:bilga/features/agent/agent_access.dart';
import 'package:bilga/features/agent/agent_hub.dart';
import 'package:bilga/features/finance/finance_page.dart';
import 'package:bilga/features/habits/habits_page.dart';
import 'package:bilga/features/notes/notes_page.dart';
import 'package:bilga/features/planning/today_page.dart';
import 'package:bilga/features/private_space/space_page.dart';
import 'package:bilga/features/search/library_page.dart';
import 'package:bilga/features/settings/profile_page.dart';
import 'package:bilga/features/todo/todo_page.dart';
import 'package:bilga/main.dart' as application;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void registerAppJourney(IntegrationTestWidgetsFlutterBinding binding) {
  testWidgets(
    'Actual startup and every home module navigate; palettes and RTL render',
    (tester) async {
      await AppSettings.instance.load();
      final settings = AppSettings.instance;
      final originalLanguage = settings.language,
          originalPalette = settings.palette;
      final originalMode = settings.mode;
      final visited = <String>[];
      final previousHitTestPolicy =
          WidgetController.hitTestWarningShouldBeFatal;
      WidgetController.hitTestWarningShouldBeFatal = true;
      addTearDown(
        () => WidgetController.hitTestWarningShouldBeFatal =
            previousHitTestPolicy,
      );
      Future<void> until(bool Function() condition) async {
        for (var i = 0; i < 120 && !condition(); i++) {
          await tester.pump(const Duration(milliseconds: 250));
        }
        expect(condition(), isTrue);
        await tester.pumpAndSettle(
          const Duration(milliseconds: 100),
          EnginePhase.sendSemanticsUpdate,
          const Duration(seconds: 30),
        );
        expect(tester.takeException(), isNull);
      }

      Future<void> back() async {
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle(
          const Duration(milliseconds: 100),
          EnginePhase.sendSemanticsUpdate,
          const Duration(seconds: 30),
        );
        expect(
          ModalRoute.of(tester.element(find.byType(HomePage)))!.isCurrent,
          isTrue,
        );
        expect(tester.takeException(), isNull);
      }

      try {
        settings.language = 'en';
        await settings.save();
        application.main();
        await until(
          () =>
              AgentAccess.instance.initialized &&
              find.byType(HomePage).evaluate().isNotEmpty,
        );
        if (AgentAccess.instance.trial?.introduced == false) {
          await tester.tap(find.text(Strings.get('en', 'trialBegin')));
          await until(() => AgentAccess.instance.trial?.introduced == true);
        }
        expect(AgentAccess.instance.coreAllowed, isTrue);
        final pages = <(String, Type)>[
          ('notes', NotesPage),
          ('todos', TodoPage),
          ('xHabits', HabitsPage),
          ('textAssistant', AgentHub),
          ('xFinance', FinancePage),
          ('xExperience', SpacePage),
          ('xBooks', SpacePage),
        ];
        for (var index = 0; index < pages.length; index++) {
          final (label, type) = pages[index];
          if (index > 0) {
            final carousel = find.descendant(
              of: find.byType(LoopCarousel).first,
              matching: find.byType(PageView),
            );
            await tester.drag(
              carousel,
              Offset(-tester.getSize(carousel).width * .68, 0),
            );
            await tester.pump(const Duration(seconds: 1));
          }
          await tester.tap(find.text(Strings.get('en', label)).first);
          await until(() => find.byType(type).evaluate().isNotEmpty);
          await tester.pump(const Duration(seconds: 1));
          expect(tester.takeException(), isNull);
          visited.add(label);
          await back();
        }
        await tester.tap(find.text(Strings.get('en', 'todayPlan')));
        await until(() => find.byType(TodayPage).evaluate().isNotEmpty);
        visited.add('today');
        await back();
        await tester.tap(find.byTooltip(Strings.get('en', 'search')));
        await until(() => find.byType(LibraryPage).evaluate().isNotEmpty);
        visited.add('search');
        await back();
        await tester.tap(find.byTooltip(Strings.get('en', 'profile')));
        await until(() => find.byType(ProfilePage).evaluate().isNotEmpty);
        visited.add('settings');
        await back();
        for (final palette in palettes.keys) {
          for (final mode in [ThemeMode.light, ThemeMode.dark]) {
            settings.palette = palette;
            settings.mode = mode;
            await settings.save();
            await tester.pumpAndSettle(
              const Duration(milliseconds: 100),
              EnginePhase.sendSemanticsUpdate,
              const Duration(seconds: 30),
            );
            expect(
              Theme.of(tester.element(find.byType(HomePage))).brightness,
              mode == ThemeMode.light ? Brightness.light : Brightness.dark,
            );
            expect(tester.takeException(), isNull);
          }
        }
        settings.language = 'ar';
        await Strings.load(code: 'ar');
        await settings.save();
        await tester.pumpAndSettle(
          const Duration(milliseconds: 100),
          EnginePhase.sendSemanticsUpdate,
          const Duration(seconds: 30),
        );
        expect(
          Directionality.of(tester.element(find.byType(HomePage))),
          TextDirection.rtl,
        );
        expect(tester.takeException(), isNull);
        binding.reportData = {
          ...?binding.reportData,
          'deviceSuite': 'isolated Bilga Review',
          'visitedModules': visited,
          'themeVariants': 14,
          'rtl': 'Arabic',
        };
      } finally {
        settings.language = originalLanguage;
        settings.palette = originalPalette;
        settings.mode = originalMode;
        await Strings.load(code: originalLanguage);
        await settings.save();
        await tester.pumpWidget(const SizedBox.shrink());
      }
    },
  );
}
