import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ecocampus_mobile/core/theme/app_theme.dart';
import 'package:ecocampus_mobile/features/home/data/companion_provider.dart';
import 'package:ecocampus_mobile/features/home/data/home_providers.dart';
import 'package:ecocampus_mobile/features/home/presentation/student_home_screen.dart';
import 'package:ecocampus_mobile/features/report/data/reports_provider.dart';
import 'package:ecocampus_mobile/features/report/domain/report_model.dart';

void main() {
  group('Companion Provider Tests', () {
    test('Default companion name is Sprig when unpersisted', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(companionNameProvider), kDefaultCompanionName);
    });

    test('Setting valid name updates companion name in state', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final success = await container
          .read(companionNameProvider.notifier)
          .setName('  EcoPal  ');

      expect(success, true);
      expect(container.read(companionNameProvider), 'EcoPal');
    });

    test('Empty or whitespace name is rejected', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final success = await container
          .read(companionNameProvider.notifier)
          .setName('   ');

      expect(success, false);
      expect(container.read(companionNameProvider), kDefaultCompanionName);
    });

    test('Name longer than 20 characters is rejected', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final success = await container
          .read(companionNameProvider.notifier)
          .setName('ThisNameIsWayTooLongForCompanion');

      expect(success, false);
      expect(container.read(companionNameProvider), kDefaultCompanionName);
    });
  });

  group('Home Dashboard Provider Tests', () {
    test('Computes stats, eco score and level correctly from initial state', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final stats = container.read(homeDashboardProvider);
      expect(stats.totalReports, 4);
      expect(stats.resolvedReports, 1);
      expect(stats.activeReports, 3);
      expect(stats.pendingReports, 1);
      // Eco Score: 60 + (1/4 * 40) = 70
      expect(stats.ecoScore, 70);
      // User points = 420 -> level 5 'Sprout'
      expect(stats.level, 5);
      expect(stats.levelTitle, 'Sprout');
    });

    test('Level tiers adjust dynamically when points change', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Add points to reach Protector tier (>= 1500)
      container.read(userPointsProvider.notifier).addPoints(1100); // 420 + 1100 = 1520
      final stats = container.read(homeDashboardProvider);
      expect(stats.level, 9);
      expect(stats.levelTitle, 'Protector');
    });

    test('Resolving more reports increases eco score estimate', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final initialScore = container.read(homeDashboardProvider).ecoScore;

      // Resolve another report
      container.read(reportsProvider.notifier).updateReportStatus(
            'REP-2026-001',
            ReportStatus.resolved,
          );

      final updatedScore = container.read(homeDashboardProvider).ecoScore;
      expect(updatedScore > initialScore, true);
    });
  });

  group('Student Home Screen Widget Tests', () {
    testWidgets('Renders dynamic greeting, companion name, eco score and CTA', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            greetingProvider.overrideWithValue('Good morning'),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: StudentHomeScreen(
              onNavigateToReports: () {},
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Good morning'), findsOneWidget);
      expect(find.text('Sprig'), findsOneWidget);
      expect(find.text('Report an issue'), findsOneWidget);
      expect(find.text('Eco Score'), findsOneWidget);
      expect(find.text('Level'), findsOneWidget);
    });

    testWidgets('Tapping mascot speech bubble cycles through sustainability tips', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            greetingProvider.overrideWithValue('Good afternoon'),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: StudentHomeScreen(
              onNavigateToReports: () {},
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      // Initial tip
      expect(
        find.text("Spotted something on campus? Snap it, I'll sort the rest!"),
        findsOneWidget,
      );

      // Tap speech bubble to cycle
      await tester.tap(find.text("Spotted something on campus? Snap it, I'll sort the rest!"));
      await tester.pump(const Duration(milliseconds: 200));

      expect(
        find.text('Reporting a dripping tap can save over 5,000 liters of water a year!'),
        findsOneWidget,
      );
    });

    testWidgets('Tapping Eco Score card opens estimate details modal', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            greetingProvider.overrideWithValue('Good afternoon'),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: StudentHomeScreen(
              onNavigateToReports: () {},
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      // Tap Eco Score card
      await tester.tap(find.text('Eco Score'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('ESTIMATE'), findsOneWidget);
      expect(find.text('Campus Eco Score'), findsWidgets);
      expect(find.text('Got it'), findsOneWidget);

      // Close modal
      await tester.tap(find.text('Got it'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
    });

    testWidgets('Renaming companion modal opens and saves new name', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            greetingProvider.overrideWithValue('Good afternoon'),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: StudentHomeScreen(
              onNavigateToReports: () {},
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      // Tap companion name or edit button
      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Name Your Companion'), findsOneWidget);

      // Enter new name
      await tester.enterText(find.byType(TextFormField), 'Leafy');
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('Save Name'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));

      // Verify companion name updated on home screen
      expect(find.text('Leafy'), findsOneWidget);
    });
  });
}
