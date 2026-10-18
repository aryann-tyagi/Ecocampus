import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/custom_bottom_nav.dart';
import '../../../core/widgets/severity_badge.dart';
import '../../report/data/reports_provider.dart';
import '../../report/domain/report_model.dart';
import 'report_detail_screen.dart';

class MyReportsScreen extends ConsumerStatefulWidget {
  const MyReportsScreen({super.key});

  @override
  ConsumerState<MyReportsScreen> createState() => _MyReportsScreenState();
}

class _MyReportsScreenState extends ConsumerState<MyReportsScreen> {
  int _selectedTab = 0; // 0: Active, 1: Resolved

  @override
  Widget build(BuildContext context) {
    final reportsAsync = ref.watch(myReportsProvider);

    final double scaffoldBottomPadding = MediaQuery.paddingOf(context).bottom;
    final double hardwareBottomInset = MediaQuery.viewPaddingOf(context).bottom;

    // When hosted inside MainNavigationShell's Scaffold(extendBody: true),
    // Scaffold automatically includes the bottomNavigationBar height in MediaQuery.paddingOf(context).bottom.
    // To prevent duplicating this inset, we use the Scaffold-provided bottom padding directly if available,
    // or fallback to CustomBottomNavBar.totalHeight(context) if tested standalone without a parent Scaffold.
    final double navBarHeight = scaffoldBottomPadding > hardwareBottomInset
        ? scaffoldBottomPadding
        : CustomBottomNavBar.totalHeight(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            bottom: navBarHeight,
            child: SafeArea(
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
            // Top Title & Subtitle
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'My Reports',
                    style: AppTextStyles.titleLarge.copyWith(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Track issue lifecycle and departmental resolution',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.inkSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            // Tab bar and body
            Expanded(
              child: reportsAsync.when(
                data: (allReports) {
                  final activeReports = allReports
                      .where((r) =>
                          r.status != ReportStatus.resolved &&
                          r.status != ReportStatus.rejected &&
                          r.status != ReportStatus.duplicate)
                      .toList();

                  final resolvedReports = allReports
                      .where((r) =>
                          r.status == ReportStatus.resolved ||
                          r.status == ReportStatus.rejected ||
                          r.status == ReportStatus.duplicate)
                      .toList();

                  final currentList = _selectedTab == 0 ? activeReports : resolvedReports;

                  return RefreshIndicator(
                    onRefresh: () => ref.read(myReportsProvider.notifier).refresh(),
                    color: AppColors.primary,
                    child: Column(
                      children: [
                        // Tabs (Active / Resolved)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF144D37).withValues(alpha: 0.04),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: _buildTabButton(
                                    'Active (${activeReports.length})',
                                    _selectedTab == 0,
                                    () => setState(() => _selectedTab = 0),
                                  ),
                                ),
                                Expanded(
                                  child: _buildTabButton(
                                    'Resolved (${resolvedReports.length})',
                                    _selectedTab == 1,
                                    () => setState(() => _selectedTab = 1),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 8),

                        // Reports List or Empty State
                        Expanded(
                          child: currentList.isEmpty
                              ? _buildEmptyState()
                              : ListView.builder(
                                  physics: const AlwaysScrollableScrollPhysics(
                                    parent: BouncingScrollPhysics(),
                                  ),
                                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                                  itemCount: currentList.length,
                                  itemBuilder: (context, index) {
                                    final report = currentList[index];
                                    return _buildReportCard(context, report);
                                  },
                                ),
                        ),
                      ],
                    ),
                  );
                },
                loading: _buildLoadingSkeleton,
                error: (err, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.cloud_off_rounded, size: 54, color: AppColors.severityCritical),
                        const SizedBox(height: 14),
                        Text(
                          'Failed to load reports',
                          style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '$err',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.bodySmall.copyWith(color: AppColors.inkSecondary),
                        ),
                        const SizedBox(height: 18),
                        ElevatedButton.icon(
                          onPressed: () => ref.read(myReportsProvider.notifier).refresh(),
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: const Text('Try Again'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  ],
),
);
  }

  Widget _buildEmptyState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.18),
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Color(0xFFE8F7EE),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.assignment_turned_in_outlined,
                  size: 48,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _selectedTab == 0 ? 'No active reports' : 'No resolved reports yet',
                style: AppTextStyles.labelLarge.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: AppColors.inkPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _selectedTab == 0
                    ? 'Issues you submit will be tracked here.'
                    : 'Resolved issues and notes will appear here.',
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.inkSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTabButton(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              color: isSelected ? Colors.white : AppColors.inkSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReportCard(BuildContext context, ReportModel report) {
    final dateStr = DateFormat('dd MMM yyyy, h:mm a').format(report.createdAt);

    return Container(
      key: ValueKey('report-card-${report.id}'),
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF144D37).withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => ReportDetailScreen(
                  reportId: report.id,
                  initialReport: report,
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: Category, Severity, and Status Badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceSubtle,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            report.category.displayName,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.inkSecondary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SeverityBadge(severity: report.severity),
                      ],
                    ),
                    _buildStatusPill(report.status),
                  ],
                ),

                const SizedBox(height: 12),

                // Middle: Thumbnail and Title / Description
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (report.imageUrl != null) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          width: 60,
                          height: 60,
                          color: AppColors.surfaceSubtle,
                          child: Image.network(
                            report.imageUrl!,
                            fit: BoxFit.cover,
                            cacheWidth: 180,
                            cacheHeight: 180,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.photo_outlined,
                              color: AppColors.inkMuted,
                              size: 24,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            report.title,
                            style: AppTextStyles.titleMedium.copyWith(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            report.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.inkSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const Divider(height: 20, color: AppColors.borderLight),

                // Footer: Location & Date
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined, size: 14, color: AppColors.primary),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        report.location.formatted,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodySmall.copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.inkPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      dateStr,
                      style: AppTextStyles.bodySmall.copyWith(
                        fontSize: 10,
                        color: AppColors.inkMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusPill(ReportStatus status) {
    Color bg;
    Color fg;
    switch (status) {
      case ReportStatus.reported:
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFF92400E);
        break;
      case ReportStatus.assigned:
        bg = const Color(0xFFE0E7FF);
        fg = const Color(0xFF3730A3);
        break;
      case ReportStatus.inProgress:
        bg = const Color(0xFFDBEAFE);
        fg = const Color(0xFF1E40AF);
        break;
      case ReportStatus.resolved:
        bg = const Color(0xFFD1FAE5);
        fg = const Color(0xFF065F46);
        break;
      case ReportStatus.rejected:
      case ReportStatus.duplicate:
        bg = const Color(0xFFFEE2E2);
        fg = const Color(0xFF991B1B);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.displayName,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: fg,
        ),
      ),
    );
  }

  Widget _buildLoadingSkeleton() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      itemCount: 4,
      itemBuilder: (ctx, i) => Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(width: 80, height: 18, color: AppColors.surfaceSubtle),
                Container(width: 60, height: 18, color: AppColors.surfaceSubtle),
              ],
            ),
            const SizedBox(height: 12),
            Container(width: 180, height: 16, color: AppColors.surfaceSubtle),
            const SizedBox(height: 8),
            Container(width: double.infinity, height: 12, color: AppColors.surfaceSubtle),
            const SizedBox(height: 16),
            Container(width: 120, height: 12, color: AppColors.surfaceSubtle),
          ],
        ),
      ),
    );
  }
}
