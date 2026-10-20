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

    test('Resolved reports are excluded from nearby reports feed', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final activeReport = ReportModel(
        id: 'ACTIVE-001',
        title: 'Active issue',
        category: IssueCategory.electricity,
        severity: IssueSeverity.medium,
        location: const CampusLocation(building: 'Block A', floor: '1st Floor', area: 'Corridor'),
        status: ReportStatus.reported,
        createdAt: DateTime.now(),
        description: 'Active light fixture broken',
      );

      final resolvedReport = ReportModel(
        id: 'RESOLVED-001',
        title: 'Resolved issue',
        category: IssueCategory.water,
        severity: IssueSeverity.low,
        location: const CampusLocation(building: 'Block B', floor: 'Ground Floor', area: 'Restroom'),
        status: ReportStatus.resolved,
        createdAt: DateTime.now(),
        description: 'Fixed tap leak',
      );

      container.read(reportsProvider.notifier).addReport(activeReport);
      container.read(reportsProvider.notifier).addReport(resolvedReport);

      final nearby = container.read(nearbyReportsProvider);
      expect(nearby.any((r) => r.id == 'ACTIVE-001'), isTrue);
      expect(nearby.any((r) => r.id == 'RESOLVED-001'), isFalse);
    });

    test('Soft-deleted reports (deletedAt != null) are excluded from nearby reports feed', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final activeReport = ReportModel(
        id: 'ACTIVE-002',
        title: 'Active issue 2',
        category: IssueCategory.waste,
        severity: IssueSeverity.low,
        location: const CampusLocation(building: 'Block C', floor: '2nd Floor', area: 'Common Room'),
        status: ReportStatus.assigned,
        createdAt: DateTime.now(),
        description: 'Bin overflow',
      );

      final deletedReport = ReportModel(
        id: 'DELETED-001',
        title: 'Removed issue',
        category: IssueCategory.cleanliness,
        severity: IssueSeverity.medium,
        location: const CampusLocation(building: 'Block D', floor: '1st Floor', area: 'Lobby'),
        status: ReportStatus.reported,
        createdAt: DateTime.now(),
        description: 'Cleanliness issue removed by admin',
        deletedAt: DateTime.now(),
        deletedBy: 'admin-uuid',
        deletionReason: 'Duplicate entry',
      );

      container.read(reportsProvider.notifier).addReport(activeReport);
      container.read(reportsProvider.notifier).addReport(deletedReport);

      final nearby = container.read(nearbyReportsProvider);
      expect(nearby.any((r) => r.id == 'ACTIVE-002'), isTrue);
      expect(nearby.any((r) => r.id == 'DELETED-001'), isFalse);
    });

    test('Soft deleting an active report immediately removes it from nearby feed', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final report = ReportModel(
        id: 'TO-DELETE-001',
        title: 'Temporary issue',
        category: IssueCategory.infrastructure,
        severity: IssueSeverity.high,
        location: const CampusLocation(building: 'Main Hall', floor: 'Ground Floor', area: 'Entrance'),
        status: ReportStatus.reported,
        createdAt: DateTime.now(),
        description: 'Broken handrail',
      );

      container.read(reportsProvider.notifier).addReport(report);
      expect(container.read(nearbyReportsProvider).any((r) => r.id == 'TO-DELETE-001'), isTrue);

      container.read(reportsProvider.notifier).softDeleteReport('TO-DELETE-001', reason: 'Safety resolved elsewhere');

      expect(container.read(nearbyReportsProvider).any((r) => r.id == 'TO-DELETE-001'), isFalse);
      // But the report still exists in reportsProvider for audit/history
      final storedReport = container.read(reportsProvider).firstWhere((r) => r.id == 'TO-DELETE-001');
      expect(storedReport.isDeleted, isTrue);
      expect(storedReport.deletionReason, 'Safety resolved elsewhere');
    });

    test('Resolving an active report immediately removes it from nearby feed', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final report = ReportModel(
        id: 'TO-RESOLVE-001',
        title: 'Issue to be fixed',
        category: IssueCategory.water,
        severity: IssueSeverity.medium,
        location: const CampusLocation(building: 'Hostel 1', floor: 'Floor 3', area: 'Bathroom'),
        status: ReportStatus.inProgress,
        createdAt: DateTime.now(),
        description: 'Leaking shower head',
      );

      container.read(reportsProvider.notifier).addReport(report);
      expect(container.read(nearbyReportsProvider).any((r) => r.id == 'TO-RESOLVE-001'), isTrue);

      container.read(reportsProvider.notifier).updateReportStatus(
            'TO-RESOLVE-001',
            ReportStatus.resolved,
            resolutionNote: 'Shower head replaced and tested',
          );

      expect(container.read(nearbyReportsProvider).any((r) => r.id == 'TO-RESOLVE-001'), isFalse);
      // Preserved in reportsProvider for student history
      final storedReport = container.read(reportsProvider).firstWhere((r) => r.id == 'TO-RESOLVE-001');
      expect(storedReport.status, ReportStatus.resolved);
      expect(storedReport.resolutionNote, 'Shower head replaced and tested');
    });
  });
}
