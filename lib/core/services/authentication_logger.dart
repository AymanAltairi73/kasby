import 'dart:async' show unawaited;
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:kasby/core/services/crash_reporting_service.dart';
import 'package:kasby/core/services/supabase_service.dart';
import 'package:kasby/core/utils/mask_utils.dart';
import 'package:kasby/core/utils/safe_getx.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Centralized structured logging for all authentication operations.
class AuthenticationLogger {
  AuthenticationLogger._();

  static PackageInfo? _packageInfo;

  static Future<void> init() async {
    try {
      _packageInfo = await PackageInfo.fromPlatform();
    } catch (_) {}
  }

  static String get _platform {
    if (kIsWeb) return 'web';
    return Platform.operatingSystem;
  }

  static String get _device {
    if (kIsWeb) return 'Web Browser';
    return '${Platform.operatingSystem} ${Platform.operatingSystemVersion}';
  }

  static String? get _userId => SupabaseService.userId;

  static String? get _email =>
      SupabaseService.currentUser?.email?.trim().toLowerCase();

  static String? get _maskedPhone {
    final phone =
        SupabaseService.currentUser?.phone ??
        SupabaseService.currentUser?.userMetadata?['phone']?.toString();
    if (phone == null || phone.isEmpty) return null;
    return MaskUtils.maskIdentifier(value: phone, isPhone: true);
  }

  static String get _route => Get.currentRoute;

  /// Logs the start of an authentication operation.
  static Stopwatch logStart(
    String operation, {
    String method = 'execute',
    String? authMethod,
    String? email,
    String? phone,
    Map<String, Object?>? params,
  }) {
    final sw = Stopwatch()..start();
    _emit(
      operation: operation,
      method: method,
      phase: 'START',
      authMethod: authMethod,
      email: email,
      phone: phone,
      params: params,
    );
    return sw;
  }

  /// Logs successful completion of an authentication operation.
  static void logSuccess(
    String operation, {
    required Stopwatch stopwatch,
    String method = 'execute',
    String? authMethod,
    String? email,
    String? phone,
    Map<String, Object?>? params,
  }) {
    _emit(
      operation: operation,
      method: method,
      phase: 'SUCCESS',
      authMethod: authMethod,
      email: email,
      phone: phone,
      params: params,
      durationMs: stopwatch.elapsedMilliseconds,
    );
  }

  /// Logs a failed authentication operation — never swallows the error.
  static void logFailure(
    String operation,
    Object error, {
    required Stopwatch stopwatch,
    String method = 'execute',
    String? authMethod,
    String? email,
    String? phone,
    StackTrace? stackTrace,
    Map<String, Object?>? params,
  }) {
    final errorCode = error is AuthException
        ? error.statusCode?.toString()
        : null;
    final errorMessage = error is AuthException
        ? error.message
        : error.toString();

    _emit(
      operation: operation,
      method: method,
      phase: 'FAILURE',
      status: 'ERROR',
      authMethod: authMethod,
      email: email,
      phone: phone,
      params: params,
      durationMs: stopwatch.elapsedMilliseconds,
      error: error,
      errorCode: errorCode,
      errorMessage: errorMessage,
      stackTrace: stackTrace,
    );

    unawaited(
      CrashReportingService.recordAuthError(
        error,
        stack: stackTrace,
        expectedFailure: error is AuthException,
      ),
    );
  }

  static void _emit({
    required String operation,
    required String method,
    required String phase,
    String status = 'INFO',
    String? authMethod,
    String? email,
    String? phone,
    Map<String, Object?>? params,
    int? durationMs,
    Object? error,
    String? errorCode,
    String? errorMessage,
    StackTrace? stackTrace,
  }) {
    final payload = <String, Object?>{
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'operation': operation,
      'phase': phase,
      'userId': _userId,
      if (email != null || _email != null)
        'email': MaskUtils.maskEmail(email ?? _email ?? ''),
      if (phone != null || _maskedPhone != null) 'phone': phone ?? _maskedPhone,
      'platform': _platform,
      'device': _device,
      'appVersion': _packageInfo?.version,
      'authMethod': authMethod,
      'route': _route,
      if (durationMs != null) 'durationMs': durationMs,
      if (errorCode != null) 'errorCode': errorCode,
      if (errorMessage != null) 'errorMessage': errorMessage,
      if (params != null && params.isNotEmpty) 'params': params,
    };

    SafeGetx.debugTrace(
      className: 'AuthenticationLogger',
      method: method,
      feature: 'Authentication',
      status: status,
      message: '[$operation] $phase',
      params: payload,
      error: error,
      stackTrace: stackTrace,
    );

    if (phase == 'FAILURE') {
      unawaited(
        SupabaseService.logActivity(
          action: 'AUTH_${operation.toUpperCase()}_FAILURE',
          details: errorMessage ?? operation,
          severity: 'critical',
        ),
      );
    }
  }
}
