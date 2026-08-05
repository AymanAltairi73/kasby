import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:kasby/core/services/supabase_service.dart';
import 'package:kasby/core/services/snack_service.dart';
import 'package:kasby/core/utils/safe_getx.dart';
import 'package:kasby/features/home/presentation/controllers/home_controller.dart';
import 'package:kasby/core/theme/app_colors.dart';
import 'package:kasby/core/services/fcm_service.dart';
import 'package:kasby/core/services/referral_service.dart';

class SubscriptionController extends GetxController {
  static SubscriptionController get to => Get.find();

  final RxBool isLoading = false.obs;
  final RxMap<String, dynamic> activeSubscription = <String, dynamic>{}.obs;
  final RxString countdownText = ''.obs;
  final RxDouble remainingPercentage = 0.0.obs;
  final Rx<Color> countdownColor = AppColors.softGreen.obs;

  Timer? _timer;
  bool _notifiedExpiry = false;

  @override
  void onInit() {
    SafeGetx.debugTrace(
      className: 'SubscriptionController',
      method: 'onInit',
      feature: 'Home',
      status: 'INFO',
    );
    super.onInit();
    fetchActiveSubscription();
    _startCountdownTimer();
  }

  @override
  void onClose() {
    SafeGetx.debugTrace(
      className: 'SubscriptionController',
      method: 'onClose',
      feature: 'Home',
      status: 'INFO',
    );
    _timer?.cancel();
    super.onClose();
  }

  void _startCountdownTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _updateCountdown();
    });
  }

  void _updateCountdown() {
    if (activeSubscription.isEmpty) {
      countdownText.value = '';
      remainingPercentage.value = 0.0;
      _notifiedExpiry = false;
      return;
    }

    final String? startStr = activeSubscription['start_date'];
    final String? endStr = activeSubscription['end_date'];
    if (endStr == null) return;

    final DateTime startDate = startStr != null
        ? DateTime.parse(startStr).toLocal()
        : DateTime.now().subtract(const Duration(days: 1));
    final DateTime endDate = DateTime.parse(endStr).toLocal();
    final DateTime now = DateTime.now();

    final Duration total = endDate.difference(startDate);
    final Duration remaining = endDate.difference(now);

    if (remaining.isNegative) {
      countdownText.value = '';
      remainingPercentage.value = 0.0;

      if (!_notifiedExpiry && activeSubscription['status'] == 'active') {
        _notifiedExpiry = true;
        _showExpiryNotification();
      }

      if (activeSubscription['status'] == 'active') {
        fetchActiveSubscription();
      }
    } else {
      _notifiedExpiry = false;

      // Calculate Percentage
      final double percent =
          (remaining.inSeconds / total.inSeconds.clamp(1, 99999999)).clamp(
            0.0,
            1.0,
          );
      remainingPercentage.value = percent;

      // Determine Color
      if (remaining.inHours > 24) {
        countdownColor.value = AppColors.softGreen;
      } else if (remaining.inHours > 1) {
        countdownColor.value = Colors.amber;
      } else {
        countdownColor.value = AppColors.error;
      }

      // Format Countdown Text
      final int days = remaining.inDays;
      final int hours = remaining.inHours.remainder(24);
      final int minutes = remaining.inMinutes.remainder(60);
      final int seconds = remaining.inSeconds.remainder(60);

      String timeStr =
          '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
      if (days > 0) {
        countdownText.value =
            '${'days_label'.trParams({'count': days.toString()})} $timeStr';
      } else {
        countdownText.value = timeStr;
      }
    }
  }

  void _showExpiryNotification() {
    FCMService.to.showNotification(
      title: 'subscription_ended'.tr,
      body: 'subscription_ended_desc'.tr,
    );
  }

  Future<void> fetchActiveSubscription() async {
    if (!SupabaseService.isLoggedIn) return;
    final stopwatch = Stopwatch()..start();
    try {
      final response = await SupabaseService.client
          .from('subscriptions')
          .select()
          .eq('user_id', SupabaseService.userId!)
          .eq('status', 'active')
          .order('end_date', ascending: false)
          .maybeSingle();

      if (response != null) {
        activeSubscription.value = response;
        _updateCountdown();
      } else {
        activeSubscription.clear();
      }
      SafeGetx.debugTrace(
        className: 'SubscriptionController',
        method: 'fetchActiveSubscription',
        feature: 'Home',
        status: 'SUCCESS',
        params: {'hasActive': response != null},
        durationMs: stopwatch.elapsedMilliseconds,
      );
    } catch (e, stack) {
      SafeGetx.debugTrace(
        className: 'SubscriptionController',
        method: 'fetchActiveSubscription',
        feature: 'Home',
        status: 'ERROR',
        durationMs: stopwatch.elapsedMilliseconds,
        error: e,
        stackTrace: stack,
      );
    }
  }

  Future<void> buySubscription({
    required bool isYearly,
    String tier = 'vip',
  }) async {
    if (activeSubscription.isNotEmpty) {
      _showActiveSubscriptionWarning();
      return;
    }

    isLoading.value = true;
    final stopwatch = Stopwatch()..start();
    try {
      final response = await SupabaseService.client.rpc(
        'buy_subscription',
        params: {'p_tier': tier, 'p_is_yearly': isYearly},
      );

      if (response['success'] == true) {
        HapticFeedback.heavyImpact();
        AppSnack.success('success'.tr, 'subscription_activated'.tr);

        await HomeController.to.fetchProfile();
        await fetchActiveSubscription();

        // Process referral commission for subscription
        final amount = isYearly ? 89.0 : 9.0;
        ReferralService.processReferralCommission(
          investmentAmount: amount,
          investmentId:
              'sub_${DateTime.now().millisecondsSinceEpoch}', // Unique ID for idempotency
        );

        SafeGetx.debugTrace(
          className: 'SubscriptionController',
          method: 'buySubscription',
          feature: 'Home',
          status: 'SUCCESS',
          params: {'tier': tier, 'isYearly': isYearly},
          durationMs: stopwatch.elapsedMilliseconds,
        );
        Get.back();
      } else {
        SafeGetx.debugTrace(
          className: 'SubscriptionController',
          method: 'buySubscription',
          feature: 'Home',
          status: 'ERROR',
          message: response['error']?.toString(),
          durationMs: stopwatch.elapsedMilliseconds,
        );
        AppSnack.error(
          'error'.tr,
          response['error']?.toString() ?? 'unknown_error'.tr,
        );
      }
    } catch (e, stack) {
      SafeGetx.debugTrace(
        className: 'SubscriptionController',
        method: 'buySubscription',
        feature: 'Home',
        status: 'ERROR',
        durationMs: stopwatch.elapsedMilliseconds,
        error: e,
        stackTrace: stack,
      );
      AppSnack.error('error'.tr, 'unknown_error'.tr);
    } finally {
      isLoading.value = false;
    }
  }

  void _showActiveSubscriptionWarning() {
    Get.dialog(
      AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'subscription_active_title'.tr,
          style: TextStyle(color: AppColors.onSurface),
        ),
        content: Text(
          'subscription_active_desc'.tr,
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('ok'.tr, style: TextStyle(color: AppColors.darkGold)),
          ),
        ],
      ),
    );
  }
}
