import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kasby/core/utils/safe_getx.dart';

class ThemeController extends GetxController {
  static ThemeController get to => Get.find();

  final RxBool isDark = true.obs;
  final RxString currentLanguage = (Get.locale?.languageCode ?? 'ar').obs;

  bool get isEnglish => currentLanguage.value == 'en';

  void updateLanguage(String langCode) {
    if (currentLanguage.value != langCode) {
      currentLanguage.value = langCode;
    }
  }

  static const String _themeKey = 'isDarkMode';

  @override
  void onInit() {
    SafeGetx.debugTrace(
      className: 'ThemeController',
      method: 'onInit',
      feature: 'Settings',
      status: 'INFO',
    );
    super.onInit();
    _loadSavedTheme();
  }

  @override
  void onReady() {
    SafeGetx.debugTrace(
      className: 'ThemeController',
      method: 'onReady',
      feature: 'Settings',
      status: 'INFO',
      params: {'isDark': isDark.value},
    );
    super.onReady();
  }

  @override
  void onClose() {
    SafeGetx.debugTrace(
      className: 'ThemeController',
      method: 'onClose',
      feature: 'Settings',
      status: 'INFO',
    );
    super.onClose();
  }

  Future<void> _loadSavedTheme() async {
    final stopwatch = Stopwatch()..start();
    try {
      final prefs = await SharedPreferences.getInstance();
      isDark.value = prefs.getBool(_themeKey) ?? true;
      _applyTheme();
      SafeGetx.debugTrace(
        className: 'ThemeController',
        method: '_loadSavedTheme',
        feature: 'Settings',
        status: 'SUCCESS',
        params: {'isDark': isDark.value},
        durationMs: stopwatch.elapsedMilliseconds,
      );
    } catch (e, stack) {
      SafeGetx.debugTrace(
        className: 'ThemeController',
        method: '_loadSavedTheme',
        feature: 'Settings',
        status: 'ERROR',
        durationMs: stopwatch.elapsedMilliseconds,
        error: e,
        stackTrace: stack,
      );
    }
  }

  Future<void> toggleTheme() async {
    isDark.value = !isDark.value;
    SafeGetx.debugTrace(
      className: 'ThemeController',
      method: 'toggleTheme',
      feature: 'Settings',
      status: 'SUCCESS',
      params: {'isDark': isDark.value},
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_themeKey, isDark.value);
    _applyTheme();
  }

  void _applyTheme() {
    Get.changeThemeMode(isDark.value ? ThemeMode.dark : ThemeMode.light);
  }
}
