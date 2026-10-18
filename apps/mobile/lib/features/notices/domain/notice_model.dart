import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';

/// Domain model representing a campus notice displayed in the student mobile application.
class CampusNoticeModel {
  final String id;
  final String title;
  final String message;
  final String? summary;
  final String noticeType;
  final String priority;
  final bool isPinned;
  final String? targetBuildingId;
  final String? targetBuildingName;
  final DateTime startsAt;
  final DateTime? expiresAt;
  final DateTime? publishedAt;
  final DateTime? createdAt;

  const CampusNoticeModel({
    required this.id,
    required this.title,
    required this.message,
    this.summary,
    required this.noticeType,
    this.priority = 'normal',
    this.isPinned = false,
    this.targetBuildingId,
    this.targetBuildingName,
    required this.startsAt,
    this.expiresAt,
    this.publishedAt,
    this.createdAt,
  });

  bool get isUrgent => priority.toLowerCase() == 'urgent';
  bool get isImportant => priority.toLowerCase() == 'important';

  /// Readable type badge text
  String get typeLabel {
    switch (noticeType.toLowerCase()) {
      case 'issue_notice':
        return 'Issue Notice';
      case 'campus_announcement':
        return 'Announcement';
      case 'maintenance_update':
        return 'Maintenance';
      case 'utility_notice':
        return 'Utility';
      case 'safety_notice':
        return 'Safety Alert';
      case 'general_notice':
      default:
        return 'General';
    }
  }

  /// Icon representing the notice type
  IconData get iconData {
    switch (noticeType.toLowerCase()) {
      case 'issue_notice':
        return Icons.report_problem_rounded;
      case 'campus_announcement':
        return Icons.campaign_rounded;
      case 'maintenance_update':
        return Icons.build_rounded;
      case 'utility_notice':
        return Icons.water_drop_rounded;
      case 'safety_notice':
        return Icons.warning_amber_rounded;
      case 'general_notice':
      default:
        return Icons.info_outline_rounded;
    }
  }

  /// Accent color for the notice
  Color get accentColor {
    if (isUrgent) return const Color(0xFFE53935);
    if (isImportant) return const Color(0xFFF57C00);

    switch (noticeType.toLowerCase()) {
      case 'issue_notice':
        return const Color(0xFFE53935);
      case 'campus_announcement':
        return AppColors.primary;
      case 'maintenance_update':
        return const Color(0xFFF57C00);
      case 'utility_notice':
        return const Color(0xFF0288D1);
      case 'safety_notice':
        return const Color(0xFFD32F2F);
      case 'general_notice':
      default:
        return AppColors.primary;
    }
  }

  /// Background tint for badge pills
  Color get badgeBgColor {
    if (isUrgent) return const Color(0xFFFFEBEE);
    if (isImportant) return const Color(0xFFFFF3E0);
    return const Color(0xFFE8F7EE);
  }

  /// Formatted publication date
  String get formattedDate {
    final effective = publishedAt ?? startsAt;
    final now = DateTime.now();
    final difference = now.difference(effective);

    if (difference.inMinutes < 60) {
      final mins = difference.inMinutes;
      return mins <= 1 ? 'Just now' : '${mins}m ago';
    } else if (difference.inHours < 24) {
      final hours = difference.inHours;
      return '${hours}h ago';
    } else if (difference.inDays < 7) {
      final days = difference.inDays;
      return '${days}d ago';
    } else {
      return DateFormat('MMM d, yyyy').format(effective);
    }
  }

  factory CampusNoticeModel.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic val) {
      if (val is String) {
        return DateTime.tryParse(val)?.toLocal() ?? DateTime.now();
      }
      return DateTime.now();
    }

    DateTime? parseNullableDate(dynamic val) {
      if (val is String) {
        return DateTime.tryParse(val)?.toLocal();
      }
      return null;
    }

    return CampusNoticeModel(
      id: (json['id'] as String?) ?? '',
      title: (json['title'] as String?) ?? '',
      message: (json['message'] as String?) ?? '',
      summary: json['summary'] as String?,
      noticeType: (json['notice_type'] as String?) ?? 'general_notice',
      priority: (json['priority'] as String?) ?? 'normal',
      isPinned: (json['is_pinned'] as bool?) ?? false,
      targetBuildingId: json['target_building_id'] as String?,
      targetBuildingName: json['target_building_name'] as String?,
      startsAt: parseDate(json['starts_at']),
      expiresAt: parseNullableDate(json['expires_at']),
      publishedAt: parseNullableDate(json['published_at']),
      createdAt: parseNullableDate(json['created_at']),
    );
  }
}
