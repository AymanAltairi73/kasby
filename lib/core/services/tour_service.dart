import 'package:shared_preferences/shared_preferences.dart';

import 'package:kasby/core/services/enterprise_operations_logger.dart';
import 'package:kasby/core/services/supabase_service.dart';
import 'package:kasby/core/tour/tour_ids.dart';

/// Persists product-tour state per authenticated Supabase user.
class TourService {
  TourService._();

  static String? get _userId => SupabaseService.userId;

  static String _completedKey(TourId id) {
    final uid = _userId;
    if (uid == null) return 'tour_completed_${id.storageKey}';
    return 'tour_${uid}_completed_${id.storageKey}';
  }

  static String _skippedKey(TourId id) {
    final uid = _userId;
    if (uid == null) return 'tour_skipped_${id.storageKey}';
    return 'tour_${uid}_skipped_${id.storageKey}';
  }

  static String _lastStepKey(TourId id) {
    final uid = _userId;
    if (uid == null) return 'tour_last_step_${id.storageKey}';
    return 'tour_${uid}_last_step_${id.storageKey}';
  }

  static String _versionKey(TourId id) {
    final uid = _userId;
    if (uid == null) return 'tour_version_${id.storageKey}';
    return 'tour_${uid}_version_${id.storageKey}';
  }

  static String _autoEligibleKey() {
    final uid = _userId;
    if (uid == null) return 'tour_auto_eligible_anonymous';
    return 'tour_${uid}_auto_eligible';
  }

  static String _baselineKey() {
    final uid = _userId;
    if (uid == null) return 'tour_baseline_anonymous';
    return 'tour_${uid}_baseline_initialized';
  }

  // Legacy device-scoped home tour keys (migration).
  static const _legacyCompleted = 'tour_completed';
  static const _legacyLastStep = 'tour_last_step';
  static const _legacySkipped = 'tour_skipped';

  static bool _newUserTourSetupInProgress = false;
  static bool _pendingAutoHomeTour = false;
  static Future<void>? _baselineInFlight;

  static bool get isNewUserTourSetupInProgress => _newUserTourSetupInProgress;

  static bool get hasPendingAutoHomeTour => _pendingAutoHomeTour;

  static void beginNewUserTourSetup() {
    _newUserTourSetupInProgress = true;
  }

  static void endNewUserTourSetup() {
    _newUserTourSetupInProgress = false;
  }

  static Future<void> _migrateLegacyHomeTourIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey(_legacyCompleted)) return;

    final legacyDone = prefs.getBool(_legacyCompleted) ?? false;
    if (legacyDone) {
      await markCompleted(TourId.home);
    }

    await prefs.remove(_legacyCompleted);
    await prefs.remove(_legacyLastStep);
    await prefs.remove(_legacySkipped);
  }

  /// Called once after registration — only new users may receive auto tours.
  static Future<void> enableAutoToursForNewUser() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoEligibleKey(), true);
    await prefs.remove(_baselineKey());
    for (final id in TourId.values) {
      await resetTour(id);
    }
    _pendingAutoHomeTour = true;
    EnterpriseOperationsLogger.log(
      domain: 'tutorial',
      operation: 'enable_auto_tours',
      phase: 'COMPLETE',
      userId: _userId,
    );
  }

  /// Called for returning / existing users — suppresses all automatic tours.
  static Future<void> disableAutoToursForExistingUser() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoEligibleKey(), false);
    _pendingAutoHomeTour = false;
    await ensureExistingUserTourBaseline();
    EnterpriseOperationsLogger.log(
      domain: 'tutorial',
      operation: 'disable_auto_tours',
      phase: 'COMPLETE',
      userId: _userId,
    );
  }

  static void markPendingAutoHomeTour() {
    _pendingAutoHomeTour = true;
  }

  static bool consumePendingAutoHomeTour() {
    if (!_pendingAutoHomeTour) return false;
    _pendingAutoHomeTour = false;
    return true;
  }

  static Future<bool> isAutoTourEligible() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_autoEligibleKey()) ?? false;
  }

  /// Marks every tour complete for users who were never flagged as new signups.
  static Future<void> ensureExistingUserTourBaseline() async {
    if (await isAutoTourEligible()) return;

    _baselineInFlight ??= _applyExistingUserTourBaseline();
    try {
      await _baselineInFlight;
    } finally {
      _baselineInFlight = null;
    }
  }

  static Future<void> _applyExistingUserTourBaseline() async {
    if (await isAutoTourEligible()) return;

    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_baselineKey()) ?? false) return;

    for (final id in TourId.values) {
      if (await isAutoTourEligible()) return;
      await markCompleted(id);
    }

    if (await isAutoTourEligible()) {
      for (final id in TourId.values) {
        await resetTour(id);
      }
      return;
    }

    await prefs.setBool(_baselineKey(), true);
    EnterpriseOperationsLogger.log(
      domain: 'tutorial',
      operation: 'existing_user_baseline',
      phase: 'COMPLETE',
      userId: _userId,
    );
  }

  /// Whether an automatic (non-manual) tour may start.
  static Future<bool> canAutoStartTour(TourId tourId) async {
    if (_userId == null) return false;
    if (!await isAutoTourEligible()) return false;
    if (await isPermanentlySkipped()) return false;
    if (await isTourCompleted(tourId)) return false;
    return true;
  }

  static Future<bool> isTourCompleted(
    TourId tourId, {
    int? requiredVersion,
  }) async {
    if (tourId == TourId.home) {
      await _migrateLegacyHomeTourIfNeeded();
    }

    final prefs = await SharedPreferences.getInstance();
    final version = requiredVersion ?? tourId.version;
    final storedVersion = prefs.getInt(_versionKey(tourId)) ?? 0;
    if (storedVersion < version) return false;
    return prefs.getBool(_completedKey(tourId)) ?? false;
  }

  static Future<bool> wasSkipped(TourId tourId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_skippedKey(tourId)) ?? false;
  }

  static Future<void> markCompleted(TourId tourId, {int? version}) async {
    final prefs = await SharedPreferences.getInstance();
    final v = version ?? tourId.version;
    await prefs.setBool(_completedKey(tourId), true);
    await prefs.setBool(_skippedKey(tourId), false);
    await prefs.setInt(_versionKey(tourId), v);
    await prefs.remove(_lastStepKey(tourId));
    EnterpriseOperationsLogger.log(
      domain: 'tutorial',
      operation: 'mark_completed',
      phase: 'COMPLETE',
      userId: _userId,
      params: {'tourId': tourId.storageKey, 'version': v},
    );
  }

  static Future<void> markSkipped(TourId tourId, {int? version}) async {
    final prefs = await SharedPreferences.getInstance();
    final v = version ?? tourId.version;
    await prefs.setBool(_skippedKey(tourId), true);
    await prefs.setBool(_completedKey(tourId), true);
    await prefs.setInt(_versionKey(tourId), v);
    await prefs.remove(_lastStepKey(tourId));
  }

  static Future<int> getLastStep(TourId tourId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_lastStepKey(tourId)) ?? 0;
  }

  static Future<void> saveLastStep(TourId tourId, int step) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastStepKey(tourId), step);
  }

  static Future<void> resetTour(TourId tourId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_completedKey(tourId));
    await prefs.remove(_skippedKey(tourId));
    await prefs.remove(_lastStepKey(tourId));
    await prefs.remove(_versionKey(tourId));
  }

  static const _permanentSkipKey = 'tour_permanently_skipped';

  static Future<bool> isPermanentlySkipped() async {
    final prefs = await SharedPreferences.getInstance();
    final uid = _userId;
    final scopedKey =
        uid != null ? '${_permanentSkipKey}_$uid' : _permanentSkipKey;
    return prefs.getBool(scopedKey) ?? false;
  }

  static Future<void> setPermanentlySkipped(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    final uid = _userId;
    final scopedKey =
        uid != null ? '${_permanentSkipKey}_$uid' : _permanentSkipKey;
    await prefs.setBool(scopedKey, value);
    if (value) {
      await prefs.setBool(_autoEligibleKey(), false);
    }
  }

  static Future<void> resetAllTours() async {
    for (final id in TourId.values) {
      await resetTour(id);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_legacyCompleted);
    await prefs.remove(_legacyLastStep);
    await prefs.remove(_legacySkipped);
    await prefs.remove(_baselineKey());
  }

  // Legacy API (home tour)
  static Future<bool> isTourCompletedLegacy() => isTourCompleted(TourId.home);

  static Future<void> markCompletedLegacy() => markCompleted(TourId.home);

  static Future<void> markSkippedLegacy() => markSkipped(TourId.home);

  static Future<void> resetTourLegacy() => resetTour(TourId.home);
}
