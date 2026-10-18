import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ecocampus_mobile/features/notifications/domain/notification_model.dart';
import 'package:ecocampus_mobile/features/notifications/data/notifications_provider.dart';
import 'package:ecocampus_mobile/features/notifications/presentation/widgets/notification_bell_button.dart';
import 'package:ecocampus_mobile/features/notifications/presentation/notifications_screen.dart';

void main() {
  group('In-App Notification Model Tests', () {
    test('1. Parses all event types correctly from Supabase JSON', () {
      final json = {
        'id': 'notif-101',
        'user_id': 'user-student-1',
        'report_id': 'rep-202',
        'status_event_id': 'evt-303',
        'event_type': 'report_resolved',
        'title': 'Issue Resolved',
        'message': 'Your report for "Broken water pipe" has been resolved.',
        'is_read': false,
        'read_at': null,
        'created_at': DateTime.now().subtract(const Duration(minutes: 5)).toIso8601String(),
      };

      final notif = NotificationModel.fromJson(json);

      expect(notif.id, 'notif-101');
      expect(notif.userId, 'user-student-1');
      expect(notif.reportId, 'rep-202');
      expect(notif.statusEventId, 'evt-303');
      expect(notif.eventType, NotificationEventType.reportResolved);
      expect(notif.title, 'Issue Resolved');
      expect(notif.message, contains('Broken water pipe'));
      expect(notif.isRead, isFalse);
      expect(notif.readAt, isNull);
      expect(notif.iconData, Icons.check_circle_rounded);
      expect(notif.iconColor, const Color(0xFF1EA05A));
    });

    test('2. Maps event type strings to enum and icons symmetrically', () {
      final cases = [
        ('report_submitted', NotificationEventType.reportSubmitted, Icons.send_rounded),
        ('report_assigned', NotificationEventType.reportAssigned, Icons.assignment_ind_rounded),
        ('report_in_progress', NotificationEventType.reportInProgress, Icons.construction_rounded),
        ('report_resolved', NotificationEventType.reportResolved, Icons.check_circle_rounded),
        ('report_rejected', NotificationEventType.reportRejected, Icons.cancel_rounded),
        ('report_duplicate', NotificationEventType.reportDuplicate, Icons.copy_rounded),
        ('admin_new_report', NotificationEventType.adminNewReport, Icons.campaign_rounded),
        ('staff_issue_assigned', NotificationEventType.staffIssueAssigned, Icons.build_circle_rounded),
      ];

      for (final (dbVal, expectedEnum, expectedIcon) in cases) {
        final parsed = NotificationEventType.fromDbValue(dbVal);
        expect(parsed, expectedEnum);
        expect(parsed.toDbValue(), dbVal);

        final model = NotificationModel(
          id: 'test',
          userId: 'u',
          reportId: 'r',
          eventType: parsed,
          title: 'T',
          message: 'M',
          createdAt: DateTime.now(),
        );
        expect(model.iconData, expectedIcon);
      }
    });

    test('3. Relative time formatting calculates appropriate labels', () {
      final now = DateTime.now();

      final justNow = NotificationModel(
        id: '1',
        userId: 'u',
        reportId: 'r',
        eventType: NotificationEventType.reportSubmitted,
        title: 'T',
        message: 'M',
        createdAt: now.subtract(const Duration(seconds: 15)),
      );
      expect(justNow.relativeTime, 'Just now');

      final minutesAgo = NotificationModel(
        id: '2',
        userId: 'u',
        reportId: 'r',
        eventType: NotificationEventType.reportSubmitted,
        title: 'T',
        message: 'M',
        createdAt: now.subtract(const Duration(minutes: 25)),
      );
      expect(minutesAgo.relativeTime, '25 mins ago');

      final hoursAgo = NotificationModel(
        id: '3',
        userId: 'u',
        reportId: 'r',
        eventType: NotificationEventType.reportSubmitted,
        title: 'T',
        message: 'M',
        createdAt: now.subtract(const Duration(hours: 4)),
      );
      expect(hoursAgo.relativeTime, '4 hours ago');
    });
  });

  group('UnreadNotificationCountNotifier Unit Tests', () {
    test('4. Correctly manages decrement, reset, and setCount bounds', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(unreadNotificationCountProvider.notifier);
      notifier.setCount(5);
      expect(container.read(unreadNotificationCountProvider).value, 5);

      notifier.decrement();
      expect(container.read(unreadNotificationCountProvider).value, 4);

      notifier.reset();
      expect(container.read(unreadNotificationCountProvider).value, 0);

      // Decrementing at 0 stays at 0
      notifier.decrement();
      expect(container.read(unreadNotificationCountProvider).value, 0);

      // Negative values clamped to 0
      notifier.setCount(-3);
      expect(container.read(unreadNotificationCountProvider).value, 0);
    });
  });

  group('NotificationBellButton Widget Tests', () {
    testWidgets('5. Renders bell button without badge when unread count is 0', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            unreadNotificationCountProvider.overrideWith(() => MockUnreadCountNotifier(0)),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: NotificationBellButton(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.notifications_outlined), findsOneWidget);
      expect(find.text('0'), findsNothing);
    });

    testWidgets('6. Renders badge with count when unread items exist', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            unreadNotificationCountProvider.overrideWith(() => MockUnreadCountNotifier(4)),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: NotificationBellButton(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.notifications_outlined), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
    });

    testWidgets('7. Displays 9+ when unread count exceeds 9', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            unreadNotificationCountProvider.overrideWith(() => MockUnreadCountNotifier(15)),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: NotificationBellButton(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('9+'), findsOneWidget);
    });
  });

  group('NotificationsScreen Widget Tests', () {
    testWidgets('8. Displays empty state "All Caught Up!" when list is empty', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            notificationsListProvider.overrideWith(() => MockNotificationsListNotifier([])),
            unreadNotificationCountProvider.overrideWith(() => MockUnreadCountNotifier(0)),
          ],
          child: const MaterialApp(
            home: NotificationsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('All Caught Up!'), findsOneWidget);
      expect(find.textContaining("You don't have any notifications right now"), findsOneWidget);
      expect(find.text('Mark all read'), findsNothing);
    });

    testWidgets('9. Renders notifications list with titles, messages, and mark all read button', (tester) async {
      final items = [
        NotificationModel(
          id: 'n-1',
          userId: 'u-1',
          reportId: 'rep-1',
          eventType: NotificationEventType.reportSubmitted,
          title: 'Report Submitted',
          message: 'Your report for "Broken Light" was received.',
          isRead: false,
          createdAt: DateTime.now().subtract(const Duration(minutes: 10)),
        ),
        NotificationModel(
          id: 'n-2',
          userId: 'u-1',
          reportId: 'rep-2',
          eventType: NotificationEventType.reportResolved,
          title: 'Issue Resolved',
          message: 'Light fixture replaced with LED.',
          isRead: true,
          createdAt: DateTime.now().subtract(const Duration(hours: 1)),
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            notificationsListProvider.overrideWith(() => MockNotificationsListNotifier(items)),
            unreadNotificationCountProvider.overrideWith(() => MockUnreadCountNotifier(1)),
          ],
          child: const MaterialApp(
            home: NotificationsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('Report Submitted'), findsOneWidget);
      expect(find.text('Issue Resolved'), findsOneWidget);
      expect(find.text('Mark all read'), findsOneWidget);
      expect(find.text('Your report for "Broken Light" was received.'), findsOneWidget);
    });
  });
}

class MockUnreadCountNotifier extends UnreadNotificationCountNotifier {
  final int initialCount;
  MockUnreadCountNotifier(this.initialCount);

  @override
  Future<int> build() async => initialCount;
}

class MockNotificationsListNotifier extends NotificationsListNotifier {
  final List<NotificationModel> initialList;
  MockNotificationsListNotifier(this.initialList);

  @override
  Future<List<NotificationModel>> build() async => initialList;
}
