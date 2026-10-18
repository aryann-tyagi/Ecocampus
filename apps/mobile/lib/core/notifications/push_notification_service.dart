import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../features/reports_tracking/presentation/report_detail_screen.dart';

/// Top-level background message handler required by FCM.
/// Must be annotated with `@pragma('vm:entry-point')`.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
  } catch (e) {
    debugPrint('[PushNotificationService] Background Firebase initialization error: $e');
  }
  debugPrint('[PushNotificationService] Handling background message: ${message.messageId} - ${message.data}');
}

class PushNotificationService {
  PushNotificationService._internal();
  static final PushNotificationService instance = PushNotificationService._internal();

  /// Global Navigator key for notification-tap routing across the application.
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;
  bool _firebaseAvailable = false;
  bool _permissionGranted = false;
  String? _currentRegisteredToken;
  String? _currentRegisteredUserId;

  /// High-importance Android notification channel for report updates.
  static const AndroidNotificationChannel reportUpdatesChannel = AndroidNotificationChannel(
    'report_updates_channel',
    'Report Updates',
    description: 'Urgent and important campus issue notifications',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );

  bool get isFirebaseAvailable => _firebaseAvailable;
  bool get isPermissionGranted => _permissionGranted;
  String? get currentToken => _currentRegisteredToken;

  /// Initialize push notification services, local notification channel, and FCM handlers.
  Future<void> initialize() async {
    if (_isInitialized) return;

    // 1. Initialize local notification display plugin
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);

    try {
      await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          final payload = response.payload;
          if (payload != null && payload.isNotEmpty) {
            navigateToReport(payload);
          }
        },
      );

      // Create Android High-Importance Notification Channel
      final androidPlatform = _localNotifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await androidPlatform?.createNotificationChannel(reportUpdatesChannel);
    } catch (e) {
      debugPrint('[PushNotificationService] Local notifications initialization failed: $e');
    }

    // 2. Initialize Firebase safely
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      _firebaseAvailable = true;
      debugPrint('[PushNotificationService] Firebase initialized successfully.');
    } catch (e) {
      _firebaseAvailable = false;
      debugPrint(
        '[PushNotificationService] Firebase not initialized ($e). '
        'If google-services.json is not yet added, visible tray pushes are deferred. '
        'In-app notification list and Supabase triggers remain fully functional.',
      );
    }

    // 3. Setup FCM handlers if Firebase is available
    if (_firebaseAvailable) {
      try {
        FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

        // Configure foreground presentation options
        await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );

        // A. Listen to foreground FCM messages
        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          _handleForegroundMessage(message);
        });

        // B. Listen to notification-tap events when app is backgrounded
        FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
          _handleMessageTap(message);
        });

        // C. Check if app was opened from terminated state via notification tap
        final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
        if (initialMessage != null) {
          // Delay briefly to allow navigator hierarchy to mount
          Future.delayed(const Duration(milliseconds: 500), () {
            _handleMessageTap(initialMessage);
          });
        }

        // D. Listen to token refreshes
        // ignore: deprecated_member_use
        FirebaseMessaging.instance.onTokenRefresh.listen((String newToken) {
          _currentRegisteredToken = newToken;
          if (_currentRegisteredUserId != null) {
            syncDeviceToken(_currentRegisteredUserId!);
          }
        });
      } catch (e) {
        debugPrint('[PushNotificationService] FCM listener configuration error: $e');
      }
    }

    _isInitialized = true;
  }

  /// Explicitly requests notification permission from the user (Android 13+ / iOS).
  Future<bool> requestPermission() async {
    // Request Android notification runtime permission
    try {
      final androidPlatform = _localNotifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final localGranted = await androidPlatform?.requestNotificationsPermission();
      if (localGranted != null) {
        _permissionGranted = localGranted;
      }
    } catch (e) {
      debugPrint('[PushNotificationService] Error requesting local notification permission: $e');
    }

    if (_firebaseAvailable) {
      try {
        final settings = await FirebaseMessaging.instance.requestPermission(
          alert: true,
          announcement: false,
          badge: true,
          carPlay: false,
          criticalAlert: false,
          provisional: false,
          sound: true,
        );

        _permissionGranted = settings.authorizationStatus == AuthorizationStatus.authorized ||
            settings.authorizationStatus == AuthorizationStatus.provisional;
      } catch (e) {
        debugPrint('[PushNotificationService] Error requesting FCM permission: $e');
      }
    }

    return _permissionGranted;
  }

  /// Registers or refreshes the current device's FCM token in Supabase for the signed-in user.
  Future<void> syncDeviceToken(String userId) async {
    _currentRegisteredUserId = userId;

    if (!_firebaseAvailable) {
      debugPrint('[PushNotificationService] Cannot sync token: Firebase is not available.');
      return;
    }

    try {
      // ignore: deprecated_member_use
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) {
        debugPrint('[PushNotificationService] FCM token is null or empty.');
        return;
      }

      _currentRegisteredToken = token;

      final client = Supabase.instance.client;
      if (client.auth.currentUser == null) {
        debugPrint('[PushNotificationService] No authenticated Supabase user to associate token with.');
        return;
      }

      final res = await client.rpc('register_device_token', params: {
        'p_fcm_token': token,
        'p_platform': 'android',
        'p_device_name': 'Android Device',
      });

      debugPrint('[PushNotificationService] Device token registered in Supabase: $res');
    } catch (e) {
      debugPrint('[PushNotificationService] Error syncing device token: $e');
    }
  }

  /// Unregisters the current device token from Supabase upon logout / account switch.
  Future<void> unregisterCurrentDeviceToken() async {
    final token = _currentRegisteredToken;
    _currentRegisteredUserId = null;

    if (token == null || token.isEmpty) return;

    try {
      final client = Supabase.instance.client;
      if (client.auth.currentUser != null) {
        await client.rpc('unregister_device_token', params: {
          'p_fcm_token': token,
        });
        debugPrint('[PushNotificationService] Device token unregistered from Supabase.');
      }
    } catch (e) {
      debugPrint('[PushNotificationService] Error unregistering token: $e');
    }
  }

  /// Visible presentation of foreground notifications using high-importance channel.
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    debugPrint('[PushNotificationService] Foreground message received: ${message.messageId}');

    final notification = message.notification;
    final data = message.data;

    final title = notification?.title ?? data['title'] ?? 'EcoCampus Notification';
    final body = notification?.body ?? data['message'] ?? data['body'] ?? '';
    final reportId = data['report_id'] ?? data['reportId'];

    // Avoid displaying an empty notification
    if (title.isEmpty && body.isEmpty) return;

    final androidDetails = AndroidNotificationDetails(
      reportUpdatesChannel.id,
      reportUpdatesChannel.name,
      channelDescription: reportUpdatesChannel.description,
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      playSound: true,
      enableVibration: true,
    );

    final notificationDetails = NotificationDetails(android: androidDetails);

    final notificationId = (message.messageId?.hashCode ?? DateTime.now().millisecondsSinceEpoch) & 0x7FFFFFFF;

    try {
      await _localNotifications.show(
        notificationId,
        title,
        body,
        notificationDetails,
        payload: reportId,
      );
    } catch (e) {
      debugPrint('[PushNotificationService] Error displaying foreground notification: $e');
    }
  }

  /// Handles user tapping on a notification in the system notification tray.
  void _handleMessageTap(RemoteMessage message) {
    debugPrint('[PushNotificationService] Notification tapped: ${message.data}');
    final reportId = message.data['report_id'] ?? message.data['reportId'];
    if (reportId != null && reportId.toString().isNotEmpty) {
      navigateToReport(reportId.toString());
    }
  }

  /// Navigates the user directly to the relevant report details screen.
  static void navigateToReport(String reportId) {
    final state = navigatorKey.currentState;
    if (state == null) {
      debugPrint('[PushNotificationService] Cannot navigate: NavigatorState is null.');
      return;
    }

    state.push(
      MaterialPageRoute(
        builder: (_) => ReportDetailScreen(reportId: reportId),
      ),
    );
  }
}
