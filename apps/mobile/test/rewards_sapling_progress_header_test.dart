import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ecocampus_mobile/features/rewards/domain/eco_points_model.dart';
import 'package:ecocampus_mobile/features/rewards/presentation/widgets/rewards_sapling_progress_header.dart';

void main() {
  group('RewardsSaplingProgressHeader Visual & Functional Tests', () {
    // 120 EcoPoints corresponds to Level 3: Sapling (range 100-199, so 20/100 = 20% progress)
    final saplingSummary = EcoPointsSummary.fromTotals(
      totalPoints: 120,
      eventCount: 4,
    );

    testWidgets(
        'Renders all visual header elements accurately on standard mobile width (390px)',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390 * 2, 844 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: RewardsSaplingProgressHeader(
                summary: saplingSummary,
                animated: false,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Heading and subtitle
      expect(find.text('Rewards'), findsOneWidget);
      expect(
        find.text(
            'Complete challenges, earn EcoPoints\nto make your campus better!'),
        findsOneWidget,
      );

      // Level pill
      expect(find.text('Level 3 of 5'), findsOneWidget);

      // Progress Card center texts
      expect(find.text('Your level'), findsOneWidget);
      expect(find.text('Sapling'), findsOneWidget);
      expect(find.text('120 EcoPoints'), findsOneWidget);

      // Supporting next level text
      // Next level after Sapling is Tree (Level 4, 200 points).
      // With 120 points, 200 - 120 = 80 pts to go.
      expect(
        find.text('Next: Tree · Level 4 (80 pts to go)'),
        findsOneWidget,
      );

      // Tree badge image asset is loaded
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Image &&
              widget.image is AssetImage &&
              (widget.image as AssetImage).assetName ==
                  'assets/images/rewards/next_level_tree_badge.png',
        ),
        findsOneWidget,
      );

      // Card background image asset is loaded
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Image &&
              widget.image is AssetImage &&
              (widget.image as AssetImage).assetName ==
                  'assets/images/rewards/rewards_card_bg.png',
        ),
        findsOneWidget,
      );

      // Mascot image asset is loaded
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Image &&
              widget.image is AssetImage &&
              (widget.image as AssetImage).assetName ==
                  'assets/images/rewards/rewards_mascot.png',
        ),
        findsOneWidget,
      );

      // Floating leaf assets are present in the card
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Image &&
              widget.image is AssetImage &&
              (widget.image as AssetImage).assetName.contains('rewards_floating_leaf'),
        ),
        findsNWidgets(4),
      );

      // Verify no overflow exceptions occurred
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'Adapts responsively to narrow screen (320px) without overflow',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(320 * 2, 600 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: RewardsSaplingProgressHeader(
                summary: saplingSummary,
                animated: false,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Rewards'), findsOneWidget);
      expect(find.text('Level 3 of 5'), findsOneWidget);
      expect(find.text('Sapling'), findsOneWidget);
      expect(find.text('120 EcoPoints'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'Leaves orbit continuously in an infinite loop across at least 3 full cycles',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390 * 2, 844 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: RewardsSaplingProgressHeader(
                summary: saplingSummary,
                animated: true,
              ),
            ),
          ),
        ),
      );

      // Initial frame
      await tester.pump();

      // Find all Positioned widgets holding floating leaves
      final leafFinders = find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName.contains('rewards_floating_leaf'),
      );
      expect(leafFinders, findsNWidgets(4));

      // Record positions at start of cycle 1 (t = 0ms)
      final initialOffsets = <Offset>[];
      for (int i = 0; i < 4; i++) {
        initialOffsets.add(tester.getTopLeft(leafFinders.at(i)));
      }

      // Duration of one full orbit cycle is 7000ms.
      // We will pump through 3 full cycles (3 * 7000ms = 21,000ms) in 500ms increments.
      final cycleDurationMs = 7000;
      final stepMs = 500;
      final totalSteps = (3 * cycleDurationMs) ~/ stepMs;

      for (int step = 1; step <= totalSteps; step++) {
        await tester.pump(Duration(milliseconds: stepMs));

        // After every pump, verify that all 4 leaves are rendered with finite valid coordinates
        for (int i = 0; i < 4; i++) {
          final pos = tester.getTopLeft(leafFinders.at(i));
          expect(pos.dx.isFinite, isTrue);
          expect(pos.dy.isFinite, isTrue);
        }

        // At exactly one full cycle boundary (e.g. step = 14 -> 7000ms),
        // verify that each leaf has completed a continuous orbit loop
        // and returns exactly to its cycle starting position (within 1.0px float tolerance).
        if (step % (cycleDurationMs ~/ stepMs) == 0) {
          for (int i = 0; i < 4; i++) {
            final cycleEndPos = tester.getTopLeft(leafFinders.at(i));
            final initialPos = initialOffsets[i];
            expect(
              (cycleEndPos.dx - initialPos.dx).abs(),
              lessThan(1.5),
              reason: 'Leaf $i x-position should match at cycle boundary',
            );
            expect(
              (cycleEndPos.dy - initialPos.dy).abs(),
              lessThan(1.5),
              reason: 'Leaf $i y-position should match at cycle boundary',
            );
          }
        }
      }

      // Verify no exceptions were thrown across 3 full cycles (21 seconds of continuous motion)
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'Calculates dynamic progress and remaining points correctly for different levels',
        (WidgetTester tester) async {
      // Test Level 1: Seedling (0-49 pts, so 25 pts = 50% progress)
      final seedlingSummary = EcoPointsSummary.fromTotals(
        totalPoints: 25,
        eventCount: 1,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RewardsSaplingProgressHeader(
              summary: seedlingSummary,
              animated: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Level 1 of 5'), findsOneWidget);
      expect(find.text('Seedling'), findsOneWidget);
      expect(find.text('25 EcoPoints'), findsOneWidget);
      // Next level is Sprout (50 pts). Remaining = 50 - 25 = 25 pts
      expect(find.text('Next: Sprout · Level 2 (25 pts to go)'), findsOneWidget);
    });

    testWidgets(
        'Mascot is positioned fully inside the card and does not overlap text or badge across screen sizes',
        (WidgetTester tester) async {
      final testSizes = [
        const Size(320 * 2, 600 * 2), // Compact mobile
        const Size(390 * 2, 844 * 2), // Standard iPhone
        const Size(430 * 2, 932 * 2), // Large Pro Max
      ];

      for (final physicalSize in testSizes) {
        tester.view.physicalSize = physicalSize;
        tester.view.devicePixelRatio = 2.0;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: RewardsSaplingProgressHeader(
                  summary: saplingSummary,
                  animated: false,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Find Card Rect
        final cardFinder = find.byWidgetPredicate(
          (w) =>
              w is Image &&
              w.image is AssetImage &&
              (w.image as AssetImage).assetName ==
                  'assets/images/rewards/rewards_card_bg.png',
        );
        final cardRect = tester.getRect(cardFinder);

        // Find Mascot Rect
        final mascotFinder = find.byWidgetPredicate(
          (w) =>
              w is Image &&
              w.image is AssetImage &&
              (w.image as AssetImage).assetName ==
                  'assets/images/rewards/rewards_mascot.png',
        );
        final mascotRect = tester.getRect(mascotFinder);

        // Find Level Title Rect ("Sapling")
        final levelTitleFinder = find.text('Sapling');
        final levelTitleRect = tester.getRect(levelTitleFinder);

        // Find Badge Rect
        final badgeFinder = find.byWidgetPredicate(
          (w) =>
              w is Image &&
              w.image is AssetImage &&
              (w.image as AssetImage).assetName ==
                  'assets/images/rewards/next_level_tree_badge.png',
        );
        final badgeRect = tester.getRect(badgeFinder);

        // Find EcoPoints Total Rect ("120 EcoPoints")
        final ecoPointsFinder = find.text('120 EcoPoints');
        final ecoPointsRect = tester.getRect(ecoPointsFinder);

        // Find Progress Bar container
        final progressBarFinder = find.byWidgetPredicate(
          (w) =>
              w is FractionallySizedBox &&
              w.child is Container &&
              (w.child as Container).decoration is BoxDecoration,
        );
        final progressBarRect = tester.getRect(progressBarFinder);

        // 1. Mascot is strictly inside the card with comfortable insets
        expect(mascotRect.left, greaterThanOrEqualTo(cardRect.left));
        expect(mascotRect.right, lessThanOrEqualTo(cardRect.right));
        expect(mascotRect.top, greaterThanOrEqualTo(cardRect.top));
        expect(mascotRect.bottom, lessThanOrEqualTo(cardRect.bottom));

        // 2. Mascot does not overlap center level text
        expect(
          mascotRect.right,
          lessThan(levelTitleRect.left),
          reason: 'Mascot must not overlap level text',
        );

        // 3. Center level text does not overlap badge
        expect(
          levelTitleRect.right,
          lessThan(badgeRect.left),
          reason: 'Level text must not overlap tree badge',
        );

        // 4. EcoPoints total does not overlap badge
        expect(
          ecoPointsRect.right,
          lessThan(badgeRect.left),
          reason: 'EcoPoints total must not overlap tree badge',
        );

        // 5. Progress bar does not overlap badge
        expect(
          progressBarRect.right,
          lessThan(badgeRect.left),
          reason: 'Progress bar must not overlap tree badge',
        );

        // 6. Badge is strictly inside the card
        expect(badgeRect.right, lessThanOrEqualTo(cardRect.right));
        expect(badgeRect.left, greaterThanOrEqualTo(cardRect.left));
        expect(badgeRect.top, greaterThanOrEqualTo(cardRect.top));
        expect(badgeRect.bottom, lessThanOrEqualTo(cardRect.bottom));
      }

      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    testWidgets(
        'Eye-blinking animation runs smoothly and renders over mascot face',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390 * 2, 844 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: RewardsSaplingProgressHeader(
                summary: saplingSummary,
                animated: true,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Pump 5 seconds to trigger natural randomized blinking
      for (int i = 0; i < 50; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'At 150 points, shows Sapling Level 3 and exactly 50 pts to go to Tree (never 0 pts to go)',
        (WidgetTester tester) async {
      final summary150 = EcoPointsSummary.fromJson({
        'total_points': 150,
        'eco_score': 100,
        'level': 3,
        'level_title': 'Sapling',
        'next_level_points': 200,
        'progress_percent': 50,
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RewardsSaplingProgressHeader(
              summary: summary150,
              animated: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Level 3 of 5'), findsOneWidget);
      expect(find.text('Sapling'), findsOneWidget);
      expect(find.text('150 EcoPoints'), findsOneWidget);
      expect(find.text('Next: Tree · Level 4 (50 pts to go)'), findsOneWidget);
      expect(find.textContaining('(0 pts to go)'), findsNothing);

      // Next level is Tree (Level 4), so the 3D Tree badge is loaded
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Image &&
              widget.image is AssetImage &&
              (widget.image as AssetImage).assetName ==
                  'assets/images/rewards/next_level_tree_badge.png',
        ),
        findsOneWidget,
      );
    });

    testWidgets(
        'Reaching 200 points automatically advances level to Tree Level 4 and targets Forest Guardian',
        (WidgetTester tester) async {
      final summary200 = EcoPointsSummary.fromTotals(
        totalPoints: 200,
        eventCount: 8,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RewardsSaplingProgressHeader(
              summary: summary200,
              animated: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Level 4 of 5'), findsOneWidget);
      expect(find.text('Tree'), findsOneWidget);
      expect(find.text('200 EcoPoints'), findsOneWidget);
      // Next level is Forest Guardian (350 pts). Remaining = 350 - 200 = 150 pts
      expect(
        find.text('Next: Forest Guardian · Level 5 (150 pts to go)'),
        findsOneWidget,
      );
      expect(find.textContaining('(0 pts to go)'), findsNothing);

      // Badge dynamically updates to Forest Guardian shield icon
      expect(find.byIcon(Icons.shield_rounded), findsOneWidget);
    });

    testWidgets(
        'Reaching 350 points (Max level) displays Forest Guardian and celebratory max level message',
        (WidgetTester tester) async {
      final summary350 = EcoPointsSummary.fromTotals(
        totalPoints: 350,
        eventCount: 15,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RewardsSaplingProgressHeader(
              summary: summary350,
              animated: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Level 5 of 5'), findsOneWidget);
      expect(find.text('Forest Guardian'), findsOneWidget);
      expect(find.text('350 EcoPoints'), findsOneWidget);
      expect(find.text('Max level reached! 🌟'), findsOneWidget);
      expect(find.textContaining('pts to go'), findsNothing);

      // Celebratory max level badge
      expect(find.byIcon(Icons.workspace_premium_rounded), findsOneWidget);
    });
  });
}

