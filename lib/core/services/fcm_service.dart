import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:kasby/core/services/notification_navigation_service.dart';
import 'package:kasby/core/services/supabase_service.dart';
import 'notification_service.dart';
import 'notification_preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kasby/core/localization/content_localization_service.dart';
import 'package:kasby/core/utils/locale_helper.dart';
import 'package:kasby/routes/app_routes.dart';
import 'package:kasby/core/utils/safe_getx.dart';
import '../../firebase_options.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  SafeGetx.debugTrace(
    className: 'FCMService',
    method: 'firebaseMessagingBackgroundHandler',
    feature: 'Core',
    status: 'INFO',
    params: {'messageId': message.messageId ?? 'unknown'},
  );
}

class FCMService extends GetxService {
  static FCMService get to => Get.find();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  final RxString fcmToken = ''.obs;
  final RxString lastOtpCode = ''.obs;
  final RxBool isNotificationsEnabled = true.obs;
  StreamSubscription<String>? _tokenRefreshSubscription;
  StreamSubscription<RemoteMessage>? _foregroundMessageSubscription;
  StreamSubscription<RemoteMessage>? _messageOpenedAppSubscription;

  Future<FCMService> init() async {
    final stopwatch = Stopwatch()..start();
    SafeGetx.debugTrace(
      className: 'FCMService',
      method: 'init',
      feature: 'Core',
      status: 'INFO',
    );
    await _setupLocalNotifications();
    // Only setup FCM if enabled
    final prefs = await SharedPreferences.getInstance();
    isNotificationsEnabled.value =
        prefs.getBool('notifications_enabled') ?? true;

    if (isNotificationsEnabled.value) {
      unawaited(_setupFCM());
      unawaited(_handleColdStartMessage());
    }
    SafeGetx.debugTrace(
      className: 'FCMService',
      method: 'init',
      feature: 'Core',
      status: 'SUCCESS',
      params: {'notificationsEnabled': isNotificationsEnabled.value},
      durationMs: stopwatch.elapsedMilliseconds,
    );
    return this;
  }

  Future<void> _handleColdStartMessage() async {
    final initialMessage = await _fcm.getInitialMessage();
    if (initialMessage != null) {
      SafeGetx.debugTrace(
        className: 'FCMService',
        method: '_handleColdStartMessage',
        feature: 'Core',
        status: 'INFO',
        params: {'messageId': initialMessage.messageId ?? 'unknown'},
      );
      _handleOtpFromMessage(initialMessage);
      await NotificationNavigationService.navigateFromPayload(
        initialMessage.data,
        fromUserTap: true,
      );
    }
  }

  Future<void> _setupLocalNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: DarwinInitializationSettings(),
        );

    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (details) {
        SafeGetx.debugTrace(
          className: 'FCMService',
          method: '_setupLocalNotifications',
          feature: 'Core',
          status: 'INFO',
          message: 'Local notification tapped',
        );
        NotificationNavigationService.navigateFromLocalPayload(details.payload);
      },
    );

    // Create high importance channel
    final channelName = await LocaleHelper.translate('fcm_channel_name');
    final channelDescription = await LocaleHelper.translate(
      'fcm_channel_description',
    );

    final AndroidNotificationChannel channel = AndroidNotificationChannel(
      'high_importance_channel',
      channelName,
      description: channelDescription,
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);
  }

  Future<void> _setupFCM() async {
    try {
      // Request permissions
      NotificationSettings settings = await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        SafeGetx.debugTrace(
          className: 'FCMService',
          method: '_setupFCM',
          feature: 'Core',
          status: 'SUCCESS',
          message: 'User granted permission',
        );

        if (!await _waitForApnsToken()) {
          return;
        }

        // An APNs token must be available before FCM registration on iOS.
        try {
          String? token = await _fcm.getToken();
          if (token != null) {
            fcmToken.value = token;
            SafeGetx.debugTrace(
              className: 'FCMService',
              method: '_setupFCM',
              feature: 'Core',
              status: 'SUCCESS',
              params: {'tokenPresent': true},
            );
            await syncTokenToServer(token);
          }
        } catch (e, stack) {
          SafeGetx.debugTrace(
            className: 'FCMService',
            method: '_setupFCM',
            feature: 'Core',
            status: 'WARN',
            message: 'Failed to get FCM token (e.g. on iOS Simulator)',
            error: e,
            stackTrace: stack,
          );
        }

        _registerMessageListeners();
      } else {
        SafeGetx.debugTrace(
          className: 'FCMService',
          method: '_setupFCM',
          feature: 'Core',
          status: 'WARN',
          message: 'User declined notification permission',
        );
      }
    } catch (e, stack) {
      SafeGetx.debugTrace(
        className: 'FCMService',
        method: '_setupFCM',
        feature: 'Core',
        status: 'WARN',
        message: 'Error during FCM setup',
        error: e,
        stackTrace: stack,
      );
    }
  }

  /// On Apple platforms Firebase Messaging needs the APNs token before it can
  /// create an FCM token. A physical device obtains this asynchronously after
  /// notification permission and signed push capability are in place.
  Future<bool> _waitForApnsToken() async {
    if (kIsWeb || !GetPlatform.isIOS) return true;

    const timeout = Duration(seconds: 10);
    const retryInterval = Duration(milliseconds: 250);
    final stopwatch = Stopwatch()..start();

    while (stopwatch.elapsed < timeout) {
      final apnsToken = await _fcm.getAPNSToken();
      if (apnsToken != null && apnsToken.isNotEmpty) {
        return true;
      }
      await Future<void>.delayed(retryInterval);
    }

    SafeGetx.debugTrace(
      className: 'FCMService',
      method: '_waitForApnsToken',
      feature: 'Core',
      status: 'WARN',
      message:
          'APNs token was not available. Verify push signing and test on a physical iPhone.',
    );
    return false;
  }

  void _registerMessageListeners() {
    _tokenRefreshSubscription ??= _fcm.onTokenRefresh.listen((newToken) {
      fcmToken.value = newToken;
      unawaited(syncTokenToServer(newToken));
    });

    _foregroundMessageSubscription ??=
        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          SafeGetx.debugTrace(
            className: 'FCMService',
            method: 'onMessage',
            feature: 'Core',
            status: 'INFO',
            params: {'title': message.notification?.title ?? 'none'},
          );
          _handleOtpFromMessage(message);
          NotificationService().playNotificationSound();
          _showLocalNotification(message);
        });

    _messageOpenedAppSubscription ??=
        FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
          _handleOtpFromMessage(message);
          unawaited(
            NotificationNavigationService.navigateFromPayload(
              message.data,
              fromUserTap: true,
            ),
          );
        });
  }

  Future<void> setNotificationsEnabled(bool enabled) async {
    isNotificationsEnabled.value = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', enabled);

    if (enabled) {
      SafeGetx.debugTrace(
        className: 'FCMService',
        method: 'setNotificationsEnabled',
        feature: 'Core',
        status: 'INFO',
        params: {'enabled': enabled},
      );
      await _setupFCM();
    } else {
      SafeGetx.debugTrace(
        className: 'FCMService',
        method: 'setNotificationsEnabled',
        feature: 'Core',
        status: 'INFO',
        message: 'Disabling notifications',
      );
      await _fcm.deleteToken();
      fcmToken.value = '';
      // Also clear on server
      await _clearTokenOnServer();
    }
  }

  Future<void> _clearTokenOnServer() async {
    try {
      if (SupabaseService.isLoggedIn) {
        await SupabaseService.client.rpc('fn_clear_device_token');
        SafeGetx.debugTrace(
          className: 'FCMService',
          method: '_clearTokenOnServer',
          feature: 'Core',
          status: 'SUCCESS',
        );
      }
    } catch (e, stack) {
      SafeGetx.debugTrace(
        className: 'FCMService',
        method: '_clearTokenOnServer',
        feature: 'Core',
        status: 'ERROR',
        error: e,
        stackTrace: stack,
      );
    }
  }

  /// On-demand trigger to synchronize current FCM token upon authentication / signup.
  Future<void> syncCurrentToken() async {
    try {
      if (!SupabaseService.isLoggedIn) return;
      String? token = fcmToken.value;
      if (token.isEmpty) {
        token = await _fcm.getToken();
        if (token != null && token.isNotEmpty) {
          fcmToken.value = token;
        }
      }
      if (token != null && token.isNotEmpty) {
        await syncTokenToServer(token);
      }
    } catch (e, stack) {
      SafeGetx.debugTrace(
        className: 'FCMService',
        method: 'syncCurrentToken',
        feature: 'Core',
        status: 'ERROR',
        error: e,
        stackTrace: stack,
      );
    }
  }

  /// Public method to clear token disassociations on logout.
  Future<void> clearTokenOnLogout() async {
    await _clearTokenOnServer();
    fcmToken.value = '';
  }

  void _showLocalNotification(RemoteMessage message) async {
    RemoteNotification? notification = message.notification;

    if (notification != null && !kIsWeb) {
      final category = message.data['category'] as String?;
      final entityType = message.data['entity_type'] as String?;
      final type = message.data['type'] as String?;
      final allowed =
          await NotificationPreferencesService.shouldDeliverNotification(
            category: category,
            entityType: entityType,
            notificationType: type,
          );
      if (!allowed) return;

      final title = ContentLocalizationService.resolve(
        message.data['title_key'] as String? ?? notification.title,
      );
      final body = ContentLocalizationService.resolve(
        message.data['message_key'] as String? ?? notification.body,
      );
      final resolvedTitle = title.isNotEmpty
          ? title
          : ContentLocalizationService.resolve(notification.title);
      final resolvedBody = body.isNotEmpty
          ? body
          : ContentLocalizationService.resolve(notification.body);

      final channelName = await LocaleHelper.translate('fcm_channel_name');
      final channelDescription = await LocaleHelper.translate(
        'fcm_channel_description',
      );

      _localNotifications.show(
        notification.hashCode,
        resolvedTitle,
        resolvedBody,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'high_importance_channel',
            channelName,
            channelDescription: channelDescription,
            importance: Importance.max,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: const DarwinNotificationDetails(),
        ),
        payload: jsonEncode(message.data),
      );
    }
  }

  void _handleOtpFromMessage(RemoteMessage message) {
    if (message.data['type'] == 'otp_verification') {
      final otp = message.data['otp_code'];
      if (otp != null) {
        lastOtpCode.value = otp;
        SafeGetx.debugTrace(
          className: 'FCMService',
          method: '_handleOtpFromMessage',
          feature: 'Core',
          status: 'INFO',
          message: 'OTP received (redacted)',
        );
      }
    }
  }

  Future<void> syncTokenToServer(String token) async {
    try {
      if (SupabaseService.client.auth.currentUser != null) {
        await SupabaseService.client.rpc(
          'fn_register_device_token',
          params: {
            'p_token': token,
            'p_platform': GetPlatform.isIOS ? 'ios' : 'android',
            'p_app_type': 'user',
          },
        );
        SafeGetx.debugTrace(
          className: 'FCMService',
          method: 'syncTokenToServer',
          feature: 'Core',
          status: 'SUCCESS',
        );
      }
    } catch (e, stack) {
      SafeGetx.debugTrace(
        className: 'FCMService',
        method: 'syncTokenToServer',
        feature: 'Core',
        status: 'ERROR',
        error: e,
        stackTrace: stack,
      );
    }
  }

  Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    final channelName = await LocaleHelper.translate('fcm_channel_name');
    final channelDescription = await LocaleHelper.translate(
      'fcm_channel_description',
    );

    await _localNotifications.show(
      DateTime.now().millisecond,
      ContentLocalizationService.resolve(title),
      ContentLocalizationService.resolve(body),
      NotificationDetails(
        android: AndroidNotificationDetails(
          'high_importance_channel',
          channelName,
          channelDescription: channelDescription,
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: payload,
    );
  }

  // ─── CHECK-IN REMINDER NOTIFICATIONS ─────────────────────

  /// IDs: 9001 = 5h, 9002 = 3h, 9003 = 1h before expiry
  static const int _checkIn5hId = 9001;
  static const int _checkIn3hId = 9002;
  static const int _checkIn1hId = 9003;

  /// Schedule smart reminders before the check-in window closes.
  /// [nextCheckInAt] is the server-provided expiry timestamp.
  Future<void> scheduleCheckInReminders(DateTime nextCheckInAt) async {
    // Cancel any old ones first
    await cancelCheckInNotifications();

    final now = DateTime.now();

    // 5 hours before expiry
    final fiveHBefore = nextCheckInAt.subtract(const Duration(hours: 5));
    if (fiveHBefore.isAfter(now)) {
      await _scheduleLocal(
        id: _checkIn5hId,
        title: await LocaleHelper.translate('checkin_reminder_5h_title'),
        body: await LocaleHelper.translate('checkin_reminder_5h'),
        scheduledDate: fiveHBefore,
      );
    }

    // 3 hours before expiry
    final threeHBefore = nextCheckInAt.subtract(const Duration(hours: 3));
    if (threeHBefore.isAfter(now)) {
      await _scheduleLocal(
        id: _checkIn3hId,
        title: await LocaleHelper.translate('checkin_reminder_3h_title'),
        body: await LocaleHelper.translate('checkin_reminder_3h'),
        scheduledDate: threeHBefore,
      );
    }

    // 1 hour before expiry
    final oneHBefore = nextCheckInAt.subtract(const Duration(hours: 1));
    if (oneHBefore.isAfter(now)) {
      await _scheduleLocal(
        id: _checkIn1hId,
        title: await LocaleHelper.translate('checkin_reminder_1h_title'),
        body: await LocaleHelper.translate('checkin_reminder_1h'),
        scheduledDate: oneHBefore,
      );
    }
  }

  /// Cancel all check-in reminder notifications.
  Future<void> cancelCheckInNotifications() async {
    await _localNotifications.cancel(_checkIn5hId);
    await _localNotifications.cancel(_checkIn3hId);
    await _localNotifications.cancel(_checkIn1hId);
  }

  Future<void> _scheduleLocal({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    final delay = scheduledDate.difference(DateTime.now());
    if (delay.isNegative) return;

    // Use Future.delayed as a simple cross-platform scheduling mechanism
    // that works without timezone dependencies
    Future.delayed(delay, () async {
      final channelName = await LocaleHelper.translate('fcm_channel_name');
      final channelDescription = await LocaleHelper.translate(
        'fcm_channel_description',
      );

      await _localNotifications.show(
        id,
        title,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'high_importance_channel',
            channelName,
            channelDescription: channelDescription,
            importance: Importance.max,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: const DarwinNotificationDetails(),
        ),
        payload: jsonEncode({
          'type': 'check_in_reminder',
          'route': Routes.dailyCheckIn,
        }),
      );
    });
  }
}
