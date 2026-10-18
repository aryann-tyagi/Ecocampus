import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ecocampus_mobile/features/map/data/campus_map_provider.dart';
import 'package:ecocampus_mobile/features/map/data/campus_map_repository.dart';
import 'package:ecocampus_mobile/features/map/domain/campus_building_summary_model.dart';
import 'package:ecocampus_mobile/core/widgets/custom_bottom_nav.dart';
import 'package:ecocampus_mobile/features/map/presentation/campus_map_screen.dart';

class MockCampusMapRepository implements CampusMapRepository {
  List<CampusBuildingSummary> summaries;
  bool shouldThrow;

  MockCampusMapRepository({
    this.summaries = const [],
    this.shouldThrow = false,
  });

  @override
  Future<List<CampusBuildingSummary>> getCampusBuildingSummaries() async {
    if (shouldThrow) {
      throw Exception('Simulated network error');
    }
    return summaries;
  }
}

final _testBuildings = [
  CampusBuildingSummary(
    buildingId: 'b-lib',
    buildingName: 'Green Library',
    totalReports: 15,
    activeReports: 2,
    resolvedReports: 13,
    wasteReports: 3,
    waterReports: 5,
    electricityReports: 4,
    infrastructureReports: 2,
    greeneryReports: 1,
    cleanlinessReports: 0,
    otherReports: 0,
    reportsWithCoordinates: 6,
    lastReportAt: DateTime(2026, 10, 14, 9, 30),
  ),
  CampusBuildingSummary(
    buildingId: 'b-eng',
    buildingName: 'Engineering Lab',
    totalReports: 8,
    activeReports: 0,
    resolvedReports: 8,
    wasteReports: 2,
    waterReports: 2,
    electricityReports: 3,
    infrastructureReports: 1,
    greeneryReports: 0,
    cleanlinessReports: 0,
    otherReports: 0,
    reportsWithCoordinates: 0,
    lastReportAt: DateTime(2026, 10, 13, 14, 15),
  ),
  CampusBuildingSummary(
    buildingId: 'b-hub',
    buildingName: 'Innovation Hub',
    totalReports: 0,
    activeReports: 0,
    resolvedReports: 0,
    wasteReports: 0,
    waterReports: 0,
    electricityReports: 0,
    infrastructureReports: 0,
    greeneryReports: 0,
    cleanlinessReports: 0,
    otherReports: 0,
    reportsWithCoordinates: 0,
    lastReportAt: null,
  ),
];

void main() {
  group('CampusBuildingSummary Model Tests', () {
    test('Parses JSON with safe bigint and timestamp conversions', () {
      final json = {
        'building_id': 'uuid-1234',
        'building_name': 'Solar Canopy',
        'total_reports': '42', // String bigint representation
        'active_reports': 5, // int
        'resolved_reports': 37.0, // num
        'waste_reports': '10',
        'water_reports': 8,
        'electricity_reports': 12,
        'infrastructure_reports': 6,
        'greenery_reports': 4,
        'cleanliness_reports': 2,
        'other_reports': 0,
        'reports_with_coordinates': '14',
        'last_report_at': '2026-10-14T08:00:00Z',
      };

      final summary = CampusBuildingSummary.fromJson(json);

      expect(summary.buildingId, 'uuid-1234');
      expect(summary.buildingName, 'Solar Canopy');
      expect(summary.totalReports, 42);
      expect(summary.activeReports, 5);
      expect(summary.resolvedReports, 37);
      expect(summary.wasteReports, 10);
      expect(summary.waterReports, 8);
      expect(summary.electricityReports, 12);
      expect(summary.infrastructureReports, 6);
      expect(summary.greeneryReports, 4);
      expect(summary.cleanlinessReports, 2);
      expect(summary.otherReports, 0);
      expect(summary.reportsWithCoordinates, 14);
      expect(summary.lastReportAt, isNotNull);
      expect(summary.lastReportAt?.toUtc().hour, 8);
    });

    test('Handles missing/null fields gracefully with default values', () {
      final json = <String, dynamic>{
        'building_id': null,
        'building_name': null,
      };

      final summary = CampusBuildingSummary.fromJson(json);

      expect(summary.buildingId, '');
      expect(summary.buildingName, 'Campus Building');
      expect(summary.totalReports, 0);
      expect(summary.activeReports, 0);
      expect(summary.resolvedReports, 0);
      expect(summary.wasteReports, 0);
      expect(summary.lastReportAt, isNull);
    });
  });

  group('CampusMapScreen Widget Tests', () {
    void setupScreen(WidgetTester tester) {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
    }

    testWidgets('Shows loading state while building summaries are being fetched',
        (tester) async {
      setupScreen(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            buildingSummariesProvider.overrideWith(() => _DelayedNotifier()),
          ],
          child: const MaterialApp(
            home: CampusMapScreen(enableContinuousAnimations: false),
          ),
        ),
      );

      // Immediately verify loading state without advancing timer
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Loading campus buildings...'), findsOneWidget);

      await tester.pumpAndSettle();
    });

    testWidgets('Shows error state with actionable retry button on RPC failure',
        (tester) async {
      setupScreen(tester);
      final mockRepo = MockCampusMapRepository(shouldThrow: true);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            campusMapRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: const MaterialApp(
            home: CampusMapScreen(enableContinuousAnimations: false),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Unable to load campus map'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      // Now enable success and tap retry
      mockRepo.shouldThrow = false;
      mockRepo.summaries = _testBuildings;

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.text('Unable to load campus map'), findsNothing);
      expect(find.text('Green Library'), findsWidgets);
    });

    testWidgets('Shows empty state when Supabase returns no active buildings',
        (tester) async {
      setupScreen(tester);
      final mockRepo = MockCampusMapRepository(summaries: []);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            campusMapRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: const MaterialApp(
            home: CampusMapScreen(enableContinuousAnimations: false),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No active campus buildings'), findsOneWidget);
    });

    testWidgets('Displays authentic building cards and detail card without mock data',
        (tester) async {
      setupScreen(tester);
      final mockRepo = MockCampusMapRepository(summaries: _testBuildings);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            campusMapRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: const MaterialApp(
            home: CampusMapScreen(enableContinuousAnimations: false),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify removed hardcoded scores & mock building strings
      expect(find.text('61'), findsNothing);
      expect(find.text('82'), findsNothing);
      expect(find.text('91'), findsNothing);
      expect(find.text('87'), findsNothing);
      expect(find.text('Jun'), findsNothing);
      expect(find.text('Oct'), findsNothing);
      expect(find.text('Recurring water issue.'), findsNothing);

      // Verify honest schematic disclaimer
      expect(
        find.textContaining('Campus Schematic'),
        findsOneWidget,
      );

      // Verify authentic buildings on the map
      expect(find.text('Green Library'), findsWidgets);
      expect(find.text('Engineering Lab'), findsWidgets);
      expect(find.text('Innovation Hub'), findsWidgets);

      // Verify live campus header metrics
      expect(find.text('Campus Map'), findsOneWidget);
      expect(find.text('2 active issues across 3 buildings'), findsOneWidget);

      // Verify default selection (first building: Green Library)
      expect(find.text('View Active Issue (2)'), findsOneWidget);
      expect(find.text('Total'), findsOneWidget);
      expect(find.text('Active'), findsOneWidget);
      expect(find.text('Resolved'), findsOneWidget);

      // Verify categories breakdown counts for Green Library
      expect(find.text('Waste'), findsOneWidget);
      expect(find.text('Water'), findsOneWidget);
      expect(find.text('Energy'), findsOneWidget);
      expect(find.text('Infrastructure'), findsOneWidget);
      expect(find.text('Greenery'), findsOneWidget);
      expect(find.text('Cleanliness'), findsOneWidget);

      // Verify GPS verification note when reportsWithCoordinates > 0
      expect(
        find.textContaining('6 of 15 report(s) include verified GPS coordinates'),
        findsOneWidget,
      );
    });

    testWidgets('Tapping building card updates selection and details sheet',
        (tester) async {
      setupScreen(tester);
      final mockRepo = MockCampusMapRepository(summaries: _testBuildings);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            campusMapRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: const MaterialApp(
            home: CampusMapScreen(enableContinuousAnimations: false),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Innovation Hub card (3rd building with 0 reports)
      await tester.tap(find.text('Innovation Hub'));
      await tester.pumpAndSettle();

      // Verify detail sheet shows zero reports state
      expect(find.text('No reports yet'), findsWidgets);
      expect(find.text('No Active Issues'), findsOneWidget);
    });

    testWidgets('Search input filters building list dynamically',
        (tester) async {
      setupScreen(tester);
      final mockRepo = MockCampusMapRepository(summaries: _testBuildings);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            campusMapRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: const MaterialApp(
            home: CampusMapScreen(enableContinuousAnimations: false),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Enter search query 'Engineering'
      await tester.enterText(
        find.byType(TextField),
        'Engineering',
      );
      await tester.pumpAndSettle();

      expect(find.text('Engineering Lab'), findsWidgets);
      expect(find.text('Green Library'), findsNothing);
      expect(find.text('Innovation Hub'), findsNothing);

      // Enter query with no match
      await tester.enterText(
        find.byType(TextField),
        'Dormitory XYZ',
      );
      await tester.pumpAndSettle();

      expect(find.text('No matching buildings'), findsOneWidget);
      expect(find.text('Reset filters'), findsOneWidget);

      // Tap reset filters
      await tester.tap(find.text('Reset filters'));
      await tester.pumpAndSettle();

      expect(find.text('Green Library'), findsWidgets);
      expect(find.text('Engineering Lab'), findsWidgets);
    });

    testWidgets('Filter pills filter buildings by Active Issues and No Reported Issues',
        (tester) async {
      setupScreen(tester);
      final mockRepo = MockCampusMapRepository(summaries: _testBuildings);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            campusMapRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: const MaterialApp(
            home: CampusMapScreen(enableContinuousAnimations: false),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Filter: With Issues
      await tester.tap(find.text('With Issues'));
      await tester.pumpAndSettle();

      // Green Library has 2 active reports; others have 0
      expect(find.text('Green Library'), findsWidgets);
      expect(find.text('Engineering Lab'), findsNothing);
      expect(find.text('Innovation Hub'), findsNothing);

      // 2. Filter: No Issues
      await tester.tap(find.text('No Issues'));
      await tester.pumpAndSettle();

      // Buildings with zero active reports (Engineering Lab and Innovation Hub)
      expect(find.text('Innovation Hub'), findsWidgets);
      expect(find.text('Engineering Lab'), findsWidgets);
      expect(find.text('Green Library'), findsNothing);

      // 3. Filter: All
      await tester.tap(find.text('All'));
      await tester.pumpAndSettle();

      expect(find.text('Green Library'), findsWidgets);
      expect(find.text('Engineering Lab'), findsWidgets);
      expect(find.text('Innovation Hub'), findsWidgets);
    });

    testWidgets('Refresh re-queries Supabase building summaries',
        (tester) async {
      setupScreen(tester);
      final mockRepo = MockCampusMapRepository(summaries: _testBuildings);

      late WidgetRef refContext;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            campusMapRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, _) {
                refContext = ref;
                return const CampusMapScreen(enableContinuousAnimations: false);
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Green Library'), findsWidgets);

      // Change repo data to simulate live database update
      mockRepo.summaries = [
        ..._testBuildings,
        const CampusBuildingSummary(
          buildingId: 'b-new',
          buildingName: 'New Science Tower',
          totalReports: 1,
          activeReports: 1,
          resolvedReports: 0,
          wasteReports: 0,
          waterReports: 1,
          electricityReports: 0,
          infrastructureReports: 0,
          greeneryReports: 0,
          cleanlinessReports: 0,
          otherReports: 0,
          reportsWithCoordinates: 1,
        ),
      ];

      // Refresh building summaries
      await refContext.read(buildingSummariesProvider.notifier).refresh();
      await tester.pumpAndSettle();

      expect(find.text('New Science Tower'), findsWidgets);
    });

    testWidgets('Respects animation lifecycle and reduced-motion preferences',
        (tester) async {
      setupScreen(tester);
      final mockRepo = MockCampusMapRepository(summaries: _testBuildings);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            campusMapRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: const MaterialApp(
            home: CampusMapScreen(enableContinuousAnimations: true),
          ),
        ),
      );

      // Advance frames to verify smooth animation ticking without error
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Campus Map'), findsOneWidget);
      expect(find.text('Green Library'), findsWidgets);
    });

    testWidgets('Building markers do not overlap on small Android screens (360x740)',
        (tester) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final eightBuildings = [
        for (int i = 0; i < 8; i++)
          CampusBuildingSummary(
            buildingId: 'b-$i',
            buildingName: 'Hall $i',
            totalReports: i,
            activeReports: i % 2,
            resolvedReports: i ~/ 2,
            wasteReports: 0,
            waterReports: 0,
            electricityReports: 0,
            infrastructureReports: 0,
            greeneryReports: 0,
            cleanlinessReports: 0,
            otherReports: 0,
            reportsWithCoordinates: 0,
          ),
      ];
      final mockRepo = MockCampusMapRepository(summaries: eightBuildings);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            campusMapRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: const MaterialApp(
            home: CampusMapScreen(enableContinuousAnimations: false),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Retrieve rects of all 8 building markers
      final rects = <Rect>[];
      for (int i = 0; i < 8; i++) {
        final finder = find.text('Hall $i');
        expect(finder, findsWidgets);
        final rect = tester.getRect(finder.first);
        rects.add(rect);

        // Verify marker stays within screen bounds
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(360));
      }

      // Assert that no two markers overlap
      for (int i = 0; i < rects.length; i++) {
        for (int j = i + 1; j < rects.length; j++) {
          final overlaps = rects[i].overlaps(rects[j]);
          expect(overlaps, isFalse,
              reason: 'Marker Hall $i and Hall $j should not overlap: ${rects[i]} vs ${rects[j]}');
        }
      }
    });

    testWidgets('Handles ultra-compact screens (320x568) and building clustering cleanly',
        (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final tenBuildings = [
        for (int i = 0; i < 10; i++)
          CampusBuildingSummary(
            buildingId: 'b-$i',
            buildingName: 'Zone $i',
            totalReports: i,
            activeReports: i % 2,
            resolvedReports: i ~/ 2,
            wasteReports: 0,
            waterReports: 0,
            electricityReports: 0,
            infrastructureReports: 0,
            greeneryReports: 0,
            cleanlinessReports: 0,
            otherReports: 0,
            reportsWithCoordinates: 0,
          ),
      ];
      final mockRepo = MockCampusMapRepository(summaries: tenBuildings);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            campusMapRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: const MaterialApp(
            home: CampusMapScreen(enableContinuousAnimations: false),
          ),
        ),
      );
      await tester.pumpAndSettle();

      for (int i = 0; i < 10; i++) {
        expect(find.text('Zone $i'), findsWidgets);
      }
    });

    testWidgets('Building markers do not collide with the selected details sheet',
        (tester) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final eightBuildings = [
        for (int i = 0; i < 8; i++)
          CampusBuildingSummary(
            buildingId: 'b-$i',
            buildingName: 'Pavilion $i',
            totalReports: 3,
            activeReports: 1,
            resolvedReports: 2,
            wasteReports: 1,
            waterReports: 0,
            electricityReports: 0,
            infrastructureReports: 0,
            greeneryReports: 0,
            cleanlinessReports: 0,
            otherReports: 0,
            reportsWithCoordinates: 0,
          ),
      ];
      final mockRepo = MockCampusMapRepository(summaries: eightBuildings);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            campusMapRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: const MaterialApp(
            home: CampusMapScreen(enableContinuousAnimations: false),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Details panel is visible by default for the first building
      final detailsTotalTile = find.text('Total');
      expect(detailsTotalTile, findsOneWidget);
      final detailsRect = tester.getRect(detailsTotalTile);

      // Verify the selected building marker (Pavilion 0) is positioned comfortably
      // in the visible viewing area above the details sheet
      final selectedMarkerRect = tester.getRect(find.text('Pavilion 0').first);
      expect(selectedMarkerRect.bottom, lessThanOrEqualTo(detailsRect.top),
          reason: 'Selected marker at ${selectedMarkerRect.bottom} should be positioned above details sheet at ${detailsRect.top}');

      // Verify all 8 building markers are placed across the scrollable canvas without any overlaps
      final markerRects = <Rect>[];
      for (int i = 0; i < 8; i++) {
        final rect = tester.getRect(find.text('Pavilion $i').first);
        markerRects.add(rect);
      }
      for (int i = 0; i < markerRects.length; i++) {
        for (int j = i + 1; j < markerRects.length; j++) {
          expect(markerRects[i].overlaps(markerRects[j]), isFalse,
              reason: 'Marker Pavilion $i and Pavilion $j should not overlap on the scrollable canvas');
        }
      }
    });

    testWidgets('Animation pauses when screen is inactive and resumes when active',
        (tester) async {
      setupScreen(tester);
      final mockRepo = MockCampusMapRepository(summaries: _testBuildings);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            campusMapRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: const MaterialApp(
            home: CampusMapScreen(isActive: true, enableContinuousAnimations: true),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      // Make screen inactive (e.g. user switched tabs)
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            campusMapRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: const MaterialApp(
            home: CampusMapScreen(isActive: false, enableContinuousAnimations: true),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      // Re-activate screen
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            campusMapRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: const MaterialApp(
            home: CampusMapScreen(isActive: true, enableContinuousAnimations: true),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Campus Map'), findsOneWidget);
    });

    testWidgets('Renders all 14 authentic buildings across G1, G2, G3 zones and respects bottom navigation clearance',
        (tester) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final fourteenBuildings = [
        // G1: Hostel & Parking Zone
        const CampusBuildingSummary(
          buildingId: 'b-bp',
          buildingName: 'Bus Parking',
          totalReports: 1,
          activeReports: 0,
          resolvedReports: 1,
          wasteReports: 0,
          waterReports: 0,
          electricityReports: 0,
          infrastructureReports: 1,
          greeneryReports: 0,
          cleanlinessReports: 0,
          otherReports: 0,
          reportsWithCoordinates: 0,
        ),
        const CampusBuildingSummary(
          buildingId: 'b-bh',
          buildingName: 'Boys Hostel',
          totalReports: 4,
          activeReports: 2,
          resolvedReports: 2,
          wasteReports: 1,
          waterReports: 2,
          electricityReports: 1,
          infrastructureReports: 0,
          greeneryReports: 0,
          cleanlinessReports: 0,
          otherReports: 0,
          reportsWithCoordinates: 1,
        ),
        const CampusBuildingSummary(
          buildingId: 'b-gh',
          buildingName: 'Girls Hostel',
          totalReports: 2,
          activeReports: 0,
          resolvedReports: 2,
          wasteReports: 0,
          waterReports: 1,
          electricityReports: 1,
          infrastructureReports: 0,
          greeneryReports: 0,
          cleanlinessReports: 0,
          otherReports: 0,
          reportsWithCoordinates: 0,
        ),
        const CampusBuildingSummary(
          buildingId: 'b-hm',
          buildingName: 'Hostel Mess',
          totalReports: 3,
          activeReports: 1,
          resolvedReports: 2,
          wasteReports: 2,
          waterReports: 0,
          electricityReports: 1,
          infrastructureReports: 0,
          greeneryReports: 0,
          cleanlinessReports: 0,
          otherReports: 0,
          reportsWithCoordinates: 0,
        ),
        const CampusBuildingSummary(
          buildingId: 'b-hg',
          buildingName: 'Hostel Ground',
          totalReports: 0,
          activeReports: 0,
          resolvedReports: 0,
          wasteReports: 0,
          waterReports: 0,
          electricityReports: 0,
          infrastructureReports: 0,
          greeneryReports: 0,
          cleanlinessReports: 0,
          otherReports: 0,
          reportsWithCoordinates: 0,
        ),

        // G2: Café & Library Zone
        const CampusBuildingSummary(
          buildingId: 'b-rc',
          buildingName: 'Royals Cafe',
          totalReports: 2,
          activeReports: 1,
          resolvedReports: 1,
          wasteReports: 1,
          waterReports: 0,
          electricityReports: 0,
          infrastructureReports: 0,
          greeneryReports: 0,
          cleanlinessReports: 1,
          otherReports: 0,
          reportsWithCoordinates: 0,
        ),
        const CampusBuildingSummary(
          buildingId: 'b-caf',
          buildingName: 'Cafeteria',
          totalReports: 5,
          activeReports: 0,
          resolvedReports: 5,
          wasteReports: 3,
          waterReports: 1,
          electricityReports: 0,
          infrastructureReports: 0,
          greeneryReports: 0,
          cleanlinessReports: 1,
          otherReports: 0,
          reportsWithCoordinates: 2,
        ),
        const CampusBuildingSummary(
          buildingId: 'b-hmb',
          buildingName: 'Hotel Management Block',
          totalReports: 1,
          activeReports: 0,
          resolvedReports: 1,
          wasteReports: 0,
          waterReports: 0,
          electricityReports: 1,
          infrastructureReports: 0,
          greeneryReports: 0,
          cleanlinessReports: 0,
          otherReports: 0,
          reportsWithCoordinates: 0,
        ),
        const CampusBuildingSummary(
          buildingId: 'b-lib',
          buildingName: 'Library',
          totalReports: 3,
          activeReports: 0,
          resolvedReports: 3,
          wasteReports: 1,
          waterReports: 1,
          electricityReports: 1,
          infrastructureReports: 0,
          greeneryReports: 0,
          cleanlinessReports: 0,
          otherReports: 0,
          reportsWithCoordinates: 1,
        ),

        // G3: Academic & Sports Zone
        const CampusBuildingSummary(
          buildingId: 'b-eng',
          buildingName: 'Engineering Block',
          totalReports: 6,
          activeReports: 2,
          resolvedReports: 4,
          wasteReports: 2,
          waterReports: 1,
          electricityReports: 2,
          infrastructureReports: 1,
          greeneryReports: 0,
          cleanlinessReports: 0,
          otherReports: 0,
          reportsWithCoordinates: 2,
        ),
        const CampusBuildingSummary(
          buildingId: 'b-neng',
          buildingName: 'New Engineering Block',
          totalReports: 2,
          activeReports: 0,
          resolvedReports: 2,
          wasteReports: 0,
          waterReports: 1,
          electricityReports: 1,
          infrastructureReports: 0,
          greeneryReports: 0,
          cleanlinessReports: 0,
          otherReports: 0,
          reportsWithCoordinates: 0,
        ),
        const CampusBuildingSummary(
          buildingId: 'b-olaw',
          buildingName: 'Old Law Block',
          totalReports: 1,
          activeReports: 0,
          resolvedReports: 1,
          wasteReports: 0,
          waterReports: 0,
          electricityReports: 0,
          infrastructureReports: 1,
          greeneryReports: 0,
          cleanlinessReports: 0,
          otherReports: 0,
          reportsWithCoordinates: 0,
        ),
        const CampusBuildingSummary(
          buildingId: 'b-llaw',
          buildingName: 'Law Library',
          totalReports: 0,
          activeReports: 0,
          resolvedReports: 0,
          wasteReports: 0,
          waterReports: 0,
          electricityReports: 0,
          infrastructureReports: 0,
          greeneryReports: 0,
          cleanlinessReports: 0,
          otherReports: 0,
          reportsWithCoordinates: 0,
        ),
        const CampusBuildingSummary(
          buildingId: 'b-sc',
          buildingName: 'Sports Complex',
          totalReports: 2,
          activeReports: 1,
          resolvedReports: 1,
          wasteReports: 0,
          waterReports: 1,
          electricityReports: 0,
          infrastructureReports: 1,
          greeneryReports: 0,
          cleanlinessReports: 0,
          otherReports: 0,
          reportsWithCoordinates: 1,
        ),
      ];

      final mockRepo = MockCampusMapRepository(summaries: fourteenBuildings);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            campusMapRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: const MaterialApp(
            home: CampusMapScreen(enableContinuousAnimations: false),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Verify all 3 zone labels are rendered
      expect(find.text('G1'), findsOneWidget);
      expect(find.text('Hostel & Parking Zone'), findsOneWidget);
      expect(find.text('G2'), findsOneWidget);
      expect(find.text('Café & Library Zone'), findsOneWidget);
      expect(find.text('G3'), findsOneWidget);
      expect(find.text('Academic & Sports Zone'), findsOneWidget);

      // 2. Verify all 14 buildings are found in the widget tree
      for (final b in fourteenBuildings) {
        expect(find.text(b.buildingName), findsWidgets,
            reason: 'Building ${b.buildingName} should be present on the canvas');
      }

      // 3. Verify no two building markers overlap
      final rects = <Rect>[];
      for (final b in fourteenBuildings) {
        final rect = tester.getRect(find.text(b.buildingName).first);
        rects.add(rect);
        // Verify horizontal bounds
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(360));
      }

      for (int i = 0; i < rects.length; i++) {
        for (int j = i + 1; j < rects.length; j++) {
          expect(rects[i].overlaps(rects[j]), isFalse,
              reason: 'Marker ${fourteenBuildings[i].buildingName} and ${fourteenBuildings[j].buildingName} should not overlap: ${rects[i]} vs ${rects[j]}');
        }
      }

      // 4. Search for the final building (Sports Complex in G3) which scrolls to it and highlights it
      await tester.enterText(find.byType(TextField), 'Sports Complex');
      await tester.pumpAndSettle();

      // Details panel displays Sports Complex
      expect(find.text('Sports Complex'), findsWidgets);
      expect(find.text('View Active Issue (1)'), findsOneWidget);

      // Verify the details panel sits cleanly above bottom navigation clearance (740 - 88 = 652)
      final detailsTotalTile = find.text('Total');
      expect(detailsTotalTile, findsOneWidget);
      final detailsRect = tester.getRect(detailsTotalTile);
      expect(detailsRect.bottom, lessThanOrEqualTo(652.0),
          reason: 'Details panel at ${detailsRect.bottom} must stay strictly above the bottom navigation clearance');
    });

    testWidgets('Boys Hostel selection shows dynamic category ordering with Water first and action buttons',
        (tester) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final boysHostelBuilding = const CampusBuildingSummary(
        buildingId: 'b-boys-hostel',
        buildingName: 'Boys Hostel',
        totalReports: 1,
        activeReports: 1,
        resolvedReports: 0,
        wasteReports: 0,
        waterReports: 1,
        electricityReports: 0,
        infrastructureReports: 0,
        greeneryReports: 0,
        cleanlinessReports: 0,
        otherReports: 0,
        reportsWithCoordinates: 0,
        lastReportAt: null,
      );

      final otherBuilding = const CampusBuildingSummary(
        buildingId: 'b-lib',
        buildingName: 'Library',
        totalReports: 0,
        activeReports: 0,
        resolvedReports: 0,
        wasteReports: 0,
        waterReports: 0,
        electricityReports: 0,
        infrastructureReports: 0,
        greeneryReports: 0,
        cleanlinessReports: 0,
        otherReports: 0,
        reportsWithCoordinates: 0,
        lastReportAt: null,
      );

      final mockRepo = MockCampusMapRepository(
        summaries: [boysHostelBuilding, otherBuilding],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            campusMapRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: const MaterialApp(
            home: CampusMapScreen(enableContinuousAnimations: false),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Boys Hostel
      await tester.tap(find.text('Boys Hostel').first);
      await tester.pumpAndSettle();

      // 1. Verify Boys Hostel details sheet header & metrics
      expect(find.text('Boys Hostel'), findsWidgets);
      expect(find.text('Total'), findsOneWidget);
      expect(find.text('Active'), findsOneWidget);
      expect(find.text('Resolved'), findsOneWidget);

      // 2. Verify dynamic category ordering: Water (1 report) appears first before 0-count categories
      final waterFinder = find.text('Water');
      final wasteFinder = find.text('Waste');
      expect(waterFinder, findsOneWidget);
      expect(wasteFinder, findsOneWidget);

      final waterRect = tester.getRect(waterFinder);
      final wasteRect = tester.getRect(wasteFinder);
      expect(waterRect.left, lessThan(wasteRect.left),
          reason: 'Water (positive report) must appear before Waste (zero reports)');

      // 3. Verify primary action buttons: + Report Issue and View Active Issue (1)
      expect(find.text('Report Issue'), findsOneWidget);
      expect(find.text('View Active Issue (1)'), findsOneWidget);

      // 4. Tap Map Layers button and verify toggle dialog
      final layersButton = find.byTooltip('Map Layers');
      expect(layersButton, findsOneWidget);
      await tester.tap(layersButton);
      await tester.pumpAndSettle();

      expect(find.text('Map Layers'), findsOneWidget);
      expect(find.text('Buildings'), findsOneWidget);
      expect(find.text('Walkways'), findsOneWidget);
      expect(find.text('Landscaping'), findsOneWidget);

      // Tap Done
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      expect(find.text('Map Layers'), findsNothing);
    });

    testWidgets('Campus Map does NOT render fake blue location dot or accuracy halo',
        (WidgetTester tester) async {
      final mockRepo = MockCampusMapRepository(summaries: _testBuildings);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            campusMapRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: const MaterialApp(
            home: CampusMapScreen(enableContinuousAnimations: false),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify no fake location marker or accuracy halo exists
      expect(find.text('Your Location'), findsNothing);
      expect(find.text('Current Location'), findsNothing);
      expect(find.byKey(const Key('fake_location_dot')), findsNothing);
      expect(find.byTooltip('Current Location'), findsNothing);
    });

    testWidgets('Sequential building selection updates transition origin correctly without jumps',
        (WidgetTester tester) async {
      setupScreen(tester);
      final buildings = [
        const CampusBuildingSummary(
          buildingId: 'b-hostel',
          buildingName: 'Boys Hostel',
          totalReports: 1,
          activeReports: 1,
          resolvedReports: 0,
          wasteReports: 0,
          waterReports: 1,
          electricityReports: 0,
          infrastructureReports: 0,
          greeneryReports: 0,
          cleanlinessReports: 0,
          otherReports: 0,
          reportsWithCoordinates: 0,
        ),
        const CampusBuildingSummary(
          buildingId: 'b-parking',
          buildingName: 'Bus Parking',
          totalReports: 0,
          activeReports: 0,
          resolvedReports: 0,
          wasteReports: 0,
          waterReports: 0,
          electricityReports: 0,
          infrastructureReports: 0,
          greeneryReports: 0,
          cleanlinessReports: 0,
          otherReports: 0,
          reportsWithCoordinates: 0,
        ),
        const CampusBuildingSummary(
          buildingId: 'b-lib',
          buildingName: 'Library',
          totalReports: 2,
          activeReports: 0,
          resolvedReports: 2,
          wasteReports: 0,
          waterReports: 0,
          electricityReports: 2,
          infrastructureReports: 0,
          greeneryReports: 0,
          cleanlinessReports: 0,
          otherReports: 0,
          reportsWithCoordinates: 0,
        ),
      ];

      final mockRepo = MockCampusMapRepository(summaries: buildings);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            campusMapRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: const MaterialApp(
            home: CampusMapScreen(enableContinuousAnimations: false),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Initial building is selected (Boys Hostel)
      expect(find.text('Boys Hostel'), findsWidgets);

      // 2. Select Bus Parking
      await tester.tap(find.text('Bus Parking').first);
      await tester.pumpAndSettle();
      expect(find.text('Bus Parking'), findsWidgets);

      // 3. Select Library
      await tester.tap(find.text('Library').first);
      await tester.pumpAndSettle();
      expect(find.text('Library'), findsWidgets);

      // 4. Tap Library again - should maintain selection without error
      await tester.tap(find.text('Library').first);
      await tester.pumpAndSettle();
      expect(find.text('Library'), findsWidgets);
    });

    testWidgets('Details sheet docks directly above bottom navigation without excessive gap',
        (WidgetTester tester) async {
      setupScreen(tester);
      final mockRepo = MockCampusMapRepository(summaries: _testBuildings);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            campusMapRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: const MaterialApp(
            home: CampusMapScreen(enableContinuousAnimations: false),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify details sheet is rendered for Green Library
      final sheetFinder = find.byKey(const ValueKey('b-lib'));
      expect(sheetFinder, findsOneWidget);

      // Locate sheet position and verify it is docked above the bottom nav (within 68-100px from screen bottom)
      final sheetRect = tester.getRect(sheetFinder);
      expect(sheetRect.bottom, lessThanOrEqualTo(2400.0));
      expect(sheetRect.bottom, greaterThan(2400.0 - 120.0));
    });

    testWidgets('Duplicate fixed zone tag overlay is removed while map canvas zone label remains',
        (WidgetTester tester) async {
      setupScreen(tester);
      final mockRepo = MockCampusMapRepository(summaries: _testBuildings);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            campusMapRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: const MaterialApp(
            home: CampusMapScreen(enableContinuousAnimations: false),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Verify the duplicate stuck screen-fixed overlay tag is NOT present
      expect(find.text('G1 · Hostel & Parking Zone'), findsNothing);

      // 2. Verify the authentic zone label remains on the map canvas
      expect(find.text('Hostel & Parking Zone'), findsOneWidget);
      expect(find.text('G1'), findsOneWidget);
    });

    testWidgets(
        'When hosted with bottom navigation, details sheet sits close with small 8px gap without duplicate insets',
        (WidgetTester tester) async {
      setupScreen(tester);
      final mockRepo = MockCampusMapRepository(summaries: _testBuildings);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            campusMapRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: MaterialApp(
            home: Scaffold(
              extendBody: true,
              body: const CampusMapScreen(enableContinuousAnimations: false),
              bottomNavigationBar: CustomBottomNavBar(
                currentIndex: 1,
                onTap: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Details sheet for initial building (Green Library)
      final sheetFinder = find.byKey(const ValueKey('b-lib'));
      expect(sheetFinder, findsOneWidget);

      final navFinder = find.byType(CustomBottomNavBar);
      expect(navFinder, findsOneWidget);

      final sheetRect = tester.getRect(sheetFinder);
      final navRect = tester.getRect(navFinder);

      // The gap between the bottom of the details sheet and the top of CustomBottomNavBar
      // should be exactly 8.0 logical pixels (small, visually balanced gap), not 68+ px.
      final gap = navRect.top - sheetRect.bottom;
      expect(gap, closeTo(8.0, 1.0),
          reason: 'Details sheet should sit naturally 8px above bottom navigation without excessive 68px gap');

      // Tap Engineering Lab to select another building
      await tester.tap(find.text('Engineering Lab').first);
      await tester.pumpAndSettle();

      final engSheetFinder = find.byKey(const ValueKey('b-eng'));
      expect(engSheetFinder, findsOneWidget);

      final engSheetRect = tester.getRect(engSheetFinder);
      final engGap = navRect.top - engSheetRect.bottom;
      expect(engGap, closeTo(8.0, 1.0),
          reason: 'Details sheet for another building should also maintain the exact 8px gap');
    });
  });
}

class _DelayedNotifier extends BuildingSummariesNotifier {
  @override
  Future<List<CampusBuildingSummary>> build() async {
    await Future.delayed(const Duration(milliseconds: 100));
    return [];
  }
}
