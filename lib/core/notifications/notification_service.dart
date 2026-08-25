import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import '../constants/app_constants.dart';

/// Top-level background message handler executed in an isolated Dart environment
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {}
  dev.log(
    '🌙 [FCM:Background] Received message in background/terminated state: ID=${message.messageId} Data=${message.data}',
    name: 'NotificationService',
  );
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  String? _fcmToken;
  String? _currentUserId;
  String _serverUrl = AppConstants.defaultServerUrl;

  String? get fcmToken => _fcmToken;

  /// High importance notification channel for Android heads-up alerts
  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'friday_chat_messages',
    'Friday Chat Messages',
    description: 'High importance channel for real-time messages and incoming call notifications.',
    importance: Importance.max,
    priority: Priority.high,
    playSound: true,
    enableVibration: true,
  );

  void Function(Map<String, dynamic> data)? onNotificationClicked;

  /// Initializes FCM, requests permissions, sets up local notifications and backend sync
  Future<void> initialize({
    String? currentUserId,
    String? serverUrl,
    void Function(String token)? onTokenRefreshCallback,
    void Function(Map<String, dynamic> data)? onNotificationTap,
  }) async {
    _currentUserId = currentUserId;
    if (serverUrl != null) _serverUrl = serverUrl;
    onNotificationClicked = onNotificationTap;

    dev.log('[FCM] Initializing Notification Service...', name: 'NotificationService');

    // 1. Request notification permissions (iOS & Android 13+)
    final settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
      criticalAlert: true,
    );

    dev.log(
      '[FCM] User notification authorization status: ${settings.authorizationStatus}',
      name: 'NotificationService',
    );

    // 2. Configure Android & iOS local notification settings
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        if (response.payload != null && response.payload!.isNotEmpty) {
          try {
            final Map<String, dynamic> data = jsonDecode(response.payload!);
            onNotificationClicked?.call(data);
          } catch (e) {
            dev.log('[FCM] Error decoding notification tap payload: $e', name: 'NotificationService');
          }
        }
      },
    );

    // 3. Create the Android notification channel
    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    await _fcm.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // 4. Fetch FCM Device Registration Token & upload to Go server
    await fetchDeviceToken();
    if (_currentUserId != null && _fcmToken != null) {
      await syncDeviceTokenWithBackend(userId: _currentUserId!);
    }

    // 5. Setup Token Refresh Listener
    _fcm.onTokenRefresh.listen((newToken) async {
      _fcmToken = newToken;
      dev.log('🔄 [FCM] Device Token refreshed: $newToken', name: 'NotificationService');
      onTokenRefreshCallback?.call(newToken);

      if (_currentUserId != null) {
        await syncDeviceTokenWithBackend(userId: _currentUserId!);
      }
    });

    // 6. Handle App States

    // Terminated State
    final initialMessage = await _fcm.getInitialMessage();
    if (initialMessage != null) {
      dev.log('🚀 [FCM:Terminated] App launched from notification: ${initialMessage.data}',
          name: 'NotificationService');
      onNotificationClicked?.call(initialMessage.data);
    }

    // Background State
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      dev.log('📱 [FCM:Resume] App opened from background: ${message.data}', name: 'NotificationService');
      onNotificationClicked?.call(message.data);
    });

    // Foreground State
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      dev.log('🔔 [FCM:Foreground] Notification: ${message.notification?.title}',
          name: 'NotificationService');

      final title = message.notification?.title ?? message.data['senderName'] ?? 'New Message';
      final body = message.notification?.body ?? message.data['content'] ?? 'You received a message.';

      showHeadsUpNotification(
        title: title,
        body: body,
        payload: message.data,
      );
    });
  }

  /// Fetches unique FCM Device Token
  Future<String?> fetchDeviceToken() async {
    try {
      _fcmToken = await _fcm.getToken();
      dev.log('🔑 [FCM] Device Registration Token: $_fcmToken', name: 'NotificationService');
      return _fcmToken;
    } catch (e) {
      dev.log('⚠️ [FCM] Could not retrieve FCM token: $e', name: 'NotificationService');
      return null;
    }
  }

  /// 📲 Uploads and updates the user's current FCM Device Token on the Go backend server
  Future<void> syncDeviceTokenWithBackend({
    required String userId,
    String? serverUrl,
    String deviceType = 'android',
  }) async {
    _currentUserId = userId;
    final url = serverUrl ?? _serverUrl;

    if (_fcmToken == null) {
      await fetchDeviceToken();
    }
    if (_fcmToken == null) return;

    final uri = Uri.parse('$url/api/v1/user/device-token');
    dev.log('[FCM] Uploading device token for $userId to $uri...', name: 'NotificationService');

    try {
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': userId,
          'token': _fcmToken,
          'deviceType': deviceType,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        dev.log('✅ [FCM] Device token registered on Go backend for $userId', name: 'NotificationService');
      } else {
        dev.log('⚠️ [FCM] Failed to register device token: ${response.statusCode} - ${response.body}',
            name: 'NotificationService');
      }
    } catch (e) {
      dev.log('⚠️ [FCM] Network notice uploading token (Server offline/local): $e',
          name: 'NotificationService');
    }
  }

  /// 🚪 Deletes the device token from the backend when user logs out
  Future<void> deleteDeviceTokenFromBackend({String? serverUrl}) async {
    if (_fcmToken == null) return;
    final url = serverUrl ?? _serverUrl;
    final uri = Uri.parse('$url/api/v1/user/device-token');

    try {
      await http.delete(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'token': _fcmToken}),
      );
      dev.log('✅ [FCM] Device token removed from Go backend on logout', name: 'NotificationService');
    } catch (e) {
      dev.log('⚠️ [FCM] Error removing device token: $e', name: 'NotificationService');
    }
  }

  /// Displays an immediate high-priority heads-up local notification banner
  Future<void> showHeadsUpNotification({
    required String title,
    required String body,
    Map<String, dynamic>? payload,
    int? notificationId,
  }) async {
    final id = notificationId ?? DateTime.now().millisecondsSinceEpoch.remainder(100000);

    final androidDetails = AndroidNotificationDetails(
      _channel.id,
      _channel.name,
      channelDescription: _channel.description,
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
      color: const Color(0xFF00A884),
      styleInformation: BigTextStyleInformation(body),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      id,
      title,
      body,
      notificationDetails,
      payload: payload != null ? jsonEncode(payload) : null,
    );
  }

  Future<void> cancelNotification(int id) async {
    await _localNotifications.cancel(id);
  }

  Future<void> cancelAll() async {
    await _localNotifications.cancelAll();
  }
}
