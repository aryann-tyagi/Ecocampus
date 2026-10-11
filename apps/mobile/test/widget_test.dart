import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ecocampus_mobile/main.dart';

void main() {
  testWidgets('EcoCampus mobile app smoke and navigation test', (WidgetTester tester) async {
    // Build our app and trigger frames
    await tester.pumpWidget(const ProviderScope(child: EcoCampusApp()));
    await tester.pump(const Duration(milliseconds: 200));

    // Verify Student Home elements
    expect(find.text('Good afternoon'), findsOneWidget);
    expect(find.text('Report an issue'), findsOneWidget);
    expect(find.text('Sprig'), findsOneWidget);
    expect(find.text('Nearby issues'), findsOneWidget);

    // Switch to Map tab
    await tester.tap(find.text('Map'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Block B'), findsWidgets);

    // Switch to Rewards tab
    await tester.tap(find.text('Rewards'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Level 5 of 20'), findsOneWidget);
    expect(find.text('Achievements'), findsOneWidget);
    expect(find.text('Leaderboard'), findsOneWidget);

    // Switch to Reports tab
    await tester.tap(find.text('Reports'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('My Reports'), findsOneWidget);
  });
}
