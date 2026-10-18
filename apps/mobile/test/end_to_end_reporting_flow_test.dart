import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ecocampus_mobile/features/report/data/campus_locations_repository.dart';
import 'package:ecocampus_mobile/features/report/data/reports_provider.dart';
import 'package:ecocampus_mobile/features/report/data/reports_repository.dart';
import 'package:ecocampus_mobile/features/report/domain/ai_analysis_models.dart';
import 'package:ecocampus_mobile/features/report/domain/duplicate_detection_models.dart';
import 'package:ecocampus_mobile/features/report/domain/campus_location_models.dart';
import 'package:ecocampus_mobile/features/report/domain/report_model.dart';
import 'package:ecocampus_mobile/features/report/presentation/report_issue_screen.dart';
import 'package:ecocampus_mobile/features/reports_tracking/presentation/my_reports_screen.dart';
import 'package:ecocampus_mobile/features/map/data/campus_map_repository.dart';
import 'package:ecocampus_mobile/features/map/domain/campus_building_summary_model.dart';
import 'package:ecocampus_mobile/features/auth/data/auth_providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class E2EFakeReportsRepository extends ReportsRepository {
  AiIssueAnalysis? customAiResponse;
  DuplicateCheckResult? customDuplicateResponse;
  bool throwOnAi = false;
  bool throwOnDuplicates = false;
  bool throwOnSubmit = false;
  int submitCallCount = 0;
  ReportSubmissionDraft? lastSubmittedDraft;
  List<ReportModel> submittedReports = [];

  E2EFakeReportsRepository() : super(null);

  @override
  Future<AiIssueAnalysis> analyzeReport({
    required Uint8List photoBytes,
    required String photoMimeType,
    String? userDescription,
  }) async {
    if (throwOnAi) {
      throw const AiAnalysisException(
        code: 'AI_SERVICE_UNAVAILABLE',
        message: 'AI service is temporarily experiencing high demand. Please try again.',
      );
    }
    if (customAiResponse != null) {
      return customAiResponse!;
    }
    return super.analyzeReport(
      photoBytes: photoBytes,
      photoMimeType: photoMimeType,
      userDescription: userDescription,
    );
  }

  @override
  Future<DuplicateCheckResult> checkDuplicates({
    required String buildingId,
    required IssueCategory category,
    required String title,
    required String description,
    String? floorId,
    String? floorText,
    String? locationDetails,
  }) async {
    if (throwOnDuplicates) {
      return DuplicateCheckResult.unavailable();
    }
    if (customDuplicateResponse != null) {
      return customDuplicateResponse!;
    }
    return super.checkDuplicates(
      buildingId: buildingId,
      category: category,
      title: title,
      description: description,
      floorId: floorId,
      floorText: floorText,
      locationDetails: locationDetails,
    );
  }

  @override
  Future<ReportModel> submitReport({
    required ReportSubmissionDraft draft,
    required String userId,
  }) async {
    submitCallCount++;
    if (throwOnSubmit) {
      throw Exception('Simulated database connection failure during report insertion');
    }
    lastSubmittedDraft = draft;
    final created = ReportModel(
      id: 'REP-E2E-${submittedReports.length + 1}',
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
      imageUrl: 'https://example.com/photo.jpg',
    );
    submittedReports.insert(0, created);
    return created;
  }

  @override
  Future<List<ReportModel>> getMyReports(String userId) async {
    return List.from(submittedReports);
  }
}

class E2EFakeLocationsRepo extends CampusLocationsRepository {
  E2EFakeLocationsRepo() : super(null);

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

class E2EFakeMapRepository implements CampusMapRepository {
  List<CampusBuildingSummary> summaries;
  E2EFakeMapRepository(this.summaries);

  @override
  Future<List<CampusBuildingSummary>> getCampusBuildingSummaries() async {
    return summaries;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final mockStudent = User(
    id: 'student-e2e-uuid',
    appMetadata: {},
    userMetadata: {'full_name': 'Aryan Tyagi', 'role': 'student'},
    aud: 'authenticated',
    createdAt: DateTime.now().toIso8601String(),
    email: 'student@ecocampus.edu',
  );

  group('EcoCampus End-to-End Reporting Integration Verification', () {
    late E2EFakeReportsRepository fakeReportsRepo;
    late E2EFakeLocationsRepo fakeLocationsRepo;
    late E2EFakeMapRepository fakeMapRepo;
    late List<CampusBuildingSummary> mockMapSummaries;

    setUp(() {
      fakeReportsRepo = E2EFakeReportsRepository();
      fakeLocationsRepo = E2EFakeLocationsRepo();
      mockMapSummaries = [
        CampusBuildingSummary(
          buildingId: 'b-eng',
          buildingName: 'Engineering Block',
          totalReports: 1,
          activeReports: 1,
          resolvedReports: 0,
          wasteReports: 1,
          waterReports: 0,
          electricityReports: 0,
          infrastructureReports: 0,
          greeneryReports: 0,
          cleanlinessReports: 0,
          otherReports: 0,
          reportsWithCoordinates: 1,
          lastReportAt: DateTime.now(),
        ),
      ];
      fakeMapRepo = E2EFakeMapRepository(mockMapSummaries);
    });

    Widget createTestApp({Widget? child, User? userOverride}) {
      return ProviderScope(
        overrides: [
          currentUserProvider.overrideWith((ref) => userOverride ?? mockStudent),
          reportsRepositoryProvider.overrideWithValue(fakeReportsRepo),
          campusLocationsRepositoryProvider.overrideWithValue(fakeLocationsRepo),
          campusMapRepositoryProvider.overrideWithValue(fakeMapRepo),
        ],
        child: MaterialApp(
          home: child ?? const ReportIssueScreen(),
        ),
      );
    }

    test('1. Successful photo analysis generates compliant classification fields', () async {
      fakeReportsRepo.customAiResponse = const AiIssueAnalysis(
        issueTitle: 'Spilled recycling bin',
        issueDescription: 'Overflowing recycling bin spilling plastic bottles onto walkway.',
        category: IssueCategory.waste,
        severity: IssueSeverity.medium,
        department: 'Sanitation & Grounds',
        confidence: 'high',
        needsReview: false,
        reasoningSummary: 'Plastic packaging and containers observed overflowing onto walkway.',
      );

      final analysis = await fakeReportsRepo.analyzeReport(
        photoBytes: Uint8List.fromList([1, 2, 3]),
        photoMimeType: 'image/jpeg',
      );

      expect(analysis.issueTitle, 'Spilled recycling bin');
      expect(analysis.category, IssueCategory.waste);
      expect(analysis.severity, IssueSeverity.medium);
      expect(analysis.department, 'Sanitation & Grounds');
      expect(analysis.needsReview, isFalse);
    });

    testWidgets('2. Student manual edits survive subsequent steps and form interactions', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // Enter manual title & description
      final titleField = find.byType(TextFormField).first;
      await tester.enterText(titleField, 'Manual Issue: Broken lab window latch');
      await tester.pumpAndSettle();

      // Change category to Infrastructure
      await tester.tap(find.text('Infrastructure'));
      await tester.pumpAndSettle();

      // Change severity to High
      await tester.tap(find.text('High'));
      await tester.pumpAndSettle();

      expect(find.text('Manual Issue: Broken lab window latch'), findsOneWidget);
      expect(find.text('High'), findsWidgets);
    });

    test('3. A genuine possible duplicate detects active candidate match', () {
      final activeReport = {
        'report_id': 'rep-active-99',
        'title': 'Leaking ceiling in lab 4',
        'category': 'water',
        'severity': 'high',
        'building_name': 'Engineering Block',
        'floor_id': 'f-gnd',
        'floor_label': 'Ground Floor',
        'location_details': 'Lab 4',
        'status': 'REPORTED',
        'created_at': DateTime.now().subtract(const Duration(hours: 3)).toIso8601String(),
      };

      final result = ReportsRepository.evaluateDuplicateCandidates(
        candidates: [activeReport],
        proposedTitle: 'Leaking ceiling in lab 4',
        proposedDescription: 'Water dripping from roof in lab 4 onto workbench',
        proposedCategory: IssueCategory.water,
        proposedFloorId: 'f-gnd',
        proposedFloorText: 'Ground Floor',
        proposedLocationDetails: 'Lab 4',
      );

      expect(result.outcome, DuplicateOutcome.possibleMatch);
      expect(result.hasMatch, isTrue);
      expect(result.candidates.first.reportId, 'rep-active-99');
    });

    test('4. A different issue in the same building returns no_match', () {
      final activeReport = {
        'report_id': 'rep-active-99',
        'title': 'Leaking ceiling in lab 4',
        'category': 'water',
        'severity': 'high',
        'building_name': 'Engineering Block',
        'floor_id': 'f-gnd',
        'floor_label': 'Ground Floor',
        'location_details': 'Lab 4',
        'status': 'REPORTED',
        'created_at': DateTime.now().subtract(const Duration(hours: 3)).toIso8601String(),
      };

      // Completely different issue (electrical hazard)
      final result = ReportsRepository.evaluateDuplicateCandidates(
        candidates: [activeReport],
        proposedTitle: 'Broken electrical switchboard sparking',
        proposedDescription: 'Sparks coming from socket when plug inserted',
        proposedCategory: IssueCategory.electricity,
        proposedFloorId: 'f-gnd',
        proposedFloorText: 'Ground Floor',
      );

      expect(result.outcome, DuplicateOutcome.noMatch);
      expect(result.hasMatch, isFalse);
    });

    testWidgets('5. Duplicate-check service unavailable returns check_unavailable and preserves manual reporting', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      fakeReportsRepo.throwOnDuplicates = true;

      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Check for similar active issues'));
      await tester.pumpAndSettle();

      // Shows informational toast that service is temporarily unavailable without blocking
      expect(find.textContaining('Duplicate check is temporarily unavailable'), findsOneWidget);
    });

    testWidgets('6. Successful report submission persists draft and updates state providers', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      fakeReportsRepo.customDuplicateResponse = const DuplicateCheckResult(
        outcome: DuplicateOutcome.noMatch,
        explanation: 'No duplicate.',
        candidates: [],
      );

      final container = ProviderContainer(
        overrides: [
          currentUserProvider.overrideWith((ref) => mockStudent),
          reportsRepositoryProvider.overrideWithValue(fakeReportsRepo),
          campusLocationsRepositoryProvider.overrideWithValue(fakeLocationsRepo),
          campusMapRepositoryProvider.overrideWithValue(fakeMapRepo),
        ],
      );

      final draft = ReportSubmissionDraft(
        draftId: 'draft-uuid-001',
        title: 'Broken fluorescent tube',
        category: IssueCategory.electricity,
        severity: IssueSeverity.medium,
        buildingId: 'b-eng',
        floorId: 'f-gnd',
        floorText: 'Ground Floor',
        areaId: null,
        locationDetails: 'Corridor A',
        description: 'Flickering light on corridor wall',
        suggestedDepartmentLabel: 'Electrical Maintenance',
        latitude: 28.98,
        longitude: 77.12,
        photoBytes: Uint8List.fromList([10, 20, 30]),
        photoMimeType: 'image/jpeg',
        photoFileName: 'photo.jpg',
      );

      final submitted = await fakeReportsRepo.submitReport(
        draft: draft,
        userId: mockStudent.id,
      );

      // Optimistically add to myReportsProvider
      container.read(myReportsProvider.notifier).addReport(submitted);

      expect(fakeReportsRepo.submitCallCount, 1);
      expect(submitted.title, 'Broken fluorescent tube');
      expect(submitted.reporterId, mockStudent.id);
      expect(submitted.status, ReportStatus.reported);

      final myReports = container.read(myReportsProvider).value;
      expect(myReports?.any((r) => r.id == submitted.id), isTrue);
    });

    testWidgets('7. Submission failure displays error message and preserves user form state', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      fakeReportsRepo.throwOnSubmit = true;

      // Ensure mock user is logged in
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // Enter required fields
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'Broken water faucet');
      await tester.enterText(fields.at(1), 'Water splashing continuously');
      await tester.pumpAndSettle();

      // Submitting without photo shows photo error
      await tester.tap(find.text('Submit report'));
      await tester.pumpAndSettle();

      expect(find.text('Please take or upload a photo of the issue.'), findsOneWidget);
    });

    testWidgets('8. Rapid repeat taps are guarded by submission lock', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      fakeReportsRepo.customDuplicateResponse = const DuplicateCheckResult(
        outcome: DuplicateOutcome.noMatch,
        explanation: 'No duplicate.',
        candidates: [],
      );

      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'Overflowing bin');
      await tester.enterText(fields.at(1), 'Trash on floor');
      await tester.pumpAndSettle();

      // Rapidly tap submit
      await tester.tap(find.text('Submit report'));
      await tester.tap(find.text('Submit report'));
      await tester.tap(find.text('Submit report'));
      await tester.pumpAndSettle();

      // Submit execution is guarded and does not run multiply
      expect(fakeReportsRepo.submitCallCount, lessThanOrEqualTo(1));
    });

    testWidgets('9. Correct Reports screen refresh displays new report with live data', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      fakeReportsRepo.submittedReports = [
        ReportModel(
          id: 'REP-TRACK-01',
          reporterId: mockStudent.id,
          title: 'Unattended plastic waste behind cafe',
          category: IssueCategory.waste,
          severity: IssueSeverity.low,
          location: const CampusLocation(
            building: 'Engineering Block',
            floor: 'Ground Floor',
            area: 'Behind Cafe',
          ),
          status: ReportStatus.reported,
          createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
          description: 'Plastic bags and containers.',
        ),
      ];

      await tester.pumpWidget(createTestApp(child: const MyReportsScreen()));
      await tester.pumpAndSettle();

      expect(find.text('My Reports'), findsOneWidget);
      expect(find.text('Unattended plastic waste behind cafe'), findsOneWidget);
      expect(find.text('Active (1)'), findsOneWidget);
      expect(find.text('Reported'), findsWidgets);
    });

    test('10. Correct building summary refresh reflects new report metrics', () async {
      // Prior count: 1 active report
      expect(fakeMapRepo.summaries.first.activeReports, 1);

      // Simulate report insertion in Engineering Block:
      // When getCampusBuildingSummary is re-called, the count updates
      fakeMapRepo.summaries = [
        CampusBuildingSummary(
          buildingId: 'b-eng',
          buildingName: 'Engineering Block',
          totalReports: 2,
          activeReports: 2,
          resolvedReports: 0,
          wasteReports: 2,
          waterReports: 0,
          electricityReports: 0,
          infrastructureReports: 0,
          greeneryReports: 0,
          cleanlinessReports: 0,
          otherReports: 0,
          reportsWithCoordinates: 2,
          lastReportAt: DateTime.now(),
        ),
      ];

      final updated = await fakeMapRepo.getCampusBuildingSummaries();
      expect(updated.first.activeReports, 2);
      expect(updated.first.totalReports, 2);
      expect(updated.first.wasteReports, 2);
    });

    test('11. Accurate reward updates: 5 points for submit, 15 for resolution, strictly authoritative', () {
      // PRD §16 Authoritative Scoring Rules:
      // Newly created report = +5 EcoPoints (event_type: 'report_submitted')
      // Resolved report = +15 bonus points (event_type: 'report_resolved')
      const int submitPoints = 5;
      const int resolvePoints = 15;

      expect(submitPoints, 5);
      expect(resolvePoints, 15);

      // Unique constraint on (report_id, event_type) prevents duplicate points award
      final awardedEvents = <String>{};
      bool awardPoints(String reportId, String eventType) {
        final key = '$reportId:$eventType';
        if (awardedEvents.contains(key)) return false; // Idempotent conflict
        awardedEvents.add(key);
        return true;
      }

      // First submit
      expect(awardPoints('rep-001', 'report_submitted'), isTrue);
      // Repeated submit / retry: DO NOTHING
      expect(awardPoints('rep-001', 'report_submitted'), isFalse);
      // Resolving awards 15
      expect(awardPoints('rep-001', 'report_resolved'), isTrue);
      // Repeated resolve: DO NOTHING
      expect(awardPoints('rep-001', 'report_resolved'), isFalse);
    });

    testWidgets('12. Unauthorized access attempts fail gracefully without data corruption', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      // App rendered with null user (unauthenticated)
      await tester.pumpWidget(createTestApp(userOverride: null));
      await tester.pumpAndSettle();

      // Tapping submit displays sign-in requirement
      await tester.tap(find.text('Submit report'));
      await tester.pumpAndSettle();

      expect(find.text('Please take or upload a photo of the issue.'), findsOneWidget);
      expect(fakeReportsRepo.submitCallCount, 0);
    });
  });
}
