import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/severity_badge.dart';
import '../../report/data/reports_provider.dart';
import '../../report/domain/report_model.dart';

class ReportDetailScreen extends ConsumerWidget {
  final String reportId;

  const ReportDetailScreen({super.key, required this.reportId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reports = ref.watch(reportsProvider);
    final report = reports.firstWhere(
      (r) => r.id == reportId,
      orElse: () => reports.first,
    );

    final dateStr = DateFormat('dd MMMM yyyy, h:mm a').format(report.createdAt);

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
              child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: AppColors.inkPrimary),
            ),
          ),
        ),
        title: Text(
          report.id,
          style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.w800),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Timeline Card
            _buildTimelineCard(report),

            const SizedBox(height: 18),

            // Main Details Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF144D37).withValues(alpha: 0.05),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.inkSecondary,
                          ),
                        ),
                      ),
                      SeverityBadge(severity: report.severity),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    report.title,
                    style: AppTextStyles.titleMedium.copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: 19,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Reported: $dateStr',
                    style: AppTextStyles.bodySmall.copyWith(fontSize: 12),
                  ),
                  const Divider(height: 24, color: AppColors.borderLight),
                  // Location details
                  _buildDetailRow(
                    icon: Icons.location_on_outlined,
                    label: 'Location',
                    value: '${report.location.building} · ${report.location.floor}\n${report.location.area}',
                  ),
                  const SizedBox(height: 12),
                  // Department
                  _buildDetailRow(
                    icon: Icons.business_outlined,
                    label: 'Assigned Department',
                    value: report.department ?? 'Facilities Management',
                  ),
                  const SizedBox(height: 12),
                  // Description
                  _buildDetailRow(
                    icon: Icons.notes_outlined,
                    label: 'Student Note',
                    value: report.description,
                  ),
                ],
              ),
            ),

            if (report.resolutionNote != null) ...[
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFFE5F8EE),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: const Color(0xFFBCE8D1)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.task_alt_rounded, color: Color(0xFF1EA05A), size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Resolution Notes',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF144D37),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      report.resolutionNote!,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.inkPrimary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineCard(ReportModel report) {
    final stages = [
      {'name': 'Reported', 'done': true},
      {
        'name': 'Assigned',
        'done': report.status == ReportStatus.assigned ||
            report.status == ReportStatus.inProgress ||
            report.status == ReportStatus.resolved
      },
      {
        'name': 'In Progress',
        'done': report.status == ReportStatus.inProgress || report.status == ReportStatus.resolved
      },
      {'name': 'Resolved', 'done': report.status == ReportStatus.resolved},
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF144D37).withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Lifecycle Tracking',
            style: AppTextStyles.labelLarge.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          Row(
            children: List.generate(stages.length * 2 - 1, (index) {
              if (index.isEven) {
                final stageIdx = index ~/ 2;
                final stage = stages[stageIdx];
                final bool isDone = stage['done'] as bool;
                return Column(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: isDone ? const Color(0xFF1EA05A) : const Color(0xFFE4EDE7),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isDone ? Icons.check_rounded : Icons.circle_outlined,
                        size: 16,
                        color: isDone ? Colors.white : AppColors.inkMuted,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      stage['name'] as String,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: isDone ? FontWeight.w700 : FontWeight.w500,
                        color: isDone ? AppColors.inkPrimary : AppColors.inkMuted,
                      ),
                    ),
                  ],
                );
              } else {
                final prevIdx = (index - 1) ~/ 2;
                final bool isConnectedDone = stages[prevIdx + 1]['done'] as bool;
                return Expanded(
                  child: Container(
                    height: 3,
                    margin: const EdgeInsets.only(bottom: 20),
                    color: isConnectedDone ? const Color(0xFF1EA05A) : const Color(0xFFE4EDE7),
                  ),
                );
              }
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow({required IconData icon, required String label, required String value}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppColors.inkSecondary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTextStyles.bodySmall.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                  color: AppColors.inkMuted,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.inkPrimary,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
