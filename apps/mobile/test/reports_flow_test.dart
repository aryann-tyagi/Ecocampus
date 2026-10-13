import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ecocampus_mobile/core/theme/app_theme.dart';
import 'package:ecocampus_mobile/features/report/data/campus_locations_repository.dart';
import 'package:ecocampus_mobile/features/report/data/reports_repository.dart';
import 'package:ecocampus_mobile/features/report/domain/campus_location_models.dart';
import 'package:ecocampus_mobile/features/report/domain/report_model.dart';
import 'package:ecocampus_mobile/features/report/presentation/report_issue_screen.dart';
import 'package:ecocampus_mobile/features/reports_tracking/presentation/my_reports_screen.dart';
import 'package:ecocampus_mobile/features/reports_tracking/presentation/report_detail_screen.dart';
import 'package:ecocampus_mobile/features/auth/data/auth_providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Fake in-memory ReportsRepository for unit and widget testing
class FakeReportsRepository extends ReportsRepository {
  final List<ReportModel> mockReports;
  bool shouldThrow = false;
  int uploadCallCount = 0;

  FakeReportsRepository({this.mockReports = const []}) : super(null);

  @override
  Future<String?> getSignedPhotoUrl(String storagePath, {int expiresIn = 3600}) async {
    return 'https://example.com/signed/$storagePath';
  }

  @override
  Future<ReportModel> submitReport({
    required ReportSubmissionDraft draft,
    required String userId,
  }) async {
    if (shouldThrow) throw Exception('Simulated database error');
    uploadCallCount++;
    return ReportModel(
      id: 'REP-MOCK-999',
      reporterId: userId,
      title: draft.title,
      category: draft.category,
      severity: draft.severity,
      location: CampusLocation(
        building: 'Engineering Block',
        floor: draft.floorText ?? 'Ground Floor',
        area: draft.locationDetails,
        buildingId: draft.buildingId,
        floorId: draft.floorId,
        floorText: draft.floorText,
        locationDetails: draft.locationDetails,
      ),
      status: ReportStatus.reported,
      createdAt: DateTime.now(),
      description: draft.description,
      department: draft.suggestedDepartmentLabel,
      imageUrl: 'https://example.com/signed/photo.jpg',
    );
  }

  @override
  Future<List<ReportModel>> getMyReports(String userId) async {
    if (shouldThrow) throw Exception('Failed to load user reports');
    return mockReports;
  }
}

/// Fake CampusLocationsRepository
class FakeCampusLocationsRepository extends CampusLocationsRepository {
  FakeCampusLocationsRepository() : super(null);

  @override
  Future<List<CampusBuilding>> getActiveBuildings() async {
    return const [
      CampusBuilding(id: 'b-eng', name: 'Engineering Block', slug: 'engineering-block'),
      CampusBuilding(id: 'b-hostel', name: 'Boys Hostel', slug: 'boys-hostel'),
    ];
  }

  @override
  Future<List<CampusFloor>> getFloorsForBuilding(String buildingId) async {
    if (buildingId == 'b-eng') {
      return const [
        CampusFloor(id: 'f-gnd', buildingId: 'b-eng', label: 'Ground Floor', sortOrder: 0),
        CampusFloor(id: 'f-1st', buildingId: 'b-eng', label: 'First Floor', sortOrder: 1),
      ];
    }
    return const [];
  }
}

void main() {
  group('Report & Location Models Tests', () {
    test('CampusBuilding and CampusFloor JSON serialization', () {
      final buildingJson = {
        'id': 'b1',
        'name': 'Library',
        'slug': 'library',
        'active': true,
      };
      final building = CampusBuilding.fromJson(buildingJson);
      expect(building.id, 'b1');
      expect(building.name, 'Library');

      final floorJson = {
        'id': 'f1',
        'building_id': 'b1',
        'label': 'Ground Floor',
        'sort_order': 0,
        'active': true,
      };
      final floor = CampusFloor.fromJson(floorJson);
      expect(floor.id, 'f1');
      expect(floor.label, 'Ground Floor');
    });

    test('ReportModel fromSupabaseJson maps fields, joins, and enums', () {
      final json = {
        'id': 'rep-123',
        'reporter_id': 'user-abc',
        'building_id': 'b-eng',
        'floor_id': 'f-1',
        'floor_text': null,
        'area_id': null,
        'location_details': 'Room 102',
        'category': 'water',
        'severity': 'critical',
        'issue_label': 'Burst pipe',
        'description': 'Water flooding corridor',
        'suggested_department_label': 'Plumbing & Facilities',
        'status': 'REPORTED',
        'created_at': '2026-10-13T01:00:00.000Z',
        'buildings': {'id': 'b-eng', 'name': 'Engineering Block', 'slug': 'eng'},
        'floors': {'id': 'f-1', 'label': 'Ground Floor', 'sort_order': 0},
        'report_media': [
          {'id': 'm1', 'storage_path': 'user-abc/draft-1/photo.jpg', 'mime_type': 'image/jpeg', 'position': 0}
        ],
        'report_status_events': [
          {'id': 'e1', 'report_id': 'rep-123', 'to_status': 'REPORTED', 'occurred_at': '2026-10-13T01:00:00.000Z'}
        ]
      };

      final report = ReportModel.fromSupabaseJson(json, primarySignedUrl: 'https://example.com/p.jpg');
      expect(report.id, 'rep-123');
      expect(report.category, IssueCategory.water);
      expect(report.severity, IssueSeverity.critical);
      expect(report.status, ReportStatus.reported);
      expect(report.location.building, 'Engineering Block');
      expect(report.location.floor, 'Ground Floor');
      expect(report.location.locationDetails, 'Room 102');
      expect(report.media.length, 1);
      expect(report.imageUrl, 'https://example.com/p.jpg');
    });

    test('ReportModel fromSupabaseJson safely parses real-shaped Supabase record with nullable fields and initial event', () {
      final realShapedJson = {
        'id': 'rep-nulls-001',
        'reporter_id': 'user-123',
        'building_id': 'b-main',
        'floor_id': null,
        'floor_text': '2nd Floor',
        'area_id': null,
        'location_details': 'Near East Stairwell',
        'category': 'electricity',
        'severity': 'medium',
        'issue_label': 'Flickering corridor light',
        'description': 'Light turns off randomly in the hallway',
        'suggested_department_id': null,
        'suggested_department_label': 'Electrical Maintenance',
        'latitude': null,
        'longitude': null,
        'status': 'REPORTED',
        'created_at': '2026-10-13T08:30:00.000Z',
        'buildings': {'id': 'b-main', 'name': 'Main Academic Block', 'slug': 'main'},
        'floors': null,
        'areas': null,
        'report_media': <dynamic>[],
        'report_status_events': [
          {
            'id': 'ev-init-001',
            // Note: report_id omitted from query, from_status null on initial report creation
            'from_status': null,
            'to_status': 'REPORTED',
            'actor_id': 'user-123',
            'note': null,
            'occurred_at': '2026-10-13T08:30:00.000Z',
          }
        ]
      };

      final report = ReportModel.fromSupabaseJson(realShapedJson);

      expect(report.id, 'rep-nulls-001');
      expect(report.reporterId, 'user-123');
      expect(report.title, 'Flickering corridor light');
      expect(report.category, IssueCategory.electricity);
      expect(report.severity, IssueSeverity.medium);
      expect(report.status, ReportStatus.reported);
      // Floor falls back to floor_text when floors relation is null
      expect(report.location.floor, '2nd Floor');
      expect(report.location.floorId, isNull);
      expect(report.location.floorText, '2nd Floor');
      // Area falls back to location_details when areas relation is null
      expect(report.location.area, 'Near East Stairwell');
      expect(report.location.areaId, isNull);
      expect(report.location.locationDetails, 'Near East Stairwell');
      expect(report.location.building, 'Main Academic Block');
      expect(report.location.formatted, 'Main Academic Block · 2nd Floor (Near East Stairwell)');
      // Department uses suggested_department_label when suggested_department_id is null
      expect(report.department, 'Electrical Maintenance');
      expect(report.departmentId, isNull);
      // Coordinates are nullable
      expect(report.latitude, isNull);
      expect(report.longitude, isNull);
      // Empty media list is handled safely
      expect(report.media, isEmpty);
      expect(report.imageUrl, isNull);
      // Initial status event with from_status == null is handled as report creation, not as an error
      expect(report.statusEvents.length, 1);
      final initialEvent = report.statusEvents.first;
      expect(initialEvent.id, 'ev-init-001');
      expect(initialEvent.reportId, 'rep-nulls-001'); // Resolved from fallback parent id
      expect(initialEvent.fromStatus, isNull);
      expect(initialEvent.toStatus, 'REPORTED');
      expect(initialEvent.isInitialCreation, isTrue);
      expect(initialEvent.displayTitle, 'Report Created');
    });

    test('ReportModel fromSupabaseJson handles missing embedded objects without crashing', () {
      final minimalJson = {
        'id': 'rep-minimal',
        'issue_label': 'Puddle on floor',
        'category': 'water',
        'severity': 'low',
        'location_details': 'Water dispenser area',
      };

      final report = ReportModel.fromSupabaseJson(minimalJson);

      expect(report.id, 'rep-minimal');
      expect(report.location.building, 'Campus Building');
      expect(report.location.floor, 'General Area');
      expect(report.location.area, 'Water dispenser area');
      expect(report.media, isEmpty);
      expect(report.statusEvents, isEmpty);
      expect(report.department, isNull);
    });

    test('ReportStatus enum conversions support canonical DB values', () {
      expect(ReportStatus.fromDbValue('REPORTED'), ReportStatus.reported);
      expect(ReportStatus.fromDbValue('ASSIGNED'), ReportStatus.assigned);
      expect(ReportStatus.fromDbValue('IN_PROGRESS'), ReportStatus.inProgress);
      expect(ReportStatus.fromDbValue('RESOLVED'), ReportStatus.resolved);
      expect(ReportStatus.fromDbValue('REJECTED'), ReportStatus.rejected);
      expect(ReportStatus.fromDbValue('DUPLICATE'), ReportStatus.duplicate);

      expect(ReportStatus.reported.toDbValue(), 'REPORTED');
      expect(ReportStatus.inProgress.toDbValue(), 'IN_PROGRESS');
      expect(ReportStatus.resolved.toDbValue(), 'RESOLVED');
    });
  });

  group('Reports Repository & Submission Flow Tests', () {
    test('Submit report calls repository and returns created model', () async {
      final fakeRepo = FakeReportsRepository();

      final draft = ReportSubmissionDraft(
        draftId: 'draft-abc',
        title: 'Broken chair',
        category: IssueCategory.infrastructure,
        severity: IssueSeverity.low,
        buildingId: 'b-eng',
        floorId: 'f-gnd',
        locationDetails: 'Room 101',
        description: 'Chair leg is broken',
        photoBytes: Uint8List.fromList([1, 2, 3]),
        photoMimeType: 'image/jpeg',
        photoFileName: 'chair.jpg',
      );

      final result = await fakeRepo.submitReport(draft: draft, userId: 'user-test');
      expect(result.id, 'REP-MOCK-999');
      expect(result.title, 'Broken chair');
      expect(result.category, IssueCategory.infrastructure);
      expect(fakeRepo.uploadCallCount, 1);
    });

    test('Submit report throws on backend error without claiming success', () async {
      final fakeRepo = FakeReportsRepository();
      fakeRepo.shouldThrow = true;

      final draft = ReportSubmissionDraft(
        draftId: 'draft-fail',
        title: 'Broken chair',
        category: IssueCategory.infrastructure,
        severity: IssueSeverity.low,
        buildingId: 'b-eng',
        locationDetails: 'Room 101',
        description: 'Chair leg is broken',
        photoBytes: Uint8List.fromList([1, 2, 3]),
        photoMimeType: 'image/jpeg',
        photoFileName: 'chair.jpg',
      );

      expect(
        () => fakeRepo.submitReport(draft: draft, userId: 'user-test'),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('My Reports Screen Widget Tests', () {
    testWidgets('Renders Active and Resolved tabs with correct filter counts', (tester) async {
      final testReports = [
        ReportModel(
          id: 'REP-001',
          title: 'Active Issue',
          category: IssueCategory.waste,
          severity: IssueSeverity.medium,
          location: const CampusLocation(building: 'Engineering Block', floor: '1st Floor', area: 'Hallway'),
          status: ReportStatus.reported,
          createdAt: DateTime.now(),
          description: 'Trash overflowing',
        ),
        ReportModel(
          id: 'REP-002',
          title: 'Resolved Issue',
          category: IssueCategory.electricity,
          severity: IssueSeverity.low,
          location: const CampusLocation(building: 'Library', floor: 'Ground Floor', area: 'Reading Hall'),
          status: ReportStatus.resolved,
          createdAt: DateTime.now().subtract(const Duration(days: 2)),
          description: 'AC was running',
          resolutionNote: 'Turned off by technician',
        ),
      ];

      final fakeRepo = FakeReportsRepository(mockReports: testReports);
      const mockUser = User(
        id: 'student-123',
        appMetadata: {},
        userMetadata: {},
        aud: 'authenticated',
        createdAt: '2026-01-01',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserProvider.overrideWithValue(mockUser),
            reportsRepositoryProvider.overrideWithValue(fakeRepo),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const MyReportsScreen(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Active tab shows 1 report
      expect(find.text('Active (1)'), findsOneWidget);
      expect(find.text('Resolved (1)'), findsOneWidget);
      expect(find.text('Active Issue'), findsOneWidget);
      expect(find.text('Resolved Issue'), findsNothing);

      // Switch to Resolved tab
      await tester.tap(find.text('Resolved (1)'));
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Resolved Issue'), findsOneWidget);
      expect(find.text('Active Issue'), findsNothing);
    });

    testWidgets('Report detail screen renders timeline, student note and location', (tester) async {
      final sampleReport = ReportModel(
        id: 'REP-DETAIL-001',
        title: 'Broken Water Tap',
        category: IssueCategory.water,
        severity: IssueSeverity.high,
        location: const CampusLocation(building: 'Hostel Mess', floor: 'Ground Floor', area: 'Kitchen'),
        status: ReportStatus.inProgress,
        createdAt: DateTime.now(),
        description: 'Tap leaking rapidly causing water waste',
        department: 'Plumbing & Facilities',
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: ReportDetailScreen(
              reportId: sampleReport.id,
              initialReport: sampleReport,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('REP-DETAIL-001'), findsOneWidget);
      expect(find.text('Broken Water Tap'), findsOneWidget);
      expect(find.text('Plumbing & Facilities'), findsOneWidget);
      expect(find.text('Tap leaking rapidly causing water waste'), findsOneWidget);
      expect(find.text('Lifecycle Tracking'), findsOneWidget);
    });

    testWidgets('ReportDetailScreen renders gracefully with null fields and initial status event', (tester) async {
      final realShapedJson = {
        'id': 'rep-widget-001',
        'reporter_id': 'user-123',
        'building_id': 'b-main',
        'floor_id': null,
        'floor_text': '3rd Floor',
        'area_id': null,
        'location_details': 'Study Room 305',
        'category': 'electricity',
        'severity': 'low',
        'issue_label': 'Blown fuse socket',
        'description': 'Power socket not working',
        'suggested_department_id': null,
        'suggested_department_label': 'Electrical Maintenance',
        'latitude': null,
        'longitude': null,
        'status': 'REPORTED',
        'created_at': '2026-10-13T09:00:00.000Z',
        'buildings': {'id': 'b-main', 'name': 'Science Building', 'slug': 'sci'},
        'floors': null,
        'areas': null,
        'report_media': <dynamic>[],
        'report_status_events': [
          {
            'id': 'ev-init-002',
            'from_status': null,
            'to_status': 'REPORTED',
            'actor_id': 'user-123',
            'note': null,
            'occurred_at': '2026-10-13T09:00:00.000Z',
          }
        ]
      };

      final report = ReportModel.fromSupabaseJson(realShapedJson);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: ReportDetailScreen(
              reportId: report.id,
              initialReport: report,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('rep-widget-001'), findsOneWidget);
      expect(find.text('Blown fuse socket'), findsOneWidget);
      expect(find.text('Electrical Maintenance'), findsOneWidget);
      expect(find.text('Science Building · 3rd Floor (Study Room 305)'), findsOneWidget);
      expect(find.text('Lifecycle Tracking'), findsOneWidget);
      expect(find.text('Activity History'), findsOneWidget);
      expect(find.text('Report Created'), findsOneWidget);
    });
  });

  group('Report Issue Screen Form Validation Tests', () {
    testWidgets('Shows validation error when submitting without a photo', (tester) async {
      final fakeLocationsRepo = FakeCampusLocationsRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            campusLocationsRepositoryProvider.overrideWithValue(fakeLocationsRepo),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const ReportIssueScreen(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      // Ensure button is scrolled into view before tapping
      await tester.ensureVisible(find.text('Submit report'));
      await tester.pumpAndSettle();

      // Attempt to submit without a photo
      await tester.tap(find.text('Submit report'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Verifies prompt requires photo
      expect(find.text('Please take or upload a photo of the issue.'), findsOneWidget);
    });
  });
}
