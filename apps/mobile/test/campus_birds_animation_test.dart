import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ecocampus_mobile/core/theme/app_theme.dart';
import 'package:ecocampus_mobile/features/home/presentation/student_home_screen.dart';
import 'package:ecocampus_mobile/features/home/data/home_providers.dart';

void main() {
  group('Campus Header Animated Sky Birds Validation', () {
    testWidgets('Animated birds widget is rendered in the top campus header stack', (tester) async {
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

      // Find CustomPaint widgets that use _CampusSkyBirdsPainter
      final birdsCustomPaintFinder = find.byWidgetPredicate(
        (widget) => widget is CustomPaint && widget.painter.runtimeType.toString() == '_CampusSkyBirdsPainter',
      );
      expect(birdsCustomPaintFinder, findsOneWidget);

      final customPaint = tester.widget<CustomPaint>(birdsCustomPaintFinder);
      expect(customPaint.painter, isNotNull);
    });

    testWidgets('Birds fly continuously through multiple cycles without disruption', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [greetingProvider.overrideWithValue('Good afternoon')],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: StudentHomeScreen(onNavigateToReports: () {}),
          ),
        ),
      );
      // Wait for initial frame
      await tester.pump(const Duration(milliseconds: 100));

      final birdsFinder = find.byWidgetPredicate(
        (widget) => widget is CustomPaint && widget.painter.runtimeType.toString() == '_CampusSkyBirdsPainter',
      );
      expect(birdsFinder, findsOneWidget);

      CustomPaint customPaint = tester.widget<CustomPaint>(birdsFinder);
      dynamic painter = customPaint.painter;
      final initialProgress = painter.progress as double;

      // Flight controller duration is 14000ms (14.0s).
      // Verify that after 1 full cycle (14000ms), the progress seamlessly loops back
      for (int cycle = 1; cycle <= 3; cycle++) {
        // Quarter cycle (3.5s)
        await tester.pump(const Duration(milliseconds: 3500));
        customPaint = tester.widget<CustomPaint>(birdsFinder);
        painter = customPaint.painter;
        final quarterProgress = painter.progress as double;
        expect((quarterProgress - initialProgress).abs(), greaterThan(0.1), reason: 'Birds advance in flight');

        // Half cycle (3.5s)
        await tester.pump(const Duration(milliseconds: 3500));

        // Three-quarter cycle (3.5s)
        await tester.pump(const Duration(milliseconds: 3500));

        // Complete full 14.0s cycle
        await tester.pump(const Duration(milliseconds: 3500));
        customPaint = tester.widget<CustomPaint>(birdsFinder);
        painter = customPaint.painter;
        final endProgress = painter.progress as double;

        // At exactly one complete 14.0s cycle, progress loops seamlessly
        expect(endProgress, closeTo(initialProgress, 0.01), reason: 'Cycle $cycle loops seamlessly');
      }
    });

    testWidgets('Reduced motion preferences disable bird flight ticks safely', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [greetingProvider.overrideWithValue('Good afternoon')],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: MediaQuery(
              data: const MediaQueryData(disableAnimations: true),
              child: StudentHomeScreen(onNavigateToReports: () {}),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      final birdsFinder = find.byWidgetPredicate(
        (widget) => widget is CustomPaint && widget.painter.runtimeType.toString() == '_CampusSkyBirdsPainter',
      );
      expect(birdsFinder, findsOneWidget);

      final customPaint = tester.widget<CustomPaint>(birdsFinder);
      dynamic painter = customPaint.painter;
      expect(painter.progress, equals(0.0), reason: 'Static resting pose when animations disabled');
    });
  });
}
