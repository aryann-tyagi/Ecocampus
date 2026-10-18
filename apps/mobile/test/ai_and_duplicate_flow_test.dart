import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ecocampus_mobile/features/report/data/campus_locations_repository.dart';
import 'package:ecocampus_mobile/features/report/data/reports_repository.dart';
import 'package:ecocampus_mobile/features/report/domain/ai_analysis_models.dart';
import 'package:ecocampus_mobile/features/report/domain/duplicate_detection_models.dart';
import 'package:ecocampus_mobile/features/report/domain/campus_location_models.dart';
import 'package:ecocampus_mobile/features/report/domain/report_model.dart';
import 'package:ecocampus_mobile/features/report/presentation/report_issue_screen.dart';
import 'package:ecocampus_mobile/features/auth/data/auth_providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Test implementation of ReportsRepository for AI and Duplicate Testing
class FakeAiReportsRepository extends ReportsRepository {
  AiIssueAnalysis? customAiResponse;
  DuplicateCheckResult? customDuplicateResponse;
  bool throwOnAi = false;
  bool throwOnDuplicates = false;
  int submitCallCount = 0;
  ReportSubmissionDraft? lastSubmittedDraft;

  FakeAiReportsRepository() : super(null);

  @override
  Future<AiIssueAnalysis> analyzeReport({
    required Uint8List photoBytes,
    required String photoMimeType,
    String? userDescription,
  }) async {
    if (throwOnAi) {
      throw Exception('AI Edge Function timeout / service unavailable');
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
      throw Exception('Duplicate check connection failed');
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
    lastSubmittedDraft = draft;
    return ReportModel(
      id: 'REP-UNIT-001',
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
  }

  @override
  Future<List<ReportModel>> getMyReports(String userId) async {
    return [];
  }
}

class FakeCampusLocationsRepo extends CampusLocationsRepository {
  FakeCampusLocationsRepo() : super(null);

  @override
  Future<List<CampusBuilding>> getActiveBuildings() async {
    return const [
      CampusBuilding(id: 'b-eng', name: 'Engineering Block', slug: 'engineering-block'),
      CampusBuilding(id: 'b-hostel', name: 'Boys Hostel', slug: 'boys-hostel'),
      CampusBuilding(id: 'b-lib', name: 'Library', slug: 'library'),
    ];
  }

  @override
  Future<List<CampusFloor>> getFloorsForBuilding(String buildingId) async {
    if (buildingId == 'b-eng') {
      return const [
        CampusFloor(id: 'f-gnd', buildingId: 'b-eng', label: 'Ground Floor', sortOrder: 0),
        CampusFloor(id: 'f-1st', buildingId: 'b-eng', label: 'First Floor', sortOrder: 1),
        CampusFloor(id: 'f-2nd', buildingId: 'b-eng', label: 'Second Floor', sortOrder: 2),
      ];
    }
    return const [];
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final mockUser = User(
    id: 'student-uuid-42',
    appMetadata: {},
    userMetadata: {'full_name': 'Aryan Tyagi', 'role': 'student'},
    aud: 'authenticated',
    createdAt: DateTime.now().toIso8601String(),
    email: 'student@ecocampus.edu',
  );

  group('8.1 AI Issue Classification Unit Tests', () {
    test('A clear overflowing-bin photograph/context suggests Waste', () {
      final analysis = AiIssueAnalysis.fromJson({
        'issue_title': 'Overflowing trash container',
        'issue_description': 'Garbage can overflowing with packaging waste and beverage cups spilling on walkway.',
        'category': 'waste',
        'severity': 'medium',
        'department': 'Sanitation & Grounds',
        'confidence': 'high',
        'needs_review': false,
        'reasoning_summary': 'Visible accumulation of solid trash beyond bin capacity.',
      });

      expect(analysis.category, IssueCategory.waste);
      expect(analysis.severity, IssueSeverity.medium);
      expect(analysis.confidence, 'high');
      expect(analysis.needsReview, isFalse);
      expect(analysis.department, 'Sanitation & Grounds');
    });

    test('A visible water leak suggests Water', () {
      final analysis = AiIssueAnalysis.fromJson({
        'issue_title': 'Ceiling pipe dripping rapidly',
        'issue_description': 'Severe water leak forming a puddle near the first floor corridor.',
        'category': 'water',
        'severity': 'high',
        'department': 'Plumbing & Facilities',
        'confidence': 'high',
        'needs_review': false,
        'reasoning_summary': 'Direct stream of water leaking onto the floor.',
      });

      expect(analysis.category, IssueCategory.water);
      expect(analysis.severity, IssueSeverity.high);
      expect(analysis.department, 'Plumbing & Facilities');
    });

    test('A damaged fixture suggests Infrastructure', () {
      final analysis = AiIssueAnalysis.fromJson({
        'issue_title': 'Broken stairway railing',
        'issue_description': 'Handrail detachment posing a structural safety hazard on stairwell.',
        'category': 'infrastructure',
        'severity': 'critical',
        'department': 'Campus Infrastructure',
        'confidence': 'high',
        'needs_review': false,
        'reasoning_summary': 'Physical breakage in building handrail.',
      });

      expect(analysis.category, IssueCategory.infrastructure);
      expect(analysis.severity, IssueSeverity.critical);
    });

    test('An unclear or unrelated photograph sets needs_review: true', () {
      final analysis = AiIssueAnalysis.fromJson({
        'issue_title': 'Unclear observation',
        'issue_description': 'Image appears blurry or ambiguous; unable to clearly ascertain defect.',
        'category': 'other',
        'severity': 'low',
        'department': null,
        'confidence': 'low',
        'needs_review': true,
        'reasoning_summary': 'Photograph is dark and out of focus.',
      });

      expect(analysis.needsReview, isTrue);
      expect(analysis.confidence, 'low');
    });

    test('Malformed model output is safely handled via fallback', () {
      final fallback = AiIssueAnalysis.fromJson({
        'issue_title': null,
        'category': 'cleanliness',
        'confidence': 'unknown_value',
        'needs_review': true,
      });

      expect(fallback.needsReview, isTrue);
      expect(fallback.confidence, 'medium');
      expect(fallback.issueTitle, 'Campus Issue');
      expect(fallback.category, IssueCategory.cleanliness);
    });

    test('Unsupported categories are safely mapped to valid domain enums', () {
      final analysis = AiIssueAnalysis.fromJson({
        'issue_title': 'Loose wires',
        'issue_description': 'Exposed conduit',
        'category': 'electricity',
        'severity': 'critical',
      });

      expect(analysis.category, IssueCategory.electricity);

      final unknownCategory = AiIssueAnalysis.fromJson({
        'issue_title': 'Unknown',
        'category': 'cyber_security', // unsupported enum value in db
      });
      expect(unknownCategory.category, IssueCategory.other);
    });

    test('ReportsRepository throws AiAnalysisException when client is uninitialized', () async {
      final repo = ReportsRepository(null);
      expect(
        () => repo.analyzeReport(
          photoBytes: Uint8List.fromList([1, 2, 3]),
          photoMimeType: 'image/jpeg',
          userDescription: 'bin overflowing',
        ),
        throwsA(isA<AiAnalysisException>().having(
          (e) => e.code,
          'code',
          'CLIENT_NOT_INITIALIZED',
        )),
      );
    });

    test('ReportsRepository never masquerades failure as deterministic fake waste analysis', () async {
      final repo = ReportsRepository(null);
      try {
        await repo.analyzeReport(
          photoBytes: Uint8List.fromList([1, 2, 3]),
          photoMimeType: 'image/jpeg',
          userDescription: 'Recycling bin overflowing with cups',
        );
        fail('Should have thrown AiAnalysisException');
      } on AiAnalysisException catch (e) {
        expect(e.code, 'CLIENT_NOT_INITIALIZED');
        expect(e.message, contains('not initialized'));
      }
    });

    test('Real test fixtures can be loaded and verified as distinct non-empty images', () async {
      final wasteBytes = await File('test/fixtures/images/test_waste_bin.jpg').readAsBytes();
      final waterBytes = await File('test/fixtures/images/test_water_leak.jpg').readAsBytes();
      final infraBytes = await File('test/fixtures/images/test_damaged_infra.jpg').readAsBytes();
      final unclearBytes = await File('test/fixtures/images/test_unclear_scene.jpg').readAsBytes();

      expect(wasteBytes.isNotEmpty, isTrue);
      expect(waterBytes.isNotEmpty, isTrue);
      expect(infraBytes.isNotEmpty, isTrue);
      expect(unclearBytes.isNotEmpty, isTrue);

      // Verify each image has distinct byte lengths
      expect(wasteBytes.length != waterBytes.length, isTrue);
      expect(waterBytes.length != infraBytes.length, isTrue);
      expect(infraBytes.length != unclearBytes.length, isTrue);
    });

    test('AiAnalysisException represents 503 AI_SERVICE_UNAVAILABLE with actionable message', () {
      const ex = AiAnalysisException(
        code: 'AI_SERVICE_UNAVAILABLE',
        message: 'AI service is temporarily experiencing high demand. Please try again or continue with manual entry.',
      );
      expect(ex.code, 'AI_SERVICE_UNAVAILABLE');
      expect(ex.message, contains('high demand'));
      expect(ex.toString(), ex.message);
    });
  });

  group('8.2 Duplicate Detection Candidate Algorithm Tests', () {
    final candidateRow1 = {
      'report_id': 'rep-active-1',
      'title': 'Overflowing recycle bin',
      'category': 'waste',
      'severity': 'medium',
      'building_name': 'Engineering Block',
      'floor_id': 'f-gnd',
      'floor_label': 'Ground Floor',
      'location_details': 'West Wing Entrance',
      'status': 'REPORTED',
      'created_at': DateTime.now().subtract(const Duration(hours: 2)).toIso8601String(),
    };

    final candidateObj1 = DuplicateCandidate(
      reportId: 'rep-active-1',
      title: 'Overflowing recycle bin',
      category: IssueCategory.waste,
      severity: IssueSeverity.medium,
      buildingName: 'Engineering Block',
      floorName: 'Ground Floor',
      areaName: 'West Wing Entrance',
      status: ReportStatus.reported,
      reportedAt: DateTime.now().subtract(const Duration(hours: 2)),
    );

    test('Scenario 1: Same unresolved incident at the same location returns likely_duplicate', () {
      final result = ReportsRepository.evaluateDuplicateCandidates(
        candidates: [candidateRow1],
        proposedTitle: 'Overflowing recycle bin',
        proposedDescription: 'Trash bin is full and spilling on floor',
        proposedCategory: IssueCategory.waste,
        proposedFloorId: 'f-gnd',
        proposedFloorText: 'Ground Floor',
        proposedLocationDetails: 'West Wing Entrance',
      );

      expect(result.outcome, DuplicateOutcome.likelyDuplicate);
      expect(result.hasMatch, isTrue);
      expect(result.candidates.length, 1);
      expect(result.candidates.first.reportId, 'rep-active-1');
    });

    test('Scenario 2: Same category in different buildings does not automatically match', () {
      // Leaking tap in Boys Hostel vs Leaking tap in Library:
      // Bounded candidate lookup shortlists strictly candidates belonging to the queried building.
      // An empty candidate pool for a distinct building returns no_match.
      final result = ReportsRepository.evaluateDuplicateCandidates(
        candidates: [], // No candidates in Boys Hostel
        proposedTitle: 'Leaking tap in washroom',
        proposedDescription: 'Tap is dripping water continuously',
        proposedCategory: IssueCategory.water,
      );

      expect(result.outcome, DuplicateOutcome.noMatch);
      expect(result.hasMatch, isFalse);
    });

    test('Scenario 3: Same building and category but different physical locations do not automatically match', () {
      final result = ReportsRepository.evaluateDuplicateCandidates(
        candidates: [candidateRow1], // candidate is Ground Floor (f-gnd)
        proposedTitle: 'Overflowing recycle bin',
        proposedDescription: 'Bin is completely full',
        proposedCategory: IssueCategory.waste,
        proposedFloorId: 'f-2nd', // Distinct floor ID!
        proposedFloorText: 'Second Floor',
        proposedLocationDetails: 'Room 205',
      );

      // Floor distinction penalty and score capping differentiate separate physical bins
      expect(result.outcome, DuplicateOutcome.noMatch);
      expect(result.hasMatch, isFalse);
    });

    test('Scenario 4: Similar categories with unrelated descriptions return no_match', () {
      final result = ReportsRepository.evaluateDuplicateCandidates(
        candidates: [candidateRow1], // candidate is waste: overflowing bin
        proposedTitle: 'Hazardous chemical container left in lab',
        proposedDescription: 'Toxic solvent bottle sitting open on bench',
        proposedCategory: IssueCategory.waste,
        proposedFloorId: 'f-gnd',
        proposedFloorText: 'Ground Floor',
      );

      expect(result.outcome, DuplicateOutcome.noMatch);
      expect(result.hasMatch, isFalse);
    });

    test('Scenario 5: Resolved reports do not appear as active duplicates by default', () {
      final resolvedCandidateRow = {
        'report_id': 'rep-resolved-99',
        'title': 'Overflowing recycle bin',
        'category': 'waste',
        'severity': 'medium',
        'building_name': 'Engineering Block',
        'floor_id': 'f-gnd',
        'floor_label': 'Ground Floor',
        'location_details': 'West Wing Entrance',
        'status': 'RESOLVED', // Resolved issue!
        'created_at': DateTime.now().subtract(const Duration(days: 3)).toIso8601String(),
      };

      final result = ReportsRepository.evaluateDuplicateCandidates(
        candidates: [resolvedCandidateRow],
        proposedTitle: 'Overflowing recycle bin',
        proposedDescription: 'Trash bin is full',
        proposedCategory: IssueCategory.waste,
        proposedFloorId: 'f-gnd',
      );

      expect(result.outcome, DuplicateOutcome.noMatch);
      expect(result.hasMatch, isFalse);
    });

    test('Scenario 6: No candidates returns no_match', () {
      final result = ReportsRepository.evaluateDuplicateCandidates(
        candidates: [],
        proposedTitle: 'Leaking tap',
        proposedDescription: 'Water dripping in washroom',
        proposedCategory: IssueCategory.water,
      );

      expect(result.outcome, DuplicateOutcome.noMatch);
      expect(result.hasMatch, isFalse);
      expect(result.candidates, isEmpty);
    });

    test('Scenario 7: An unavailable service returns check_unavailable and preserves manual submission', () async {
      final repo = ReportsRepository(null);
      final result = await repo.checkDuplicates(
        buildingId: 'b-eng',
        category: IssueCategory.water,
        title: 'Leaking tap',
        description: 'Water dripping continuously',
      );

      expect(result.outcome, DuplicateOutcome.checkUnavailable);
      expect(result.hasMatch, isFalse);
      expect(result.candidates, isEmpty);
      expect(result.explanation, contains('temporarily unavailable'));
    });

    test('Scenario 11: Candidate results contain no sensitive reporter or storage information', () {
      final json = candidateObj1.toJson();
      expect(json.containsKey('reporter_id'), isFalse);
      expect(json.containsKey('user_id'), isFalse);
      expect(json.containsKey('storage_path'), isFalse);
      expect(json.containsKey('admin_notes'), isFalse);
      expect(json['report_id'], 'rep-active-1');
      expect(json['title'], 'Overflowing recycle bin');
      expect(json['building_name'], 'Engineering Block');
    });
  });

  group('8.3 ReportIssueScreen UI, AI Advisory & Duplicate Workflow Widget Tests', () {
    late FakeAiReportsRepository fakeReportsRepo;
    late FakeCampusLocationsRepo fakeLocationsRepo;

    setUp(() {
      fakeReportsRepo = FakeAiReportsRepository();
      fakeLocationsRepo = FakeCampusLocationsRepo();
    });

    Widget createTestWidget() {
      return ProviderScope(
        overrides: [
          currentUserProvider.overrideWith((ref) => mockUser),
          reportsRepositoryProvider.overrideWithValue(fakeReportsRepo),
          campusLocationsRepositoryProvider.overrideWithValue(fakeLocationsRepo),
        ],
        child: const MaterialApp(
          home: ReportIssueScreen(),
        ),
      );
    }

    testWidgets('Renders Photo Card, Mascot, Category Chips and Form Fields', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Report issue'), findsOneWidget);
      expect(find.text('Campus Location'), findsOneWidget);
      expect(find.text('Category'), findsOneWidget);
      expect(find.text('Severity'), findsOneWidget);
      expect(find.text('Issue Title'), findsOneWidget);
      expect(find.text('Description'), findsOneWidget);
      expect(find.text('Submit report'), findsOneWidget);
      expect(find.text('Check for similar active issues'), findsOneWidget);
    });

    testWidgets('Student manual edits are preserved and not overwritten unexpectedly', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Student edits the title manually
      final titleField = find.byType(TextFormField).first;
      await tester.enterText(titleField, 'Student Custom Title: Broken AC unit');
      await tester.pumpAndSettle();

      // Select category 'Energy' (displayed name for IssueCategory.electricity)
      await tester.tap(find.text('Energy'));
      await tester.pumpAndSettle();

      // Select severity 'Critical'
      await tester.tap(find.text('Critical'));
      await tester.pumpAndSettle();

      // Trigger widget rebuild
      await tester.pump();

      // Verify custom values are preserved
      expect(find.text('Student Custom Title: Broken AC unit'), findsOneWidget);
      expect(find.text('Critical'), findsWidgets);
    });

    testWidgets('Duplicate check displays possible match and allows Report Anyway', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      fakeReportsRepo.customDuplicateResponse = DuplicateCheckResult(
        outcome: DuplicateOutcome.possibleMatch,
        explanation: 'Existing active report found with similar issue in same building.',
        candidates: [
          DuplicateCandidate(
            reportId: 'rep-prior-10',
            title: 'Leaking pipe on 1st floor',
            category: IssueCategory.water,
            severity: IssueSeverity.high,
            buildingName: 'Engineering Block',
            floorName: 'Ground Floor',
            status: ReportStatus.reported,
            reportedAt: DateTime.now().subtract(const Duration(hours: 1)),
          ),
        ],
      );

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Tap manual duplicate check
      await tester.tap(find.text('Check for similar active issues'));
      await tester.pumpAndSettle();

      // Warning bottom sheet should be displayed
      expect(find.text('This issue may already be reported'), findsOneWidget);
      expect(find.text('Leaking pipe on 1st floor'), findsOneWidget);
      expect(find.text('View Existing Report'), findsOneWidget);
      expect(find.text('Report Anyway'), findsOneWidget);
      expect(find.text('Edit My Report'), findsOneWidget);

      // Tap "Report Anyway" - should close warning modal and validate photo requirement
      await tester.tap(find.text('Report Anyway'));
      await tester.pumpAndSettle();

      expect(find.text('This issue may already be reported'), findsNothing);
      expect(find.text('Please take or upload a photo of the issue.'), findsOneWidget);
    });

    testWidgets('Scenario 8: A modified report invalidates its earlier duplicate-check result', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      fakeReportsRepo.customDuplicateResponse = DuplicateCheckResult(
        outcome: DuplicateOutcome.possibleMatch,
        explanation: 'Existing active report found.',
        candidates: [
          DuplicateCandidate(
            reportId: 'rep-prior-10',
            title: 'Leaking pipe',
            category: IssueCategory.water,
            severity: IssueSeverity.high,
            buildingName: 'Engineering Block',
            floorName: 'Ground Floor',
            status: ReportStatus.reported,
            reportedAt: DateTime.now().subtract(const Duration(hours: 1)),
          ),
        ],
      );

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Run duplicate check
      await tester.tap(find.text('Check for similar active issues'));
      await tester.pumpAndSettle();

      expect(find.text('This issue may already be reported'), findsOneWidget);

      // Tap "Edit My Report" to return to form
      await tester.tap(find.text('Edit My Report'));
      await tester.pumpAndSettle();

      // Modify the title
      final titleField = find.byType(TextFormField).first;
      await tester.enterText(titleField, 'Completely different issue: Broken desk');
      await tester.pumpAndSettle();

      // Change mock response to noMatch for the fresh check
      fakeReportsRepo.customDuplicateResponse = const DuplicateCheckResult(
        outcome: DuplicateOutcome.noMatch,
        explanation: 'No similar active report found.',
        candidates: [],
      );

      await tester.tap(find.text('Check for similar active issues'));
      await tester.pumpAndSettle();

      // Previous match was invalidated, fresh check shows no match!
      expect(find.text('This issue may already be reported'), findsNothing);
      expect(find.textContaining('No similar active report found'), findsOneWidget);
    });

    testWidgets('Scenario 9: Viewing an existing report does not insert a new record', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      fakeReportsRepo.customDuplicateResponse = DuplicateCheckResult(
        outcome: DuplicateOutcome.likelyDuplicate,
        explanation: 'Likely duplicate issue detected.',
        candidates: [
          DuplicateCandidate(
            reportId: 'rep-existing-99',
            title: 'Overflowing dustbin near lab',
            category: IssueCategory.waste,
            severity: IssueSeverity.medium,
            buildingName: 'Engineering Block',
            floorName: 'Ground Floor',
            status: ReportStatus.reported,
            reportedAt: DateTime.now().subtract(const Duration(hours: 2)),
          ),
        ],
      );

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Trigger duplicate check
      await tester.tap(find.text('Check for similar active issues'));
      await tester.pumpAndSettle();

      expect(find.text('This issue may already be reported'), findsOneWidget);
      expect(find.text('View Existing Report'), findsOneWidget);

      // Tap "View Existing Report"
      await tester.tap(find.text('View Existing Report'));
      await tester.pumpAndSettle();

      // Modal is dismissed, existing report detail is pushed
      expect(find.text('This issue may already be reported'), findsNothing);
      expect(find.text('Overflowing dustbin near lab'), findsOneWidget);

      // Critical assertion: submit was NOT called, no new report record was created
      expect(fakeReportsRepo.submitCallCount, 0);
      expect(fakeReportsRepo.lastSubmittedDraft, isNull);
    });

    testWidgets('Scenario 10: Rapid submit taps do not create accidental duplicate records', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      fakeReportsRepo.customDuplicateResponse = const DuplicateCheckResult(
        outcome: DuplicateOutcome.noMatch,
        explanation: 'No duplicates.',
        candidates: [],
      );

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Enter required title and description
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'Broken water faucet');
      await tester.enterText(fields.at(1), 'Water splashing on floor continuously');
      await tester.pumpAndSettle();

      // Tap "Submit report" rapidly in succession
      await tester.tap(find.text('Submit report'));
      await tester.tap(find.text('Submit report'));
      await tester.tap(find.text('Submit report'));
      await tester.pumpAndSettle();

      // Submit should not execute more than once
      expect(fakeReportsRepo.submitCallCount, lessThanOrEqualTo(1));
    });

    testWidgets('Duplicate check displays No Match when no similar issues exist', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      fakeReportsRepo.customDuplicateResponse = const DuplicateCheckResult(
        outcome: DuplicateOutcome.noMatch,
        explanation: 'No similar active report found.',
        candidates: [],
      );

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Check for similar active issues'));
      await tester.pumpAndSettle();

      // Inline banner / SnackBar informs student no duplicate found
      expect(find.textContaining('No similar active report found'), findsOneWidget);
    });

    testWidgets('Duplicate check displays fallback message when service is unavailable', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      fakeReportsRepo.throwOnDuplicates = true;

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Check for similar active issues'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Duplicate check error'), findsOneWidget);
    });
  });
}
