import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ecocampus_mobile/core/theme/app_theme.dart';
import 'package:ecocampus_mobile/features/auth/data/auth_providers.dart';
import 'package:ecocampus_mobile/features/rewards/domain/eco_points_model.dart';
import 'package:ecocampus_mobile/features/rewards/data/eco_points_provider.dart';
import 'package:ecocampus_mobile/features/rewards/presentation/rewards_screen.dart';
import 'package:ecocampus_mobile/features/rewards/presentation/widgets/rewards_sapling_progress_header.dart';

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

class _StaticLeaderboardNotifier extends LeaderboardNotifier {
  final List<LeaderboardEntry> _entries;
  _StaticLeaderboardNotifier(this._entries);

  @override
  FutureOr<List<LeaderboardEntry>> build() => _entries;
}

class _ErrorLeaderboardNotifier extends LeaderboardNotifier {
  @override
  FutureOr<List<LeaderboardEntry>> build() =>
      throw Exception('Leaderboard network timeout');
}

void main() {
  group('1. Level Progression Logic & Threshold Tests', () {
    test('Points below, at, between, and above thresholds calculate accurately', () {
      final testCases = [
        // Seedling (0–49)
        {'pts': 0, 'lvl': 1, 'title': 'Seedling', 'next': 'Sprout', 'nextLvl': 2, 'toNext': 50, 'prog': 0.0},
        {'pts': 25, 'lvl': 1, 'title': 'Seedling', 'next': 'Sprout', 'nextLvl': 2, 'toNext': 25, 'prog': 0.5},
        {'pts': 49, 'lvl': 1, 'title': 'Seedling', 'next': 'Sprout', 'nextLvl': 2, 'toNext': 1, 'prog': 0.98},

        // Sprout (50–99)
        {'pts': 50, 'lvl': 2, 'title': 'Sprout', 'next': 'Sapling', 'nextLvl': 3, 'toNext': 50, 'prog': 0.0},
        {'pts': 75, 'lvl': 2, 'title': 'Sprout', 'next': 'Sapling', 'nextLvl': 3, 'toNext': 25, 'prog': 0.5},
        {'pts': 99, 'lvl': 2, 'title': 'Sprout', 'next': 'Sapling', 'nextLvl': 3, 'toNext': 1, 'prog': 0.98},

        // Sapling (100–199)
        {'pts': 100, 'lvl': 3, 'title': 'Sapling', 'next': 'Tree', 'nextLvl': 4, 'toNext': 100, 'prog': 0.0},
        {'pts': 120, 'lvl': 3, 'title': 'Sapling', 'next': 'Tree', 'nextLvl': 4, 'toNext': 80, 'prog': 0.20},
        {'pts': 150, 'lvl': 3, 'title': 'Sapling', 'next': 'Tree', 'nextLvl': 4, 'toNext': 50, 'prog': 0.50},
        {'pts': 199, 'lvl': 3, 'title': 'Sapling', 'next': 'Tree', 'nextLvl': 4, 'toNext': 1, 'prog': 0.99},

        // Tree (200–349)
        {'pts': 200, 'lvl': 4, 'title': 'Tree', 'next': 'Forest Guardian', 'nextLvl': 5, 'toNext': 150, 'prog': 0.0},
        {'pts': 275, 'lvl': 4, 'title': 'Tree', 'next': 'Forest Guardian', 'nextLvl': 5, 'toNext': 75, 'prog': 0.50},
        {'pts': 349, 'lvl': 4, 'title': 'Tree', 'next': 'Forest Guardian', 'nextLvl': 5, 'toNext': 1, 'prog': 149 / 150},

        // Forest Guardian (350+ max level)
        {'pts': 350, 'lvl': 5, 'title': 'Forest Guardian', 'next': null, 'nextLvl': null, 'toNext': 0, 'prog': 1.0},
        {'pts': 500, 'lvl': 5, 'title': 'Forest Guardian', 'next': null, 'nextLvl': null, 'toNext': 0, 'prog': 1.0},
      ];

      for (final tc in testCases) {
        final pts = tc['pts'] as int;
        final summaryFromTotals = EcoPointsSummary.fromTotals(totalPoints: pts, eventCount: 1);
        final summaryFromJson = EcoPointsSummary.fromJson({'total_points': pts});

        for (final summary in [summaryFromTotals, summaryFromJson]) {
          expect(summary.totalPoints, pts);
          expect(summary.level, tc['lvl'], reason: 'Level mismatch at $pts pts');
          expect(summary.levelTitle, tc['title'], reason: 'Title mismatch at $pts pts');
          expect(summary.pointsToNextLevel, tc['toNext'], reason: 'Points to next level mismatch at $pts pts');
          expect(summary.levelProgress, closeTo(tc['prog'] as double, 0.01), reason: 'Progress mismatch at $pts pts');

          if (tc['next'] == null) {
            expect(summary.nextLevel, isNull, reason: 'Expected max level reached at $pts pts');
          } else {
            expect(summary.nextLevel, isNotNull, reason: 'Expected next level at $pts pts');
            expect(summary.nextLevel!.title, tc['next']);
            expect(summary.nextLevel!.level, tc['nextLvl']);
          }
        }
      }
    });

    test('Never shows 0 pts to go while below a threshold across every point value 0-349', () {
      for (int pts = 0; pts < 350; pts++) {
        final summary = EcoPointsSummary.fromJson({'total_points': pts});
        expect(
          summary.nextLevel,
          isNotNull,
          reason: 'Level $pts must have a next level before 350 pts',
        );
        expect(
          summary.pointsToNextLevel > 0,
          isTrue,
          reason: 'Points to next level must be > 0 at $pts pts, got ${summary.pointsToNextLevel}',
        );
      }
    });

    testWidgets('UI renders proper next level target and never shows 0 pts to go at 150 pts', (tester) async {
      final summary150 = EcoPointsSummary.fromJson({'total_points': 150});

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: RewardsSaplingProgressHeader(
              summary: summary150,
              animated: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sapling'), findsOneWidget);
      expect(find.text('150 EcoPoints'), findsOneWidget);
      expect(find.text('Level 3 of 5'), findsOneWidget);
      expect(find.text('Next: Tree · Level 4 (50 pts to go)'), findsOneWidget);
      expect(find.textContaining('(0 pts to go)'), findsNothing);
    });

    testWidgets('UI dynamically advances level to Tree and updates badge at 200 pts', (tester) async {
      final summary200 = EcoPointsSummary.fromJson({'total_points': 200});

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: RewardsSaplingProgressHeader(
              summary: summary200,
              animated: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Tree'), findsOneWidget);
      expect(find.text('200 EcoPoints'), findsOneWidget);
      expect(find.text('Level 4 of 5'), findsOneWidget);
      expect(find.text('Next: Forest Guardian · Level 5 (150 pts to go)'), findsOneWidget);
      expect(find.byIcon(Icons.shield_rounded), findsOneWidget);
    });

    testWidgets('UI displays celebratory max level message and badge at 350+ pts', (tester) async {
      final summary350 = EcoPointsSummary.fromJson({'total_points': 350});

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: RewardsSaplingProgressHeader(
              summary: summary350,
              animated: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Forest Guardian'), findsOneWidget);
      expect(find.text('350 EcoPoints'), findsOneWidget);
      expect(find.text('Level 5 of 5'), findsOneWidget);
      expect(find.text('Max level reached! 🌟'), findsOneWidget);
      expect(find.textContaining('pts to go'), findsNothing);
      expect(find.byIcon(Icons.workspace_premium_rounded), findsOneWidget);
    });
  });

  group('2. Leaderboard Real Data & Empty/Error State Tests', () {
    testWidgets('Production leaderboard displays genuine student and no hardcoded test values', (tester) async {
      final genuineLeaderboard = [
        const LeaderboardEntry(
          rank: 1,
          displayName: 'Aryan',
          totalPoints: 150,
          level: 3,
          levelTitle: 'Sapling',
          userId: 'dc0b22d0-765f-4aa9-a27f-f132f862b061',
        ),
      ];

      final testUser = _mockUser('dc0b22d0-765f-4aa9-a27f-f132f862b061', 'aryantyagi556@gmail.com');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserProvider.overrideWith((ref) => testUser),
            leaderboardProvider.overrideWith(() => _StaticLeaderboardNotifier(genuineLeaderboard)),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const RewardsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify genuine student is rendered
      expect(find.text('Aryan (You)'), findsOneWidget);
      expect(find.text('150 pts'), findsOneWidget);
      expect(find.text('Level 3 · Sapling'), findsOneWidget);

      // Verify no test users ('Test Student', 'System', 'demo') appear in the leaderboard
      expect(find.text('Test Student'), findsNothing);
      expect(find.text('System'), findsNothing);
      expect(find.text('Demo Student'), findsNothing);
    });

    testWidgets('Empty leaderboard shows informative empty state without fake/placeholder rows', (tester) async {
      final testUser = _mockUser('empty-user-id', 'student@university.edu');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserProvider.overrideWith((ref) => testUser),
            leaderboardProvider.overrideWith(() => _StaticLeaderboardNotifier(const [])),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const RewardsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Must show authentic empty state
      expect(find.text('No ranked students yet'), findsOneWidget);
      expect(find.text('Submit reports to earn EcoPoints and claim #1!'), findsOneWidget);

      // Must NOT display synthetic rows
      expect(find.text('Student'), findsNothing);
      expect(find.text('Priya Sharma'), findsNothing);
    });

    testWidgets('Network error state shows clean error message without injecting mock accounts', (tester) async {
      final testUser = _mockUser('err-user-id', 'student@university.edu');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserProvider.overrideWith((ref) => testUser),
            leaderboardProvider.overrideWith(() => _ErrorLeaderboardNotifier()),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const RewardsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Could not load leaderboard.'), findsOneWidget);
      expect(find.text('No ranked students yet'), findsNothing);
      expect(find.text('Test Student'), findsNothing);
      expect(find.text('System'), findsNothing);
    });
  });
}
