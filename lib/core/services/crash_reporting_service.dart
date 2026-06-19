import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:kasby/core/utils/safe_getx.dart';

/// Production crash reporting via Firebase Crashlytics.
///
/// Disabled in debug builds to avoid polluting the Crashlytics dashboard.
class CrashReportingService {
  CrashReportingService._();

  static bool _initialized = false;

  static Future<void> init({required bool firebaseReady}) async {
    if (!firebaseReady || _initialized) return;
    _initialized = true;

    await FirebaseCrashlytics.instance
        .setCrashlyticsCollectionEnabled(!kDebugMode);

    if (kDebugMode) return;

    final defaultHandler = FlutterError.onError;
    FlutterError.onError = (details) {
      defaultHandler?.call(details);
      FirebaseCrashlytics.instance.recordFlutterFatalError(details);
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
  }

  /// Records non-fatal errors (e.g. caught API failures) in release builds.
  static Future<void> recordError(
    Object error,
    StackTrace? stack, {
    String? reason,
    bool fatal = false,
  }) async {
    if (kDebugMode || !_initialized) {
      SafeGetx.debugTrace(
        className: 'CrashReportingService',
        method: 'recordError',
        feature: 'ErrorHandling',
        status: 'FAILED',
        message: reason,
        error: error,
        stackTrace: stack,
      );
      return;
    }
    await FirebaseCrashlytics.instance.recordError(
      error,
      stack,
      reason: reason,
      fatal: fatal,
    );
  }
}
