import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ecocampus_mobile/core/theme/app_theme.dart';
import 'package:ecocampus_mobile/features/home/data/companion_provider.dart';
import 'package:ecocampus_mobile/features/home/data/home_providers.dart';
import 'package:ecocampus_mobile/features/home/presentation/student_home_screen.dart';
import 'package:ecocampus_mobile/features/report/data/reports_provider.dart';
import 'package:ecocampus_mobile/features/report/domain/report_model.dart';
import 'package:ecocampus_mobile/features/rewards/data/eco_points_provider.dart';
import 'package:ecocampus_mobile/features/rewards/domain/eco_points_model.dart';

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
    test('Computes stats, eco score and level correctly from clean initial state', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final stats = container.read(homeDashboardProvider);
      expect(stats.totalReports, 0);
      expect(stats.resolvedReports, 0);
      expect(stats.activeReports, 0);
      expect(stats.pendingReports, 0);
      // Clean base eco score: genuine 0 (no preset 60/100 default)
      expect(stats.ecoScore, 0);
      // Clean initial user points = 0 -> level 1 'Seedling'
      expect(stats.level, 1);
      expect(stats.levelTitle, 'Seedling');
    });

    test('Computes report breakdown correctly when reports are populated', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(reportsProvider.notifier).setReports([
        ReportModel(
          id: 'REP-101',
          title: 'Resolved Issue',
          description: 'Fixed',
          category: IssueCategory.water,
          severity: IssueSeverity.low,
          status: ReportStatus.resolved,
          location: const CampusLocation(building: 'Block A', floor: '1st Floor', area: 'Main'),
          createdAt: DateTime.now(),
        ),
        ReportModel(
          id: 'REP-102',
          title: 'Active Issue',
          description: 'In progress',
          category: IssueCategory.electricity,
          severity: IssueSeverity.medium,
          status: ReportStatus.inProgress,
          location: const CampusLocation(building: 'Block B', floor: '2nd Floor', area: 'Lab'),
          createdAt: DateTime.now(),
        ),
      ]);

      final stats = container.read(homeDashboardProvider);
      expect(stats.totalReports, 2);
      expect(stats.resolvedReports, 1);
      expect(stats.activeReports, 1);
      expect(stats.pendingReports, 0);
    });

    test('Level tiers adjust dynamically when points change per live DB rules', () {
      final container = ProviderContainer(
        overrides: [
          ecoPointsProvider.overrideWith(() => _TestEcoPointsNotifier(
                EcoPointsSummary.fromTotals(totalPoints: 250, eventCount: 5),
              )),
        ],
      );
      addTearDown(container.dispose);

      final stats = container.read(homeDashboardProvider);
      expect(stats.level, 4);
      expect(stats.levelTitle, 'Tree');
      expect(stats.ecoScore, 100);
    });

    test('Updating report status correctly updates report breakdown counts', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(reportsProvider.notifier).setReports([
        ReportModel(
          id: 'REP-101',
          title: 'Leaking Tap',
          description: 'Dripping tap',
          category: IssueCategory.water,
          severity: IssueSeverity.high,
          status: ReportStatus.reported,
          location: const CampusLocation(building: 'Engineering', floor: 'Ground Floor', area: 'Restroom'),
          createdAt: DateTime.now(),
        ),
      ]);

      expect(container.read(homeDashboardProvider).pendingReports, 1);
      expect(container.read(homeDashboardProvider).resolvedReports, 0);

      // Resolve the report
      container.read(reportsProvider.notifier).updateReportStatus(
            'REP-101',
            ReportStatus.resolved,
          );

      expect(container.read(homeDashboardProvider).resolvedReports, 1);
      expect(container.read(homeDashboardProvider).pendingReports, 0);
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

    testWidgets('Empty state displays "All clear nearby!" and never renders mock reports', (tester) async {
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

      expect(find.text('All clear nearby!'), findsOneWidget);
      expect(find.text('No open issues around your current campus location.'), findsOneWidget);
      // Verify hardcoded/mock reports never appear
      expect(find.text('REP-2026-001'), findsNothing);
      expect(find.text('Broken Solar Inverter Display'), findsNothing);
      expect(find.text('Leaking Water Cooler Tap'), findsNothing);
      expect(find.text('Unsorted Recyclables Overflow'), findsNothing);
    });

    testWidgets('Renders genuine report entries and does not invent mock reports', (tester) async {
      final genuineReports = [
        ReportModel(
          id: 'genuine-uuid-1',
          title: 'Genuine Library AC Leak',
          description: 'A genuine issue loaded from Supabase',
          category: IssueCategory.water,
          severity: IssueSeverity.high,
          status: ReportStatus.reported,
          location: const CampusLocation(
            building: 'Central Library',
            floor: 'Floor 2',
            area: 'Study Hall West',
          ),
          createdAt: DateTime.now(),
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            greetingProvider.overrideWithValue('Good morning'),
            myReportsProvider.overrideWith(() => _TestMyReportsNotifier(genuineReports)),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: StudentHomeScreen(
              onNavigateToReports: () {},
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Genuine Library AC Leak'), findsOneWidget);
      expect(find.text('REP-2026-001'), findsNothing);
      expect(find.text('All clear nearby!'), findsNothing);
    });

    testWidgets('Pull to refresh preserves genuine data without flashing mock items', (tester) async {
      final genuineReports = [
        ReportModel(
          id: 'genuine-uuid-1',
          title: 'Genuine Library AC Leak',
          description: 'A genuine issue loaded from Supabase',
          category: IssueCategory.water,
          severity: IssueSeverity.high,
          status: ReportStatus.reported,
          location: const CampusLocation(
            building: 'Central Library',
            floor: 'Floor 2',
            area: 'Study Hall West',
          ),
          createdAt: DateTime.now(),
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            greetingProvider.overrideWithValue('Good morning'),
            myReportsProvider.overrideWith(() => _TestMyReportsNotifier(genuineReports)),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: StudentHomeScreen(
              onNavigateToReports: () {},
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Genuine Library AC Leak'), findsOneWidget);

      // Trigger pull to refresh
      await tester.fling(find.byType(SingleChildScrollView), const Offset(0, 300), 1000);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // During refresh, genuine data remains visible and mock items NEVER appear
      expect(find.text('Genuine Library AC Leak'), findsOneWidget);
      expect(find.text('Broken Solar Inverter Display'), findsNothing);
      expect(find.text('Leaking Water Cooler Tap'), findsNothing);

      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Genuine Library AC Leak'), findsOneWidget);
    });
  });
}

class _TestMyReportsNotifier extends MyReportsNotifier {
  final List<ReportModel> _initial;
  _TestMyReportsNotifier(this._initial);

  @override
  FutureOr<List<ReportModel>> build() {
    ref.read(reportsProvider.notifier).setReports(_initial);
    return _initial;
  }

  @override
  Future<void> refresh() async {
    ref.read(reportsProvider.notifier).setReports(_initial);
    state = AsyncData(_initial);
  }
}

class _TestEcoPointsNotifier extends EcoPointsNotifier {
  final EcoPointsSummary _summary;
  _TestEcoPointsNotifier(this._summary);

  @override
  FutureOr<EcoPointsSummary> build() => _summary;
}

