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
    test('Initial dashboard is empty and does not invent scores or levels', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final stats = container.read(homeDashboardProvider);
      expect(stats.totalReports, 0);
      expect(stats.resolvedReports, 0);
      expect(stats.activeReports, 0);
      expect(stats.pendingReports, 0);
      expect(stats.ecoScore, isNull);
      expect(stats.level, isNull);
      expect(stats.levelTitle, isNull);
    });

    test('Report counts update while the unconfigured Eco Score stays unavailable', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(reportsProvider.notifier).addReport(
        ReportModel(
          id: 'TEST-HOME-001',
          title: 'Water leak',
          category: IssueCategory.water,
          severity: IssueSeverity.medium,
          location: const CampusLocation(building: 'Engineering Block', floor: 'Ground Floor', area: 'Corridor'),
          status: ReportStatus.reported,
          createdAt: DateTime.now(),
          description: 'A pipe is leaking.',
        ),
      );

      expect(container.read(homeDashboardProvider).totalReports, 1);
      container.read(reportsProvider.notifier).updateReportStatus(
        'TEST-HOME-001',
        ReportStatus.resolved,
      );

      final updatedStats = container.read(homeDashboardProvider);
      expect(updatedStats.totalReports, 1);
      expect(updatedStats.resolvedReports, 1);
      expect(updatedStats.ecoScore, isNull);
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

    testWidgets('Tapping Eco Score shows that metrics are not connected', (tester) async {
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

      expect(find.text('NOT CONNECTED'), findsOneWidget);
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
