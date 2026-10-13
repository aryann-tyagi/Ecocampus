import 'package:flutter_test/flutter_test.dart';
import 'package:ecocampus_mobile/features/rewards/domain/eco_points_model.dart';

void main() {
  group('EcoScoringRules Tests', () {
    test('Points constants match current database scoring rules', () {
      expect(EcoScoringRules.reportSubmitted, 5);
      expect(EcoScoringRules.reportResolved, 15);
      expect(EcoScoringRules.reportCritical, 50);
      expect(EcoScoringRules.challengeCompleted, 100);
    });

    test('pointsForReportSubmission awards 50 for critical and 5 for standard', () {
      expect(EcoScoringRules.pointsForReportSubmission(isCritical: false), 5);
      expect(EcoScoringRules.pointsForReportSubmission(isCritical: true), 50);
    });

    test('All 5 live database levels are defined in ascending order', () {
      expect(EcoScoringRules.levels.length, 5);
      for (int i = 0; i < EcoScoringRules.levels.length - 1; i++) {
        expect(
          EcoScoringRules.levels[i].minPoints < EcoScoringRules.levels[i + 1].minPoints,
          isTrue,
          reason: 'Level ${i + 1} minPoints must be less than level ${i + 2}',
        );
      }
    });

    test('levelForPoints maps correctly to live database level tiers', () {
      // Seedling (0–49)
      expect(EcoScoringRules.levelForPoints(0).level, 1);
      expect(EcoScoringRules.levelForPoints(0).title, 'Seedling');
      expect(EcoScoringRules.levelForPoints(49).level, 1);
      expect(EcoScoringRules.levelForPoints(49).title, 'Seedling');

      // Sprout (50–99)
      expect(EcoScoringRules.levelForPoints(50).level, 2);
      expect(EcoScoringRules.levelForPoints(50).title, 'Sprout');
      expect(EcoScoringRules.levelForPoints(99).level, 2);

      // Sapling (100–199)
      expect(EcoScoringRules.levelForPoints(100).level, 3);
      expect(EcoScoringRules.levelForPoints(100).title, 'Sapling');
      expect(EcoScoringRules.levelForPoints(199).level, 3);

      // Tree (200–349)
      expect(EcoScoringRules.levelForPoints(200).level, 4);
      expect(EcoScoringRules.levelForPoints(200).title, 'Tree');
      expect(EcoScoringRules.levelForPoints(349).level, 4);

      // Forest Guardian (350+)
      expect(EcoScoringRules.levelForPoints(350).level, 5);
      expect(EcoScoringRules.levelForPoints(350).title, 'Forest Guardian');
      expect(EcoScoringRules.levelForPoints(9999).level, 5);
      expect(EcoScoringRules.levelForPoints(9999).title, 'Forest Guardian');
    });

    test('nextLevel returns correct progression and null at max', () {
      final lvl1 = EcoScoringRules.levels[0];
      final next1 = EcoScoringRules.nextLevel(lvl1);
      expect(next1, isNotNull);
      expect(next1!.level, 2);
      expect(next1.title, 'Sprout');

      final lvl5 = EcoScoringRules.levels[4];
      expect(EcoScoringRules.nextLevel(lvl5), isNull);
    });

    test('Idempotency keys are formatted reliably', () {
      expect(EcoScoringRules.reportSubmittedKey('REP-123'), 'report_submitted:REP-123');
      expect(EcoScoringRules.reportResolvedKey('REP-123'), 'report_resolved:REP-123');
      expect(EcoScoringRules.challengeCompletedKey('CH-1', 'USER-999'), 'challenge:CH-1:USER-999');
    });
  });

  group('EcoPointsSummary Tests', () {
    test('EcoPointsSummary.zero creates valid initial state', () {
      final summary = EcoPointsSummary.zero();
      expect(summary.totalPoints, 0);
      expect(summary.ecoScore, 0);
      expect(summary.eventCount, 0);
      expect(summary.level, 1);
      expect(summary.levelTitle, 'Seedling');
      expect(summary.nextLevel?.level, 2);
      expect(summary.levelProgress, 0.0);
      expect(summary.pointsToNextLevel, 50);
    });

    test('EcoPointsSummary.fromJson correctly maps live get_my_eco_stats RPC payload', () {
      final json = {
        'total_points': 65,
        'eco_score': 65,
        'level': 2,
        'level_title': 'Sprout',
        'next_level_points': 100,
        'progress_percent': 30.0,
      };

      final summary = EcoPointsSummary.fromJson(json);
      expect(summary.totalPoints, 65);
      expect(summary.ecoScore, 65);
      expect(summary.level, 2);
      expect(summary.levelTitle, 'Sprout');
      expect(summary.nextLevelPoints, 100);
      expect(summary.progressPercent, 30.0);
      expect(summary.pointsToNextLevel, 35);
      expect(summary.levelProgress, 0.3);
    });

    test('EcoScore caps at 100 even with high total points', () {
      final json = {
        'total_points': 400,
        'eco_score': 100,
        'level': 5,
        'level_title': 'Forest Guardian',
        'next_level_points': 350,
        'progress_percent': 100.0,
      };

      final summary = EcoPointsSummary.fromJson(json);
      expect(summary.totalPoints, 400);
      expect(summary.ecoScore, 100);
      expect(summary.level, 5);
      expect(summary.levelTitle, 'Forest Guardian');
      expect(summary.pointsToNextLevel, 0);
    });
  });

  group('JSON Serialization Tests', () {
    test('EcoPointEvent parses JSON correctly', () {
      final json = {
        'id': 'evt-1',
        'user_id': 'usr-1',
        'action_type': 'report_submitted',
        'points': 5,
        'idempotency_key': 'report_submitted:rep-1',
        'reference_id': 'rep-1',
        'description': 'Submitted report',
        'created_at': '2026-10-13T10:00:00Z',
      };

      final event = EcoPointEvent.fromJson(json);
      expect(event.id, 'evt-1');
      expect(event.userId, 'usr-1');
      expect(event.actionType, 'report_submitted');
      expect(event.points, 5);
      expect(event.idempotencyKey, 'report_submitted:rep-1');
      expect(event.referenceId, 'rep-1');
      expect(event.description, 'Submitted report');
    });

    test('LeaderboardEntry parses JSON correctly with fallbacks', () {
      final json = {
        'rank': 1,
        'display_name': 'Aryan Tyagi',
        'total_points': 25,
        'level': 1,
        'level_title': 'Seedling',
      };

      final entry = LeaderboardEntry.fromJson(json);
      expect(entry.rank, 1);
      expect(entry.displayName, 'Aryan Tyagi');
      expect(entry.totalPoints, 25);
      expect(entry.level, 1);
      expect(entry.levelTitle, 'Seedling');
    });
  });
}
