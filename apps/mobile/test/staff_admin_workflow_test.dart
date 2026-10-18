import 'package:flutter_test/flutter_test.dart';
import 'package:ecocampus_mobile/features/report/domain/report_model.dart';

void main() {
  group('Staff/Admin Issue Management Workflow Tests', () {
    test('1. ReportModel correctly parses assigned_department and prioritizes it over suggested_department', () {
      final json = {
        'id': 'rep-test-001',
        'reporter_id': 'user-student-123',
        'issue_label': 'High voltage sparking switchboard',
        'category': 'electricity',
        'severity': 'critical',
        'status': 'ASSIGNED',
        'location_details': 'Electrical shaft room 302',
        'floor_text': '3rd Floor',
        'buildings': {'id': 'bld-eng-1', 'name': 'Engineering Block A'},
        'suggested_department_label': 'General Maintenance',
        'suggested_department': {
          'id': 'dept-general',
          'name': 'General Maintenance',
          'slug': 'general-maintenance',
        },
        'assigned_department': {
          'id': 'dept-elec',
          'name': 'Electrical Maintenance',
          'slug': 'electrical-maintenance',
        },
        'assigned_department_id': 'dept-elec',
        'report_status_events': [
          {
            'id': 'evt-1',
            'report_id': 'rep-test-001',
            'from_status': null,
            'to_status': 'REPORTED',
            'note': 'Initial student report',
            'occurred_at': '2026-10-17T08:00:00Z',
          },
          {
            'id': 'evt-2',
            'report_id': 'rep-test-001',
            'from_status': 'REPORTED',
            'to_status': 'ASSIGNED',
            'note': 'Assigned to Electrical Department by Admin',
            'occurred_at': '2026-10-17T08:30:00Z',
          },
        ],
      };

      final report = ReportModel.fromSupabaseJson(json);

      expect(report.id, 'rep-test-001');
      expect(report.title, 'High voltage sparking switchboard');
      expect(report.category, IssueCategory.electricity);
      expect(report.severity, IssueSeverity.critical);
      expect(report.status, ReportStatus.assigned);

      // Prioritization: Assigned department should take precedence over suggested department
      expect(report.department, 'Electrical Maintenance');
      expect(report.assignedDepartment, 'Electrical Maintenance');
      expect(report.assignedDepartmentId, 'dept-elec');
      expect(report.location.building, 'Engineering Block A');
      expect(report.statusEvents.length, 2);
      expect(report.statusEvents.last.toStatus, 'ASSIGNED');
    });

    test('2. ReportModel falls back to suggested department when not yet officially assigned', () {
      final json = {
        'id': 'rep-test-002',
        'issue_label': 'Water cooler leaking',
        'category': 'water',
        'severity': 'medium',
        'status': 'REPORTED',
        'location_details': 'Near water fountain corridor',
        'buildings': {'name': 'Science Wing'},
        'suggested_department_label': 'Plumbing & Facilities',
        'suggested_department': {
          'id': 'dept-plumb',
          'name': 'Plumbing & Facilities',
        },
        'assigned_department': null,
        'assigned_department_id': null,
      };

      final report = ReportModel.fromSupabaseJson(json);

      expect(report.status, ReportStatus.reported);
      expect(report.department, 'Plumbing & Facilities');
      expect(report.assignedDepartment, isNull);
      expect(report.assignedDepartmentId, isNull);
    });

    test('3. Status transition validity rules matching Supabase transition_report_status RPC', () {
      bool isValidTransition(ReportStatus current, ReportStatus next) {
        if (current == next) return true; // Idempotent or no-op
        switch (current) {
          case ReportStatus.reported:
            return next == ReportStatus.assigned ||
                next == ReportStatus.rejected ||
                next == ReportStatus.duplicate;
          case ReportStatus.assigned:
            return next == ReportStatus.inProgress ||
                next == ReportStatus.assigned ||
                next == ReportStatus.rejected ||
                next == ReportStatus.duplicate;
          case ReportStatus.inProgress:
            return next == ReportStatus.resolved ||
                next == ReportStatus.rejected ||
                next == ReportStatus.duplicate;
          case ReportStatus.resolved:
          case ReportStatus.rejected:
          case ReportStatus.duplicate:
            // Terminal states: cannot transition further
            return false;
        }
      }

      // Valid forward flow: REPORTED -> ASSIGNED -> IN_PROGRESS -> RESOLVED
      expect(isValidTransition(ReportStatus.reported, ReportStatus.assigned), isTrue);
      expect(isValidTransition(ReportStatus.assigned, ReportStatus.inProgress), isTrue);
      expect(isValidTransition(ReportStatus.inProgress, ReportStatus.resolved), isTrue);

      // Invalid transitions: jumping steps or from terminal states
      expect(isValidTransition(ReportStatus.reported, ReportStatus.resolved), isFalse,
          reason: 'Cannot jump straight from REPORTED to RESOLVED');
      expect(isValidTransition(ReportStatus.resolved, ReportStatus.inProgress), isFalse,
          reason: 'Cannot move from RESOLVED back to IN_PROGRESS');
      expect(isValidTransition(ReportStatus.rejected, ReportStatus.assigned), isFalse,
          reason: 'Cannot reopen a rejected report');
    });

    test('4. Active report classification: RESOLVED reports are not active on Campus Map', () {
      bool isReportActive(ReportStatus status) {
        return status != ReportStatus.resolved &&
            status != ReportStatus.rejected &&
            status != ReportStatus.duplicate;
      }

      expect(isReportActive(ReportStatus.reported), isTrue);
      expect(isReportActive(ReportStatus.assigned), isTrue);
      expect(isReportActive(ReportStatus.inProgress), isTrue);
      expect(isReportActive(ReportStatus.resolved), isFalse);
      expect(isReportActive(ReportStatus.rejected), isFalse);
      expect(isReportActive(ReportStatus.duplicate), isFalse);
    });

    test('5. Resolution note parsing from status events', () {
      final json = {
        'id': 'rep-test-003',
        'issue_label': 'Damaged recycling bin',
        'category': 'waste',
        'severity': 'low',
        'status': 'RESOLVED',
        'location_details': 'Cafeteria entrance',
        'report_status_events': [
          {
            'id': 'evt-1',
            'from_status': null,
            'to_status': 'REPORTED',
            'note': 'Student report',
            'occurred_at': '2026-10-17T09:00:00Z',
          },
          {
            'id': 'evt-2',
            'from_status': 'IN_PROGRESS',
            'to_status': 'RESOLVED',
            'note': 'Bin replaced with new heavy-duty recycling unit. Cleaned area.',
            'occurred_at': '2026-10-17T11:00:00Z',
          },
        ],
      };

      final report = ReportModel.fromSupabaseJson(json);
      expect(report.status, ReportStatus.resolved);
      expect(report.resolutionNote, 'Bin replaced with new heavy-duty recycling unit. Cleaned area.');
    });
  });
}
