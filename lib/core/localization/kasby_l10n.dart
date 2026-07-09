import 'package:get/get.dart';
import 'package:kasby/core/localization/kasby_translations.dart';
import 'package:kasby/core/localization/localization_logger.dart';

/// Central localization facade — single entry point for all translation lookups.
/// Caches the translation map to avoid repeated [KasbyTranslations] instantiation.
class KasbyL10n {
  KasbyL10n._();

  static KasbyTranslations? _translations;
  static Map<String, Map<String, String>>? _keys;

  static Map<String, Map<String, String>> get keys {
    _translations ??= KasbyTranslations();
    _keys ??= _translations!.keys;
    return _keys!;
  }

  static const supportedLanguageCodes = {'ar', 'en'};
  static const defaultLanguageCode = 'ar';

  /// Current GetX locale tag, e.g. `ar_SA` or `en_US`.
  static String get currentLocaleTag {
    final locale = Get.locale;
    if (locale == null) return 'ar_SA';
    return _tagForLanguage(locale.languageCode);
  }

  static String get currentLanguageCode =>
      Get.locale?.languageCode ?? defaultLanguageCode;

  static bool get isRtl => currentLanguageCode == 'ar';

  static String _tagForLanguage(String languageCode) {
    if (!supportedLanguageCodes.contains(languageCode)) {
      LocalizationLogger.unsupportedLocale(languageCode);
      return 'ar_SA';
    }
    return languageCode == 'ar' ? 'ar_SA' : 'en_US';
  }

  /// Resolve a key for an explicit language (background tasks, scheduled notifications).
  static String forLanguage(
    String key, {
    required String languageCode,
    Map<String, String>? params,
  }) {
    final tag = _tagForLanguage(languageCode);
    return _resolve(tag, key, params: params);
  }

  /// Resolve using the active GetX locale.
  static String tr(String key, {Map<String, String>? params}) {
    return _resolve(currentLocaleTag, key, params: params);
  }

  /// Returns `true` when [key] exists in the active locale map.
  static bool hasKey(String key, {String? languageCode}) {
    final tag = languageCode == null
        ? currentLocaleTag
        : _tagForLanguage(languageCode);
    return keys[tag]?.containsKey(key) ?? false;
  }

  static String _resolve(
    String localeTag,
    String key, {
    Map<String, String>? params,
  }) {
    try {
      final map = keys[localeTag];
      if (map == null) {
        LocalizationLogger.unsupportedLocale(localeTag);
        return key;
      }

      final value = map[key];
      if (value == null) {
        LocalizationLogger.missingKey(key, locale: localeTag);
        return key;
      }

      if (params == null || params.isEmpty) return value;

      var result = value;
      for (final entry in params.entries) {
        result = result.replaceAll('@${entry.key}', entry.value);
      }
      return result;
    } catch (e, st) {
      LocalizationLogger.loadFailure(e, stackTrace: st);
      return key;
    }
  }

  /// Invalidate cache after hot-reload of translation files.
  static void invalidateCache() {
    _translations = null;
    _keys = null;
  }
}
