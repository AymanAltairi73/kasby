import 'package:get/get.dart';
import 'package:kasby/core/services/supabase_service.dart';
import 'package:kasby/core/models/earnings_analytics_model.dart';
import 'package:kasby/core/utils/safe_getx.dart';
import 'package:kasby/core/events/earnings_events.dart';

/// Earnings Analytics Controller
/// Manages earnings analytics data, filtering, and automatic refresh
class EarningsAnalyticsController extends GetxController {
  static EarningsAnalyticsController get to => Get.find();

  // Analytics data
  final Rx<EarningsAnalyticsModel?> analytics = Rx<EarningsAnalyticsModel?>(
    null,
  );
  final RxBool isLoading = false.obs;
  final RxBool hasError = false.obs;
  final RxString errorMessage = ''.obs;

  // Period filter
  final RxString selectedPeriod = 'today'.obs;
  final Rx<DateTime?> customStartDate = Rx<DateTime?>(null);
  final Rx<DateTime?> customEndDate = Rx<DateTime?>(null);

  // Event listener
  Function()? _earningsCallback;

  // Available periods
  static const List<String> periods = [
    'today',
    'last_24h',
    'last_7d',
    'last_30d',
    'this_month',
    'last_month',
    'custom',
  ];

  @override
  void onInit() {
    super.onInit();
    fetchEarningsAnalytics();
    _setupEventListeners();
  }

  @override
  void onClose() {
    _removeEventListeners();
    super.onClose();
  }

  /// Setup event listeners for automatic refresh
  void _setupEventListeners() {
    // Ensure EarningsEventService is registered
    if (!Get.isRegistered<EarningsEventService>()) {
      Get.put(EarningsEventService());
    }

    // Register callback to refresh analytics when earnings are updated
    _earningsCallback = () {
      fetchEarningsAnalytics();
    };

    EarningsEventService.to.onEarningsUpdated(_earningsCallback!);
  }

  /// Remove event listeners
  void _removeEventListeners() {
    if (_earningsCallback != null && Get.isRegistered<EarningsEventService>()) {
      EarningsEventService.to.removeCallback(_earningsCallback!);
    }
    _earningsCallback = null;
  }

  /// Fetch earnings analytics from server
  Future<void> fetchEarningsAnalytics() async {
    if (!SupabaseService.isLoggedIn) return;

    isLoading.value = true;
    hasError.value = false;
    errorMessage.value = '';

    try {
      final response = await SupabaseService.client.rpc(
        'get_earnings_analytics',
        params: {
          'p_period': selectedPeriod.value,
          'p_start_date': customStartDate.value?.toIso8601String(),
          'p_end_date': customEndDate.value?.toIso8601String(),
        },
      );

      if (response != null) {
        analytics.value = EarningsAnalyticsModel.fromJson(
          response as Map<String, dynamic>,
        );

        if (!analytics.value!.success) {
          hasError.value = true;
          errorMessage.value = analytics.value!.error ?? 'unknown_error'.tr;
        }
      } else {
        hasError.value = true;
        errorMessage.value = 'no_data_received'.tr;
      }
    } catch (e, stack) {
      hasError.value = true;
      errorMessage.value = 'error_loading_analytics'.tr;
      SafeGetx.debugTrace(
        className: 'EarningsAnalyticsController',
        method: 'fetchEarningsAnalytics',
        feature: 'Earnings',
        status: 'ERROR',
        error: e,
        stackTrace: stack,
      );
    } finally {
      isLoading.value = false;
    }
  }

  /// Change period filter and refresh data
  void changePeriod(String period) {
    selectedPeriod.value = period;
    fetchEarningsAnalytics();
  }

  /// Set custom date range and refresh data
  void setCustomDateRange(DateTime start, DateTime end) {
    customStartDate.value = start;
    customEndDate.value = end;
    selectedPeriod.value = 'custom';
    fetchEarningsAnalytics();
  }

  /// Refresh analytics data
  @override
  Future<void> refresh() async {
    await fetchEarningsAnalytics();
  }

  /// Get total earnings in USD (including KSP conversion)
  double getTotalEarningsUsd() {
    if (analytics.value?.summary == null) return 0.0;
    final summary = analytics.value!.summary!;
    // Convert KSP to USD: 1 KSP = 0.001 USD
    return summary.totalEarningsUsd + (summary.totalEarningsKsp * 0.001);
  }

  /// Get today's earnings in USD (including KSP conversion)
  double getTodayEarningsUsd() {
    if (analytics.value?.statistics == null) return 0.0;
    final stats = analytics.value!.statistics!;
    return stats.todayEarningsUsd + (stats.todayEarningsKsp * 0.001);
  }

  /// Get last 24h earnings in USD (including KSP conversion)
  double getLast24hEarningsUsd() {
    if (analytics.value?.statistics == null) return 0.0;
    final stats = analytics.value!.statistics!;
    return stats.last24hEarningsUsd + (stats.last24hEarningsKsp * 0.001);
  }

  /// Get breakdown with KSP converted to USD
  List<BreakdownItem> getBreakdownWithConversion() {
    if (analytics.value == null) return [];

    return analytics.value!.breakdown.map((item) {
      final totalUsd = item.getTotalUsdEquivalent();
      final totalEarnings = getTotalEarningsUsd();
      final percentage = totalEarnings > 0
          ? (totalUsd / totalEarnings * 100)
          : 0.0;

      return BreakdownItem(
        source: item.source,
        amountUsd: item.amountUsd,
        amountKsp: item.amountKsp,
        percentage: percentage,
      );
    }).toList();
  }

  /// Get localized period name
  String getLocalizedPeriodName(String period) {
    switch (period) {
      case 'today':
        return 'today'.tr;
      case 'last_24h':
        return 'last_24h'.tr;
      case 'last_7d':
        return 'last_7d'.tr;
      case 'last_30d':
        return 'last_30d'.tr;
      case 'this_month':
        return 'this_month'.tr;
      case 'last_month':
        return 'last_month'.tr;
      case 'custom':
        return 'custom'.tr;
      default:
        return period;
    }
  }
}
