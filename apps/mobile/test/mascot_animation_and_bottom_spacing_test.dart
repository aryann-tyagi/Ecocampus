import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ecocampus_mobile/core/theme/app_theme.dart';
import 'package:ecocampus_mobile/core/widgets/custom_bottom_nav.dart';
import 'package:ecocampus_mobile/features/home/presentation/student_home_screen.dart';
import 'package:ecocampus_mobile/features/home/data/home_providers.dart';
import 'package:ecocampus_mobile/features/report/data/reports_provider.dart';
import 'package:ecocampus_mobile/features/report/domain/report_model.dart';
import 'package:ecocampus_mobile/main.dart';

void main() {
  group('Mascot Animation, Sizing and Bottom Spacing Validation', () {
    testWidgets('Mascot is enlarged by 10-15% (118dp) without clipping', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [greetingProvider.overrideWithValue('Good afternoon')],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: StudentHomeScreen(onNavigateToReports: () {}),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      final mascotImageFinder = find.byWidgetPredicate(
        (widget) => widget is Image && widget.image is AssetImage && (widget.image as AssetImage).assetName == 'assets/images/home/eco_mascot.png',
      );
      expect(mascotImageFinder, findsOneWidget);

      final mascotBox = tester.renderObject<RenderBox>(mascotImageFinder);
      expect(mascotBox.size.width, closeTo(118.0, 0.5));
      expect(mascotBox.size.height, closeTo(118.0, 0.5));
    });

    testWidgets('Leaves and stars orbit continuously through multiple cycles without disruption', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [greetingProvider.overrideWithValue('Good afternoon')],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: StudentHomeScreen(onNavigateToReports: () {}),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      final leaf1Finder = find.byWidgetPredicate(
        (widget) => widget is Image && widget.image is AssetImage && (widget.image as AssetImage).assetName == 'assets/images/home/floating_leaf_1.png',
      );
      final leaf2Finder = find.byWidgetPredicate(
        (widget) => widget is Image && widget.image is AssetImage && (widget.image as AssetImage).assetName == 'assets/images/home/floating_leaf_2.png',
      );
      expect(leaf1Finder, findsOneWidget);
      expect(leaf2Finder, findsOneWidget);

      final leaf1BoxInitial = tester.renderObject<RenderBox>(leaf1Finder);
      final initialOffset = leaf1BoxInitial.localToGlobal(Offset.zero);

      // Orbit controller duration is 12000ms (12.0s per cycle).
      // Tick through 3 complete animation cycles (12.0s x 3 = 36.0s)
      for (int cycle = 1; cycle <= 3; cycle++) {
        // Quarter cycle: 3.0s
        await tester.pump(const Duration(milliseconds: 3000));
        final quarterOffset = tester.renderObject<RenderBox>(leaf1Finder).localToGlobal(Offset.zero);
        expect((quarterOffset - initialOffset).distance, greaterThan(10.0), reason: 'Leaf 1 moves along orbit');

        // Half cycle: 3.0s
        await tester.pump(const Duration(milliseconds: 3000));
        final halfOffset = tester.renderObject<RenderBox>(leaf1Finder).localToGlobal(Offset.zero);
        expect((halfOffset - initialOffset).distance, greaterThan(20.0), reason: 'Leaf 1 reaches opposite side');

        // Three-quarter cycle: 3.0s
        await tester.pump(const Duration(milliseconds: 3000));

        // Full cycle completed: 3.0s (Total 12.0s)
        await tester.pump(const Duration(milliseconds: 3000));
        final cycleEndOffset = tester.renderObject<RenderBox>(leaf1Finder).localToGlobal(Offset.zero);

        // At end of full cycle, position matches initial position seamlessly (no jumps/snapping)
        expect(cycleEndOffset.dx, closeTo(initialOffset.dx, 0.5), reason: 'Cycle $cycle seamless loop boundary X');
        expect(cycleEndOffset.dy, closeTo(initialOffset.dy, 0.5), reason: 'Cycle $cycle seamless loop boundary Y');
      }
    });

    testWidgets('Scrollable viewport ends cleanly at the top of bottom navigation without duplicated insets', (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final testReports = [
        ReportModel(
          id: 'REP-01',
          title: 'Library Faucet Dripping',
          description: 'Water leak',
          category: IssueCategory.water,
          severity: IssueSeverity.medium,
          status: ReportStatus.reported,
          location: const CampusLocation(building: 'Library', floor: '1st Floor', area: 'Restroom'),
          createdAt: DateTime.now(),
        ),
        ReportModel(
          id: 'REP-02',
          title: 'Broken AC Unit in Lab 3',
          description: 'HVAC repair',
          category: IssueCategory.electricity,
          severity: IssueSeverity.high,
          status: ReportStatus.inProgress,
          location: const CampusLocation(building: 'Science', floor: 'Ground', area: 'Lab 3'),
          createdAt: DateTime.now(),
        ),
        ReportModel(
          id: 'REP-03',
          title: 'Overflowing Recycling Bin',
          description: 'Waste management',
          category: IssueCategory.waste,
          severity: IssueSeverity.low,
          status: ReportStatus.reported,
          location: const CampusLocation(building: 'Cafeteria', floor: 'Main', area: 'East Exit'),
          createdAt: DateTime.now(),
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            campusReportsProvider.overrideWith(() => _TestCampusReportsNotifier(testReports)),
            myReportsProvider.overrideWith(() => _TestMyReportsNotifier(testReports)),
            greetingProvider.overrideWithValue('Good afternoon'),
          ],
          child: const MaterialApp(
            home: MainNavigationShell(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      final navFinder = find.byType(CustomBottomNavBar);
      final navBox = tester.renderObject<RenderBox>(navFinder);
      final navTopY = navBox.localToGlobal(Offset.zero).dy;

      final scrollFinder = find.byType(SingleChildScrollView);
      final scrollBox = tester.renderObject<RenderBox>(scrollFinder);
      final scrollTopY = scrollBox.localToGlobal(Offset.zero).dy;
      final scrollHeight = scrollBox.size.height;
      final scrollBottomY = scrollTopY + scrollHeight;

      // When scrollable, the viewport's bottom boundary matches the top of the navigation bar exactly
      expect(scrollBottomY, closeTo(navTopY, 1.0));
      expect(navTopY - scrollBottomY, lessThanOrEqualTo(1.0));

      // Scroll to the very bottom
      await tester.drag(scrollFinder, const Offset(0, -500));
      await tester.pump(const Duration(milliseconds: 100));

      // Viewport remains firmly bounded at the navigation bar
      final scrollBoxAfter = tester.renderObject<RenderBox>(scrollFinder);
      final scrollBottomYAfter = scrollBoxAfter.localToGlobal(Offset.zero).dy + scrollBoxAfter.size.height;
      expect(scrollBottomYAfter, equals(scrollBottomY));
    });
  });
}

class _TestCampusReportsNotifier extends CampusReportsNotifier {
  final List<ReportModel> _initial;
  _TestCampusReportsNotifier(this._initial);

  @override
  Future<List<ReportModel>> build() async => _initial;

  @override
  Future<void> refresh() async {
    state = AsyncData(_initial);
  }
}

class _TestMyReportsNotifier extends MyReportsNotifier {
  final List<ReportModel> _initial;
  _TestMyReportsNotifier(this._initial);

  @override
  Future<List<ReportModel>> build() async => _initial;

  @override
  Future<void> refresh() async {
    state = AsyncData(_initial);
  }
}

