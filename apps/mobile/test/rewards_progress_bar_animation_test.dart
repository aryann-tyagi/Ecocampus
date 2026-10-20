import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ecocampus_mobile/features/rewards/domain/eco_points_model.dart';
import 'package:ecocampus_mobile/features/rewards/presentation/widgets/rewards_sapling_progress_header.dart';

void main() {
  group('Rewards Flowing Progress Bar Animation & Accuracy Tests', () {
    // Standard test summaries for different progress levels
    final summaryLow = EcoPointsSummary.fromTotals(
      totalPoints: 100, // Level 3 start -> 0% progress -> clamped to 0.04 min
      eventCount: 2,
    );

    final summaryMid = EcoPointsSummary.fromTotals(
      totalPoints: 120, // Level 3 -> (120-100)/100 = 20% progress
      eventCount: 4,
    );

    final summaryHigh = EcoPointsSummary.fromTotals(
      totalPoints: 195, // Level 3 -> (195-100)/100 = 95% progress
      eventCount: 7,
    );

    final summaryMax = EcoPointsSummary.fromTotals(
      totalPoints: 350, // Level 5 (Max) -> 100% progress
      eventCount: 15,
    );

    testWidgets(
      'Fill length accurately represents real progress across low, mid, high, and max values',
      (WidgetTester tester) async {
        // 1. Test Mid Progress (20%)
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RewardsSaplingProgressHeader(
                summary: summaryMid,
                animated: false,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final midFinder = find.byWidgetPredicate(
          (w) =>
              w is FractionallySizedBox &&
              w.alignment == Alignment.centerLeft &&
              w.child is Container &&
              (w.child as Container).decoration is BoxDecoration,
        );
        expect(midFinder, findsOneWidget);
        final midBox = tester.widget<FractionallySizedBox>(midFinder);
        expect(midBox.widthFactor, closeTo(0.20, 0.001));

        // 2. Test Low Progress (0% clamped to 0.04 minimum rounded cap)
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RewardsSaplingProgressHeader(
                summary: summaryLow,
                animated: false,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final lowBox = tester.widget<FractionallySizedBox>(midFinder);
        expect(lowBox.widthFactor, closeTo(0.04, 0.001));

        // 3. Test High Progress (95%)
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RewardsSaplingProgressHeader(
                summary: summaryHigh,
                animated: false,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final highBox = tester.widget<FractionallySizedBox>(midFinder);
        expect(highBox.widthFactor, closeTo(0.95, 0.001));

        // 4. Test Max Level (100%)
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RewardsSaplingProgressHeader(
                summary: summaryMax,
                animated: false,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final maxBox = tester.widget<FractionallySizedBox>(midFinder);
        expect(maxBox.widthFactor, closeTo(1.0, 0.001));
      },
    );

    testWidgets(
      'Smooth fill animation advances to target on open and does not repeatedly refill',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RewardsSaplingProgressHeader(
                summary: summaryMid, // 20% target
                animated: true,
              ),
            ),
          ),
        );

        // Initial frame: starts at minimum cap (0.04)
        await tester.pump();
        final finder = find.byWidgetPredicate(
          (w) =>
              w is FractionallySizedBox &&
              w.alignment == Alignment.centerLeft &&
              w.child is Container &&
              (w.child as Container).decoration is BoxDecoration,
        );
        final initialBox = tester.widget<FractionallySizedBox>(finder);
        expect(initialBox.widthFactor, closeTo(0.04, 0.005));

        // Halfway through fill animation (400ms out of 800ms)
        await tester.pump(const Duration(milliseconds: 400));
        final halfwayBox = tester.widget<FractionallySizedBox>(finder);
        expect(halfwayBox.widthFactor, greaterThan(0.04));
        expect(halfwayBox.widthFactor, lessThan(0.20));

        // Complete fill animation (additional 500ms -> 900ms total)
        await tester.pump(const Duration(milliseconds: 500));
        final finalBox = tester.widget<FractionallySizedBox>(finder);
        expect(finalBox.widthFactor, closeTo(0.20, 0.001));

        // Advance another 2000ms: the fill must REMAIN steady at 0.20 and not empty/refill
        await tester.pump(const Duration(milliseconds: 2000));
        final steadyBox = tester.widget<FractionallySizedBox>(finder);
        expect(steadyBox.widthFactor, closeTo(0.20, 0.001));
      },
    );

    testWidgets(
      'Continuous flowing animation runs through at least 3 full cycles seamlessly without error',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RewardsSaplingProgressHeader(
                summary: summaryMid,
                animated: true,
              ),
            ),
          ),
        );
        await tester.pump();

        // One continuous cycle is 3200ms.
        // We will simulate 3.5 cycles (11,200ms) with regular 100ms ticks.
        const int totalTicks = 112; // 112 * 100ms = 11.2 seconds (> 3 full cycles)
        final gradientFinders = <LinearGradient>[];

        for (int i = 0; i < totalTicks; i++) {
          await tester.pump(const Duration(milliseconds: 100));

          // Inspect the Container decoration to verify gradient is active and valid
          final fillContainer = tester.widget<Container>(
            find.descendant(
              of: find.byWidgetPredicate((w) => w is FractionallySizedBox),
              matching: find.byType(Container),
            ).first,
          );
          final boxDec = fillContainer.decoration as BoxDecoration;
          final grad = boxDec.gradient as LinearGradient;
          gradientFinders.add(grad);

          // Ensure gradient tileMode is repeated for seamless looping
          expect(grad.tileMode, equals(TileMode.repeated));
          // Ensure first and last colors match for zero seam
          expect(grad.colors.first, equals(const Color(0xFF0A9E52)));
          expect(grad.colors.last, equals(const Color(0xFF0A9E52)));
        }

        // Verify no exceptions occurred throughout the entire 3+ cycles
        expect(tester.takeException(), isNull);
        expect(gradientFinders.length, equals(totalTicks));
      },
    );

    testWidgets(
      'Progress updates animate smoothly to new value without resetting gradient cycle',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RewardsSaplingProgressHeader(
                summary: summaryMid, // 20%
                animated: true,
              ),
            ),
          ),
        );
        // Let initial fill finish (1000ms)
        await tester.pump(const Duration(milliseconds: 1000));

        final finder = find.byWidgetPredicate(
          (w) =>
              w is FractionallySizedBox &&
              w.alignment == Alignment.centerLeft &&
              w.child is Container &&
              (w.child as Container).decoration is BoxDecoration,
        );
        expect(
          tester.widget<FractionallySizedBox>(finder).widthFactor,
          closeTo(0.20, 0.001),
        );

        // Update widget to summaryHigh (95%)
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RewardsSaplingProgressHeader(
                summary: summaryHigh, // 95%
                animated: true,
              ),
            ),
          ),
        );

        // Halfway through update animation
        await tester.pump(const Duration(milliseconds: 400));
        final updatedHalfway = tester.widget<FractionallySizedBox>(finder);
        expect(updatedHalfway.widthFactor, greaterThan(0.20));
        expect(updatedHalfway.widthFactor, lessThan(0.95));

        // Complete update animation
        await tester.pump(const Duration(milliseconds: 500));
        final updatedFinal = tester.widget<FractionallySizedBox>(finder);
        expect(updatedFinal.widthFactor, closeTo(0.95, 0.001));
      },
    );

    testWidgets(
      'Pauses flowing animation when isActive is false',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RewardsSaplingProgressHeader(
                summary: summaryMid,
                isActive: true,
                animated: true,
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 1000));

        // Get gradient begin alignment while active
        final activeFill = tester.widget<Container>(
          find.descendant(
            of: find.byWidgetPredicate((w) => w is FractionallySizedBox),
            matching: find.byType(Container),
          ).first,
        );
        final activeBegin =
            (activeFill.decoration as BoxDecoration).gradient as LinearGradient;

        // Advance 200ms
        await tester.pump(const Duration(milliseconds: 200));
        final activeFill2 = tester.widget<Container>(
          find.descendant(
            of: find.byWidgetPredicate((w) => w is FractionallySizedBox),
            matching: find.byType(Container),
          ).first,
        );
        final activeBegin2 =
            (activeFill2.decoration as BoxDecoration).gradient as LinearGradient;
        // Verify begin has moved
        expect(activeBegin.begin, isNot(equals(activeBegin2.begin)));

        // Set isActive: false
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RewardsSaplingProgressHeader(
                summary: summaryMid,
                isActive: false,
                animated: true,
              ),
            ),
          ),
        );
        await tester.pump();

        final pausedFill1 = tester.widget<Container>(
          find.descendant(
            of: find.byWidgetPredicate((w) => w is FractionallySizedBox),
            matching: find.byType(Container),
          ).first,
        );
        final pausedBegin1 =
            (pausedFill1.decoration as BoxDecoration).gradient as LinearGradient;

        // Advance 500ms while paused
        await tester.pump(const Duration(milliseconds: 500));
        final pausedFill2 = tester.widget<Container>(
          find.descendant(
            of: find.byWidgetPredicate((w) => w is FractionallySizedBox),
            matching: find.byType(Container),
          ).first,
        );
        final pausedBegin2 =
            (pausedFill2.decoration as BoxDecoration).gradient as LinearGradient;

        // Since it's paused, the gradient offset must NOT move
        expect(pausedBegin1.begin, equals(pausedBegin2.begin));
      },
    );

    testWidgets(
      'Respects system reduced motion setting (disableAnimations: true)',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: MaterialApp(
              home: Scaffold(
                body: RewardsSaplingProgressHeader(
                  summary: summaryMid,
                  animated: true,
                ),
              ),
            ),
          ),
        );
        // With disableAnimations: true, pump 1 frame
        await tester.pump();

        final finder = find.byWidgetPredicate(
          (w) =>
              w is FractionallySizedBox &&
              w.alignment == Alignment.centerLeft &&
              w.child is Container &&
              (w.child as Container).decoration is BoxDecoration,
        );
        // Should immediately sit at target progress
        expect(
          tester.widget<FractionallySizedBox>(finder).widthFactor,
          closeTo(0.20, 0.001),
        );

        // Gradient should remain static
        final fill1 = tester.widget<Container>(
          find.descendant(
            of: find.byWidgetPredicate((w) => w is FractionallySizedBox),
            matching: find.byType(Container),
          ).first,
        );
        final grad1 =
            (fill1.decoration as BoxDecoration).gradient as LinearGradient;

        await tester.pump(const Duration(milliseconds: 500));

        final fill2 = tester.widget<Container>(
          find.descendant(
            of: find.byWidgetPredicate((w) => w is FractionallySizedBox),
            matching: find.byType(Container),
          ).first,
        );
        final grad2 =
            (fill2.decoration as BoxDecoration).gradient as LinearGradient;

        expect(grad1.begin, equals(grad2.begin));
      },
    );
  });
}
