import 'package:kasby/core/services/crash_reporting/crash_error_category.dart';
import 'package:kasby/core/services/crash_reporting_service.dart';
import 'package:kasby/core/services/supabase_service.dart';
import 'package:kasby/core/utils/safe_getx.dart';

/// Structured diagnostics for email / OTP delivery pipelines.
class EmailDeliveryLogger {
  EmailDeliveryLogger._();

  static String? get _userId => SupabaseService.currentUser?.id;

  static String _maskEmail(String email) {
    final trimmed = email.trim();
    final at = trimmed.indexOf('@');
    if (at <= 1) return '***';
    return '${trimmed[0]}***${trimmed.substring(at)}';
  }

  static String _maskPhone(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 4) return '***';
    return '***${digits.substring(digits.length - 4)}';
  }

  static void logRequest({
    required String flow,
    required String source,
    String? email,
    String? phone,
    Map<String, Object?>? extra,
  }) {
    final params = <String, Object?>{
      'flow': flow,
      'source': source,
      if (_userId != null) 'userId': _userId,
      if (email != null) 'email': _maskEmail(email),
      if (phone != null) 'phone': _maskPhone(phone),
      ...?extra,
    };
    SafeGetx.debugTrace(
      className: 'EmailDelivery',
      method: flow,
      feature: 'EmailDelivery',
      status: 'INFO',
      message: 'Request started',
      params: params,
    );
  }

  static void logSuccess({
    required String flow,
    required String source,
    int? httpStatus,
    String? delivery,
    Map<String, Object?>? extra,
  }) {
    final params = <String, Object?>{
      'flow': flow,
      'source': source,
      if (_userId != null) 'userId': _userId,
      if (httpStatus != null) 'httpStatus': httpStatus,
      if (delivery != null) 'delivery': delivery,
      ...?extra,
    };
    SafeGetx.debugTrace(
      className: 'EmailDelivery',
      method: flow,
      feature: 'EmailDelivery',
      status: 'SUCCESS',
      message: 'Delivery succeeded',
      params: params,
    );
  }

  static void logFailure({
    required String flow,
    required String source,
    required Object error,
    StackTrace? stackTrace,
    int? httpStatus,
    String? email,
    String? phone,
    Map<String, Object?>? extra,
  }) {
    final params = <String, Object?>{
      'flow': flow,
      'source': source,
      if (_userId != null) 'userId': _userId,
      if (httpStatus != null) 'httpStatus': httpStatus,
      if (email != null) 'email': _maskEmail(email),
      if (phone != null) 'phone': _maskPhone(phone),
      ...?extra,
    };
    SafeGetx.debugTrace(
      className: 'EmailDelivery',
      method: flow,
      feature: 'EmailDelivery',
      status: 'ERROR',
      message: 'Delivery failed',
      params: params,
      error: error,
      stackTrace: stackTrace,
    );
    CrashReportingService.recordError(
      error,
      stackTrace,
      reason: '[EMAIL][$flow] source=$source status=${httpStatus ?? 'n/a'}',
      fatal: false,
      category: CrashErrorCategory.authentication,
    );
  }
}
