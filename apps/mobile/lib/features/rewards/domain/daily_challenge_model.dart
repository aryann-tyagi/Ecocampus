import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

/// Represents a student challenge returned by live Supabase challenge RPCs.
/// Supports custom admin-configured challenges with customizable EcoPoints rewards,
/// criteria filters (category, building, count), and recurrence rules (daily, weekly, one_time).
class DailyChallenge {
  static const String dailyReporterKey = 'daily_reporter';
  static const String waterWatchKey = 'water_watch';
  static const String energyCheckKey = 'energy_check';

  final String? id;
  final String challengeKey;
  final String title;
  final String description;
  final String? instructions;
  final String challengeType;
  final String? category;
  final String? buildingId;
  final String? buildingName;
  final int targetCount;
  final int progressCount;
  final int rewardPoints; // ADMIN CUSTOMIZABLE POINTS
  final String recurrenceType; // 'daily', 'weekly', 'one_time'
  final bool isPinned;
  final bool isCompleted;
  final String challengeDate;
  final int sortOrder;
  final DateTime? completedAt;
  final DateTime? endsAt;

  const DailyChallenge({
    this.id,
    required this.challengeKey,
    required this.title,
    required this.description,
    this.instructions,
    this.challengeType = 'report_issue',
    this.category,
    this.buildingId,
    this.buildingName,
    required this.targetCount,
    required this.progressCount,
    this.rewardPoints = 25,
    this.recurrenceType = 'daily',
    this.isPinned = false,
    required this.isCompleted,
    required this.challengeDate,
    this.sortOrder = 0,
    this.completedAt,
    this.endsAt,
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

  /// Recurrence tag
  String get recurrenceLabel {
    switch (recurrenceType.toLowerCase()) {
      case 'weekly':
        return 'WEEKLY';
      case 'one_time':
        return 'SPECIAL';
      case 'daily':
      default:
        return 'DAILY';
    }
  }

  /// Icon corresponding to this challenge type or required category.
  IconData get iconData {
    if (category != null) {
      switch (category!.toLowerCase()) {
        case 'water':
          return Icons.water_drop_rounded;
        case 'electricity':
          return Icons.bolt_rounded;
        case 'waste':
          return Icons.delete_outline_rounded;
        case 'cleanliness':
          return Icons.cleaning_services_rounded;
        case 'greenery':
          return Icons.park_rounded;
        case 'infrastructure':
          return Icons.handyman_rounded;
      }
    }

    switch (challengeType) {
      case 'category_reporting':
        return Icons.category_rounded;
      case 'building_reporting':
        return Icons.apartment_rounded;
      case 'multiple_reports':
        return Icons.fact_check_rounded;
      case 'report_issue':
      default:
        return Icons.edit_note_rounded;
    }
  }

  /// Accent color for the challenge badge and progress bar.
  Color get accentColor {
    if (category != null) {
      switch (category!.toLowerCase()) {
        case 'water':
          return const Color(0xFF0288D1);
        case 'electricity':
          return const Color(0xFFF57C00);
        case 'waste':
          return AppColors.primary;
        case 'cleanliness':
          return const Color(0xFF0097A7);
        case 'greenery':
          return const Color(0xFF2E7D32);
        case 'infrastructure':
          return const Color(0xFFE65100);
      }
    }

    switch (recurrenceType.toLowerCase()) {
      case 'weekly':
        return const Color(0xFF5E35B1);
      case 'one_time':
        return const Color(0xFFC2185B);
      case 'daily':
      default:
        return AppColors.primary;
    }
  }

  factory DailyChallenge.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic val) {
      if (val is String) return DateTime.tryParse(val)?.toLocal();
      return null;
    }

    return DailyChallenge(
      id: json['id'] as String?,
      challengeKey: (json['challenge_key'] as String?) ?? '',
      title: (json['title'] as String?) ?? 'Challenge',
      description: (json['description'] as String?) ?? '',
      instructions: json['instructions'] as String?,
      challengeType: (json['challenge_type'] as String?) ?? 'report_issue',
      category: json['category'] as String?,
      buildingId: json['building_id'] as String?,
      buildingName: json['building_name'] as String?,
      targetCount: (json['target_count'] as num?)?.toInt() ?? 1,
      progressCount: (json['progress_count'] as num?)?.toInt() ?? 0,
      rewardPoints: (json['reward_points'] as num?)?.toInt() ?? 25,
      recurrenceType: (json['recurrence_type'] as String?) ?? 'daily',
      isPinned: (json['is_pinned'] as bool?) ?? false,
      isCompleted: (json['is_completed'] as bool?) ?? false,
      challengeDate: (json['period_key'] as String?) ?? (json['challenge_date'] as String?) ?? '',
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      completedAt: parseDate(json['completed_at']),
      endsAt: parseDate(json['ends_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'challenge_key': challengeKey,
      'title': title,
      'description': description,
      'instructions': instructions,
      'challenge_type': challengeType,
      'category': category,
      'building_id': buildingId,
      'building_name': buildingName,
      'target_count': targetCount,
      'progress_count': progressCount,
      'reward_points': rewardPoints,
      'recurrence_type': recurrenceType,
      'is_pinned': isPinned,
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
        title: 'Daily Campus Reporter',
        description: 'Submit one campus issue report today.',
        targetCount: 1,
        progressCount: dailyReports.clamp(0, 1),
        isCompleted: dailyReports >= 1,
        rewardPoints: 25,
        challengeDate: date,
        sortOrder: 1,
      ),
      DailyChallenge(
        challengeKey: waterWatchKey,
        title: 'Water Sentinel',
        description: 'Submit one report in the Water category today.',
        targetCount: 1,
        progressCount: waterReports.clamp(0, 1),
        isCompleted: waterReports >= 1,
        rewardPoints: 30,
        category: 'water',
        challengeDate: date,
        sortOrder: 2,
      ),
      DailyChallenge(
        challengeKey: energyCheckKey,
        title: 'Energy Scout',
        description: 'Submit one report in the Electricity category today.',
        targetCount: 1,
        progressCount: energyReports.clamp(0, 1),
        isCompleted: energyReports >= 1,
        rewardPoints: 30,
        category: 'electricity',
        challengeDate: date,
        sortOrder: 3,
      ),
    ];
  }
}
