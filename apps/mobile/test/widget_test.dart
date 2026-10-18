import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ecocampus_mobile/features/home/data/home_providers.dart';
import 'package:ecocampus_mobile/features/map/data/campus_map_repository.dart';
import 'package:ecocampus_mobile/features/map/domain/campus_building_summary_model.dart';
import 'package:ecocampus_mobile/main.dart';

class _FakeCampusMapRepository implements CampusMapRepository {
  @override
  Future<List<CampusBuildingSummary>> getCampusBuildingSummaries() async {
    return const [
      CampusBuildingSummary(
        buildingId: 'b-1',
        buildingName: 'Science Block',
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
  }
}

void main() {
  testWidgets('EcoCampus mobile app smoke and navigation test', (WidgetTester tester) async {
    // Build our app with MainNavigationShell and trigger frames
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          greetingProvider.overrideWithValue('Good afternoon'),
          campusMapRepositoryProvider.overrideWithValue(_FakeCampusMapRepository()),
        ],
        child: const EcoCampusApp(home: MainNavigationShell()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));

    // Verify Student Home elements
    expect(find.text('Good afternoon'), findsOneWidget);
    expect(find.text('Report an issue'), findsOneWidget);
    expect(find.text('Sprig'), findsOneWidget);
    expect(find.text('Nearby issues'), findsOneWidget);

    // Switch to Map tab
    await tester.tap(find.text('Map'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Campus Map'), findsOneWidget);
    expect(find.text('Science Block'), findsWidgets);

    // Switch to Rewards tab
    await tester.tap(find.text('Rewards'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Level 1 of 5'), findsOneWidget);
    expect(find.text('Achievements'), findsOneWidget);
    expect(find.text('Leaderboard'), findsOneWidget);

    // Switch to Reports tab
    await tester.tap(find.text('Reports'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('My Reports'), findsOneWidget);
  });

  testWidgets('Unauthenticated EcoCampusApp defaults to LoginScreen via AuthGate', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: EcoCampusApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('EcoCampus'), findsOneWidget);
    expect(find.text('Sign in to your campus account'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
    expect(find.text('Register'), findsOneWidget);
  });
}
