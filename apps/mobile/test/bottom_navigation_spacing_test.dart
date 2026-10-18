import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ecocampus_mobile/core/theme/app_theme.dart';
import 'package:ecocampus_mobile/core/widgets/custom_bottom_nav.dart';
import 'package:ecocampus_mobile/features/home/data/home_providers.dart';
import 'package:ecocampus_mobile/features/map/data/campus_map_repository.dart';
import 'package:ecocampus_mobile/features/map/domain/campus_building_summary_model.dart';
import 'package:ecocampus_mobile/features/report/data/reports_repository.dart';
import 'package:ecocampus_mobile/features/report/data/reports_provider.dart';
import 'package:ecocampus_mobile/features/report/domain/report_model.dart';
import 'package:ecocampus_mobile/features/rewards/data/achievements_repository.dart';
import 'package:ecocampus_mobile/features/rewards/data/challenges_repository.dart';
import 'package:ecocampus_mobile/features/rewards/data/eco_points_provider.dart';
import 'package:ecocampus_mobile/features/rewards/domain/achievement_model.dart';
import 'package:ecocampus_mobile/features/rewards/domain/daily_challenge_model.dart';
import 'package:ecocampus_mobile/features/rewards/domain/eco_points_model.dart';
import 'package:ecocampus_mobile/main.dart';

class _FakeReportsRepository extends ReportsRepository {
  final List<ReportModel> reports;
  _FakeReportsRepository(this.reports) : super(null);

  @override
  Future<List<ReportModel>> getMyReports(String userId) async => reports;
}

class _TestMyReportsNotifier extends MyReportsNotifier {
  final List<ReportModel> _initial;
  _TestMyReportsNotifier(this._initial);

  @override
  Future<List<ReportModel>> build() async => _initial;

  @override
  Future<void> refresh() async {
    state = AsyncData(_initial);
  }
}

class _TestEcoPointsNotifier extends EcoPointsNotifier {
  final EcoPointsSummary _summary;
  _TestEcoPointsNotifier(this._summary);

  @override
  FutureOr<EcoPointsSummary> build() => _summary;
}

class _TestLeaderboardNotifier extends LeaderboardNotifier {
  final List<LeaderboardEntry> _entries;
  _TestLeaderboardNotifier(this._entries);

  @override
  FutureOr<List<LeaderboardEntry>> build() => _entries;
}

class _FakeAchievementsRepo implements AchievementsRepository {
  @override
  void clearCache() {}

  @override
  Future<List<Achievement>> getAchievements({String? userId}) async {
    return [
      Achievement(
        achievementKey: 'first_report',
        title: 'First Report',
        description: 'Submit your first campus issue report.',
        iconKey: 'flag',
        targetCount: 1,
        progressCount: 1,
        isUnlocked: true,
        unlockedAt: DateTime(2026, 10, 14, 10, 0),
        sortOrder: 1,
      ),
    ];
  }
}

class _FakeChallengesRepo implements ChallengesRepository {
  @override
  void clearCache() {}

  @override
  Future<List<DailyChallenge>> getDailyChallenges({String? userId}) async {
    return [
      const DailyChallenge(
        challengeKey: 'water_watch',
        title: 'Water Watch',
        description: 'Report any dripping faucet or water leak.',
        targetCount: 1,
        progressCount: 0,
        isCompleted: false,
        challengeDate: '2026-10-14',
        sortOrder: 1,
      ),
    ];
  }
}

class _FakeCampusMapRepository implements CampusMapRepository {
  @override
  Future<List<CampusBuildingSummary>> getCampusBuildingSummaries() async => [];
}

List<ReportModel> _generateMockReports(int count) {
  return List.generate(count, (i) {
    return ReportModel(
      id: 'rep-$i',
      reporterId: 'test-user',
      title: 'Issue #$i: Leaking faucet',
      category: IssueCategory.water,
      severity: IssueSeverity.medium,
      location: const CampusLocation(
        building: 'Science Block',
        floor: '2nd Floor',
        area: 'Room 204',
      ),
      status: ReportStatus.reported,
      createdAt: DateTime.now().subtract(Duration(hours: i)),
      description: 'Water dripping continuously from tap $i',
      department: 'Plumbing',
    );
  });
}

void main() {
  group('Bottom Navigation Spacing Tests on Reports & Rewards Pages', () {
    testWidgets(
      'Reports Page: Viewport strictly ends above CustomBottomNavBar with balanced 16dp spacing',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1080, 1600);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final mockReports = _generateMockReports(8);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              myReportsProvider.overrideWith(() => _TestMyReportsNotifier(mockReports)),
              reportsRepositoryProvider.overrideWithValue(_FakeReportsRepository(mockReports)),
              greetingProvider.overrideWithValue('Good morning'),
              campusMapRepositoryProvider.overrideWithValue(_FakeCampusMapRepository()),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: const MainNavigationShell(),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));

        // Switch to Reports tab (index 2)
        await tester.tap(find.text('Reports'));
        await tester.pump(const Duration(milliseconds: 300));

        // Find the ListView in MyReportsScreen
        final listViewFinder = find.byType(ListView);
        expect(listViewFinder, findsOneWidget);

        final listView = tester.widget<ListView>(listViewFinder);
        final insets = listView.padding as EdgeInsets;

        // Clean 16dp bottom padding (no duplicated or bloated navBarHeight insets)
        expect(insets.bottom, equals(16.0));

        // Find bottom navigation bar position
        final navBarFinder = find.byType(CustomBottomNavBar);
        expect(navBarFinder, findsOneWidget);
        final navBarBox = tester.renderObject<RenderBox>(navBarFinder);
        final navBarTopY = navBarBox.localToGlobal(Offset.zero).dy;

        // Verify the ListView viewport ends exactly at or above the navigation bar top (never behind it)
        final listViewBox = tester.renderObject<RenderBox>(listViewFinder);
        final listViewBottomY = listViewBox.localToGlobal(Offset.zero).dy + listViewBox.size.height;
        expect(listViewBottomY, lessThanOrEqualTo(navBarTopY + 0.1));

        // Scroll to the end of the list
        final scrollable = tester.state<ScrollableState>(find.byType(Scrollable).first);
        scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
        await tester.pump(const Duration(milliseconds: 300));

        // The last card (rep-7) must be rendered and visible
        final lastCardFinder = find.byKey(const ValueKey('report-card-rep-7'));
        expect(lastCardFinder, findsOneWidget);

        final cardBoxAtEnd = tester.renderObject<RenderBox>(lastCardFinder);
        final cardBottomYAtEnd = cardBoxAtEnd.localToGlobal(Offset.zero).dy + cardBoxAtEnd.size.height;

        // Card rests strictly above the navigation bar top without passing behind it
        expect(cardBottomYAtEnd, lessThanOrEqualTo(navBarTopY));
        final clearance = navBarTopY - cardBottomYAtEnd;
        expect(clearance, greaterThanOrEqualTo(14.0));
      },
    );

    testWidgets(
      'Rewards Page: Viewport strictly ends above CustomBottomNavBar with balanced 16dp spacing',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1080, 1600); // 800 logical height
        tester.view.devicePixelRatio = 2.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final mockSummary = EcoPointsSummary.fromTotals(totalPoints: 150, eventCount: 4);
        final mockLeaderboard = <LeaderboardEntry>[
          const LeaderboardEntry(
            userId: 'user-1',
            rank: 1,
            displayName: 'Priya Sharma',
            totalPoints: 420,
            level: 3,
            levelTitle: 'Sapling',
          ),
          const LeaderboardEntry(
            userId: 'user-2',
            rank: 2,
            displayName: 'Rahul Patel',
            totalPoints: 310,
            level: 2,
            levelTitle: 'Sprout',
          ),
        ];

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              ecoPointsProvider.overrideWith(() => _TestEcoPointsNotifier(mockSummary)),
              leaderboardProvider.overrideWith(() => _TestLeaderboardNotifier(mockLeaderboard)),
              achievementsRepositoryProvider.overrideWithValue(_FakeAchievementsRepo()),
              challengesRepositoryProvider.overrideWithValue(_FakeChallengesRepo()),
              greetingProvider.overrideWithValue('Good morning'),
              campusMapRepositoryProvider.overrideWithValue(_FakeCampusMapRepository()),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: const MainNavigationShell(),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));

        // Switch to Rewards tab (index 3)
        await tester.tap(find.text('Rewards'));
        await tester.pump(const Duration(milliseconds: 300));

        // Find the SingleChildScrollView in RewardsScreen
        final scrollFinder = find.byType(SingleChildScrollView);
        expect(scrollFinder, findsOneWidget);

        final scrollView = tester.widget<SingleChildScrollView>(scrollFinder);
        final insets = scrollView.padding as EdgeInsets;

        // Clean 16dp bottom padding (no duplicated or bloated navBarHeight insets)
        expect(insets.bottom, equals(16.0));

        // Find bottom navigation bar position
        final navBarFinder = find.byType(CustomBottomNavBar);
        expect(navBarFinder, findsOneWidget);
        final navBarBox = tester.renderObject<RenderBox>(navBarFinder);
        final navBarTopY = navBarBox.localToGlobal(Offset.zero).dy;

        final scrollBox = tester.renderObject<RenderBox>(scrollFinder);
        final scrollBottomY = scrollBox.localToGlobal(Offset.zero).dy + scrollBox.size.height;
        expect(scrollBottomY, lessThanOrEqualTo(navBarTopY + 0.1));

        // Scroll to the bottom of the Rewards page
        final scrollableFinder = find.descendant(
          of: scrollFinder,
          matching: find.byType(Scrollable),
        );
        final scrollable = tester.state<ScrollableState>(scrollableFinder);
        scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
        await tester.pump(const Duration(milliseconds: 300));

        // Verify leaderboard elements are fully visible at the bottom
        expect(find.text('Leaderboard'), findsOneWidget);
        expect(find.text('Priya Sharma'), findsOneWidget);
        expect(find.text('Rahul Patel'), findsOneWidget);

        // The final element in the leaderboard should sit strictly above the nav bar
        final rahulBox = tester.renderObject<RenderBox>(find.text('Rahul Patel'));
        final rahulBottomY = rahulBox.localToGlobal(Offset.zero).dy + rahulBox.size.height;
        final clearance = navBarTopY - rahulBottomY;

        expect(rahulBottomY, lessThanOrEqualTo(navBarTopY));
        expect(clearance, greaterThanOrEqualTo(16.0));
      },
    );

    testWidgets(
      'Gesture navigation insets (e.g. 34dp safe-area) scale viewport cleanly without duplication',
      (WidgetTester tester) async {
        // Set physical size with 34dp bottom padding (like modern bezel-less devices)
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 2.0;
        tester.view.padding = const FakeViewPadding(bottom: 68); // 34dp at 2.0 ratio
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
          tester.view.resetPadding();
        });

        final mockSummary = EcoPointsSummary.fromTotals(totalPoints: 150, eventCount: 4);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              reportsRepositoryProvider.overrideWithValue(_FakeReportsRepository([])),
              ecoPointsProvider.overrideWith(() => _TestEcoPointsNotifier(mockSummary)),
              leaderboardProvider.overrideWith(() => _TestLeaderboardNotifier([])),
              achievementsRepositoryProvider.overrideWithValue(_FakeAchievementsRepo()),
              challengesRepositoryProvider.overrideWithValue(_FakeChallengesRepo()),
              greetingProvider.overrideWithValue('Good morning'),
              campusMapRepositoryProvider.overrideWithValue(_FakeCampusMapRepository()),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: const MainNavigationShell(),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));

        // Switch to Rewards tab
        await tester.tap(find.text('Rewards'));
        await tester.pump(const Duration(milliseconds: 300));

        final scrollFinder = find.byType(SingleChildScrollView);
        final navBarFinder = find.byType(CustomBottomNavBar);
        final navBarBox = tester.renderObject<RenderBox>(navBarFinder);
        final navBarTopY = navBarBox.localToGlobal(Offset.zero).dy;

        final scrollBox = tester.renderObject<RenderBox>(scrollFinder);
        final scrollBottomY = scrollBox.localToGlobal(Offset.zero).dy + scrollBox.size.height;
        expect(scrollBottomY, lessThanOrEqualTo(navBarTopY + 0.1));
      },
    );
  });
}
