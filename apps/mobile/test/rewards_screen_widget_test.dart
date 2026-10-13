import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ecocampus_mobile/features/rewards/domain/achievement_model.dart';
import 'package:ecocampus_mobile/features/rewards/domain/daily_challenge_model.dart';
import 'package:ecocampus_mobile/features/rewards/data/achievements_repository.dart';
import 'package:ecocampus_mobile/features/rewards/data/challenges_repository.dart';
import 'package:ecocampus_mobile/features/rewards/presentation/rewards_screen.dart';
import 'package:ecocampus_mobile/features/auth/data/auth_providers.dart';

User _mockUser(String id, String email) {
  return User(
    id: id,
    appMetadata: const {},
    userMetadata: const {},
    aud: 'authenticated',
    email: email,
    createdAt: '2026-10-14T00:00:00Z',
  );
}

class FakeAchievementsRepo implements AchievementsRepository {
  final List<Achievement> data;
  FakeAchievementsRepo(this.data);

  @override
  void clearCache() {}

  @override
  Future<List<Achievement>> getAchievements({String? userId}) async {
    return data;
  }
}

class FakeChallengesRepo implements ChallengesRepository {
  final List<DailyChallenge> data;
  final bool shouldThrow;
  FakeChallengesRepo(this.data, {this.shouldThrow = false});

  @override
  void clearCache() {}

  @override
  Future<List<DailyChallenge>> getDailyChallenges({String? userId}) async {
    if (shouldThrow) {
      throw Exception('Failed to load challenges');
    }
    return data;
  }
}

final _testAchievements = [
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
  const Achievement(
    achievementKey: 'ten_reports',
    title: '10 Issues Reported',
    description: 'Submit 10 campus issue reports.',
    iconKey: 'clipboard-check',
    targetCount: 10,
    progressCount: 3,
    isUnlocked: false,
    sortOrder: 2,
  ),
  const Achievement(
    achievementKey: 'ten_resolved',
    title: '10 Issues Resolved',
    description: 'Have 10 of your reports reach Resolved status.',
    iconKey: 'check-circle',
    targetCount: 10,
    progressCount: 1,
    isUnlocked: false,
    sortOrder: 3,
  ),
];

final _testChallenges = [
  const DailyChallenge(
    challengeKey: 'daily_reporter',
    title: 'Daily Reporter',
    description: 'Submit at least 1 verified campus issue report today.',
    targetCount: 1,
    progressCount: 1,
    isCompleted: true,
    challengeDate: '2026-10-14',
    sortOrder: 1,
  ),
  const DailyChallenge(
    challengeKey: 'water_watch',
    title: 'Water Watch',
    description: 'Report any active water leak or plumbing issue today.',
    targetCount: 1,
    progressCount: 0,
    isCompleted: false,
    challengeDate: '2026-10-14',
    sortOrder: 2,
  ),
  const DailyChallenge(
    challengeKey: 'energy_check',
    title: 'Energy Check',
    description: 'Spot and report any lighting or electrical energy waste today.',
    targetCount: 1,
    progressCount: 0,
    isCompleted: false,
    challengeDate: '2026-10-14',
    sortOrder: 3,
  ),
];

void main() {
  Widget buildTestWidget({
    List<Achievement>? achievements,
    List<DailyChallenge>? challenges,
    bool challengeError = false,
  }) {
    return ProviderScope(
      overrides: [
        currentUserProvider.overrideWith((ref) => _mockUser('user-1', 'user1@campus.edu')),
        achievementsRepositoryProvider.overrideWithValue(
          FakeAchievementsRepo(achievements ?? _testAchievements),
        ),
        challengesRepositoryProvider.overrideWithValue(
          FakeChallengesRepo(challenges ?? _testChallenges, shouldThrow: challengeError),
        ),
      ],
      child: const MaterialApp(
        home: RewardsScreen(),
      ),
    );
  }

  testWidgets('RewardsScreen displays only first 2 achievements initially, then expands with Show more and collapses with Show less',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    // 1. Initial State: First 2 achievements visible
    expect(find.text('First Report'), findsOneWidget);
    expect(find.text('10 Issues Reported'), findsOneWidget);
    // 3rd achievement should NOT be visible initially
    expect(find.text('10 Issues Resolved'), findsNothing);

    // Show more button is present
    expect(find.text('Show more'), findsOneWidget);

    // 2. Tap Show more to expand
    await tester.ensureVisible(find.text('Show more'));
    await tester.tap(find.text('Show more'));
    await tester.pumpAndSettle();

    // All 3 achievements are now visible
    expect(find.text('First Report'), findsOneWidget);
    expect(find.text('10 Issues Reported'), findsOneWidget);
    expect(find.text('10 Issues Resolved'), findsOneWidget);
    expect(find.text('Show less'), findsOneWidget);

    // 3. Tap Show less to collapse again
    await tester.ensureVisible(find.text('Show less'));
    await tester.tap(find.text('Show less'));
    await tester.pumpAndSettle();

    // 3rd achievement is collapsed again
    expect(find.text('First Report'), findsOneWidget);
    expect(find.text('10 Issues Reported'), findsOneWidget);
    expect(find.text('10 Issues Resolved'), findsNothing);
    expect(find.text('Show more'), findsOneWidget);
  });

  testWidgets('First Report is displayed as unlocked with timestamp for user with existing report',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    // First Report displays Unlocked pill and timestamp
    expect(find.text('Unlocked'), findsWidgets);
    expect(find.text('Earned on Oct 14, 2026'), findsOneWidget);

    // Locked milestone achievement displays progress/target
    expect(find.text('3 / 10'), findsWidgets);
  });

  testWidgets('Daily Challenges section renders real progress, completion status, and formatted date',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    expect(find.text('Daily Challenges'), findsOneWidget);
    expect(find.text('Today · 14 Oct'), findsOneWidget);
    expect(find.text('1 of 3 completed'), findsOneWidget);

    // Challenge titles
    expect(find.text('Daily Reporter'), findsOneWidget);
    expect(find.text('Water Watch'), findsOneWidget);
    expect(find.text('Energy Check'), findsOneWidget);

    // Completed state
    expect(find.text('Completed'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);
  });

  testWidgets('Daily Challenges error displays retry button instead of false progress',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(buildTestWidget(challengeError: true));
    await tester.pumpAndSettle();

    expect(find.text('Unable to load daily challenges.'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Retry'), findsOneWidget);
  });
}
