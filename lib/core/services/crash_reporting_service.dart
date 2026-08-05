import 'dart:async';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:kasby/core/services/crash_reporting/crash_breadcrumb.dart';
import 'package:kasby/core/services/crash_reporting/crash_error_category.dart';
import 'package:kasby/core/services/supabase_service.dart';
import 'package:kasby/core/utils/safe_getx.dart';
import 'package:kasby/features/home/presentation/controllers/home_controller.dart';

/// Production crash monitoring via Firebase Crashlytics.
///
/// Disabled in debug builds. All reporting flows through this service.
class CrashReportingService {
  CrashReportingService._();

  static bool _initialized = false;
  static bool _handlersInstalled = false;
  static String _appVersion = 'unknown';
  static String _buildNumber = 'unknown';

  static String? _lastFingerprint;
  static DateTime? _lastFingerprintAt;

  static bool get isInitialized => _initialized;

  /// Crash collection enabled in release/profile only.
  static bool get isCollectionEnabled => !kDebugMode;

  /// Initializes Crashlytics and installs global error handlers.
  static Future<void> initialize({required bool firebaseReady}) async {
    if (!firebaseReady || _initialized) return;
    _initialized = true;

    await _loadAppMetadata();
    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
      isCollectionEnabled,
    );

    if (isCollectionEnabled) {
      await setCustomKey(CrashCustomKey.appVersion, _appVersion);
      await setCustomKey(CrashCustomKey.buildNumber, _buildNumber);
      _installGlobalHandlers();
    }
  }

  /// Backward-compatible alias.
  static Future<void> init({required bool firebaseReady}) =>
      initialize(firebaseReady: firebaseReady);

  /// Wraps [main] with [runZonedGuarded] for async error capture.
  static void runAppWithCrashGuards(Future<void> Function() appRunner) {
    runZonedGuarded(
      () {
        unawaited(appRunner());
      },
      (error, stack) {
        unawaited(
          recordFatal(
            error,
            stack,
            reason: 'Zone.runGuarded',
            category: CrashErrorCategory.unknown,
          ),
        );
      },
    );
  }

  static void _installGlobalHandlers() {
    if (_handlersInstalled) return;
    _handlersInstalled = true;

    final previousFlutterHandler = FlutterError.onError;
    FlutterError.onError = (details) {
      previousFlutterHandler?.call(details);
      FlutterError.presentError(details);
      if (kDebugMode) {
        SafeGetx.debugTrace(
          className: 'FlutterError',
          method: 'onError',
          feature: 'ErrorHandling',
          status: 'FAILED',
          error: details.exceptionAsString(),
          stackTrace: details.stack,
        );
      }
      if (isCollectionEnabled &&
          _shouldReport(details.exception, details.stack, source: 'flutter')) {
        unawaited(
          FirebaseCrashlytics.instance.recordFlutterFatalError(details),
        );
      }
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      if (kDebugMode) {
        SafeGetx.debugTrace(
          className: 'PlatformDispatcher',
          method: 'onError',
          feature: 'ErrorHandling',
          status: 'FAILED',
          error: error,
          stackTrace: stack,
        );
      }
      if (isCollectionEnabled &&
          _shouldReport(error, stack, source: 'platform')) {
        unawaited(
          FirebaseCrashlytics.instance.recordError(
            error,
            stack,
            fatal: true,
            reason: 'PlatformDispatcher.onError',
          ),
        );
      }
      return true;
    };
  }

  static Future<void> _loadAppMetadata() async {
    try {
      final info = await PackageInfo.fromPlatform();
      _appVersion = info.version;
      _buildNumber = info.buildNumber;
    } catch (_) {
      _appVersion = 'unknown';
      _buildNumber = 'unknown';
    }
  }

  // ─────────── Core reporting ───────────

  static Future<void> recordError(
    Object error,
    StackTrace? stack, {
    String? reason,
    bool fatal = false,
    CrashErrorCategory category = CrashErrorCategory.unknown,
    Map<String, Object?>? context,
  }) async {
    await _applyCategory(category);
    if (context != null) {
      await _applyContextKeys(context);
    }

    if (!isCollectionEnabled || !_initialized) {
      if (kDebugMode) {
        SafeGetx.debugTrace(
          className: 'CrashReportingService',
          method: 'recordError',
          feature: 'ErrorHandling',
          status: 'FAILED',
          message: reason,
          error: error,
          stackTrace: stack,
          params: {'fatal': fatal, 'category': category.key},
        );
      }
      return;
    }

    if (!_shouldReport(error, stack, source: reason ?? 'recordError')) {
      return;
    }

    await FirebaseCrashlytics.instance.recordError(
      error,
      stack,
      reason: _buildReason(reason, category),
      fatal: fatal,
    );
  }

  static Future<void> recordFatal(
    Object error,
    StackTrace? stack, {
    String? reason,
    CrashErrorCategory category = CrashErrorCategory.unknown,
    Map<String, Object?>? context,
  }) => recordError(
    error,
    stack,
    reason: reason,
    fatal: true,
    category: category,
    context: context,
  );

  static Future<void> recordException(
    Object exception,
    StackTrace? stack, {
    String? reason,
    CrashErrorCategory category = CrashErrorCategory.unknown,
    Map<String, Object?>? context,
  }) => recordError(
    exception,
    stack,
    reason: reason,
    fatal: false,
    category: category,
    context: context,
  );

  // ─────────── Typed error reporters ───────────

  static Future<void> recordNetworkError(
    Object error,
    StackTrace? stack, {
    String? operation,
    bool isTimeout = false,
  }) => recordError(
    error,
    stack,
    reason: operation ?? 'Network failure',
    category: CrashErrorCategory.network,
    context: {
      if (operation != null) 'operation': operation,
      'is_timeout': isTimeout,
    },
  );

  static Future<void> recordSupabaseError(
    Object error, {
    StackTrace? stack,
    String? rpcName,
    String? tableName,
    String? operation,
    CrashErrorCategory category = CrashErrorCategory.supabase,
  }) async {
    final context = <String, Object?>{
      CrashCustomKey.supabaseErrorType: error.runtimeType.toString(),
      if (rpcName != null) CrashCustomKey.rpcName: rpcName,
      if (tableName != null) CrashCustomKey.tableName: tableName,
      if (operation != null) 'operation': operation,
    };

    if (error is PostgrestException) {
      context[CrashCustomKey.postgrestCode] = error.code ?? 'unknown';
      context[CrashCustomKey.httpStatus] = error.code ?? 'unknown';
    } else if (error is AuthException) {
      context[CrashCustomKey.httpStatus] =
          error.statusCode?.toString() ?? 'unknown';
    } else if (error is FunctionException) {
      context[CrashCustomKey.httpStatus] = error.status.toString();
    }

    await recordError(
      error,
      stack ?? StackTrace.current,
      reason: _sanitizeMessage(error.toString()),
      category: category,
      context: context,
    );
  }

  static Future<void> recordAuthError(
    Object error, {
    StackTrace? stack,
    String? authMethod,
    String? loginType,
    bool expectedFailure = false,
  }) async {
    if (expectedFailure && error is AuthException) return;

    await recordError(
      error,
      stack ?? StackTrace.current,
      reason: 'Authentication failure',
      category: CrashErrorCategory.authentication,
      context: {
        if (authMethod != null) CrashCustomKey.authMethod: authMethod,
        if (loginType != null) CrashCustomKey.loginType: loginType,
      },
    );
  }

  static Future<void> recordBusinessError(
    Object error, {
    StackTrace? stack,
    required CrashErrorCategory category,
    String? operation,
    Map<String, Object?>? context,
  }) => recordError(
    error,
    stack ?? StackTrace.current,
    reason: operation ?? 'Business logic failure',
    category: category,
    context: context,
  );

  // ─────────── Breadcrumbs & keys ───────────

  static Future<void> log(String message) async {
    final sanitized = _sanitizeMessage(message);
    if (!isCollectionEnabled || !_initialized) {
      if (kDebugMode) {
        SafeGetx.debugTrace(
          className: 'CrashReportingService',
          method: 'log',
          feature: 'ErrorHandling',
          status: 'INFO',
          message: sanitized,
        );
      }
      return;
    }
    await FirebaseCrashlytics.instance.log(sanitized);
  }

  static Future<void> setUser({
    String? userId,
    String? userRole,
    String? accountType,
    String? kycStatus,
    String? country,
  }) async {
    if (!isCollectionEnabled || !_initialized) return;

    if (userId != null && userId.isNotEmpty) {
      await FirebaseCrashlytics.instance.setUserIdentifier(userId);
    }
    if (userRole != null) {
      await setCustomKey(CrashCustomKey.userRole, userRole);
    }
    if (accountType != null) {
      await setCustomKey(CrashCustomKey.accountType, accountType);
    }
    if (kycStatus != null) {
      await setCustomKey(CrashCustomKey.kycStatus, kycStatus);
    }
    if (country != null) {
      await setCustomKey(CrashCustomKey.country, country);
    }
  }

  static Future<void> clearUser() async {
    if (!isCollectionEnabled || !_initialized) return;
    await FirebaseCrashlytics.instance.setUserIdentifier('');
    await setCustomKey(CrashCustomKey.userRole, 'anonymous');
    await setCustomKey(CrashCustomKey.accountType, 'none');
    await setCustomKey(CrashCustomKey.kycStatus, 'none');
    await setCustomKey(CrashCustomKey.country, 'none');
  }

  static Future<void> setCustomKey(String key, Object value) async {
    if (!isCollectionEnabled || !_initialized) return;
    await FirebaseCrashlytics.instance.setCustomKey(
      key,
      _sanitizeCustomValue(value),
    );
  }

  static Future<void> setCustomKeys(Map<String, Object?> keys) async {
    for (final entry in keys.entries) {
      final value = entry.value;
      if (value != null) {
        await setCustomKey(entry.key, value);
      }
    }
  }

  /// Syncs user context from [HomeController] profile after authentication.
  static Future<void> syncUserContextFromProfile() async {
    final userId = SupabaseService.userId;
    if (userId == null) {
      await clearUser();
      return;
    }

    String? role;
    String? accountType;
    String? kycStatus;
    String? country;

    if (Get.isRegistered<HomeController>()) {
      final profile = HomeController.to.profile.value;
      role = profile?.role;
      accountType = profile?.accountTier;
      kycStatus = profile?.kycStatus;
      country = profile?.countryCode ?? profile?.country;
    }

    role ??=
        SupabaseService.currentUser?.appMetadata['role'] as String? ?? 'user';

    await setUser(
      userId: userId,
      userRole: role,
      accountType: accountType,
      kycStatus: kycStatus,
      country: country,
    );
  }

  static Future<void> updateRouteContext(
    String? route, {
    String? screenName,
  }) async {
    if (route != null && route.isNotEmpty) {
      await setCustomKey(CrashCustomKey.currentRoute, route);
    }
    if (screenName != null && screenName.isNotEmpty) {
      await setCustomKey(CrashCustomKey.screenName, screenName);
    }
  }

  /// Maps wallet balance to a non-sensitive range bucket.
  static String balanceRange(num? balance) {
    if (balance == null) return 'unknown';
    if (balance < 0) return 'negative';
    if (balance < 100) return '0-100';
    if (balance < 1000) return '100-1k';
    if (balance < 10000) return '1k-10k';
    if (balance < 100000) return '10k-100k';
    return '100k+';
  }

  static CrashErrorCategory categoryFromFeature(String? feature) {
    if (feature == null) return CrashErrorCategory.unknown;
    final normalized = feature.toLowerCase();
    if (normalized.contains('auth')) return CrashErrorCategory.authentication;
    if (normalized.contains('wallet') || normalized.contains('transaction')) {
      return CrashErrorCategory.wallet;
    }
    if (normalized.contains('market') || normalized.contains('ksp')) {
      return CrashErrorCategory.marketplace;
    }
    if (normalized.contains('invest')) return CrashErrorCategory.investments;
    if (normalized.contains('notif')) return CrashErrorCategory.notifications;
    if (normalized.contains('profile')) return CrashErrorCategory.profile;
    if (normalized.contains('network') || normalized.contains('core')) {
      return CrashErrorCategory.network;
    }
    return CrashErrorCategory.unknown;
  }

  // ─────────── Internals ───────────

  static Future<void> _applyCategory(CrashErrorCategory category) async {
    await setCustomKey(CrashCustomKey.errorCategory, category.key);
  }

  static Future<void> _applyContextKeys(Map<String, Object?> context) async {
    for (final entry in context.entries) {
      final value = entry.value;
      if (value != null) {
        await setCustomKey(entry.key, _sanitizeCustomValue(value));
      }
    }
  }

  static String _buildReason(String? reason, CrashErrorCategory category) {
    final base = reason ?? category.key;
    return '${category.key}: $base';
  }

  static bool _shouldReport(Object error, StackTrace? stack, {String? source}) {
    final fingerprint =
        '${error.runtimeType}|${error.hashCode}|${stack?.hashCode ?? 0}|$source';
    final now = DateTime.now();
    if (_lastFingerprint == fingerprint &&
        _lastFingerprintAt != null &&
        now.difference(_lastFingerprintAt!) < const Duration(seconds: 3)) {
      return false;
    }
    _lastFingerprint = fingerprint;
    _lastFingerprintAt = now;
    return true;
  }

  static Object _sanitizeCustomValue(Object value) {
    if (value is num || value is bool) return value;
    return _sanitizeMessage(value.toString());
  }

  static String _sanitizeMessage(String message) {
    var sanitized = message;
    final sensitivePatterns = [
      RegExp(r'password\s*[:=]\s*\S+', caseSensitive: false),
      RegExp(r'token\s*[:=]\s*\S+', caseSensitive: false),
      RegExp(r'otp\s*[:=]\s*\S+', caseSensitive: false),
      RegExp(r'bearer\s+\S+', caseSensitive: false),
      RegExp(r'api[_-]?key\s*[:=]\s*\S+', caseSensitive: false),
    ];
    for (final pattern in sensitivePatterns) {
      sanitized = sanitized.replaceAll(pattern, '[REDACTED]');
    }
    if (sanitized.length > 500) {
      sanitized = '${sanitized.substring(0, 500)}...';
    }
    return sanitized;
  }
}
