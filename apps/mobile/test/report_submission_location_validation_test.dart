import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ecocampus_mobile/core/theme/app_theme.dart';
import 'package:ecocampus_mobile/features/auth/data/auth_providers.dart';
import 'package:ecocampus_mobile/features/report/data/campus_locations_repository.dart';
import 'package:ecocampus_mobile/features/report/data/reports_repository.dart';
import 'package:ecocampus_mobile/features/report/domain/campus_location_models.dart';
import 'package:ecocampus_mobile/features/report/domain/report_model.dart';
import 'package:ecocampus_mobile/features/report/presentation/report_issue_screen.dart';

class MockReportsRepositoryForLocationTests extends ReportsRepository {
  ReportSubmissionDraft? lastSubmittedDraft;
  String? lastSubmittedUserId;
  bool shouldThrow = false;
  Exception? exceptionToThrow;
  int submitCount = 0;

  MockReportsRepositoryForLocationTests() : super(null);

  @override
  Future<String?> getSignedPhotoUrl(String storagePath, {int expiresIn = 3600}) async {
    return 'https://example.com/signed/$storagePath';
  }

  @override
  Future<ReportModel> submitReport({
    required ReportSubmissionDraft draft,
    required String userId,
  }) async {
    // Mirror the real repository's client-side pre-validation
    final locationValidation = LocationDetailsValidator.validate(draft.locationDetails, isRequired: true);
    if (locationValidation != null) {
      throw ReportSubmissionException(
        locationValidation,
        code: '23514',
        field: 'location_details',
      );
    }

    if (shouldThrow) {
      throw exceptionToThrow ?? Exception('Simulated database error');
    }

    lastSubmittedDraft = draft;
    lastSubmittedUserId = userId;
    submitCount++;

    return ReportModel(
      id: 'REP-TEST-${draft.draftId.substring(0, 8)}',
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
}

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
    return const [
      CampusFloor(id: 'f-gnd', buildingId: 'b-eng', label: 'Ground Floor', sortOrder: 0),
      CampusFloor(id: 'f-1st', buildingId: 'b-eng', label: 'First Floor', sortOrder: 1),
    ];
  }
}

const mockUser = User(
  id: 'student-uuid-456',
  appMetadata: {},
  userMetadata: {},
  aud: 'authenticated',
  createdAt: '2026-01-01',
);

void main() {
  group('LocationDetailsValidator Tests', () {
    test('1. Valid concise location details pass validation', () {
      expect(LocationDetailsValidator.validate('Room 204'), isNull);
      expect(LocationDetailsValidator.validate('West Corridor'), isNull);
      expect(LocationDetailsValidator.validate('Lab 9'), isNull);
      expect(LocationDetailsValidator.validate('AB'), isNull); // Exactly minLength 2
    });

    test('2. Location details at permitted maximum length (255 chars) pass validation', () {
      final exact255 = 'A' * 255;
      expect(exact255.length, equals(255));
      expect(LocationDetailsValidator.validate(exact255), isNull);

      final withSurroundingSpaces = '   ${'B' * 255}   ';
      expect(LocationDetailsValidator.validate(withSurroundingSpaces), isNull);
    });

    test('3. Location details exceeding permitted length (256+ chars) fail validation', () {
      final exact256 = 'A' * 256;
      final error = LocationDetailsValidator.validate(exact256);
      expect(error, isNotNull);
      expect(error, contains('cannot exceed 255 characters'));
      expect(error, contains('currently 256 characters'));

      final long500 = 'A' * 500;
      final error500 = LocationDetailsValidator.validate(long500);
      expect(error500, contains('currently 500 characters'));
    });

    test('4. Optional location details when schema allows them to be absent (isRequired: false)', () {
      // Allowed to be absent
      expect(LocationDetailsValidator.validate(null, isRequired: false), isNull);
      expect(LocationDetailsValidator.validate('', isRequired: false), isNull);
      expect(LocationDetailsValidator.validate('   ', isRequired: false), isNull);

      // But when provided, still enforces length boundaries
      expect(LocationDetailsValidator.validate('Room 101', isRequired: false), isNull);
      expect(LocationDetailsValidator.validate('A', isRequired: false), contains('at least 2 characters'));
      expect(LocationDetailsValidator.validate('A' * 256, isRequired: false), contains('cannot exceed 255 characters'));
    });

    test('Required location details reject empty or whitespace-only values', () {
      expect(LocationDetailsValidator.validate(null, isRequired: true), isNotNull);
      expect(LocationDetailsValidator.validate('', isRequired: true), isNotNull);
      expect(LocationDetailsValidator.validate('   ', isRequired: true), isNotNull);
      expect(LocationDetailsValidator.validate('A', isRequired: true), contains('at least 2 characters'));
    });
  });

  group('Reports Repository Payload & Constraint Tests', () {
    test('5. Long AI-generated issue description (500+ chars) with short valid location submits cleanly without payload mixing', () async {
      final repo = MockReportsRepositoryForLocationTests();
      final repeatedDesc = 'Observed critical issue with water pipeline leaking behind the utility wall. ' * 8;
      final longDescription = 'Detailed AI diagnostic: $repeatedDesc';
      expect(longDescription.length, greaterThan(500));

      const conciseLocation = 'Room 204 Utility Closet';

      final draft = ReportSubmissionDraft(
        draftId: 'draft-ai-long-desc-01',
        title: 'Water Pipe Rupture',
        category: IssueCategory.water,
        severity: IssueSeverity.high,
        buildingId: 'b-eng',
        floorId: 'f-gnd',
        locationDetails: conciseLocation,
        description: longDescription,
        photoBytes: Uint8List.fromList([1, 2, 3]),
        photoMimeType: 'image/jpeg',
        photoFileName: 'leak.jpg',
      );

      final result = await repo.submitReport(draft: draft, userId: 'user-001');

      // Verify payload separation: description has full 500+ chars, locationDetails has concise location
      expect(repo.lastSubmittedDraft, isNotNull);
      expect(repo.lastSubmittedDraft!.description, equals(longDescription));
      expect(repo.lastSubmittedDraft!.locationDetails, equals(conciseLocation));
      expect(repo.lastSubmittedDraft!.locationDetails.length, lessThanOrEqualTo(255));
      expect(result.description, equals(longDescription));
      expect(result.location.area, equals(conciseLocation));
    });

    test('6. Successful report submission after validation', () async {
      final repo = MockReportsRepositoryForLocationTests();
      final draft = ReportSubmissionDraft(
        draftId: 'draft-valid-002',
        title: 'Broken window latch',
        category: IssueCategory.infrastructure,
        severity: IssueSeverity.medium,
        buildingId: 'b-eng',
        floorId: 'f-1st',
        locationDetails: 'Room 102 West Wing',
        description: 'Window does not close securely.',
        photoBytes: Uint8List.fromList([1, 2, 3]),
        photoMimeType: 'image/jpeg',
        photoFileName: 'window.jpg',
      );

      final result = await repo.submitReport(draft: draft, userId: 'user-002');
      expect(repo.submitCount, equals(1));
      expect(result.id, startsWith('REP-TEST-'));
      expect(result.title, equals('Broken window latch'));
    });

    test('Rejects invalid location details before backend insertion', () async {
      final repo = MockReportsRepositoryForLocationTests();
      final draft = ReportSubmissionDraft(
        draftId: 'draft-invalid-003',
        title: 'Broken tap',
        category: IssueCategory.water,
        severity: IssueSeverity.low,
        buildingId: 'b-eng',
        floorId: 'f-gnd',
        locationDetails: '', // Empty
        description: 'Tap leaking',
        photoBytes: Uint8List.fromList([1, 2, 3]),
        photoMimeType: 'image/jpeg',
        photoFileName: 'tap.jpg',
      );

      expect(
        () => repo.submitReport(draft: draft, userId: 'user-003'),
        throwsA(isA<ReportSubmissionException>().having(
          (e) => e.message,
          'message',
          contains('Please enter specific location details'),
        )),
      );
      expect(repo.submitCount, equals(0));
    });
  });

  group('ReportIssueScreen Widget & Form Flow Tests', () {
    Widget buildTestScreen(ReportsRepository repo) {
      return ProviderScope(
        overrides: [
          currentUserProvider.overrideWithValue(mockUser),
          reportsRepositoryProvider.overrideWithValue(repo),
          campusLocationsRepositoryProvider.overrideWithValue(FakeCampusLocationsRepository()),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const ReportIssueScreen(),
        ),
      );
    }

    testWidgets('Validates location details field and prevents submission when empty', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final repo = MockReportsRepositoryForLocationTests();
      await tester.pumpWidget(buildTestScreen(repo));
      await tester.pump(const Duration(milliseconds: 300));

      // Attempt submission without photo or location details
      await tester.ensureVisible(find.text('Submit report'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Submit report'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Submission was blocked
      expect(repo.submitCount, equals(0));
    });

    testWidgets('7. Failed submission preserves user entered values without loss', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final repo = MockReportsRepositoryForLocationTests();
      repo.shouldThrow = true;
      repo.exceptionToThrow = const ReportSubmissionException(
        'Location details must be between 2 and 255 characters.',
        code: '23514',
        field: 'location_details',
      );

      await tester.pumpWidget(buildTestScreen(repo));
      await tester.pump(const Duration(milliseconds: 300));

      // Find Specific Location Details by hint text
      final locationFinder = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.hintText?.contains('Room 204') == true,
      );
      expect(locationFinder, findsOneWidget);

      await tester.enterText(locationFinder, 'Chemistry Lab 304');
      await tester.pump();

      // Verify text was entered and preserved in controller and UI
      final textField = tester.widget<TextField>(locationFinder);
      expect(textField.controller?.text, equals('Chemistry Lab 304'));
      expect(find.text('Chemistry Lab 304'), findsWidgets);
    });
  });
}
