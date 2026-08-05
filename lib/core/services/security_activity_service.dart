import 'dart:async' show unawaited;
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:kasby/core/services/supabase_service.dart';
import 'package:kasby/core/utils/safe_getx.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Security event types logged for the Security Center activity timeline.
enum SecurityEventType {
  registration,
  login,
  logout,
  failedLogin,
  emailVerified,
  phoneVerified,
  passwordChange,
  passwordReset,
  transactionPinChange,
  biometricEnabled,
  biometricDisabled,
  emailChange,
  phoneChange,
  deviceRegistration,
  sessionExpiration,
  accountLock,
}

extension SecurityEventTypeX on SecurityEventType {
  String get value => name;

  String get labelKey {
    final snake = name.replaceAllMapped(
      RegExp(r'([A-Z])'),
      (m) => '_${m.group(0)!.toLowerCase()}',
    );
    return 'security_event$snake';
  }
}

/// Persists and retrieves user security activity for the Security Center.
class SecurityActivityService extends GetxService {
  static SecurityActivityService get to => Get.find();

  final RxList<Map<String, dynamic>> events = <Map<String, dynamic>>[].obs;
  final RxBool isLoading = false.obs;
  final RxInt failedLoginCount = 0.obs;

  PackageInfo? _packageInfo;

  @override
  void onInit() {
    super.onInit();
    _initPackageInfo();
  }

  Future<void> _initPackageInfo() async {
    try {
      _packageInfo = await PackageInfo.fromPlatform();
    } catch (_) {}
  }

  Future<Map<String, String>> _deviceContext() async {
    if (kIsWeb) {
      return {
        'device_name': 'Web Browser',
        'device_type': 'web',
        'platform': 'web',
        'browser': defaultTargetPlatform.name,
      };
    }
    return {
      'device_name':
          '${Platform.operatingSystem} ${Platform.operatingSystemVersion}',
      'device_type': Platform.isAndroid || Platform.isIOS
          ? 'mobile'
          : 'desktop',
      'platform': Platform.operatingSystem,
      'browser': '',
    };
  }

  /// Records a security event server-side (with local fallback).
  Future<void> logEvent(
    SecurityEventType type, {
    String status = 'success',
    String? details,
    Map<String, dynamic>? metadata,
  }) async {
    if (!SupabaseService.isLoggedIn) return;

    final ctx = await _deviceContext();
    final payload = {
      'user_id': SupabaseService.userId,
      'event_type': type.value,
      'status': status,
      'device_name': ctx['device_name'],
      'device_type': ctx['device_type'],
      'platform': ctx['platform'],
      'browser': ctx['browser']?.isNotEmpty == true ? ctx['browser'] : null,
      'app_version': _packageInfo?.version,
      'metadata': {if (details != null) 'details': details, ...?metadata},
      'created_at': DateTime.now().toUtc().toIso8601String(),
    };

    try {
      await SupabaseService.client.from('user_security_events').insert(payload);
    } catch (e) {
      await SupabaseService.logActivity(
        action: 'SECURITY_${type.value.toUpperCase()}',
        details: details ?? type.value,
        severity: status == 'failed' ? 'warning' : 'info',
      );
      SafeGetx.debugTrace(
        className: 'SecurityActivityService',
        method: 'logEvent',
        feature: 'Security',
        status: 'WARN',
        message: 'user_security_events insert failed — used system_logs',
        error: e,
      );
    }

    if (type == SecurityEventType.failedLogin) {
      failedLoginCount.value++;
    }

    if (events.isNotEmpty) {
      unawaited(fetchEvents());
    }
  }

  Future<void> fetchEvents({int limit = 50}) async {
    if (!SupabaseService.isLoggedIn) return;
    isLoading.value = true;
    try {
      final rows = await SupabaseService.client
          .from('user_security_events')
          .select()
          .eq('user_id', SupabaseService.userId!)
          .order('created_at', ascending: false)
          .limit(limit);

      events.assignAll(List<Map<String, dynamic>>.from(rows));

      failedLoginCount.value = events
          .where(
            (e) =>
                e['event_type'] == SecurityEventType.failedLogin.value &&
                e['status'] == 'failed',
          )
          .length;
    } catch (e) {
      events.clear();
      SafeGetx.debugTrace(
        className: 'SecurityActivityService',
        method: 'fetchEvents',
        feature: 'Security',
        status: 'WARN',
        error: e,
      );
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> registerCurrentDevice() async {
    await logEvent(SecurityEventType.deviceRegistration);
  }
}
