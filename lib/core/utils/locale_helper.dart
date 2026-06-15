import 'package:shared_preferences/shared_preferences.dart';
import 'package:kasby/core/localization/kasby_translations.dart';
import 'package:kasby/core/utils/safe_getx.dart';

/// Locale utilities for contexts where GetX may not be available (e.g. scheduled notifications).
class LocaleHelper {
  static const String localeKey = 'app_locale';

  static Future<String> getLanguageCode() async {
    return SafeGetx.traceAsync(
      className: 'LocaleHelper',
      method: 'getLanguageCode',
      feature: 'Core',
      params: {'storage': 'SharedPreferences'},
      operation: () async {
        final prefs = await SharedPreferences.getInstance();
        return prefs.getString(localeKey) ?? 'ar';
      },
      onSuccessParams: (code) => {'languageCode': code},
    );
  }

  static Future<void> saveLanguageCode(String code) async {
    await SafeGetx.traceAsync(
      className: 'LocaleHelper',
      method: 'saveLanguageCode',
      feature: 'Core',
      params: {'languageCode': code, 'storage': 'SharedPreferences'},
      operation: () async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(localeKey, code);
      },
    );
  }

  static Future<String> translate(String key) async {
    final lang = await getLanguageCode();
    return translateForLanguage(key, lang);
  }

  static String translateForLanguage(String key, String lang) {
    final locale = lang == 'ar' ? 'ar_SA' : 'en_US';
    final translations = KasbyTranslations();
    return translations.keys[locale]?[key] ?? key;
  }
}
