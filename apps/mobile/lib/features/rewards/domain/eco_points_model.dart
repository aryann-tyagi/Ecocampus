/// Scoring rules and level definitions for the EcoCampus EcoPoints system.
///
/// Single source of truth for gamification models, live database RPC contracts,
/// and level thresholds.
///
/// ## Live Database Scoring Rules:
/// - +5 points when a report is submitted.
/// - +15 points the first time that report reaches RESOLVED.
/// - Each reward event is idempotent for the same report/event.
/// - EcoScore is the total points capped at 100.
/// - Levels: Seedling (0–49), Sprout (50–99), Sapling (100–199), Tree (200–349), Forest Guardian (350+).
library;

import 'dart:math' as math;

/// A single point-earning event from the eco_point_events ledger.
class EcoPointEvent {
  final String id;
  final String userId;
  final String actionType;
  final int points;
  final String idempotencyKey;
  final String? referenceId;
  final String? description;
  final DateTime createdAt;

  const EcoPointEvent({
    required this.id,
    required this.userId,
    required this.actionType,
    required this.points,
    required this.idempotencyKey,
    this.referenceId,
    this.description,
    required this.createdAt,
  });

  factory EcoPointEvent.fromJson(Map<String, dynamic> json) {
    return EcoPointEvent(
      id: (json['id'] as String?) ?? '',
      userId: (json['user_id'] as String?) ?? '',
      actionType: (json['action_type'] as String?) ?? '',
      points: (json['points'] as num?)?.toInt() ?? 0,
      idempotencyKey: (json['idempotency_key'] as String?) ?? '',
      referenceId: json['reference_id'] as String?,
      description: json['description'] as String?,
      createdAt: json['created_at'] != null
          ? (DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now())
          : DateTime.now(),
    );
  }
}

/// A level definition in the EcoPoints progression system.
class EcoLevel {
  final int level;
  final String title;
  final int minPoints;

  const EcoLevel({
    required this.level,
    required this.title,
    required this.minPoints,
  });
}

/// The user's current EcoPoints summary, derived from get_my_eco_stats RPC or zero state.
class EcoPointsSummary {
  final int totalPoints;
  final int ecoScore;
  final int eventCount;
  final int level;
  final String levelTitle;
  final int nextLevelPoints;
  final double progressPercent;
  final EcoLevel currentLevel;
  final EcoLevel? nextLevel;

  /// Progress fraction within the current level (0.0 to 1.0).
  final double levelProgress;

  /// Points needed to reach the next level, or 0 if at max level.
  final int pointsToNextLevel;

  const EcoPointsSummary({
    required this.totalPoints,
    required this.ecoScore,
    required this.eventCount,
    required this.level,
    required this.levelTitle,
    required this.nextLevelPoints,
    required this.progressPercent,
    required this.currentLevel,
    this.nextLevel,
    required this.levelProgress,
    required this.pointsToNextLevel,
  });

  /// Creates a zero-points summary for new accounts or signed-out states.
  factory EcoPointsSummary.zero() {
    return const EcoPointsSummary(
      totalPoints: 0,
      ecoScore: 0,
      eventCount: 0,
      level: 1,
      levelTitle: 'Seedling',
      nextLevelPoints: 50,
      progressPercent: 0.0,
      currentLevel: EcoLevel(level: 1, title: 'Seedling', minPoints: 0),
      nextLevel: EcoLevel(level: 2, title: 'Sprout', minPoints: 50),
      levelProgress: 0.0,
      pointsToNextLevel: 50,
    );
  }

  /// Parses from live Supabase get_my_eco_stats RPC response.
  factory EcoPointsSummary.fromJson(Map<String, dynamic> json, {int eventCount = 0}) {
    final total = (json['total_points'] as num?)?.toInt() ?? 0;
    final score = (json['eco_score'] as num?)?.toInt() ?? (total > 100 ? 100 : total);

    // Dynamically derive current level and next level from actual EcoPoints as single source of truth
    final current = EcoScoringRules.levelForPoints(total);
    final next = EcoScoringRules.nextLevel(current);

    double progress;
    int toNext;
    int nextPoints;

    if (next == null) {
      progress = 1.0;
      toNext = 0;
      nextPoints = current.minPoints;
    } else {
      final levelRange = next.minPoints - current.minPoints;
      final pointsInLevel = total - current.minPoints;
      progress = levelRange > 0 ? (pointsInLevel / levelRange).clamp(0.0, 1.0) : 0.0;
      toNext = math.max(0, next.minPoints - total);
      nextPoints = next.minPoints;
    }

    return EcoPointsSummary(
      totalPoints: total,
      ecoScore: score,
      eventCount: eventCount,
      level: current.level,
      levelTitle: current.title,
      nextLevelPoints: nextPoints,
      progressPercent: progress * 100.0,
      currentLevel: current,
      nextLevel: next,
      levelProgress: progress,
      pointsToNextLevel: toNext,
    );
  }

  /// Compatibility constructor from total points and event count.
  factory EcoPointsSummary.fromTotals({
    required int totalPoints,
    required int eventCount,
  }) {
    final current = EcoScoringRules.levelForPoints(totalPoints);
    final next = EcoScoringRules.nextLevel(current);
    final score = totalPoints > 100 ? 100 : totalPoints;

    double progress;
    int toNext;
    int nextPoints;

    if (next == null) {
      progress = 1.0;
      toNext = 0;
      nextPoints = current.minPoints;
    } else {
      final levelRange = next.minPoints - current.minPoints;
      final pointsInLevel = totalPoints - current.minPoints;
      progress = levelRange > 0 ? (pointsInLevel / levelRange).clamp(0.0, 1.0) : 0.0;
      toNext = math.max(0, next.minPoints - totalPoints);
      nextPoints = next.minPoints;
    }

    return EcoPointsSummary(
      totalPoints: totalPoints,
      ecoScore: score,
      eventCount: eventCount,
      level: current.level,
      levelTitle: current.title,
      nextLevelPoints: nextPoints,
      progressPercent: progress * 100.0,
      currentLevel: current,
      nextLevel: next,
      levelProgress: progress,
      pointsToNextLevel: toNext,
    );
  }

}

/// Leaderboard entry returned by get_campus_leaderboard RPC.
class LeaderboardEntry {
  final int rank;
  final String displayName;
  final int totalPoints;
  final int level;
  final String levelTitle;
  final String userId;

  const LeaderboardEntry({
    required this.rank,
    required this.displayName,
    required this.totalPoints,
    this.level = 1,
    this.levelTitle = 'Seedling',
    this.userId = '',
  });

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return LeaderboardEntry(
      rank: (json['rank'] as num?)?.toInt() ?? 0,
      displayName: (json['display_name'] as String?)?.trim().isNotEmpty == true
          ? (json['display_name'] as String).trim()
          : 'Student',
      totalPoints: (json['total_points'] as num?)?.toInt() ?? 0,
      level: (json['level'] as num?)?.toInt() ?? 1,
      levelTitle: (json['level_title'] as String?) ?? 'Seedling',
      userId: (json['user_id'] as String?) ?? '',
    );
  }
}

/// Central source of truth for all EcoPoints scoring rules and level definitions.
abstract class EcoScoringRules {
  EcoScoringRules._();

  // ─── Point Awards (Live Database Rules) ──────────────────────────────

  /// Points earned when a valid report is submitted (+5 points).
  static const int reportSubmitted = 5;

  /// Points earned when a report reaches RESOLVED (+15 points).
  static const int reportResolved = 15;

  /// Points earned when a critical valid issue report is submitted (PRD baseline).
  static const int reportCritical = 50;

  /// Points earned when an eco challenge is completed (PRD baseline).
  static const int challengeCompleted = 100;

  // ─── Action Type Identifiers ────────────────────────────────────────

  static const String actionReportSubmitted = 'report_submitted';
  static const String actionReportCritical = 'report_critical';
  static const String actionReportResolved = 'report_resolved';
  static const String actionChallengeCompleted = 'challenge_completed';

  static int pointsForReportSubmission({required bool isCritical}) =>
      isCritical ? reportCritical : reportSubmitted;

  static String challengeCompletedKey(String challengeId, String userId) =>
      'challenge:$challengeId:$userId';

  // ─── Level Definitions (Live Database Taxonomy) ─────────────────────

  /// Levels: Seedling (0–49), Sprout (50–99), Sapling (100–199), Tree (200–349), Forest Guardian (350+).
  static const List<EcoLevel> levels = [
    EcoLevel(level: 1, title: 'Seedling', minPoints: 0),
    EcoLevel(level: 2, title: 'Sprout', minPoints: 50),
    EcoLevel(level: 3, title: 'Sapling', minPoints: 100),
    EcoLevel(level: 4, title: 'Tree', minPoints: 200),
    EcoLevel(level: 5, title: 'Forest Guardian', minPoints: 350),
  ];

  /// Returns the level for a given total points value.
  static EcoLevel levelForPoints(int points) {
    EcoLevel result = levels.first;
    for (final level in levels) {
      if (points >= level.minPoints) {
        result = level;
      } else {
        break;
      }
    }
    return result;
  }

  /// Returns the next level after [current], or null if at max.
  static EcoLevel? nextLevel(EcoLevel current) {
    final idx = levels.indexWhere((l) => l.level == current.level);
    if (idx < 0 || idx >= levels.length - 1) return null;
    return levels[idx + 1];
  }

  // ─── Idempotency Key Generators ─────────────────────────────────────

  static String reportSubmittedKey(String reportId) => 'report_submitted:$reportId';
  static String reportResolvedKey(String reportId) => 'report_resolved:$reportId';
}
