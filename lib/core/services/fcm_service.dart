import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:kasby/core/services/supabase_service.dart';
import 'notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../firebase_options.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint('[FCM] Handling background message: ${message.messageId}');
}

class FCMService extends GetxService {
  static FCMService get to => Get.find();
  
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  
  final RxString fcmToken = ''.obs;
  final RxString lastOtpCode = ''.obs;
  final RxBool isNotificationsEnabled = true.obs;

  Future<FCMService> init() async {
    await _setupLocalNotifications();
    // Only setup FCM if enabled
    final prefs = await SharedPreferences.getInstance();
    isNotificationsEnabled.value = prefs.getBool('notifications_enabled') ?? true;
    
    if (isNotificationsEnabled.value) {
      await _setupFCM();
    }
    return this;
  }

  Future<void> _setupLocalNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: DarwinInitializationSettings(),
    );

    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (details) {
        debugPrint('[FCM] Notification tapped: ${details.payload}');
      },
    );

    // Create high importance channel
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'high_importance_channel',
      'High Importance Notifications',
      description: 'This channel is used for important notifications.',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  Future<void> _setupFCM() async {
    // Request permissions
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('[FCM] User granted permission');
      
      // Get token
      String? token = await _fcm.getToken();
      if (token != null) {
        fcmToken.value = token;
        debugPrint('[FCM] Token: $token');
        await syncTokenToServer(token);
      }

      // Listen for token refresh
      _fcm.onTokenRefresh.listen((newToken) {
        fcmToken.value = newToken;
        syncTokenToServer(newToken);
      });

      // Handle background messages
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('[FCM] Received message: ${message.notification?.title}');
        NotificationService().playNotificationSound();
        _showLocalNotification(message);
        _handleIncomingMessage(message);
      });

      // Handle message when app is opened from notification
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        _handleIncomingMessage(message);
      });
    } else {
      debugPrint('[FCM] User declined or has not accepted permission');
    }
  }

  Future<void> setNotificationsEnabled(bool enabled) async {
    isNotificationsEnabled.value = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', enabled);

    if (enabled) {
      debugPrint('[FCM] Enabling notifications...');
      await _setupFCM();
    } else {
      debugPrint('[FCM] Disabling notifications...');
      await _fcm.deleteToken();
      fcmToken.value = '';
      // Also clear on server
      await _clearTokenOnServer();
    }
  }

  Future<void> _clearTokenOnServer() async {
    try {
      if (SupabaseService.client.auth.currentUser != null) {
        await SupabaseService.client.from('profiles').update({
          'fcm_token': null,
        }).eq('id', SupabaseService.userId!);
        debugPrint('[FCM] Token cleared from server');
      }
    } catch (e) {
      debugPrint('[FCM] Error clearing token from server: $e');
    }
  }

  void _showLocalNotification(RemoteMessage message) {
    RemoteNotification? notification = message.notification;
    AndroidNotification? android = message.notification?.android;

    if (notification != null && android != null && !kIsWeb) {
      _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'high_importance_channel',
            'High Importance Notifications',
            channelDescription: 'This channel is used for important notifications.',
            importance: Importance.max,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
        ),
        payload: message.data.toString(),
      );
    }
  }

  void _handleIncomingMessage(RemoteMessage message) {
    if (message.data['type'] == 'otp_verification') {
      final otp = message.data['otp_code'];
      if (otp != null) {
        lastOtpCode.value = otp;
        debugPrint('[FCM] OTP received: $otp');
      }
    }
    
    // Deep Linking: If route is provided
    if (message.data['route'] != null) {
      final route = message.data['route'] as String;
      // We delay routing to ensure app is fully initialized if coming from terminated state
      Future.delayed(const Duration(milliseconds: 500), () {
        if (Get.currentRoute != route) {
          Get.toNamed(route);
        }
      });
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
            'p_app_type': 'agent', // Explicitly registering as agent for this controller's context
          },
        );
        debugPrint('[FCM] Token synced to server successfully via fn_register_device_token');
      }
    } catch (e) {
      debugPrint('[FCM] Error syncing token to server: $e');
    }
  }

  Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    await _localNotifications.show(
      DateTime.now().millisecond,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'high_importance_channel',
          'High Importance Notifications',
          channelDescription: 'This channel is used for important notifications.',
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(),
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
        title: 'لا تنسَ تسجيل حضورك! 🎁',
        body: 'لا تنس تسجيل حضورك اليومي للحصول على نقاط مجانية 🎁',
        scheduledDate: fiveHBefore,
      );
    }

    // 3 hours before expiry
    final threeHBefore = nextCheckInAt.subtract(const Duration(hours: 3));
    if (threeHBefore.isAfter(now)) {
      await _scheduleLocal(
        id: _checkIn3hId,
        title: 'تبقى 3 ساعات فقط! 💰',
        body: 'تبقى 3 ساعات فقط! سجل حضورك الآن واحصل على مكافأتك 💰',
        scheduledDate: threeHBefore,
      );
    }

    // 1 hour before expiry
    final oneHBefore = nextCheckInAt.subtract(const Duration(hours: 1));
    if (oneHBefore.isAfter(now)) {
      await _scheduleLocal(
        id: _checkIn1hId,
        title: 'آخر فرصة اليوم! ⏳',
        body: 'آخر فرصة اليوم! لا تفوت نقاطك المجانية ⏳',
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
      await _localNotifications.show(
        id,
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'high_importance_channel',
            'High Importance Notifications',
            channelDescription: 'Check-in reminder notification.',
            importance: Importance.max,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: DarwinNotificationDetails(),
        ),
      );
    });
  }
}
