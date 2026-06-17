import 'package:shared_preferences/shared_preferences.dart';

class TourService {
  static const _keyCompleted = 'tour_completed';
  static const _keyLastStep = 'tour_last_step';
  static const _keySkipped = 'tour_skipped';

  static Future<bool> isTourCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyCompleted) ?? false;
  }

  static Future<void> markCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyCompleted, true);
    await prefs.setBool(_keySkipped, false);
  }

  static Future<void> markSkipped() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keySkipped, true);
    await prefs.setBool(_keyCompleted, true);
  }

  static Future<int> getLastStep() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyLastStep) ?? 0;
  }

  static Future<void> saveLastStep(int step) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyLastStep, step);
  }

  static Future<void> resetTour() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyCompleted);
    await prefs.remove(_keyLastStep);
    await prefs.remove(_keySkipped);
  }
}
