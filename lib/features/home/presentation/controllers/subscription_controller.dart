import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:kasby/core/services/supabase_service.dart';
import 'package:kasby/core/services/snack_service.dart';
import 'package:kasby/features/home/presentation/controllers/home_controller.dart';
import 'package:kasby/core/theme/app_colors.dart';
import 'package:kasby/core/services/fcm_service.dart';
import 'package:kasby/core/services/referral_service.dart';

class SubscriptionController extends GetxController {
  static SubscriptionController get to => Get.find();

  final RxBool isLoading = false.obs;
  final RxMap<String, dynamic> activeSubscription = <String, dynamic>{}.obs;
  final RxString countdownText = ''.obs;
  final RxBool isFreePlanActivationAvailable = true.obs;
  final RxDouble remainingPercentage = 0.0.obs;
  final Rx<Color> countdownColor = AppColors.softGreen.obs;
  
  Timer? _timer;
  bool _notifiedExpiry = false;

  void _log(String message, {bool isError = false}) {
    debugPrint('[SUBSCRIPTION] ${isError ? "❌" : "ℹ️"} $message');
  }

  @override
  void onInit() {
    super.onInit();
    fetchActiveSubscription();
    _startCountdownTimer();
  }

  @override
  void onClose() {
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
      isFreePlanActivationAvailable.value = true;
      remainingPercentage.value = 0.0;
      _notifiedExpiry = false;
      return;
    }

    final String? startStr = activeSubscription['start_date'];
    final String? endStr = activeSubscription['end_date'];
    if (endStr == null) return;

    final DateTime startDate = startStr != null ? DateTime.parse(startStr).toLocal() : DateTime.now().subtract(const Duration(days: 1));
    final DateTime endDate = DateTime.parse(endStr).toLocal();
    final DateTime now = DateTime.now();
    
    final Duration total = endDate.difference(startDate);
    final Duration remaining = endDate.difference(now);

    if (remaining.isNegative) {
      countdownText.value = '';
      isFreePlanActivationAvailable.value = true;
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
      isFreePlanActivationAvailable.value = false;
      
      // Calculate Percentage
      final double percent = (remaining.inSeconds / total.inSeconds.clamp(1, 99999999)).clamp(0.0, 1.0);
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

      String timeStr = '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
      if (days > 0) {
        countdownText.value = '${'days_label'.trParams({'count': days.toString()})} $timeStr';
      } else {
        countdownText.value = timeStr;
      }
    }
  }

  void _showExpiryNotification() {
    final String tier = activeSubscription['tier'] ?? 'free';
    final String title = tier == 'free' ? 'free_plan_ended'.tr : 'subscription_ended'.tr;
    final String body = tier == 'free' ? 'free_plan_ended_desc'.tr : 'subscription_ended_desc'.tr;
    
    FCMService.to.showNotification(
      title: title,
      body: body,
    );
  }

  Future<void> fetchActiveSubscription() async {
    if (!SupabaseService.isLoggedIn) return;
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
        isFreePlanActivationAvailable.value = true;
      }
    } catch (e) {
      _log('Error fetching subscription: $e', isError: true);
    }
  }

  Future<void> activateFreePlan() async {
    if (activeSubscription.isNotEmpty) {
      _showActiveSubscriptionWarning();
      return;
    }

    isLoading.value = true;
    try {
      final response = await SupabaseService.client.rpc('activate_free_plan');

      if (response['success'] == true) {
        HapticFeedback.mediumImpact();
        AppSnack.success('success'.tr, 'free_plan_activated'.tr);

        await HomeController.to.fetchProfile();
        await fetchActiveSubscription();
      } else {
        AppSnack.error('error'.tr, response['error']?.toString() ?? 'unknown_error'.tr);
      }
    } catch (e) {
      _log('Error activating free plan: $e', isError: true);
      AppSnack.error('error'.tr, 'unknown_error'.tr);
    } finally {
      isLoading.value = false;
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
          investmentId: 'sub_${DateTime.now().millisecondsSinceEpoch}', // Unique ID for idempotency
        );

        Get.back();
      } else {
        AppSnack.error('error'.tr, response['error']?.toString() ?? 'unknown_error'.tr);
      }
    } catch (e) {
      _log('Error buying subscription: $e', isError: true);
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
        title: Text('subscription_active_title'.tr, style: TextStyle(color: AppColors.onSurface)),
        content: Text('subscription_active_desc'.tr, style: TextStyle(color: AppColors.textSecondary)),
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
