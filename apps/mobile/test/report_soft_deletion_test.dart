import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ecocampus_mobile/features/report/domain/report_model.dart';
import 'package:ecocampus_mobile/features/report/data/reports_provider.dart';
import 'package:ecocampus_mobile/features/reports_tracking/presentation/my_reports_screen.dart';
import 'package:ecocampus_mobile/features/reports_tracking/presentation/report_detail_screen.dart';

void main() {
  group('Report Soft-Deletion Workflow & Student Visibility Tests', () {
    test('1. ReportModel correctly parses deleted_at, deleted_by, and deletion_reason', () {
      final json = {
        'id': 'rep-deleted-101',
        'reporter_id': 'user-student-456',
        'issue_label': 'Graffiti on Library Wall',
        'description': 'Spray paint on second floor exterior wall.',
        'category': 'cleanliness',
        'severity': 'low',
        'status': 'REPORTED',
        'location_details': 'West wing library wall',
        'buildings': {'id': 'bld-lib', 'name': 'Central Library'},
        'created_at': '2026-10-18T10:00:00Z',
        'deleted_at': '2026-10-18T14:30:00Z',
        'deleted_by': 'admin-uuid-789',
        'deletion_reason': 'Duplicate report: Already logged by facilities staff.',
      };

      final report = ReportModel.fromSupabaseJson(json);

      expect(report.id, 'rep-deleted-101');
      expect(report.reporterId, 'user-student-456');
      expect(report.title, 'Graffiti on Library Wall');
      expect(report.category, IssueCategory.cleanliness);
      expect(report.severity, IssueSeverity.low);
      expect(report.status, ReportStatus.reported); // Original status preserved
      expect(report.isDeleted, isTrue);
      expect(report.deletedAt, DateTime.parse('2026-10-18T14:30:00Z'));
      expect(report.deletedBy, 'admin-uuid-789');
      expect(report.deletionReason, 'Duplicate report: Already logged by facilities staff.');
    });

    test('2. ReportModel defaults isDeleted to false when deleted_at is null', () {
      final json = {
        'id': 'rep-active-102',
        'reporter_id': 'user-student-456',
        'issue_label': 'Water leak under sink',
        'category': 'water',
        'severity': 'high',
        'status': 'IN_PROGRESS',
        'location_details': 'Room 101 sink',
        'buildings': {'name': 'Science Wing'},
        'created_at': '2026-10-18T12:00:00Z',
        'deleted_at': null,
        'deleted_by': null,
        'deletion_reason': null,
      };

      final report = ReportModel.fromSupabaseJson(json);

      expect(report.isDeleted, isFalse);
      expect(report.deletedAt, isNull);
      expect(report.deletedBy, isNull);
      expect(report.deletionReason, isNull);
    });

    testWidgets('3. Soft-deleted reports appear in Resolved/Archived tab and not in Active tab', (tester) async {
      final activeReport = ReportModel(
        id: 'rep-active-1',
        title: 'Active Trash Overflow',
        category: IssueCategory.waste,
        severity: IssueSeverity.medium,
        location: const CampusLocation(
          building: 'Student Centre',
          floor: 'Ground',
          area: 'Canteen',
        ),
        status: ReportStatus.reported,
        createdAt: DateTime(2026, 10, 18, 9, 0),
        description: 'Trash bin is overflowing.',
        deletedAt: null,
      );

      final deletedReport = ReportModel(
        id: 'rep-deleted-2',
        title: 'Removed Duplicate Light Issue',
        category: IssueCategory.electricity,
        severity: IssueSeverity.low,
        location: const CampusLocation(
          building: 'Engineering Block',
          floor: '1st Floor',
          area: 'Room 102',
        ),
        status: ReportStatus.reported, // original status was reported
        createdAt: DateTime(2026, 10, 18, 8, 0),
        description: 'Tube light flickering.',
        deletedAt: DateTime(2026, 10, 18, 11, 30),
        deletionReason: 'Duplicate report: Maintenance ticket already open.',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            myReportsProvider.overrideWith(() => _MockMyReportsNotifier([activeReport, deletedReport])),
          ],
          child: const MaterialApp(
            home: MyReportsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // In Active Tab (selectedTab == 0):
      // Should show 'Active (1)' and 'Resolved (1)'
      expect(find.text('Active (1)'), findsOneWidget);
      expect(find.text('Resolved (1)'), findsOneWidget);

      // Active report is visible
      expect(find.text('Active Trash Overflow'), findsOneWidget);
      // Soft-deleted report must NOT be visible in Active tab
      expect(find.text('Removed Duplicate Light Issue'), findsNothing);

      // Switch to Resolved Tab (which contains completed and removed reports)
      await tester.tap(find.text('Resolved (1)'));
      await tester.pumpAndSettle();

      // Soft-deleted report should now be visible
      expect(find.text('Removed Duplicate Light Issue'), findsOneWidget);
      // Visible "Removed by Admin" badge
      expect(find.text('Removed by Admin'), findsWidgets);
      // Visible reason
      expect(
        find.textContaining('Duplicate report: Maintenance ticket already open.'),
        findsOneWidget,
      );
    });

    testWidgets('4. ReportDetailScreen displays deletion notice banner with reason when opened', (tester) async {
      final deletedReport = ReportModel(
        id: 'rep-deleted-detail-3',
        title: 'Broken Chair in Corridor',
        category: IssueCategory.infrastructure,
        severity: IssueSeverity.low,
        location: const CampusLocation(
          building: 'Main Block',
          floor: 'Floor 2',
          area: 'Hallway',
        ),
        status: ReportStatus.reported,
        createdAt: DateTime(2026, 10, 18, 10, 0),
        description: 'Chair leg is broken.',
        deletedAt: DateTime(2026, 10, 18, 13, 15),
        deletionReason: 'Invalid report: Chair was relocated to workshop.',
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: ReportDetailScreen(
              reportId: deletedReport.id,
              initialReport: deletedReport,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should display deletion banner
      expect(find.textContaining('Report Removed by Admin'), findsOneWidget);
      expect(
        find.textContaining('Invalid report: Chair was relocated to workshop.'),
        findsOneWidget,
      );
      expect(
        find.textContaining('This report is no longer active in campus feeds'),
        findsOneWidget,
      );
      // Original title & location preserved
      expect(find.text('Broken Chair in Corridor'), findsOneWidget);
    });

    testWidgets('5. Fallback explanation displays when no explicit deletion reason was entered', (tester) async {
      final deletedReportNoReason = ReportModel(
        id: 'rep-deleted-no-reason',
        title: 'Spill on staircase',
        category: IssueCategory.cleanliness,
        severity: IssueSeverity.low,
        location: const CampusLocation(
          building: 'Hostel A',
          floor: 'Stairwell',
          area: 'Landing',
        ),
        status: ReportStatus.reported,
        createdAt: DateTime(2026, 10, 18, 10, 0),
        description: 'Water spilled.',
        deletedAt: DateTime(2026, 10, 18, 12, 0),
        deletionReason: '', // Empty reason
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: ReportDetailScreen(
              reportId: deletedReportNoReason.id,
              initialReport: deletedReportNoReason,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(
        find.textContaining('This report was removed by an administrator.'),
        findsOneWidget,
      );
    });
  });
}

class _MockMyReportsNotifier extends MyReportsNotifier {
  final List<ReportModel> _reports;
  _MockMyReportsNotifier(this._reports);

  @override
  Future<List<ReportModel>> build() async {
    return _reports;
  }
}
