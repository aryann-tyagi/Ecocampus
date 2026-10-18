import 'package:flutter/material.dart';

enum NotificationEventType {
  reportSubmitted,
  reportAssigned,
  reportInProgress,
  reportResolved,
  reportRejected,
  reportDuplicate,
  adminNewReport,
  staffIssueAssigned,
  other;

  static NotificationEventType fromDbValue(String? value) {
    if (value == null) return NotificationEventType.other;
    switch (value.trim()) {
      case 'report_submitted':
        return NotificationEventType.reportSubmitted;
      case 'report_assigned':
        return NotificationEventType.reportAssigned;
      case 'report_in_progress':
        return NotificationEventType.reportInProgress;
      case 'report_resolved':
        return NotificationEventType.reportResolved;
      case 'report_rejected':
        return NotificationEventType.reportRejected;
      case 'report_duplicate':
        return NotificationEventType.reportDuplicate;
      case 'admin_new_report':
        return NotificationEventType.adminNewReport;
      case 'staff_issue_assigned':
        return NotificationEventType.staffIssueAssigned;
      default:
        return NotificationEventType.other;
    }
  }

  String toDbValue() {
    switch (this) {
      case NotificationEventType.reportSubmitted:
        return 'report_submitted';
      case NotificationEventType.reportAssigned:
        return 'report_assigned';
      case NotificationEventType.reportInProgress:
        return 'report_in_progress';
      case NotificationEventType.reportResolved:
        return 'report_resolved';
      case NotificationEventType.reportRejected:
        return 'report_rejected';
      case NotificationEventType.reportDuplicate:
        return 'report_duplicate';
      case NotificationEventType.adminNewReport:
        return 'admin_new_report';
      case NotificationEventType.staffIssueAssigned:
        return 'staff_issue_assigned';
      case NotificationEventType.other:
        return 'other';
    }
  }
}

class NotificationModel {
  final String id;
  final String userId;
  final String reportId;
  final String? statusEventId;
  final NotificationEventType eventType;
  final String title;
  final String message;
  final bool isRead;
  final DateTime? readAt;
  final DateTime createdAt;

  const NotificationModel({
    required this.id,
    required this.userId,
    required this.reportId,
    this.statusEventId,
    required this.eventType,
    required this.title,
    required this.message,
    this.isRead = false,
    this.readAt,
    required this.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: (json['id'] as String?) ?? '',
      userId: (json['user_id'] as String?) ?? '',
      reportId: (json['report_id'] as String?) ?? '',
      statusEventId: json['status_event_id'] as String?,
      eventType: NotificationEventType.fromDbValue(json['event_type'] as String?),
      title: (json['title'] as String?)?.trim() ?? 'Notification',
      message: (json['message'] as String?)?.trim() ?? '',
      isRead: (json['is_read'] as bool?) ?? false,
      readAt: json['read_at'] != null ? DateTime.tryParse(json['read_at'].toString()) : null,
      createdAt: json['created_at'] != null
          ? (DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now())
          : DateTime.now(),
    );
  }

  NotificationModel copyWith({
    String? id,
    String? userId,
    String? reportId,
    String? statusEventId,
    NotificationEventType? eventType,
    String? title,
    String? message,
    bool? isRead,
    DateTime? readAt,
    DateTime? createdAt,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      reportId: reportId ?? this.reportId,
      statusEventId: statusEventId ?? this.statusEventId,
      eventType: eventType ?? this.eventType,
      title: title ?? this.title,
      message: message ?? this.message,
      isRead: isRead ?? this.isRead,
      readAt: readAt ?? this.readAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  IconData get iconData {
    switch (eventType) {
      case NotificationEventType.reportSubmitted:
        return Icons.send_rounded;
      case NotificationEventType.reportAssigned:
        return Icons.assignment_ind_rounded;
      case NotificationEventType.reportInProgress:
        return Icons.construction_rounded;
      case NotificationEventType.reportResolved:
        return Icons.check_circle_rounded;
      case NotificationEventType.reportRejected:
        return Icons.cancel_rounded;
      case NotificationEventType.reportDuplicate:
        return Icons.copy_rounded;
      case NotificationEventType.adminNewReport:
        return Icons.campaign_rounded;
      case NotificationEventType.staffIssueAssigned:
        return Icons.build_circle_rounded;
      case NotificationEventType.other:
        return Icons.notifications_rounded;
    }
  }

  Color get iconColor {
    switch (eventType) {
      case NotificationEventType.reportResolved:
        return const Color(0xFF1EA05A);
      case NotificationEventType.reportInProgress:
        return const Color(0xFFD98327);
      case NotificationEventType.reportAssigned:
      case NotificationEventType.staffIssueAssigned:
        return const Color(0xFF144D37);
      case NotificationEventType.reportSubmitted:
      case NotificationEventType.adminNewReport:
        return const Color(0xFF2563EB);
      case NotificationEventType.reportRejected:
        return const Color(0xFFDC2626);
      case NotificationEventType.reportDuplicate:
        return const Color(0xFF6B7280);
      case NotificationEventType.other:
        return const Color(0xFF144D37);
    }
  }

  Color get iconBackgroundColor {
    switch (eventType) {
      case NotificationEventType.reportResolved:
        return const Color(0xFFE5F8EE);
      case NotificationEventType.reportInProgress:
        return const Color(0xFFFDF4E7);
      case NotificationEventType.reportAssigned:
      case NotificationEventType.staffIssueAssigned:
        return const Color(0xFFE8F7EE);
      case NotificationEventType.reportSubmitted:
      case NotificationEventType.adminNewReport:
        return const Color(0xFFEFF6FF);
      case NotificationEventType.reportRejected:
        return const Color(0xFFFEF2F2);
      case NotificationEventType.reportDuplicate:
        return const Color(0xFFF3F4F6);
      case NotificationEventType.other:
        return const Color(0xFFE8F7EE);
    }
  }

  String get relativeTime {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inSeconds < 45) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      final mins = difference.inMinutes;
      return '$mins ${mins == 1 ? "min" : "mins"} ago';
    } else if (difference.inHours < 24) {
      final hours = difference.inHours;
      return '$hours ${hours == 1 ? "hour" : "hours"} ago';
    } else if (difference.inDays < 7) {
      final days = difference.inDays;
      return '$days ${days == 1 ? "day" : "days"} ago';
    } else {
      return '${createdAt.day}/${createdAt.month}/${createdAt.year}';
    }
  }
}
