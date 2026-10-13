import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

/// Represents a daily challenge returned by the live get_my_daily_challenges RPC.
///
/// Challenges reset daily according to the Asia/Kolkata timezone:
/// - [dailyReporterKey]: Submit one campus issue report of any category today.
/// - [waterWatchKey]: Submit one report in the Water category today.
/// - [energyCheckKey]: Submit one report in the Electricity category today.
class DailyChallenge {
  static const String dailyReporterKey = 'daily_reporter';
  static const String waterWatchKey = 'water_watch';
  static const String energyCheckKey = 'energy_check';

  final String challengeKey;
  final String title;
  final String description;
  final int targetCount;
  final int progressCount;
  final bool isCompleted;
  final String challengeDate;
  final int sortOrder;

  const DailyChallenge({
    required this.challengeKey,
    required this.title,
    required this.description,
    required this.targetCount,
    required this.progressCount,
    required this.isCompleted,
    required this.challengeDate,
    this.sortOrder = 0,
  });

  /// Fraction of completion between 0.0 and 1.0.
  double get progressFraction {
    if (isCompleted) return 1.0;
    if (targetCount <= 0) return 0.0;
    return (progressCount / targetCount).clamp(0.0, 1.0);
  }

  /// Label showing progress or completed status.
  String get progressLabel {
    if (isCompleted) return 'Completed';
    return '$progressCount / $targetCount';
  }

  /// Icon corresponding to this challenge type.
  IconData get iconData {
    switch (challengeKey) {
      case dailyReporterKey:
        return Icons.edit_note_rounded;
      case waterWatchKey:
        return Icons.water_drop_rounded;
      case energyCheckKey:
        return Icons.bolt_rounded;
      default:
        return Icons.flag_rounded;
    }
  }

  /// Accent color for the challenge badge and progress bar.
  Color get accentColor {
    switch (challengeKey) {
      case dailyReporterKey:
        return AppColors.primary;
      case waterWatchKey:
        return const Color(0xFF0288D1);
      case energyCheckKey:
        return const Color(0xFFF57C00);
      default:
        return AppColors.primary;
    }
  }

  factory DailyChallenge.fromJson(Map<String, dynamic> json) {
    return DailyChallenge(
      challengeKey: (json['challenge_key'] as String?) ?? '',
      title: (json['title'] as String?) ?? 'Daily Challenge',
      description: (json['description'] as String?) ?? '',
      targetCount: (json['target_count'] as num?)?.toInt() ?? 1,
      progressCount: (json['progress_count'] as num?)?.toInt() ?? 0,
      isCompleted: (json['is_completed'] as bool?) ?? false,
      challengeDate: (json['challenge_date'] as String?) ?? '',
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'challenge_key': challengeKey,
      'title': title,
      'description': description,
      'target_count': targetCount,
      'progress_count': progressCount,
      'is_completed': isCompleted,
      'challenge_date': challengeDate,
      'sort_order': sortOrder,
    };
  }

  /// Fallback baseline generator for tests or offline state.
  static List<DailyChallenge> buildCatalog({
    int dailyReports = 0,
    int waterReports = 0,
    int energyReports = 0,
    String? challengeDate,
  }) {
    final date = challengeDate ?? DateTime.now().toIso8601String().split('T').first;

    return [
      DailyChallenge(
        challengeKey: dailyReporterKey,
        title: 'Daily Reporter',
        description: 'Submit one campus issue report today.',
        targetCount: 1,
        progressCount: dailyReports.clamp(0, 1),
        isCompleted: dailyReports >= 1,
        challengeDate: date,
        sortOrder: 1,
      ),
      DailyChallenge(
        challengeKey: waterWatchKey,
        title: 'Water Watch',
        description: 'Submit one report in the Water category today.',
        targetCount: 1,
        progressCount: waterReports.clamp(0, 1),
        isCompleted: waterReports >= 1,
        challengeDate: date,
        sortOrder: 2,
      ),
      DailyChallenge(
        challengeKey: energyCheckKey,
        title: 'Energy Check',
        description: 'Submit one report in the Electricity category today.',
        targetCount: 1,
        progressCount: energyReports.clamp(0, 1),
        isCompleted: energyReports >= 1,
        challengeDate: date,
        sortOrder: 3,
      ),
    ];
  }
}
