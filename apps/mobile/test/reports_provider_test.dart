import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ecocampus_mobile/features/report/data/reports_provider.dart';
import 'package:ecocampus_mobile/features/report/domain/report_model.dart';

void main() {
  group('EcoCampus Riverpod State Tests', () {
    test('Initial local points counter is empty', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(userPointsProvider), 0);
    });

    test('Adding 30 points updates balance correctly', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(userPointsProvider.notifier).addPoints(30);
      expect(container.read(userPointsProvider), 30);
    });

    test('Adding a new report updates reports list and nearby reports', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final initialCount = container.read(reportsProvider).length;

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
      expect(updatedReports.length, initialCount + 1);
      expect(updatedReports.first.id, 'TEST-001');
    });

    test('Updating report status transitions correctly', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final reportToUpdate = ReportModel(
        id: 'TEST-STATUS-001',
        title: 'Broken light',
        category: IssueCategory.electricity,
        severity: IssueSeverity.medium,
        location: const CampusLocation(building: 'Engineering Block', floor: 'Second Floor', area: 'Corridor'),
        status: ReportStatus.reported,
        createdAt: DateTime.now(),
        description: 'A light is not working.',
      );
      container.read(reportsProvider.notifier).addReport(reportToUpdate);
      container.read(reportsProvider.notifier).updateReportStatus(
            'TEST-STATUS-001',
            ReportStatus.inProgress,
          );

      final report = container.read(reportsProvider).firstWhere((r) => r.id == 'TEST-STATUS-001');
      expect(report.status, ReportStatus.inProgress);
    });
  });
}
