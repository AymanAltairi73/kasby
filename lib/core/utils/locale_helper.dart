import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kasby/core/localization/kasby_l10n.dart';
import 'package:kasby/core/localization/localization_logger.dart';
import 'package:kasby/core/services/supabase_service.dart';
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
        final code =
            prefs.getString(localeKey) ?? KasbyL10n.defaultLanguageCode;
        if (!KasbyL10n.supportedLanguageCodes.contains(code)) {
          LocalizationLogger.unsupportedLocale(code);
          return KasbyL10n.defaultLanguageCode;
        }
        return code;
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
        if (!KasbyL10n.supportedLanguageCodes.contains(code)) {
          LocalizationLogger.unsupportedLocale(code);
          return;
        }
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(localeKey, code);

        // Sync with backend if user is logged in
        await syncLanguageToServer(code);
      },
    );
  }

  /// Synchronize the selected language to Supabase profiles & device_tokens
  static Future<void> syncLanguageToServer([String? languageCode]) async {
    try {
      if (!SupabaseService.isLoggedIn) return;
      final code = languageCode ?? await getLanguageCode();
      await SupabaseService.client.rpc(
        'fn_set_user_language',
        params: {'p_language': code},
      );
      debugPrint('[LocaleHelper] Language preference synced to server: $code');
    } catch (e) {
      debugPrint('[LocaleHelper] Server language sync ignored or failed: $e');
    }
  }

  /// Adopts server language preference upon login or profile load.
  /// If the server has a valid language preference that differs from local storage,
  /// updates local preferences and GetX locale.
  static Future<void> adoptServerLanguage(String? serverLanguage) async {
    if (serverLanguage == null ||
        !KasbyL10n.supportedLanguageCodes.contains(serverLanguage)) {
      return;
    }
    try {
      final localCode = await getLanguageCode();
      if (localCode != serverLanguage) {
        debugPrint(
          '[LocaleHelper] Adopting server language preference: $serverLanguage (was $localCode)',
        );
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(localeKey, serverLanguage);
        if (Get.locale?.languageCode != serverLanguage) {
          await Get.updateLocale(KasbyL10n.localeFromCode(serverLanguage));
        }
      }
    } catch (e) {
      debugPrint('[LocaleHelper] Error adopting server language: $e');
    }
  }

  static Future<String> translate(String key) async {
    final lang = await getLanguageCode();
    return translateForLanguage(key, lang);
  }

  static String translateForLanguage(String key, String lang) {
    return KasbyL10n.forLanguage(key, languageCode: lang);
  }
}
