import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';

/// Persists and evaluates user notification preference toggles.
class NotificationPreferencesService {
  NotificationPreferencesService._();

  static const _globalKey = 'notifications_enabled';
  static const _financialKey = 'notif_financial';
  static const _securityKey = 'notif_security';
  static const _socialKey = 'notif_social';
  static const _systemKey = 'notif_system';
  static const _quietHoursKey = 'notif_quiet_hours';
  static const _quietStartHKey = 'notif_quiet_start_h';
  static const _quietStartMKey = 'notif_quiet_start_m';
  static const _quietEndHKey = 'notif_quiet_end_h';
  static const _quietEndMKey = 'notif_quiet_end_m';

  static Future<bool> isGlobalEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_globalKey) ?? true;
  }

  static Future<bool> isCategoryEnabled(String category) async {
    final prefs = await SharedPreferences.getInstance();
    switch (category) {
      case 'financial':
        return prefs.getBool(_financialKey) ?? true;
      case 'security':
        return prefs.getBool(_securityKey) ?? true;
      case 'social':
        return prefs.getBool(_socialKey) ?? true;
      case 'system':
        return prefs.getBool(_systemKey) ?? true;
      default:
        return true;
    }
  }

  static Future<bool> isQuietHoursEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_quietHoursKey) ?? false;
  }

  static Future<bool> isInQuietHours([DateTime? now]) async {
    if (!await isQuietHoursEnabled()) return false;
    final prefs = await SharedPreferences.getInstance();
    final startH = prefs.getInt(_quietStartHKey) ?? 22;
    final startM = prefs.getInt(_quietStartMKey) ?? 0;
    final endH = prefs.getInt(_quietEndHKey) ?? 7;
    final endM = prefs.getInt(_quietEndMKey) ?? 0;

    final current = now ?? DateTime.now();
    final start = startH * 60 + startM;
    final end = endH * 60 + endM;
    final value = current.hour * 60 + current.minute;

    if (start == end) return false;
    if (start < end) {
      return value >= start && value < end;
    }
    return value >= start || value < end;
  }

  static String categoryFromEntityType(String? entityType) {
    final e = (entityType ?? '').toLowerCase();
    const financial = {
      'transaction', 'investment', 'loan', 'wallet', 'deposit',
      'withdraw', 'transfer', 'ksp', 'subscription', 'marketplace',
    };
    const social = {
      'friend', 'friend_request', 'chat', 'message', 'team', 'referral',
    };
    if (financial.contains(e)) return 'financial';
    if (social.contains(e)) return 'social';
    return 'system';
  }

  static String categoryFromNotificationType(String type) {
    if (type == 'critical' || type == 'warning') return 'security';
    return 'system';
  }

  static Future<bool> shouldDeliverNotification({
    String? category,
    String? entityType,
    String? notificationType,
  }) async {
    if (!await isGlobalEnabled()) return false;
    if (await isInQuietHours()) return false;

    final resolved = category ??
        (entityType != null && entityType.isNotEmpty
            ? categoryFromEntityType(entityType)
            : categoryFromNotificationType(notificationType ?? 'info'));

    return isCategoryEnabled(resolved);
  }

  static Future<void> setCategoryEnabled(String category, bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    final key = switch (category) {
      'financial' => _financialKey,
      'security' => _securityKey,
      'social' => _socialKey,
      'system' => _systemKey,
      _ => null,
    };
    if (key != null) {
      await prefs.setBool(key, enabled);
    }
  }

  static Future<void> setQuietHoursEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_quietHoursKey, enabled);
  }

  static Future<void> setQuietHoursStart(int hour, int minute) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_quietStartHKey, hour);
    await prefs.setInt(_quietStartMKey, minute);
  }

  static Future<void> setQuietHoursEnd(int hour, int minute) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_quietEndHKey, hour);
    await prefs.setInt(_quietEndMKey, minute);
  }

  static Future<TimeOfDay> getQuietStart() async {
    final prefs = await SharedPreferences.getInstance();
    return TimeOfDay(
      hour: prefs.getInt(_quietStartHKey) ?? 22,
      minute: prefs.getInt(_quietStartMKey) ?? 0,
    );
  }

  static Future<TimeOfDay> getQuietEnd() async {
    final prefs = await SharedPreferences.getInstance();
    return TimeOfDay(
      hour: prefs.getInt(_quietEndHKey) ?? 7,
      minute: prefs.getInt(_quietEndMKey) ?? 0,
    );
  }
}
