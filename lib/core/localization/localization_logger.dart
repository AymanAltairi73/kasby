import 'package:flutter/foundation.dart';
import 'package:kasby/core/utils/safe_getx.dart';

/// Structured logging for localization diagnostics (debug builds + trace pipeline).
class LocalizationLogger {
  LocalizationLogger._();

  static final Set<String> _loggedMissingKeys = <String>{};
  static final Set<String> _loggedInvalidKeys = <String>{};

  static void missingKey(String key, {String? locale, String? context}) {
    if (_loggedMissingKeys.contains(key)) return;
    _loggedMissingKeys.add(key);

    SafeGetx.debugTrace(
      className: 'LocalizationLogger',
      method: 'missingKey',
      feature: 'Localization',
      status: 'WARN',
      message: 'Missing translation key',
      params: {
        'key': key,
        if (locale != null) 'locale': locale,
        if (context != null) 'context': context,
      },
    );

    assert(() {
      debugPrint('[L10n] MISSING KEY: $key (${locale ?? 'unknown'})');
      return true;
    }());
  }

  static void missingTranslation(String key, String locale) {
    SafeGetx.debugTrace(
      className: 'LocalizationLogger',
      method: 'missingTranslation',
      feature: 'Localization',
      status: 'WARN',
      message: 'Key exists in one locale but not the other',
      params: {'key': key, 'locale': locale},
    );
  }

  static void invalidKey(String raw, {String? reason}) {
    if (_loggedInvalidKeys.contains(raw)) return;
    _loggedInvalidKeys.add(raw);

    SafeGetx.debugTrace(
      className: 'LocalizationLogger',
      method: 'invalidKey',
      feature: 'Localization',
      status: 'WARN',
      message: 'Invalid localization key format',
      params: {
        'raw': raw.length > 80 ? '${raw.substring(0, 80)}...' : raw,
        if (reason != null) 'reason': reason,
      },
    );
  }

  static void unsupportedLocale(String locale) {
    SafeGetx.debugTrace(
      className: 'LocalizationLogger',
      method: 'unsupportedLocale',
      feature: 'Localization',
      status: 'ERROR',
      message: 'Unsupported locale requested',
      params: {'locale': locale},
    );
  }

  static void loadFailure(Object error, {StackTrace? stackTrace}) {
    SafeGetx.debugTrace(
      className: 'LocalizationLogger',
      method: 'loadFailure',
      feature: 'Localization',
      status: 'ERROR',
      message: 'Localization load failure',
      error: error,
      stackTrace: stackTrace,
    );
  }

  /// Clears deduplication caches (tests only).
  @visibleForTesting
  static void resetForTests() {
    _loggedMissingKeys.clear();
    _loggedInvalidKeys.clear();
  }
}
