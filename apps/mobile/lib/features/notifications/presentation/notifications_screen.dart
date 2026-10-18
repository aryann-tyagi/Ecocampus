import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ecocampus_mobile/core/theme/app_colors.dart';
import 'package:ecocampus_mobile/core/theme/app_theme.dart';
import 'package:ecocampus_mobile/features/auth/data/auth_providers.dart';
import 'package:ecocampus_mobile/features/report/data/reports_repository.dart';
import 'package:ecocampus_mobile/features/reports_tracking/presentation/report_detail_screen.dart';
import 'package:ecocampus_mobile/features/notifications/data/notifications_provider.dart';
import 'package:ecocampus_mobile/features/notifications/domain/notification_model.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    // Refresh notifications and unread badge on open
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(notificationsListProvider.notifier).refresh();
      ref.read(unreadNotificationCountProvider.notifier).refresh();
    });
  }

  Future<void> _handleNotificationTap(NotificationModel notification) async {
    // 1. Mark as read immediately
    if (!notification.isRead) {
      await ref.read(notificationsListProvider.notifier).markAsRead(notification.id);
    }

    if (!mounted) return;

    // 2. Fetch fresh report details from Supabase
    final user = ref.read(currentUserProvider);
    if (user != null && notification.reportId.isNotEmpty) {
      try {
        final repo = ref.read(reportsRepositoryProvider);
        final freshReport = await repo.getReportDetail(notification.reportId, user.id);

        if (mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ReportDetailScreen(
                reportId: notification.reportId,
                initialReport: freshReport,
              ),
            ),
          );
          return;
        }
      } catch (e) {
        debugPrint('Could not fetch report detail: $e');
      }
    }

    // Fallback: Open with reportId directly
    if (mounted && notification.reportId.isNotEmpty) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ReportDetailScreen(
            reportId: notification.reportId,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final notificationsAsync = ref.watch(notificationsListProvider);
    final unreadCount = ref.watch(unreadNotificationCountProvider).value ?? 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: InkWell(
            onTap: () => Navigator.of(context).pop(),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 18,
                color: AppColors.inkPrimary,
              ),
            ),
          ),
        ),
        title: Text(
          'Notifications',
          style: AppTextStyles.titleMedium.copyWith(
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        actions: [
          if (unreadCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: TextButton.icon(
                onPressed: () {
                  ref.read(notificationsListProvider.notifier).markAllAsRead();
                },
                icon: const Icon(
                  Icons.done_all_rounded,
                  size: 16,
                  color: AppColors.primary,
                ),
                label: const Text(
                  'Mark all read',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: notificationsAsync.when(
        data: (notifications) {
          if (notifications.isEmpty) {
            return _buildEmptyState();
          }

          return RefreshIndicator(
            onRefresh: () async {
              await Future.wait<void>([
                ref.read(notificationsListProvider.notifier).refresh(),
                ref.read(unreadNotificationCountProvider.notifier).refresh(),
              ]);
            },
            color: AppColors.primary,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 32),
              itemCount: notifications.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final notif = notifications[index];
                return _buildNotificationCard(notif);
              },
            ),
          );
        },
        loading: () => _buildLoadingSkeleton(),
        error: (error, _) => _buildErrorState(error),
      ),
    );
  }

  Widget _buildNotificationCard(NotificationModel notif) {
    return InkWell(
      onTap: () => _handleNotificationTap(notif),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: notif.isRead ? Colors.white.withValues(alpha: 0.85) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: notif.isRead ? AppColors.borderLight : const Color(0xFFBCE8D1),
            width: notif.isRead ? 1 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: notif.isRead
                  ? Colors.black.withValues(alpha: 0.02)
                  : const Color(0xFF144D37).withValues(alpha: 0.07),
              blurRadius: notif.isRead ? 4 : 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Event Icon
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: notif.iconBackgroundColor,
                shape: BoxShape.circle,
              ),
              child: Icon(
                notif.iconData,
                color: notif.iconColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            // Title & Message Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          notif.title,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: notif.isRead ? FontWeight.w600 : FontWeight.w800,
                            color: notif.isRead ? AppColors.inkPrimary : const Color(0xFF144D37),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        notif.relativeTime,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: notif.isRead ? AppColors.inkMuted : AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notif.message,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      color: notif.isRead ? AppColors.inkSecondary : AppColors.inkPrimary,
                    ),
                  ),
                ],
              ),
            ),
            // Unread Dot Indicator
            if (!notif.isRead) ...[
              const SizedBox(width: 10),
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(top: 6),
                decoration: const BoxDecoration(
                  color: Color(0xFF1EA05A),
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: const BoxDecoration(
                color: Color(0xFFE8F7EE),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.notifications_none_rounded,
                size: 44,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'All Caught Up!',
              style: AppTextStyles.titleMedium.copyWith(
                fontWeight: FontWeight.w800,
                fontSize: 19,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "You don't have any notifications right now. You'll receive updates when your reports are reviewed, assigned, or resolved.",
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.inkSecondary,
                fontSize: 13,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                ref.read(notificationsListProvider.notifier).refresh();
              },
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Refresh'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingSkeleton() {
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 32),
      itemCount: 5,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, __) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: const BoxDecoration(
                color: AppColors.surfaceSubtle,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 140,
                    height: 16,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceSubtle,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    height: 13,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceSubtle,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: 200,
                    height: 13,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceSubtle,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(Object error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: Color(0xFFFEF2F2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.wifi_off_rounded,
                size: 36,
                color: AppColors.severityCritical,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Unable to Load Notifications',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 17,
                color: AppColors.inkPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Please check your network connection and try again.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.inkSecondary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                ref.read(notificationsListProvider.notifier).refresh();
                ref.read(unreadNotificationCountProvider.notifier).refresh();
              },
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
