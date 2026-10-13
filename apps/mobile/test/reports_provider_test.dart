import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ecocampus_mobile/features/report/data/reports_provider.dart';
import 'package:ecocampus_mobile/features/report/domain/report_model.dart';

void main() {
  group('EcoCampus Riverpod State Tests', () {


    test('Adding a new report updates reports list and nearby reports', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final initialCount = container.read(reportsProvider).length;
      expect(initialCount, 0); // No hardcoded mock reports

      final testReport = ReportModel(
        id: 'TEST-001',
        title: 'Water leak',
        category: IssueCategory.water,
        severity: IssueSeverity.high,
        location: const CampusLocation(building: 'Block B', floor: '1st Floor', area: 'Corridor'),
        status: ReportStatus.reported,
        createdAt: DateTime.now(),
        description: 'Water leaking from pipe',
      );

      container.read(reportsProvider.notifier).addReport(testReport);

      final updatedReports = container.read(reportsProvider);
      expect(updatedReports.length, 1);
      expect(updatedReports.first.id, 'TEST-001');

      final nearby = container.read(nearbyReportsProvider);
      expect(nearby.length, 1);
      expect(nearby.first.id, 'TEST-001');
    });

    test('Updating report status transitions correctly', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final testReport = ReportModel(
        id: 'TEST-001',
        title: 'Water leak',
        category: IssueCategory.water,
        severity: IssueSeverity.high,
        location: const CampusLocation(building: 'Block B', floor: '1st Floor', area: 'Corridor'),
        status: ReportStatus.reported,
        createdAt: DateTime.now(),
        description: 'Water leaking from pipe',
      );
      container.read(reportsProvider.notifier).addReport(testReport);

      container.read(reportsProvider.notifier).updateReportStatus(
            'TEST-001',
            ReportStatus.inProgress,
          );

      final report = container.read(reportsProvider).firstWhere((r) => r.id == 'TEST-001');
      expect(report.status, ReportStatus.inProgress);
    });
  });
}
