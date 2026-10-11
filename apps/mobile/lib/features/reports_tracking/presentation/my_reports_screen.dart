import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
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
    final allReports = ref.watch(reportsProvider);
    final activeReports = allReports.where((r) => r.status != ReportStatus.resolved).toList();
    final resolvedReports = allReports.where((r) => r.status == ReportStatus.resolved).toList();
    final currentList = _selectedTab == 0 ? activeReports : resolvedReports;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
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
                      child: _buildTabButton('Active (${activeReports.length})', _selectedTab == 0, () {
                        setState(() => _selectedTab = 0);
                      }),
                    ),
                    Expanded(
                      child: _buildTabButton('Resolved (${resolvedReports.length})', _selectedTab == 1, () {
                        setState(() => _selectedTab = 1);
                      }),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 8),

            // Report Cards List
            Expanded(
              child: currentList.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.assignment_turned_in_outlined, size: 54, color: AppColors.inkMuted),
                          const SizedBox(height: 12),
                          Text(
                            _selectedTab == 0 ? 'No active reports' : 'No resolved reports yet',
                            style: AppTextStyles.labelLarge.copyWith(color: AppColors.inkSecondary),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
                      itemCount: currentList.length,
                      itemBuilder: (context, index) {
                        final report = currentList[index];
                        return _buildReportCard(context, report);
                      },
                    ),
            ),
          ],
        ),
      ),
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
    final dateStr = DateFormat('dd MMM, h:mm a').format(report.createdAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF144D37).withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (ctx) => ReportDetailScreen(reportId: report.id),
            ),
          );
        },
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Status badge & Date
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildStatusBadge(report.status),
                  Text(
                    dateStr,
                    style: AppTextStyles.bodySmall.copyWith(fontSize: 11),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Issue Title
              Text(
                report.title,
                style: AppTextStyles.labelLarge.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 6),
              // Location row
              Row(
                children: [
                  const Icon(Icons.location_on_outlined, size: 15, color: AppColors.inkSecondary),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '${report.location.building} · ${report.location.floor} (${report.location.area})',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.inkSecondary,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Footer: Category chip & Severity badge & Arrow
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
                  SeverityBadge(severity: report.severity, compact: true),
                  const Spacer(),
                  const Icon(Icons.arrow_forward_ios_rounded, size: 13, color: AppColors.inkMuted),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(ReportStatus status) {
    Color bg;
    Color text;
    String label = status.displayName;

    switch (status) {
      case ReportStatus.reported:
        bg = const Color(0xFFE8F2FD);
        text = const Color(0xFF1976D2);
        break;
      case ReportStatus.assigned:
        bg = const Color(0xFFFEF4E6);
        text = const Color(0xFFD98327);
        break;
      case ReportStatus.inProgress:
        bg = const Color(0xFFF3E8FD);
        text = const Color(0xFF8E24AA);
        break;
      case ReportStatus.resolved:
        bg = const Color(0xFFE5F8EE);
        text = const Color(0xFF1EA05A);
        break;
      case ReportStatus.rejected:
      case ReportStatus.duplicate:
        bg = const Color(0xFFFCEAEA);
        text = const Color(0xFFC5231F);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: text,
        ),
      ),
    );
  }
}
