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
  final RxList<Map<String, dynamic>> plans = <Map<String, dynamic>>[].obs;
  final RxBool isLoadingPlans = false.obs;

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
    fetchPlans();
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

  Map<String, dynamic>? get monthlyPlan {
    return plans.firstWhereOrNull((p) {
      final monthly = (p['price_monthly'] as num?)?.toDouble() ?? 0.0;
      final name = (p['name'] as String? ?? '').toLowerCase();
      return monthly > 0 || name.contains('شهر') || name.contains('month');
    });
  }

  Map<String, dynamic>? get yearlyPlan {
    return plans.firstWhereOrNull((p) {
      final yearly = (p['price_yearly'] as num?)?.toDouble() ?? 0.0;
      final name = (p['name'] as String? ?? '').toLowerCase();
      return yearly > 0 || name.contains('سنو') || name.contains('year');
    });
  }

  Future<void> fetchPlans() async {
    isLoadingPlans.value = true;
    final stopwatch = Stopwatch()..start();
    try {
      final response = await SupabaseService.client
          .from('subscription_plans')
          .select()
          .eq('is_active', true)
          .order('created_at', ascending: true);

      plans.value = List<Map<String, dynamic>>.from(response);

      SafeGetx.debugTrace(
        className: 'SubscriptionController',
        method: 'fetchPlans',
        feature: 'Home',
        status: 'SUCCESS',
        params: {'plansCount': plans.length},
        durationMs: stopwatch.elapsedMilliseconds,
      );
    } catch (e, stack) {
      SafeGetx.debugTrace(
        className: 'SubscriptionController',
        method: 'fetchPlans',
        feature: 'Home',
        status: 'ERROR',
        durationMs: stopwatch.elapsedMilliseconds,
        error: e,
        stackTrace: stack,
      );
    } finally {
      isLoadingPlans.value = false;
    }
  }

  String getPlanPrice({required bool isYearly}) {
    if (isYearly) {
      final p = yearlyPlan;
      if (p != null) {
        final val = (p['price_yearly'] as num?)?.toDouble();
        if (val != null && val > 0) {
          return '\$${val.toStringAsFixed(2)}';
        }
      }
      return 'price_year'.tr;
    } else {
      final p = monthlyPlan;
      if (p != null) {
        final val = (p['price_monthly'] as num?)?.toDouble();
        if (val != null && val > 0) {
          return '\$${val.toStringAsFixed(2)}';
        }
      }
      return 'price_month'.tr;
    }
  }

  List<String> getPlanFeatures({required bool isYearly}) {
    final plan = isYearly ? yearlyPlan : monthlyPlan;
    final isArabic = Get.locale?.languageCode != 'en';

    if (plan != null && plan['features'] != null) {
      final rawFeatures = plan['features'];
      if (rawFeatures is List && rawFeatures.isNotEmpty) {
        final parsed = <String>[];
        for (final item in rawFeatures) {
          if (item is Map) {
            final text = (isArabic ? item['ar'] : item['en'])?.toString() ??
                item['ar']?.toString() ??
                item['en']?.toString();
            if (text != null && text.trim().isNotEmpty) {
              parsed.add(text.trim());
            }
          } else if (item is String && item.trim().isNotEmpty) {
            parsed.add(item.trim());
          }
        }
        if (parsed.isNotEmpty) return parsed;
      }
    }

    return _getDefaultFeatures(isYearly: isYearly, isArabic: isArabic);
  }

  List<String> _getDefaultFeatures({
    required bool isYearly,
    required bool isArabic,
  }) {
    if (isYearly) {
      return isArabic
          ? [
              'تفعيل عداد الربح 24 ساعة لمدة 365 يومًا',
              'إعادة تشغيل دورات الاستثمار تلقائيًا طوال مدة الاشتراك',
              'استثمارات غير محدودة',
              'أولوية قصوى في معالجة السحب والعمليات',
              'دعم VIP مخصص',
              'مكافآت ومزايا حصرية على مدار العام',
              'وصول مبكر إلى الميزات والخدمات الجديدة',
              'مزايا Premium مستمرة طوال السنة',
            ]
          : [
              'Activate 24-hour profit timer for 365 days',
              'Automatic investment cycle restarts during active subscription',
              'Unlimited active investments',
              'Highest priority processing for withdrawals & operations',
              'Dedicated VIP customer support',
              'Exclusive bonuses & perks all year round',
              'Early access to new features and services',
              'Continuous Premium benefits throughout the year',
            ];
    } else {
      return isArabic
          ? [
              'تفعيل عداد الربح 24 ساعة لمدة 30 يومًا',
              'إعادة تشغيل دورات الاستثمار تلقائيًا طوال مدة الاشتراك',
              'استثمارات غير محدودة',
              'أولوية السحب ومعالجة الطلبات خلال ساعتين',
              'دعم فني سريع على مدار الساعة',
              'مكافآت ومزايا حصرية للمشتركين',
            ]
          : [
              'Activate 24-hour profit timer for 30 days',
              'Automatic investment cycle restarts during active subscription',
              'Unlimited active investments',
              'Priority withdrawals & request processing within 2 hours',
              '24/7 fast-response technical support',
              'Exclusive subscriber bonuses and privileges',
            ];
    }
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
