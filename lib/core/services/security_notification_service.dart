import 'dart:async' show unawaited;
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:kasby/core/services/authentication_logger.dart';
import 'package:kasby/core/services/supabase_service.dart';
import 'package:kasby/features/home/presentation/controllers/home_controller.dart';

/// Security alert types delivered via Notification Center + realtime + push.
enum SecurityAlertType {
  passwordChanged,
  emailChanged,
  phoneChanged,
  emailVerified,
  phoneVerified,
  passwordReset,
}

extension SecurityAlertTypeX on SecurityAlertType {
  String get titleKey {
    switch (this) {
      case SecurityAlertType.passwordChanged:
        return 'security_alert_password_changed';
      case SecurityAlertType.emailChanged:
        return 'security_alert_email_changed';
      case SecurityAlertType.phoneChanged:
        return 'security_alert_phone_changed';
      case SecurityAlertType.emailVerified:
        return 'security_alert_email_verified';
      case SecurityAlertType.phoneVerified:
        return 'security_alert_phone_verified';
      case SecurityAlertType.passwordReset:
        return 'security_alert_password_reset';
    }
  }

  String get messageKey {
    switch (this) {
      case SecurityAlertType.passwordChanged:
        return 'security_alert_password_changed_msg';
      case SecurityAlertType.emailChanged:
        return 'security_alert_email_changed_msg';
      case SecurityAlertType.phoneChanged:
        return 'security_alert_phone_changed_msg';
      case SecurityAlertType.emailVerified:
        return 'security_alert_email_verified_msg';
      case SecurityAlertType.phoneVerified:
        return 'security_alert_phone_verified_msg';
      case SecurityAlertType.passwordReset:
        return 'security_alert_password_reset_msg';
    }
  }

  /// Allowed value in `notifications.type` check constraint.
  String get dbType => 'security_alert';
}

/// Creates in-app security notifications with device/platform context.
class SecurityNotificationService extends GetxService {
  static SecurityNotificationService get to => Get.find();

  Future<Map<String, String>> _deviceContext() async {
    if (kIsWeb) {
      return {'device': 'Web Browser', 'platform': 'web'};
    }
    return {
      'device':
          '${Platform.operatingSystem} ${Platform.operatingSystemVersion}',
      'platform': Platform.operatingSystem,
    };
  }

  String _formatTimestamp() {
    final now = DateTime.now();
    return DateFormat('yyyy-MM-dd HH:mm:ss').format(now);
  }

  Future<void> _notify(SecurityAlertType type) async {
    if (!SupabaseService.isLoggedIn) return;

    final sw = AuthenticationLogger.logStart(
      'security_notification',
      method: '_notify',
      params: {'type': type.name},
    );

    final ctx = await _deviceContext();
    final timestamp = _formatTimestamp();
    final title = type.titleKey.tr;
    final message = type.messageKey.trParams({
      'date': timestamp.split(' ').first,
      'time': timestamp.split(' ').last,
      'device': ctx['device'] ?? '',
      'platform': ctx['platform'] ?? '',
    });

    try {
      await SupabaseService.client.rpc(
        'fn_create_notification',
        params: {
          'p_user_id': SupabaseService.userId,
          'p_title': title,
          'p_body': message,
          'p_type': type.dbType,
          'p_entity_type': 'security_event',
          'p_entity_id': type.name,
          'p_deep_link': '/security-center',
          'p_role_target': 'user',
          'p_priority': 'high',
        },
      );

      if (Get.isRegistered<HomeController>()) {
        unawaited(HomeController.to.fetchNotifications());
      }

      AuthenticationLogger.logSuccess(
        'security_notification',
        stopwatch: sw,
        method: '_notify',
        params: {'type': type.name},
      );
    } catch (e, stack) {
      AuthenticationLogger.logFailure(
        'security_notification',
        e,
        stopwatch: sw,
        method: '_notify',
        stackTrace: stack,
        params: {'type': type.name},
      );
      // Non-blocking: auth/password flows must succeed even if notification insert fails.
    }
  }

  Future<void> notifyPasswordChanged() =>
      _notify(SecurityAlertType.passwordChanged);

  Future<void> notifyEmailChanged() => _notify(SecurityAlertType.emailChanged);

  Future<void> notifyPhoneChanged() => _notify(SecurityAlertType.phoneChanged);

  Future<void> notifyEmailVerified() =>
      _notify(SecurityAlertType.emailVerified);

  Future<void> notifyPhoneVerified() =>
      _notify(SecurityAlertType.phoneVerified);

  Future<void> notifyPasswordReset() =>
      _notify(SecurityAlertType.passwordReset);
}
