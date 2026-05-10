import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeController extends GetxController {
  static ThemeController get to => Get.find();

  final RxBool isDark = true.obs;

  static const String _themeKey = 'isDarkMode';

  @override
  void onInit() {
    super.onInit();
    _loadSavedTheme();
  }

  Future<void> _loadSavedTheme() async {
    final prefs = await SharedPreferences.getInstance();
    isDark.value = prefs.getBool(_themeKey) ?? true;
    _applyTheme();
  }

  Future<void> toggleTheme() async {
    isDark.value = !isDark.value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_themeKey, isDark.value);
    _applyTheme();
  }

  void _applyTheme() {
    Get.changeThemeMode(isDark.value ? ThemeMode.dark : ThemeMode.light);
  }
}
