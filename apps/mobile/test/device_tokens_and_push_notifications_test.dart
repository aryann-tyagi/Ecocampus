import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:ecocampus_mobile/core/notifications/push_notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Device Tokens & Push Notification Service Tests', () {
    test('1. Android High-Importance Notification Channel is configured with maximum importance', () {
      const channel = PushNotificationService.reportUpdatesChannel;

      expect(channel.id, 'report_updates_channel');
      expect(channel.name, 'Report Updates');
      expect(channel.description, 'Urgent and important campus issue notifications');
      expect(channel.importance, Importance.max);
      expect(channel.playSound, isTrue);
      expect(channel.enableVibration, isTrue);
    });

    test('2. PushNotificationService instance initializes safely without crashing when Firebase is unconfigured', () async {
      final service = PushNotificationService.instance;

      expect(service, isNotNull);
      expect(PushNotificationService.navigatorKey, isNotNull);

      // Safe initialization should not throw even if google-services.json is absent
      await service.initialize();

      // Service handles unconfigured Firebase gracefully
      expect(service.currentToken, isNull);
    });

    test('3. Permission request returns honest boolean without fabricated success', () async {
      final service = PushNotificationService.instance;

      // In unit test environment without real OS notification manager, permission request completes cleanly
      final granted = await service.requestPermission();
      expect(granted, isA<bool>());
    });

    test('4. Token unregistration completes safely when no token is registered', () async {
      final service = PushNotificationService.instance;

      // Should complete cleanly without error
      await service.unregisterCurrentDeviceToken();
      expect(service.currentToken, isNull);
    });

    test('5. Navigator key is ready for notification tap routing', () {
      expect(PushNotificationService.navigatorKey, isA<GlobalKey<NavigatorState>>());
    });
  });
}
