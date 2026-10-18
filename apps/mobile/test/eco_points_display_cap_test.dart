import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ecocampus_mobile/core/theme/app_theme.dart';
import 'package:ecocampus_mobile/features/home/data/home_providers.dart';
import 'package:ecocampus_mobile/features/home/presentation/student_home_screen.dart';
import 'package:ecocampus_mobile/features/rewards/data/eco_points_provider.dart';
import 'package:ecocampus_mobile/features/rewards/domain/eco_points_model.dart';

class _DynamicTestEcoPointsNotifier extends EcoPointsNotifier {
  EcoPointsSummary _summary;
  _DynamicTestEcoPointsNotifier(this._summary);

  @override
  FutureOr<EcoPointsSummary> build() => _summary;

  void updatePoints(int newPoints) {
    _summary = EcoPointsSummary.fromTotals(totalPoints: newPoints, eventCount: 6);
    state = AsyncData(_summary);
  }
}

void main() {
  group('EcoPoints Display Cap Tests', () {
    testWidgets(
      'Account with 120 points displays 120 in both top counter and middle component without /100 cap',
      (tester) async {
        final summary120 = EcoPointsSummary.fromTotals(
          totalPoints: 120,
          eventCount: 5,
        );

        final notifier = _DynamicTestEcoPointsNotifier(summary120);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              greetingProvider.overrideWithValue('Good afternoon'),
              ecoPointsProvider.overrideWith(() => notifier),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: StudentHomeScreen(onNavigateToReports: () {}),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 200));

        // 1. Verify '120' is displayed dynamically in both the top counter and middle score card
        final pointsWidgets = find.text('120');
        expect(
          pointsWidgets,
          findsNWidgets(2),
          reason: 'Both top counter and middle score component must display 120',
        );

        // 2. Verify that '/100' is NOT rendered anywhere in the middle score card
        expect(
          find.text('/100'),
          findsNothing,
          reason: 'Middle score component must not cap or suffix the score with /100',
        );

        // 3. Verify progress bar width factor is decoupled from 100 max:
        // For 120 points, Level is Sapling (100–199), progress is (120-100)/100 = 0.20
        final fractionallySizedBoxes = tester.widgetList<FractionallySizedBox>(
          find.byType(FractionallySizedBox),
        );
        final scoreProgressBar = fractionallySizedBoxes.firstWhere(
          (box) => box.alignment == Alignment.centerLeft,
        );
        expect(
          scoreProgressBar.widthFactor,
          closeTo(0.20, 0.01),
          reason: 'Progress bar should reflect level progress (0.20), not capped at 1.0',
        );

        // 4. Verify tapping middle score card opens modal with dynamic points
        await tester.tap(find.text('Eco Score'));
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.text('120 pts'), findsOneWidget);
        expect(find.text('100 / 100'), findsNothing);

        // Close modal
        await tester.tap(find.text('Got it'));
        await tester.pump(const Duration(milliseconds: 400));
      },
    );

    testWidgets(
      'Both top counter and middle component update dynamically when earning points',
      (tester) async {
        final summary120 = EcoPointsSummary.fromTotals(
          totalPoints: 120,
          eventCount: 5,
        );

        final notifier = _DynamicTestEcoPointsNotifier(summary120);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              greetingProvider.overrideWithValue('Good morning'),
              ecoPointsProvider.overrideWith(() => notifier),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: StudentHomeScreen(onNavigateToReports: () {}),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 200));

        expect(find.text('120'), findsNWidgets(2));

        // Simulate earning +5 points (e.g. reporting an issue) -> 125 points
        notifier.updatePoints(125);
        await tester.pump(const Duration(milliseconds: 200));

        // Both components should now display 125
        expect(find.text('120'), findsNothing);
        expect(
          find.text('125'),
          findsNWidgets(2),
          reason: 'Both top counter and middle score card must update dynamically to 125',
        );

        // Progress bar should now be 25% (25 / 100)
        final fractionallySizedBoxes = tester.widgetList<FractionallySizedBox>(
          find.byType(FractionallySizedBox),
        );
        final scoreProgressBar = fractionallySizedBoxes.firstWhere(
          (box) => box.alignment == Alignment.centerLeft,
        );
        expect(
          scoreProgressBar.widthFactor,
          closeTo(0.25, 0.01),
          reason: 'Progress bar should update dynamically to 0.25',
        );
      },
    );

    testWidgets(
      'High points (e.g. 250) display uncapped in middle component',
      (tester) async {
        final summary250 = EcoPointsSummary.fromTotals(
          totalPoints: 250,
          eventCount: 10,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              greetingProvider.overrideWithValue('Good evening'),
              ecoPointsProvider.overrideWith(
                () => _DynamicTestEcoPointsNotifier(summary250),
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: StudentHomeScreen(onNavigateToReports: () {}),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 200));

        // 250 points should be displayed in both components without being clamped to 100
        expect(find.text('250'), findsNWidgets(2));
        expect(find.text('100'), findsNothing);
      },
    );
  });
}
