import 'dart:async' show unawaited;

import 'package:flutter/foundation.dart';
import 'package:kasby/core/services/supabase_service.dart';
import 'package:kasby/core/utils/safe_getx.dart';

/// Structured logging for tutorial, KYC, notifications, permissions,
/// account activation, and account deletion workflows.
class EnterpriseOperationsLogger {
  EnterpriseOperationsLogger._();

  static const _tag = '[ENTERPRISE]';

  static void log({
    required String domain,
    required String operation,
    required String phase,
    String status = 'INFO',
    String? userId,
    String? entityId,
    Map<String, Object?>? params,
    Object? error,
    StackTrace? stackTrace,
    int? durationMs,
  }) {
    final payload = <String, Object?>{
      'domain': domain,
      'operation': operation,
      'phase': phase,
      'status': status,
      if (userId != null) 'userId': userId,
      if (entityId != null) 'entityId': entityId,
      if (durationMs != null) 'durationMs': durationMs,
      if (params != null) ..._sanitize(params),
    };

    SafeGetx.debugTrace(
      className: 'EnterpriseOperationsLogger',
      method: operation,
      feature: domain,
      status: status,
      message: '$operation.$phase',
      params: payload,
      error: error,
      stackTrace: stackTrace,
    );

    if (kDebugMode) {
      debugPrint('$_tag $domain.$operation.$phase $payload');
    }

    if (status == 'ERROR' || status == 'WARN') {
      unawaited(
        SupabaseService.logActivity(
          action: '${domain}_$operation'.toUpperCase(),
          details: _safeDetails(payload, error),
          severity: status == 'ERROR' ? 'critical' : 'warning',
        ),
      );
    }
  }

  static Map<String, Object?> _sanitize(Map<String, Object?> input) {
    const blocked = {
      'password',
      'otp',
      'token',
      'access_token',
      'refresh_token',
      'secret',
      'pin',
    };
    final out = <String, Object?>{};
    input.forEach((key, value) {
      final lower = key.toLowerCase();
      if (blocked.any(lower.contains)) return;
      out[key] = value;
    });
    return out;
  }

  static String _safeDetails(Map<String, Object?> payload, Object? error) {
    final buffer = StringBuffer(payload.toString());
    if (error != null) {
      buffer.write(' | error=');
      buffer.write(error.toString().replaceAll(RegExp(r'\b\d{4,}\b'), '****'));
    }
    return buffer.toString();
  }
}
