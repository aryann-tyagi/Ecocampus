import 'package:flutter/material.dart';

/// Represents an EcoCampus badge/achievement returned by the live get_my_achievements RPC.
///
/// Keys:
/// - [firstReportKey]: Unlocked after at least 1 valid report is submitted.
/// - [tenReportsKey]: Unlocked after at least 10 valid reports are submitted.
/// - [tenResolvedKey]: Unlocked after at least 10 reports reach Resolved status.
class Achievement {
  static const String firstReportKey = 'first_report';
  static const String tenReportsKey = 'ten_reports';
  static const String tenResolvedKey = 'ten_resolved';

  // Compatibility aliases
  static const String firstReportId = firstReportKey;
  static const String tenReportedId = tenReportsKey;
  static const String tenReportsId = tenReportsKey;
  static const String tenResolvedId = tenResolvedKey;

  final String achievementKey;
  final String title;
  final String description;
  final String iconKey;
  final int targetCount;
  final int progressCount;
  final bool isUnlocked;
  final DateTime? unlockedAt;
  final int sortOrder;

  const Achievement({
    required this.achievementKey,
    required this.title,
    required this.description,
    required this.iconKey,
    required this.targetCount,
    required this.progressCount,
    required this.isUnlocked,
    this.unlockedAt,
    this.sortOrder = 0,
  });

  // Backwards compatibility accessors
  String get id => achievementKey;
  int get target => targetCount;
  int get progress => progressCount;
  String get badgeIcon => iconKey;
  bool get isPending => false;

  /// Fraction of completion between 0.0 and 1.0.
  double get progressFraction {
    if (isUnlocked) return 1.0;
    if (targetCount <= 0) return 0.0;
    return (progressCount / targetCount).clamp(0.0, 1.0);
  }

  /// Human-readable progress string (e.g. "Unlocked" or "1 / 10").
  String get progressLabel {
    if (isUnlocked) return 'Unlocked';
    if (targetCount > 0) return '$progressCount / $targetCount';
    return 'Locked';
  }

  /// Formatted date string when unlocked.
  String? get formattedUnlockDate {
    if (unlockedAt == null) return null;
    final date = unlockedAt!.toLocal();
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final month = months[date.month - 1];
    return '$month ${date.day}, ${date.year}';
  }

  /// Material icon corresponding to [iconKey].
  IconData get iconData {
    switch (iconKey.toLowerCase()) {
      case 'flag':
        return Icons.flag_rounded;
      case 'clipboard-check':
      case 'format_list_numbered':
      case 'list':
        return Icons.assignment_turned_in_rounded;
      case 'check-circle':
        return Icons.check_circle_rounded;
      case 'shield':
        return Icons.shield_rounded;
      case 'water_drop':
        return Icons.water_drop_rounded;
      case 'bolt':
        return Icons.bolt_rounded;
      default:
        return Icons.emoji_events_rounded;
    }
  }

  /// Theme accent color for the badge.
  Color get accentColor {
    switch (achievementKey) {
      case firstReportKey:
        return const Color(0xFF1EA05A); // Green
      case tenReportsKey:
        return const Color(0xFF2E7D32); // Deep Forest Green
      case tenResolvedKey:
        return const Color(0xFF1976D2); // Blue
      default:
        return const Color(0xFF1EA05A);
    }
  }

  factory Achievement.fromJson(Map<String, dynamic> json) {
    return Achievement(
      achievementKey: (json['achievement_key'] as String?) ??
          (json['id'] as String?) ??
          '',
      title: (json['title'] as String?) ?? 'Achievement',
      description: (json['description'] as String?) ?? '',
      iconKey: (json['icon_key'] as String?) ??
          (json['badge_icon'] as String?) ??
          (json['icon_name'] as String?) ??
          'flag',
      targetCount: (json['target_count'] as num?)?.toInt() ??
          (json['target'] as num?)?.toInt() ??
          0,
      progressCount: (json['progress_count'] as num?)?.toInt() ??
          (json['progress'] as num?)?.toInt() ??
          0,
      isUnlocked: (json['is_unlocked'] as bool?) ?? false,
      unlockedAt: json['unlocked_at'] != null
          ? DateTime.tryParse(json['unlocked_at'].toString())
          : null,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'achievement_key': achievementKey,
      'title': title,
      'description': description,
      'icon_key': iconKey,
      'target_count': targetCount,
      'progress_count': progressCount,
      'is_unlocked': isUnlocked,
      'unlocked_at': unlockedAt?.toIso8601String(),
      'sort_order': sortOrder,
    };
  }

  /// Generates the standard baseline catalog when offline or in tests.
  static List<Achievement> buildCatalog({
    required int validReportCount,
    required int resolvedReportCount,
    Map<String, DateTime>? unlocks,
  }) {
    final unlockedMap = unlocks ?? {};

    return [
      // 1. First Report
      Achievement(
        achievementKey: firstReportKey,
        title: 'First Report',
        description: 'Submit your first campus issue report.',
        iconKey: 'flag',
        targetCount: 1,
        progressCount: validReportCount.clamp(0, 1),
        isUnlocked: validReportCount >= 1 || unlockedMap.containsKey(firstReportKey),
        unlockedAt: unlockedMap[firstReportKey] ?? (validReportCount >= 1 ? DateTime.now() : null),
        sortOrder: 1,
      ),

      // 2. 10 Issues Reported
      Achievement(
        achievementKey: tenReportsKey,
        title: '10 Issues Reported',
        description: 'Submit 10 campus issue reports.',
        iconKey: 'clipboard-check',
        targetCount: 10,
        progressCount: validReportCount.clamp(0, 10),
        isUnlocked: validReportCount >= 10 || unlockedMap.containsKey(tenReportsKey),
        unlockedAt: unlockedMap[tenReportsKey] ?? (validReportCount >= 10 ? DateTime.now() : null),
        sortOrder: 2,
      ),

      // 3. 10 Issues Resolved
      Achievement(
        achievementKey: tenResolvedKey,
        title: '10 Issues Resolved',
        description: 'Have 10 of your reports reach Resolved status.',
        iconKey: 'check-circle',
        targetCount: 10,
        progressCount: resolvedReportCount.clamp(0, 10),
        isUnlocked: resolvedReportCount >= 10 || unlockedMap.containsKey(tenResolvedKey),
        unlockedAt: unlockedMap[tenResolvedKey] ?? (resolvedReportCount >= 10 ? DateTime.now() : null),
        sortOrder: 3,
      ),
    ];
  }
}
