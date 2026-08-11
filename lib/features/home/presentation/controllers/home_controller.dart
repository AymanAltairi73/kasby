import 'dart:async';
import 'dart:math' show Random;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:kasby/core/services/supabase_service.dart';
import 'package:kasby/core/models/profile_model.dart';
import 'package:kasby/core/models/transaction_model.dart';
import 'package:kasby/core/models/notification_model.dart';
import 'package:kasby/core/models/user_investment_model.dart';
import 'package:kasby/core/models/investment_plan_model.dart';
import 'package:kasby/core/controllers/currency_controller.dart';
import 'package:kasby/core/models/dashboard_model.dart';

import 'package:kasby/core/services/account_restriction_service.dart';
import 'package:kasby/core/services/notification_service.dart';
import 'package:kasby/core/theme/app_colors.dart';
import 'package:kasby/core/services/fcm_service.dart';
import 'package:kasby/core/services/notification_navigation_service.dart';
import 'package:kasby/core/services/referral_service.dart';
import 'package:kasby/core/services/snack_service.dart';
import 'package:kasby/core/services/crash_reporting_service.dart';
import 'package:kasby/core/utils/safe_getx.dart';
import 'package:kasby/core/services/ksp_balance_service.dart';
import 'package:kasby/core/services/fee_service.dart';
import 'package:kasby/features/auth/presentation/controllers/auth_controller.dart';
import 'package:kasby/core/services/enterprise_operations_logger.dart';
import 'package:kasby/routes/app_routes.dart';
import 'package:kasby/core/events/earnings_events.dart';

/// Central controller for the Home & Wallet screens.
/// Fetches profile data, recent transactions, and notification count.
class HomeController extends GetxController with WidgetsBindingObserver {
  static HomeController get to => Get.find();

  // Profile & Dashboard
  final Rx<ProfileModel?> profile = Rx<ProfileModel?>(null);
  final Rx<DashboardModel?> dashboard = Rx<DashboardModel?>(null);
  final RxBool isLoadingProfile = false.obs;
  final RxBool isLoadingDashboard = false.obs;

  // Transactions
  final RxList<TransactionModel> recentTransactions = <TransactionModel>[].obs;
  final RxBool isLoadingTransactions = false.obs;

  // Notifications
  final RxInt unreadNotificationCount = 0.obs;
  final RxList<NotificationModel> notifications = <NotificationModel>[].obs;
  final RxList<UserInvestmentModel> myInvestments = <UserInvestmentModel>[].obs;
  final RxList<InvestmentPlanModel> allInvestmentPlans =
      <InvestmentPlanModel>[].obs;
  final RxBool isLoadingNotifications = false.obs;
  final RxBool isLoadingMoreNotifications = false.obs;
  final RxInt notificationTotalCount = 0.obs;
  final RxInt notificationPage = 0.obs;
  static const int notificationPageSize = 50;
  final RxBool isLoadingInvestments = false.obs;
  final RxBool hasError = false.obs;

  // KSP (Effective = wallet_ksp + reward_ksp)
  final RxInt userPoints = 0.obs; // effective KSP — backward-compatible name
  final RxInt rewardKsp = 0.obs;
  final RxInt walletKsp = 0.obs;
  final RxInt totalEarnedKsp = 0.obs;
  final RxInt totalSpentKsp = 0.obs;
  final RxBool isLoadingPoints = false.obs;

  // Transfer Recipients (recent)
  final RxList<Map<String, String>> recentRecipients =
      <Map<String, String>>[].obs;

  // Portfolio insights (home dashboard sparkline)
  final RxString portfolioPeriod = '7D'.obs;

  // Pending Rewards & Investment Timers
  final RxList<Map<String, dynamic>> pendingRewards =
      <Map<String, dynamic>>[].obs;
  final Rx<DateTime?> nextRewardRelease = Rx<DateTime?>(null);
  final RxString rewardCountdownText = ''.obs;
  final RxBool isProcessingUI = false.obs;
  final RxBool canClaimRewards = false.obs;
  final RxBool isClaimingLoading = false.obs;

  // Per-investment countdowns [InvestmentID -> CountdownText]
  final RxMap<String, String> investmentCountdowns = <String, String>{}.obs;

  // Loading states for starting next cycle and toggling auto-restart
  final RxMap<String, bool> cycleRestartLoading = <String, bool>{}.obs;
  final RxMap<String, bool> autoRestartToggleLoading = <String, bool>{}.obs;

  Timer? _rewardTimer;
  Timer? _notificationReconnectTimer;
  Timer? _profileReconnectTimer;
  Timer? _transactionReconnectTimer;
  Timer? _investmentReconnectTimer;
  Timer? _pointsReconnectTimer;
  Timer? _lifecycleReconnectTimer;
  bool _streamsStarted = false;

  // Exponential backoff for reconnection (1s -> 2s -> 4s -> ... -> 60s max)
  Duration _reconnectDelay = const Duration(seconds: 1);

  Timer _scheduleReconnect(void Function() reconnect) {
    final delay = _reconnectDelay;
    _reconnectDelay = Duration(
      seconds: (_reconnectDelay.inSeconds * 2).clamp(2, 60),
    );
    final jitterMs = Random().nextInt(1000);
    return Timer(delay + Duration(milliseconds: jitterMs), reconnect);
  }

  void _resetBackoff() {
    _reconnectDelay = const Duration(seconds: 1);
  }

  // Convenience getters
  String get profileName => profile.value?.fullName ?? '';
  String get profileEmail => profile.value?.email ?? '';
  String get accountTier =>
      dashboard.value?.accountTier ?? profile.value?.accountTier ?? 'free';
  String get kycStatus =>
      profile.value?.kycStatus ?? dashboard.value?.kycStatus ?? 'none';
  int get pointsBalance => userPoints.value;
  int get effectiveKsp => userPoints.value;
  double get dailyProfit {
    final fromDashboard = dashboard.value?.dailyProfit;
    if (fromDashboard != null && fromDashboard > 0) return fromDashboard;
    if (Get.isRegistered<CurrencyController>()) {
      return CurrencyController.to.profitBalance.value;
    }
    return 0.0;
  }

  double get profitPercentage => dashboard.value?.profitPercentage ?? 0.0;
  String get referralCode =>
      ReferralService.formatDisplayCode(profile.value?.referralCode);

  int get _portfolioPeriodDays {
    switch (portfolioPeriod.value) {
      case '30D':
        return 30;
      case '90D':
        return 90;
      default:
        return 7;
    }
  }

  double get _currentPortfolioValue {
    if (!Get.isRegistered<CurrencyController>()) return 0;
    final c = CurrencyController.to;
    return c.totalBalance.value +
        c.investedBalance.value +
        c.profitBalance.value;
  }

  /// Cumulative portfolio value curve for the selected period.
  List<double> get portfolioSparklineData {
    final days = _portfolioPeriodDays;
    final cutoff = DateTime.now().subtract(Duration(days: days));
    final current = _currentPortfolioValue;

    final txs =
        recentTransactions
            .where(
              (t) =>
                  t.createdAt != null &&
                  !t.createdAt!.isBefore(cutoff) &&
                  t.status == 'completed',
            )
            .toList()
          ..sort((a, b) => a.createdAt!.compareTo(b.createdAt!));

    if (txs.isEmpty) {
      if (current <= 0) return const [0, 0];
      const points = 8;
      final start = current * 0.92;
      return List.generate(
        points,
        (i) => start + (current - start) * i / (points - 1),
      );
    }

    var running = current;
    final values = <double>[running];
    for (final tx in txs.reversed) {
      running -= tx.isCredit ? tx.amount : -tx.amount;
      values.add(running);
    }
    final points = values.reversed.toList();

    if (points.length < 2) {
      return [points.first * 0.95, points.first];
    }
    return points;
  }

  double get portfolioGrowthPercent {
    final data = portfolioSparklineData;
    if (data.length < 2) return 0;
    final first = data.first;
    final last = data.last;
    if (first.abs() < 0.001) return last > 0 ? 100 : 0;
    return ((last - first) / first.abs()) * 100;
  }

  /// Translation key for the personalized financial insight card.
  String get financialInsightKey {
    if (kycStatus != 'verified') return 'complete_kyc_desc';

    if (!Get.isRegistered<CurrencyController>()) {
      return 'portfolio_insight_growth';
    }

    final c = CurrencyController.to;
    final available = c.totalBalance.value;
    final invested = c.investedBalance.value;

    if (available > 50 && invested < available * 0.3) {
      return 'portfolio_insight_reinvest';
    }
    if (myInvestments.length >= 3) return 'portfolio_insight_diversify';
    if (portfolioGrowthPercent > 0.5) return 'portfolio_insight_growth';
    if (myInvestments.isEmpty && available > 0) {
      return 'portfolio_insight_reinvest';
    }
    return 'portfolio_insight_growth';
  }

  @override
  void onInit() {
    debugPrint(
      '[PROFIT_LIFECYCLE] event: initialized | investment_count: ${myInvestments.length}',
    );
    SafeGetx.debugTrace(
      className: 'HomeController',
      method: 'onInit',
      feature: 'Home',
      status: 'INFO',
    );
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    if (SupabaseService.isLoggedIn) {
      unawaited(_bootstrapData());
    }
  }

  Future<void> _bootstrapData() async {
    await fetchAll();
    if (!SupabaseService.isLoggedIn) return;
    // Defer realtime until REST bootstrap completes to avoid channel storms.
    Future.delayed(const Duration(seconds: 2), _startRealtimeListeners);
    CurrencyController.to.startWalletListener(
      delay: const Duration(seconds: 3),
    );
  }

  void _startRealtimeListeners() {
    if (_streamsStarted || !SupabaseService.isLoggedIn) return;
    _streamsStarted = true;
    _resetBackoff();
    _listenToNotifications();
    Future.delayed(const Duration(seconds: 2), _listenToProfile);
    Future.delayed(const Duration(seconds: 3), _listenToPlans);
    Future.delayed(const Duration(seconds: 5), _listenToTransactions);
    Future.delayed(const Duration(seconds: 7), _listenToInvestments);
    Future.delayed(const Duration(seconds: 9), _listenToPoints);
    _setupEarningsListener();
  }

  bool _isRealtimeTimeout(Object error) {
    final str = error.toString();
    return str.contains('RealtimeSubscribeStatus.timedOut') ||
        str.contains('RealtimeSubscribeException') ||
        str.contains('channelError') ||
        str.contains('Unable to subscribe');
  }

  // ─── NOTIFICATION LISTENER ──────────────────────────────
  StreamSubscription? _notificationSubscription;
  bool _isInitialLoad = true;
  final _pendingNotifications = <NotificationModel>[].obs;
  Timer? _batchTimer;

  void _listenToNotifications() {
    if (!SupabaseService.isLoggedIn) return;

    _notificationReconnectTimer?.cancel();
    _notificationSubscription?.cancel();
    _notificationSubscription = SupabaseService.client
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', SupabaseService.userId!)
        .order('created_at', ascending: false)
        .listen(
          (data) {
            final newList = data
                .map((json) => NotificationModel.fromJson(json))
                .toList();

            if (!_isInitialLoad && newList.length > notifications.length) {
              final newItems = newList
                  .where((n) => !notifications.any((old) => old.id == n.id))
                  .toList();

              for (var item in newItems) {
                if (!item.isRead &&
                    FCMService.to.isNotificationsEnabled.value) {
                  _pendingNotifications.add(item);
                }
              }

              if (_pendingNotifications.isNotEmpty) {
                _startBatchTimer();
              }
            }

            _isInitialLoad = false;
            notifications.value = newList;
            unreadNotificationCount.value = newList
                .where((n) => !n.isRead)
                .length;
            _resetBackoff();
          },
          onError: (error, stack) {
            final isSuppressed = _isRealtimeTimeout(error);
            _log(
              isSuppressed
                  ? 'Notifications stream connection deferred'
                  : 'Notifications stream error',
              method: '_listenToNotifications',
              isError: !isSuppressed,
              isWarn: isSuppressed,
              error: isSuppressed ? null : error,
              stackTrace: isSuppressed ? null : stack,
            );
            _notificationReconnectTimer?.cancel();
            _notificationReconnectTimer = _scheduleReconnect(
              _listenToNotifications,
            );
          },
        );
  }

  void _startBatchTimer() {
    _batchTimer?.cancel();
    _batchTimer = Timer(const Duration(milliseconds: 1500), () {
      if (_pendingNotifications.isEmpty) return;

      NotificationService().playNotificationSound();

      if (_pendingNotifications.length == 1) {
        final latest = _pendingNotifications.first;
        _showNotificationSnack(latest);
      } else {
        _showMultipleNotificationsSnack(_pendingNotifications.length);
      }
      _pendingNotifications.clear();
    });
  }

  void _showNotificationSnack(NotificationModel notification) {
    SafeGetx.snackbar(
      title: notification.title,
      message: notification.message,
      snackPosition: SnackPosition.TOP,
      backgroundColor: AppColors.surface.withValues(alpha: 0.9),
      colorText: Colors.white,
      icon: Icon(Icons.notifications_active_rounded, color: AppColors.darkGold),
      margin: const EdgeInsets.all(12),
      borderRadius: 16,
      duration: const Duration(seconds: 4),
      onTap: (_) => navigateFromNotification(notification),
    );
  }

  void _showMultipleNotificationsSnack(int count) {
    SafeGetx.snackbar(
      title: 'notifications'.tr,
      message: 'you_have_multiple_notifications'.trParams({
        'count': count.toString(),
      }),
      snackPosition: SnackPosition.TOP,
      backgroundColor: AppColors.surface.withValues(alpha: 0.9),
      colorText: Colors.white,
      icon: Icon(Icons.notifications_active_rounded, color: AppColors.darkGold),
      margin: const EdgeInsets.all(12),
      borderRadius: 16,
      duration: const Duration(seconds: 4),
      onTap: (_) => NotificationNavigationService.navigateFromPayload({
        'type': 'notification',
        'route': '/notifications',
      }, fromUserTap: true),
    );
  }

  // ─── PROFILE LISTENER ──────────────────────────────────
  StreamSubscription? _profileSubscription;

  void _listenToProfile() {
    if (!SupabaseService.isLoggedIn) return;

    _profileReconnectTimer?.cancel();
    _profileSubscription?.cancel();
    _profileSubscription = SupabaseService.client
        .from('profiles')
        .stream(primaryKey: ['id'])
        .eq('id', SupabaseService.userId!)
        .listen(
          (data) {
            if (data.isNotEmpty) {
              final json = data.first;
              final previousKyc = profile.value?.kycStatus;
              final previousStatus = profile.value?.status;
              profile.value = ProfileModel.fromJson(json);
              if (Get.isRegistered<AccountRestrictionService>()) {
                AccountRestrictionService.to.onProfileUpdated();
              }
              unawaited(
                onProfileFieldsChanged(
                  previousKycStatus: previousKyc,
                  previousStatus: previousStatus,
                ),
              );
              _resetBackoff();
              _log(
                'Profile updated via real-time stream',
                method: '_listenToProfile',
                params: {
                  'kycStatus': profile.value?.kycStatus,
                  'status': profile.value?.status,
                },
              );
            }
          },
          onError: (error, stack) {
            final isSuppressed = _isRealtimeTimeout(error);
            _log(
              isSuppressed
                  ? 'Profile stream connection deferred'
                  : 'Profile stream error',
              method: '_listenToProfile',
              isError: !isSuppressed,
              isWarn: isSuppressed,
              error: isSuppressed ? null : error,
              stackTrace: isSuppressed ? null : stack,
            );
            _profileReconnectTimer?.cancel();
            _profileReconnectTimer = _scheduleReconnect(_listenToProfile);
          },
        );
  }

  // ─── TRANSACTIONS LISTENER ────────────────────────────
  StreamSubscription? _transactionSubscription;

  void _listenToTransactions() {
    if (!SupabaseService.isLoggedIn) return;

    _transactionReconnectTimer?.cancel();
    _transactionSubscription?.cancel();
    _transactionSubscription = SupabaseService.client
        .from('transactions')
        .stream(primaryKey: ['id'])
        .eq('user_id', SupabaseService.userId!)
        .order('created_at', ascending: false)
        .listen(
          (data) {
            recentTransactions.value = data
                .take(10)
                .map((json) => TransactionModel.fromJson(json))
                .toList();

            // Also update allTransactions if it's currently loaded
            if (allTransactions.isNotEmpty && selectedFilter.value == 'all') {
              fetchAllTransactions(reset: true);
            }
            _resetBackoff();
            _log(
              'Transactions updated via real-time stream',
              method: '_listenToTransactions',
            );
          },
          onError: (error, stack) {
            final isSuppressed = _isRealtimeTimeout(error);
            _log(
              isSuppressed
                  ? 'Transactions stream connection deferred'
                  : 'Transactions stream error',
              method: '_listenToTransactions',
              isError: !isSuppressed,
              isWarn: isSuppressed,
              error: isSuppressed ? null : error,
              stackTrace: isSuppressed ? null : stack,
            );
            _transactionReconnectTimer?.cancel();
            _transactionReconnectTimer = _scheduleReconnect(
              _listenToTransactions,
            );
          },
        );
  }

  // ─── INVESTMENTS LISTENER ─────────────────────────────
  StreamSubscription? _investmentSubscription;
  StreamSubscription? _plansSubscription;

  void _listenToPlans() {
    _plansSubscription?.cancel();
    _plansSubscription = SupabaseService.client
        .from('investment_plans')
        .stream(primaryKey: ['id'])
        .listen(
          (data) {
            allInvestmentPlans.value = data
                .map((json) => InvestmentPlanModel.fromJson(json))
                .toList();

            // Hydrate current myInvestments with updated plans if they are already loaded
            if (myInvestments.isNotEmpty) {
              myInvestments.value = myInvestments.map((inv) {
                final plan = allInvestmentPlans.firstWhereOrNull(
                  (p) => p.id == inv.planId,
                );
                return inv.copyWith(investment: plan);
              }).toList();
            }

            _log(
              'Investment plans cache updated via real-time stream',
              method: '_listenToPlans',
            );
          },
          onError: (error, stack) {
            final isSuppressed = _isRealtimeTimeout(error);
            _log(
              isSuppressed
                  ? 'Investment plans stream connection deferred'
                  : 'Investment plans stream error',
              method: '_listenToPlans',
              isError: !isSuppressed,
              isWarn: isSuppressed,
              error: isSuppressed ? null : error,
              stackTrace: isSuppressed ? null : stack,
            );
          },
        );
  }

  void _listenToInvestments() {
    if (!SupabaseService.isLoggedIn) return;

    _investmentReconnectTimer?.cancel();
    _investmentSubscription?.cancel();
    _investmentSubscription = SupabaseService.client
        .from('user_investments')
        .stream(primaryKey: ['id'])
        .eq('user_id', SupabaseService.userId!)
        .order('created_at', ascending: false)
        .listen(
          (data) {
            myInvestments.value = data.map((json) {
              final model = UserInvestmentModel.fromJson(json);
              final plan = allInvestmentPlans.firstWhereOrNull(
                (p) => p.id == model.planId,
              );
              return model.copyWith(investment: plan);
            }).toList();

            // Update countdowns whenever investments refresh
            _updateRewardDistributionInfo();
            _resetBackoff();
            debugPrint(
              '[PROFIT_REALTIME] event: investment_updated | investment_count: ${myInvestments.length}',
            );
            _log(
              'Investments updated via real-time stream',
              method: '_listenToInvestments',
            );
          },
          onError: (error, stack) {
            final isSuppressed = _isRealtimeTimeout(error);
            debugPrint(
              '[PROFIT_REALTIME] event: stream_error | error: $error',
            );
            _log(
              isSuppressed
                  ? 'Investments stream connection deferred'
                  : 'Investments stream error',
              method: '_listenToInvestments',
              isError: !isSuppressed,
              isWarn: isSuppressed,
              error: isSuppressed ? null : error,
              stackTrace: isSuppressed ? null : stack,
            );
            _investmentReconnectTimer?.cancel();
            _investmentReconnectTimer = _scheduleReconnect(
              _listenToInvestments,
            );
          },
        );
  }

  // ─── POINTS LISTENER ──────────────────────────────────
  StreamSubscription? _pointsSubscription;

  void _listenToPoints() {
    if (!SupabaseService.isLoggedIn) return;

    _pointsReconnectTimer?.cancel();
    _pointsSubscription?.cancel();
    _pointsSubscription = SupabaseService.client
        .from('user_points')
        .stream(primaryKey: ['user_id'])
        .eq('user_id', SupabaseService.userId!)
        .listen(
          (data) {
            if (data.isNotEmpty) {
              _resetBackoff();
              final row = data.first;
              totalEarnedKsp.value =
                  (row['total_earned'] as num?)?.toInt() ?? 0;
              totalSpentKsp.value = (row['total_spent'] as num?)?.toInt() ?? 0;
              if (Get.isRegistered<KspBalanceService>()) {
                unawaited(
                  KspBalanceService.to.refresh().then(
                    (_) => syncKspFromService(),
                  ),
                );
              }
              _log(
                'Points updated via real-time stream',
                method: '_listenToPoints',
                params: {'balance': userPoints.value},
              );
            }
          },
          onError: (error, stack) {
            final isSuppressed = _isRealtimeTimeout(error);
            _log(
              isSuppressed
                  ? 'Points stream connection deferred'
                  : 'Points stream error',
              method: '_listenToPoints',
              isError: !isSuppressed,
              isWarn: isSuppressed,
              error: isSuppressed ? null : error,
              stackTrace: isSuppressed ? null : stack,
            );
            _pointsReconnectTimer?.cancel();
            _pointsReconnectTimer = _scheduleReconnect(_listenToPoints);
          },
        );
  }

  /// Listen for earnings updates and refresh dashboard
  void _setupEarningsListener() {
    if (!Get.isRegistered<EarningsEventService>()) {
      Get.put(EarningsEventService());
    }

    // Register callback to refresh dashboard when earnings are updated
    EarningsEventService.to.onEarningsUpdated(() {
      fetchDashboard();
    });
  }

  void _log(
    String message, {
    String method = 'event',
    bool isError = false,
    bool isWarn = false,
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? params,
  }) {
    SafeGetx.debugTrace(
      className: 'HomeController',
      method: method,
      feature: 'Home',
      status: isError ? 'ERROR' : (isWarn ? 'WARN' : 'INFO'),
      message: message,
      params: params,
      error: error,
      stackTrace: stackTrace,
    );
  }

  /// Reconnect streams, useful when token is refreshed.
  void reconnectStreams() {
    SafeGetx.debugTrace(
      className: 'HomeController',
      method: 'reconnectStreams',
      feature: 'Home',
      status: 'INFO',
    );
    _streamsStarted = false;
    _resetBackoff();
    _startRealtimeListeners();
    CurrencyController.to.startWalletListener(
      delay: const Duration(seconds: 2),
    );
  }

  @override
  void onClose() {
    debugPrint(
      '[PROFIT_LIFECYCLE] event: disposed | investment_count: ${myInvestments.length}',
    );
    SafeGetx.debugTrace(
      className: 'HomeController',
      method: 'onClose',
      feature: 'Home',
      status: 'INFO',
    );
    WidgetsBinding.instance.removeObserver(this);
    _notificationSubscription?.cancel();
    _batchTimer?.cancel();
    _profileSubscription?.cancel();
    _transactionSubscription?.cancel();
    _investmentSubscription?.cancel();
    _plansSubscription?.cancel();
    _pointsSubscription?.cancel();
    _rewardTimer?.cancel();
    _notificationReconnectTimer?.cancel();
    _profileReconnectTimer?.cancel();
    _transactionReconnectTimer?.cancel();
    _investmentReconnectTimer?.cancel();
    _pointsReconnectTimer?.cancel();
    _lifecycleReconnectTimer?.cancel();
    super.onClose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    debugPrint(
      '[PROFIT_LIFECYCLE] event: $state | investment_count: ${myInvestments.length}',
    );
    if (state == AppLifecycleState.resumed) {
      SafeGetx.debugTrace(
        className: 'HomeController',
        method: 'didChangeAppLifecycleState',
        feature: 'Home',
        status: 'INFO',
        message: 'App resumed: scheduling stream reconnect',
      );
      if (SupabaseService.isLoggedIn) {
        _lifecycleReconnectTimer?.cancel();
        _lifecycleReconnectTimer = Timer(const Duration(milliseconds: 800), () {
          reconnectStreams();
          refreshAll();
        });
      }
    }
  }

  /// Fetch all data in parallel.
  Future<void> fetchAll() async {
    final stopwatch = Stopwatch()..start();
    await Future.wait([
      fetchInvestmentPlans(),
      fetchProfile(),
      fetchDashboard(),
      fetchRecentTransactions(),
      fetchNotifications(),
      fetchMyInvestments(),
      fetchKspBalance(),
      fetchRecentRecipients(),
      fetchPendingRewards(),
      CurrencyController.to.fetchCurrencies(),
      CurrencyController.to.fetchWalletBalances(),
      FeeService.load(),
    ]);
    SafeGetx.debugTrace(
      className: 'HomeController',
      method: 'fetchAll',
      feature: 'Home',
      status: 'SUCCESS',
      durationMs: stopwatch.elapsedMilliseconds,
    );
  }

  /// Refresh all data (useful for pull-to-refresh).
  Future<void> refreshAll() async => fetchAll();

  /// Resets all observable data. CRITICAL for user logout or session changes.
  void clearData() {
    SafeGetx.debugTrace(
      className: 'HomeController',
      method: 'clearData',
      feature: 'Home',
      status: 'INFO',
    );
    profile.value = null;
    dashboard.value = null;
    recentTransactions.clear();
    notifications.clear();
    myInvestments.clear();
    allInvestmentPlans.clear();
    recentRecipients.clear();
    unreadNotificationCount.value = 0;
    userPoints.value = 0;
    rewardKsp.value = 0;
    walletKsp.value = 0;
    totalEarnedKsp.value = 0;
    totalSpentKsp.value = 0;
    hasError.value = false;
    pendingRewards.clear();
    nextRewardRelease.value = null;
    rewardCountdownText.value = '';
    canClaimRewards.value = false;
    portfolioPeriod.value = '7D';
  }

  /// Keeps dashboard freeze flags aligned with the USD wallet stream.
  void syncDashboardFreezeState({
    required bool isFrozen,
    String? frozenReason,
  }) {
    final current = dashboard.value;
    if (current == null) return;
    dashboard.value = DashboardModel(
      userId: current.userId,
      fullName: current.fullName,
      accountTier: current.accountTier,
      kycStatus: current.kycStatus,
      availableBalance: current.availableBalance,
      profitBalance: current.profitBalance,
      investedBalance: current.investedBalance,
      pendingBalance: current.pendingBalance,
      isFrozen: isFrozen,
      frozenReason: frozenReason,
      currency: current.currency,
      pointBalance: current.pointBalance,
      activeInvestments: current.activeInvestments,
      activeLoans: current.activeLoans,
      dailyProfit: current.dailyProfit,
      profitPercentage: current.profitPercentage,
    );
  }

  /// Called when profile KYC/status changes via realtime — refresh dependent UI.
  Future<void> onProfileFieldsChanged({
    String? previousKycStatus,
    String? previousStatus,
  }) async {
    final current = profile.value;
    if (current == null) return;

    if (Get.isRegistered<AuthController>()) {
      AuthController.to.syncVerificationFromProfile(current);
    }

    if (previousKycStatus != current.kycStatus ||
        previousStatus != current.status) {
      await fetchDashboard();
      if (previousKycStatus != current.kycStatus) {
        EnterpriseOperationsLogger.log(
          domain: 'kyc',
          operation: 'profile_status_sync',
          phase: 'COMPLETE',
          userId: current.id,
          params: {
            'previousKycStatus': previousKycStatus,
            'kycStatus': current.kycStatus,
          },
        );
      }
      if (previousStatus != current.status) {
        EnterpriseOperationsLogger.log(
          domain: 'account_activation',
          operation: 'profile_status_sync',
          phase: 'COMPLETE',
          userId: current.id,
          params: {'previousStatus': previousStatus, 'status': current.status},
        );
      }
    }
  }

  // ─── PROFILE ──────────────────────────────────────────

  Future<void> fetchProfile() async {
    if (!SupabaseService.isLoggedIn) return;
    isLoadingProfile.value = true;
    final stopwatch = Stopwatch()..start();
    try {
      final response = await SupabaseService.client
          .from('profiles')
          .select()
          .eq('id', SupabaseService.userId!)
          .maybeSingle();

      if (response != null) {
        profile.value = ProfileModel.fromJson(response);
        unawaited(CrashReportingService.syncUserContextFromProfile());
        if (Get.isRegistered<AccountRestrictionService>()) {
          AccountRestrictionService.to.onProfileUpdated();
        }
        SafeGetx.debugTrace(
          className: 'HomeController',
          method: 'fetchProfile',
          feature: 'Home',
          status: 'SUCCESS',
          params: {
            'userId': profile.value!.id,
            'kycStatus': profile.value!.kycStatus,
            'role': profile.value!.role,
          },
          durationMs: stopwatch.elapsedMilliseconds,
        );
      } else {
        SafeGetx.debugTrace(
          className: 'HomeController',
          method: 'fetchProfile',
          feature: 'Home',
          status: 'WARN',
          message: 'Profile not found — attempting server provisioning',
          durationMs: stopwatch.elapsedMilliseconds,
        );

        final provisioned = await _tryProvisionMissingProfile();
        if (provisioned != null) {
          profile.value = provisioned;
          unawaited(CrashReportingService.syncUserContextFromProfile());
          if (Get.isRegistered<AccountRestrictionService>()) {
            AccountRestrictionService.to.onProfileUpdated();
          }
          SafeGetx.debugTrace(
            className: 'HomeController',
            method: 'fetchProfile',
            feature: 'Home',
            status: 'SUCCESS',
            message: 'Profile provisioned after missing row',
            params: {'userId': provisioned.id},
            durationMs: stopwatch.elapsedMilliseconds,
          );
          return;
        }

        profile.value = null;
        if (_shouldTreatMissingProfileAsDeleted()) {
          if (Get.isRegistered<AccountRestrictionService>()) {
            await AccountRestrictionService.to.handleDeletedAccount();
          }
        }
      }
    } catch (e, stack) {
      SafeGetx.debugTrace(
        className: 'HomeController',
        method: 'fetchProfile',
        feature: 'Home',
        status: 'ERROR',
        durationMs: stopwatch.elapsedMilliseconds,
        error: e,
        stackTrace: stack,
      );
      profile.value = null;
    } finally {
      isLoadingProfile.value = false;
    }
  }

  Future<ProfileModel?> _tryProvisionMissingProfile() async {
    if (!SupabaseService.isLoggedIn) return null;
    try {
      final response = await SupabaseService.client.rpc(
        'fn_ensure_user_profile',
      );
      final success = response is Map && response['success'] == true;
      if (!success) return null;

      final row = await SupabaseService.client
          .from('profiles')
          .select()
          .eq('id', SupabaseService.userId!)
          .maybeSingle();
      if (row == null) return null;
      return ProfileModel.fromJson(row);
    } catch (e, stack) {
      SafeGetx.debugTrace(
        className: 'HomeController',
        method: '_tryProvisionMissingProfile',
        feature: 'Home',
        status: 'WARN',
        error: e,
        stackTrace: stack,
      );
      return null;
    }
  }

  bool _shouldTreatMissingProfileAsDeleted() {
    final route = Get.currentRoute;
    if (route == Routes.verifyEmail ||
        route == Routes.register ||
        route == Routes.login ||
        route == Routes.splash) {
      return false;
    }

    final createdAt = SupabaseService.auth.currentUser?.createdAt;
    if (createdAt != null) {
      final age = DateTime.now().difference(DateTime.parse(createdAt));
      if (age.inMinutes < 30) return false;
    }

    return true;
  }

  Future<void> fetchDashboard() async {
    if (!SupabaseService.isLoggedIn) return;
    isLoadingDashboard.value = true;
    try {
      final response = await SupabaseService.client
          .from('v_user_dashboard')
          .select()
          .eq('user_id', SupabaseService.userId!)
          .maybeSingle();

      if (response != null) {
        dashboard.value = DashboardModel.fromJson(response);
      } else {
        dashboard.value = null;
      }
    } catch (e, stack) {
      SafeGetx.debugTrace(
        className: 'HomeController',
        method: 'fetchDashboard',
        feature: 'Home',
        status: 'ERROR',
        error: e,
        stackTrace: stack,
      );
      dashboard.value = null;
    } finally {
      isLoadingDashboard.value = false;
    }
  }

  // ─── TRANSACTIONS ─────────────────────────────────────

  Future<void> fetchRecentTransactions() async {
    if (!SupabaseService.isLoggedIn) return;
    isLoadingTransactions.value = true;
    try {
      final response = await SupabaseService.client
          .from('transactions')
          .select()
          .eq('user_id', SupabaseService.userId!)
          .order('created_at', ascending: false)
          .limit(10);

      recentTransactions.value = (response as List)
          .map((json) => TransactionModel.fromJson(json))
          .toList();
    } catch (e, stack) {
      SafeGetx.debugTrace(
        className: 'HomeController',
        method: 'fetchRecentTransactions',
        feature: 'Home',
        status: 'ERROR',
        error: e,
        stackTrace: stack,
      );
    } finally {
      isLoadingTransactions.value = false;
    }
  }

  // ─── ALL TRANSACTIONS (Paginated) ────────────────────

  final RxList<TransactionModel> allTransactions = <TransactionModel>[].obs;
  final RxBool isLoadingAllTransactions = false.obs;
  final RxBool hasMoreTransactions = true.obs;
  final RxString selectedFilter = 'all'.obs;
  int _transactionsPage = 0;
  static const int _pageSize = 20;

  /// Fetch all transactions with optional type filter and pagination.
  Future<void> fetchAllTransactions({bool reset = false}) async {
    if (!SupabaseService.isLoggedIn) return;
    if (isLoadingAllTransactions.value) return;

    if (reset) {
      _transactionsPage = 0;
      hasMoreTransactions.value = true;
      // Use microtask to ensure reactive updates don't conflict with build phase
      Future.microtask(() => allTransactions.clear());
    }

    if (!hasMoreTransactions.value) return;

    isLoadingAllTransactions.value = true;
    try {
      final from = _transactionsPage * _pageSize;
      final to = from + _pageSize - 1;

      // 1. Money Transactions Query
      var query = SupabaseService.client
          .from('transactions')
          .select()
          .eq('user_id', SupabaseService.userId!);

      if (selectedFilter.value != 'all') {
        if (selectedFilter.value == 'transfer_out' ||
            selectedFilter.value == 'transfer_in') {
          query = query.or('type.eq.transfer_out,type.eq.transfer_in');
        } else {
          query = query.eq('type', selectedFilter.value);
        }
      }

      final moneyResponse = await query
          .order('created_at', ascending: false)
          .range(from, to);

      final List<TransactionModel> fetchedList = (moneyResponse as List)
          .map((json) => TransactionModel.fromJson(json))
          .toList();

      // 2. Points Transactions (only if 'all' or 'points' filter)
      if (selectedFilter.value == 'all' || selectedFilter.value == 'points') {
        final pointsResponse = await SupabaseService.client
            .from('point_history')
            .select()
            .eq('user_id', SupabaseService.userId!)
            .order('created_at', ascending: false)
            .range(from, to);

        final pointsList = (pointsResponse as List).map((json) {
          return TransactionModel(
            id: json['id'],
            userId: json['user_id'],
            walletId: 'points_wallet',
            amount: (json['points'] as num).toDouble(),
            type: json['type'] == 'earn'
                ? 'reward'
                : 'transfer_out', // Mapping for UI icons
            status: 'completed',
            description: json['description'],
            createdAt: DateTime.parse(json['created_at']),
          );
        }).toList();

        fetchedList.addAll(pointsList);
        // Re-sort because we merged two lists
        fetchedList.sort(
          (a, b) => (b.createdAt ?? DateTime(0)).compareTo(
            a.createdAt ?? DateTime(0),
          ),
        );
      }

      if (fetchedList.length < _pageSize && selectedFilter.value != 'all') {
        hasMoreTransactions.value = false;
      } else if (fetchedList.isEmpty) {
        hasMoreTransactions.value = false;
      }

      allTransactions.addAll(fetchedList);
      _transactionsPage++;
    } catch (e, stack) {
      SafeGetx.debugTrace(
        className: 'HomeController',
        method: 'fetchAllTransactions',
        feature: 'Home',
        status: 'ERROR',
        error: e,
        stackTrace: stack,
      );
    } finally {
      isLoadingAllTransactions.value = false;
    }
  }

  /// Load more transactions (next page).
  Future<void> loadMoreTransactions() async {
    await fetchAllTransactions();
  }

  /// Apply a filter and reload transactions.
  void filterTransactions(String type) {
    selectedFilter.value = type;
    fetchAllTransactions(reset: true);
  }

  // ─── NOTIFICATIONS ────────────────────────────────────

  Future<void> fetchNotifications({bool reset = true}) async {
    if (!SupabaseService.isLoggedIn) return;
    if (reset) {
      notificationPage.value = 0;
      isLoadingNotifications.value = true;
    } else {
      isLoadingMoreNotifications.value = true;
    }
    try {
      final response = await SupabaseService.client.rpc(
        'fn_get_notification_history',
        params: {
          'p_limit': notificationPageSize,
          'p_offset': notificationPage.value * notificationPageSize,
          'p_category': null,
        },
      );

      if (response is Map && response['success'] == true) {
        final rows = (response['data'] as List? ?? [])
            .map(
              (json) => NotificationModel.fromJson(
                Map<String, dynamic>.from(json as Map),
              ),
            )
            .toList();

        if (reset) {
          notifications.value = rows;
        } else {
          notifications.addAll(rows);
        }
        notificationTotalCount.value =
            (response['total'] as num?)?.toInt() ?? notifications.length;
        unreadNotificationCount.value = notifications
            .where((n) => !n.isRead)
            .length;
        return;
      }
      await _fetchNotificationsFallback(reset: reset);
    } catch (e, stack) {
      SafeGetx.debugTrace(
        className: 'HomeController',
        method: 'fetchNotifications',
        feature: 'Home',
        status: 'ERROR',
        error: e,
        stackTrace: stack,
      );
      await _fetchNotificationsFallback(reset: reset);
    } finally {
      isLoadingNotifications.value = false;
      isLoadingMoreNotifications.value = false;
    }
  }

  Future<void> _fetchNotificationsFallback({bool reset = true}) async {
    final response = await SupabaseService.client
        .from('notifications')
        .select()
        .eq('user_id', SupabaseService.userId!)
        .order('sent_at', ascending: false)
        .range(
          notificationPage.value * notificationPageSize,
          (notificationPage.value + 1) * notificationPageSize - 1,
        );

    final list = (response as List)
        .map((json) => NotificationModel.fromJson(json))
        .toList();

    if (reset) {
      notifications.value = list;
    } else {
      notifications.addAll(list);
    }
    unreadNotificationCount.value = notifications
        .where((n) => !n.isRead)
        .length;
  }

  Future<void> loadMoreNotifications() async {
    if (isLoadingMoreNotifications.value) return;
    if (notifications.length >= notificationTotalCount.value) return;
    notificationPage.value++;
    await fetchNotifications(reset: false);
  }

  /// Deep-link navigation based on notification type/target.
  void navigateFromNotification(NotificationModel notification) {
    NotificationNavigationService.navigateFromModel(notification);
  }

  /// Mark a notification as read.
  Future<void> markNotificationRead(String notificationId) async {
    try {
      await SupabaseService.client
          .from('notifications')
          .update({'read_at': DateTime.now().toIso8601String()})
          .eq('id', notificationId);

      // Update local state
      final index = notifications.indexWhere((n) => n.id == notificationId);
      if (index != -1) {
        notifications[index] = notifications[index].copyWith(
          readAt: DateTime.now(),
        );
        unreadNotificationCount.value = notifications
            .where((n) => !n.isRead)
            .length;
      }
    } catch (e, stack) {
      SafeGetx.debugTrace(
        className: 'HomeController',
        method: 'markNotificationRead',
        feature: 'Home',
        status: 'ERROR',
        error: e,
        stackTrace: stack,
      );
    }
  }

  /// Mark all notifications as read.
  Future<void> markAllAsRead() async {
    if (!SupabaseService.isLoggedIn || notifications.isEmpty) return;

    try {
      final unreadIds = notifications
          .where((n) => !n.isRead)
          .map((n) => n.id)
          .toList();

      if (unreadIds.isEmpty) return;

      await SupabaseService.client
          .from('notifications')
          .update({'read_at': DateTime.now().toIso8601String()})
          .inFilter('id', unreadIds);

      // Optimistic update
      final now = DateTime.now();
      for (int i = 0; i < notifications.length; i++) {
        if (!notifications[i].isRead) {
          notifications[i] = notifications[i].copyWith(readAt: now);
        }
      }
      unreadNotificationCount.value = 0;

      HapticFeedback.mediumImpact();
    } catch (e, stack) {
      SafeGetx.debugTrace(
        className: 'HomeController',
        method: 'markAllAsRead',
        feature: 'Home',
        status: 'ERROR',
        error: e,
        stackTrace: stack,
      );
    }
  }

  // ─── INVESTMENTS ──────────────────────────────────────

  Future<void> fetchMyInvestments() async {
    if (!SupabaseService.isLoggedIn) return;
    isLoadingInvestments.value = true;
    try {
      final response = await SupabaseService.client
          .from('user_investments')
          .select('*, investment:investment_plans(*)')
          .eq('user_id', SupabaseService.userId!)
          .order('created_at', ascending: false);

      myInvestments.value = (response as List)
          .map((json) => UserInvestmentModel.fromJson(json))
          .toList();
    } catch (e, stack) {
      SafeGetx.debugTrace(
        className: 'HomeController',
        method: 'fetchMyInvestments',
        feature: 'Home',
        status: 'ERROR',
        error: e,
        stackTrace: stack,
      );
    } finally {
      isLoadingInvestments.value = false;
    }
  }

  Future<void> fetchInvestmentPlans() async {
    try {
      final response = await SupabaseService.client
          .from('investment_plans')
          .select();
      allInvestmentPlans.value = (response as List)
          .map((json) => InvestmentPlanModel.fromJson(json))
          .toList();
    } catch (e, stack) {
      SafeGetx.debugTrace(
        className: 'HomeController',
        method: 'fetchInvestmentPlans',
        feature: 'Home',
        status: 'ERROR',
        error: e,
        stackTrace: stack,
      );
    }
  }

  // ─── KSP BALANCE (Effective = wallet×1000 + reward) ───

  /// Mirrors [KspBalanceService] values into home observables (no network I/O).
  void syncKspFromService() {
    if (!Get.isRegistered<KspBalanceService>()) return;
    final ksp = KspBalanceService.to;
    userPoints.value = ksp.effectiveKsp.value;
    rewardKsp.value = ksp.rewardKsp.value;
    walletKsp.value = ksp.walletKsp.value;
  }

  Future<void> fetchKspBalance() async {
    if (!SupabaseService.isLoggedIn) return;
    isLoadingPoints.value = true;
    try {
      if (Get.isRegistered<KspBalanceService>()) {
        await KspBalanceService.to.refresh();
        syncKspFromService();
      } else {
        final raw = await SupabaseService.client.rpc('fn_get_effective_ksp');
        final payload = raw is Map ? Map<String, dynamic>.from(raw) : null;
        if (payload?['success'] == true) {
          userPoints.value = (payload!['effective_ksp'] as num?)?.toInt() ?? 0;
          rewardKsp.value = (payload['reward_ksp'] as num?)?.toInt() ?? 0;
          walletKsp.value = (payload['wallet_ksp'] as num?)?.toInt() ?? 0;
        }
      }

      final stats = await SupabaseService.client
          .from('user_points')
          .select('total_earned, total_spent')
          .eq('user_id', SupabaseService.userId!)
          .maybeSingle();
      if (stats != null) {
        totalEarnedKsp.value = (stats['total_earned'] as num?)?.toInt() ?? 0;
        totalSpentKsp.value = (stats['total_spent'] as num?)?.toInt() ?? 0;
      }
    } catch (e, stack) {
      SafeGetx.debugTrace(
        className: 'HomeController',
        method: 'fetchKspBalance',
        feature: 'Home',
        status: 'ERROR',
        error: e,
        stackTrace: stack,
      );
    } finally {
      isLoadingPoints.value = false;
    }
  }

  /// @deprecated Use [fetchKspBalance].
  Future<void> fetchPoints() => fetchKspBalance();

  // ─── RECENT RECIPIENTS ────────────────────────────────

  Future<void> fetchRecentRecipients() async {
    if (!SupabaseService.isLoggedIn) return;
    try {
      final response = await SupabaseService.client
          .from('transactions')
          .select('description, counterpart_user_id, created_at')
          .eq('user_id', SupabaseService.userId!)
          .eq('type', 'transfer_out')
          .order('created_at', ascending: false)
          .limit(20);

      final Set<String> seenCodes = {};
      final List<Map<String, String>> recipients = [];

      for (final tx in (response as List)) {
        // Extract referral code from description (e.g., "Transfer to K-XXXX")
        final desc = tx['description'] as String? ?? '';
        final code = _extractReferralCode(desc);
        if (code.isNotEmpty && seenCodes.add(code)) {
          recipients.add({'code': code, 'description': desc});
        }
      }

      recentRecipients.value = recipients;
    } catch (e, stack) {
      SafeGetx.debugTrace(
        className: 'HomeController',
        method: 'fetchRecentRecipients',
        feature: 'Home',
        status: 'ERROR',
        error: e,
        stackTrace: stack,
      );
    }
  }

  /// Try to extract a referral code from a transfer description.
  String _extractReferralCode(String description) {
    final match = RegExp(
      r'K-?\w+',
      caseSensitive: false,
    ).firstMatch(description);
    if (match != null) {
      return ReferralService.normalizeCode(match.group(0)!);
    }
    return '';
  }

  // ─── PENDING REWARDS ─────────────────────────────────

  Future<void> fetchPendingRewards() async {
    if (!SupabaseService.isLoggedIn) return;
    try {
      final response = await SupabaseService.client
          .from('pending_rewards')
          .select()
          .eq('user_id', SupabaseService.userId!)
          .eq('status', 'pending')
          .order('release_at', ascending: true);

      final List<dynamic> data = response as List;
      pendingRewards.value = data.cast<Map<String, dynamic>>();

      _updateRewardDistributionInfo();
    } catch (e, stack) {
      SafeGetx.debugTrace(
        className: 'HomeController',
        method: 'fetchPendingRewards',
        feature: 'Home',
        status: 'ERROR',
        error: e,
        stackTrace: stack,
      );
    }
  }

  bool _isDistributingProfits = false;

  /// Triggers automated profit distribution check on Supabase and refreshes data
  Future<void> _triggerProfitDistributionCheck() async {
    if (_isDistributingProfits || !SupabaseService.isLoggedIn) {
      debugPrint(
        '[PROFIT_CYCLE] Profit distribution check skipped -> isDistributing: $_isDistributingProfits, isLoggedIn: ${SupabaseService.isLoggedIn}',
      );
      return;
    }
    _isDistributingProfits = true;
    try {
      for (final inv in myInvestments.where((i) => i.status == 'active')) {
        debugPrint(
          '[PROFIT_CYCLE] PROFIT DUE -> investment_id: ${inv.id} | user_id: ${inv.userId} | plan_id: ${inv.planId} | status: ${inv.status} | auto_restart_enabled: ${inv.autoRestartEnabled} | next_payout_at: ${inv.nextPayoutAt} | current_time: ${DateTime.now()}',
        );
      }
      debugPrint('[PROFIT_CYCLE] Triggering profit distribution check');
      debugPrint(
        '[PROFIT_RPC] CALL -> rpc_name: fn_cron_distribute_daily_profits | user_id: ${SupabaseService.userId}',
      );
      final response = await SupabaseService.client.rpc(
        'fn_cron_distribute_daily_profits',
      );
      debugPrint(
        '[PROFIT_RPC] RESPONSE -> rpc_name: fn_cron_distribute_daily_profits | success: true | response: $response',
      );

      final oldBalance = Get.isRegistered<CurrencyController>()
          ? CurrencyController.to.totalBalance.value
          : 0.0;

      await fetchAll();

      final newBalance = Get.isRegistered<CurrencyController>()
          ? CurrencyController.to.totalBalance.value
          : 0.0;

      debugPrint(
        '[PROFIT_WALLET] user_id: ${SupabaseService.userId} | wallet_before: $oldBalance | wallet_after: $newBalance',
      );
      if (newBalance > oldBalance) {
        debugPrint(
          '[PROFIT_DISTRIBUTION] PROFIT CREDITED -> profit_amount: ${newBalance - oldBalance} | new_wallet_balance: $newBalance',
        );
      }

      _auditPostDistribution();
    } catch (e, stack) {
      debugPrint(
        '[PROFIT_RPC] RESPONSE -> rpc_name: fn_cron_distribute_daily_profits | success: false | error: $e',
      );
      debugPrint(
        '[PROFIT_ERROR] RPC EXCEPTION -> message: ${e.toString()} | exception: ${e.runtimeType} | stackTrace: $stack | operation: fn_cron_distribute_daily_profits',
      );
      SafeGetx.debugTrace(
        className: 'HomeController',
        method: '_triggerProfitDistributionCheck',
        feature: 'Home',
        status: 'ERROR',
        error: e,
        stackTrace: stack,
      );
    } finally {
      _isDistributingProfits = false;
    }
  }

  void _auditPostDistribution() {
    final profitTxs = recentTransactions
        .where((t) => t.type == 'daily_profit' || t.type == 'profit')
        .toList();
    if (profitTxs.isNotEmpty) {
      final latestTx = profitTxs.first;
      debugPrint(
        '[PROFIT_TRANSACTION] transaction_id: ${latestTx.id} | user_id: ${latestTx.userId} | amount: ${latestTx.amount} | created_at: ${latestTx.createdAt}',
      );
      final windowTxs = profitTxs.where(
        (t) =>
            t.createdAt != null &&
            DateTime.now().difference(t.createdAt!).inHours < 23,
      ).toList();
      if (windowTxs.length > 1) {
        debugPrint(
          '[PROFIT_ERROR] DUPLICATE PROFIT TRANSACTION -> count: ${windowTxs.length} | transaction_ids: ${windowTxs.map((t) => t.id).toList()}',
        );
      }
    }
    if (notifications.isNotEmpty) {
      final latestNotif = notifications.first;
      debugPrint(
        '[PROFIT_NOTIFICATION] notification_id: ${latestNotif.id} | title: ${latestNotif.title} | body: ${latestNotif.message} | type: ${latestNotif.type} | entity_id: ${latestNotif.entityId}',
      );
    }
  }

  /// Calculates the next reward distribution time across all sources (Pending Rewards & Active Investments)
  void _updateRewardDistributionInfo() {
    DateTime? earliest;
    final now = DateTime.now();

    // 1. Check manual pending rewards (traditional system)
    if (pendingRewards.isNotEmpty) {
      final nextManual = DateTime.parse(pendingRewards.first['release_at']);
      earliest = nextManual;
    }

    // 2. Check active investments (automated continuous system)
    // Exclude non-subscribed investments that completed their cycle and are waiting for manual restart
    final activeInvs = myInvestments.where(
      (inv) => inv.status == 'active' && !inv.isCycleWaiting,
    );
    for (final inv in activeInvs) {
      final effective = inv.effectiveNextPayout;
      if (effective != null && effective.isAfter(now)) {
        if (earliest == null || effective.isBefore(earliest)) {
          earliest = effective;
        }
      }
    }

    nextRewardRelease.value = earliest;

    if (earliest != null) {
      final diff = earliest.difference(now);
      if (diff.isNegative) {
        _triggerProfitDistributionCheck();
        DateTime nextTarget = earliest;
        while (!nextTarget.isAfter(now)) {
          nextTarget = nextTarget.add(const Duration(hours: 24));
        }
        isProcessingUI.value = false;
        canClaimRewards.value = pendingRewards.isNotEmpty;
        rewardCountdownText.value = _formatDuration(nextTarget.difference(now));
      } else {
        isProcessingUI.value = false;
        canClaimRewards.value = pendingRewards.isNotEmpty;
        rewardCountdownText.value = _formatDuration(diff);
      }
      _startRewardTimer();
    } else {
      isProcessingUI.value = false;
      canClaimRewards.value = pendingRewards.isNotEmpty;
      final hasWaitingCycle = myInvestments.any(
        (inv) => inv.status == 'active' && inv.isCycleWaiting,
      );
      rewardCountdownText.value = hasWaitingCycle ? 'cycle_completed' : '';
      _rewardTimer?.cancel();
    }
  }

  void _startRewardTimer() {
    _rewardTimer?.cancel();
    _rewardTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final now = DateTime.now();

      // Update Summary Counter
      DateTime? earliest;
      if (pendingRewards.isNotEmpty) {
        earliest = DateTime.parse(pendingRewards.first['release_at']);
      }
      final activeInvs = myInvestments.where(
        (inv) => inv.status == 'active' && !inv.isCycleWaiting,
      );
      for (final inv in activeInvs) {
        final effective = inv.effectiveNextPayout;
        if (effective != null && effective.isAfter(now)) {
          if (earliest == null || effective.isBefore(earliest)) {
            earliest = effective;
          }
        }
      }
      nextRewardRelease.value = earliest;

      if (earliest != null) {
        final difference = earliest.difference(now);

        if (difference.isNegative) {
          _triggerProfitDistributionCheck();
          DateTime nextTarget = earliest;
          while (!nextTarget.isAfter(now)) {
            nextTarget = nextTarget.add(const Duration(hours: 24));
          }
          isProcessingUI.value = false;
          canClaimRewards.value = pendingRewards.isNotEmpty;
          rewardCountdownText.value = _formatDuration(
            nextTarget.difference(now),
          );
        } else {
          isProcessingUI.value = false;
          canClaimRewards.value = pendingRewards.isNotEmpty;
          rewardCountdownText.value = _formatDuration(difference);
        }
      } else {
        final hasWaitingCycle = myInvestments.any(
          (inv) => inv.status == 'active' && inv.isCycleWaiting,
        );
        rewardCountdownText.value = hasWaitingCycle ? 'cycle_completed' : '';
      }

      // Update Individual Investment Timers
      for (final inv in myInvestments.where((i) => i.status == 'active')) {
        // Non-subscribed cycle completed — show waiting state, not 00:00:00
        if (inv.isCycleWaiting) {
          investmentCountdowns[inv.id] = 'cycle_completed';
          continue;
        }
        final effective = inv.effectiveNextPayout;
        if (effective != null) {
          final diff = effective.difference(now);
          if (diff.isNegative) {
            _triggerProfitDistributionCheck();
            DateTime nextTarget = effective;
            while (!nextTarget.isAfter(now)) {
              nextTarget = nextTarget.add(const Duration(hours: 24));
            }
            investmentCountdowns[inv.id] = _formatDuration(
              nextTarget.difference(now),
            );
          } else {
            investmentCountdowns[inv.id] = _formatDuration(diff);
          }
        } else {
          investmentCountdowns[inv.id] = 'cycle_completed';
        }
      }
    });
  }

  String _formatDuration(Duration d) {
    if (d.isNegative) return "24:00:00";
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  Future<void> claimRewards() async {
    if (!canClaimRewards.value || isClaimingLoading.value) return;

    isClaimingLoading.value = true;
    try {
      final response = await SupabaseService.client.rpc('claim_rewards');

      if (response['success'] == true) {
        // Refresh all data
        await fetchAll();
        HapticFeedback.heavyImpact();

        // Trigger earnings update event for automatic refresh
        if (Get.isRegistered<EarningsEventService>()) {
          EarningsEventService.to.triggerEarningsUpdate(source: 'investments');
        } else {
          Get.put(EarningsEventService());
          EarningsEventService.to.triggerEarningsUpdate(source: 'investments');
        }
      } else {
        AppSnack.error(
          'error'.tr,
          response['error']?.toString() ?? 'no_rewards_ready'.tr,
        );
      }
    } catch (e, stack) {
      SafeGetx.debugTrace(
        className: 'HomeController',
        method: 'claimRewards',
        feature: 'Home',
        status: 'ERROR',
        error: e,
        stackTrace: stack,
      );
    } finally {
      isClaimingLoading.value = false;
    }
  }

  // ─── EARNINGS UPDATE TRIGGER ─────────────────────────────────

  /// Trigger earnings update event
  /// Call this method when earnings are successfully credited
  void triggerEarningsUpdate({String? source}) {
    if (Get.isRegistered<EarningsEventService>()) {
      EarningsEventService.to.triggerEarningsUpdate(source: source);
    } else {
      Get.put(EarningsEventService());
      EarningsEventService.to.triggerEarningsUpdate(source: source);
    }
  }

  // ─── CYCLE MANAGEMENT ─────────────────────────────────

  Future<void> startNextCycle(String investmentId) async {
    if (cycleRestartLoading[investmentId] == true) return;

    final inv = myInvestments.firstWhereOrNull((i) => i.id == investmentId);
    debugPrint(
      '[PROFIT_CYCLE] START NEXT CYCLE -> investment_id: $investmentId | old_next_payout_at: ${inv?.nextPayoutAt} | auto_restart_enabled: ${inv?.autoRestartEnabled}',
    );
    debugPrint(
      '[PROFIT_RPC] fn_start_next_cycle CALL -> parameters: {p_investment_id: $investmentId}',
    );

    cycleRestartLoading[investmentId] = true;
    try {
      final response = await SupabaseService.client.rpc(
        'fn_start_next_cycle',
        params: {'p_investment_id': investmentId},
      );

      final success = response is Map && response['success'] == true;
      debugPrint(
        '[PROFIT_RPC] fn_start_next_cycle RESPONSE -> success: $success | response: $response',
      );

      if (success) {
        debugPrint(
          '[PROFIT_CYCLE] NEXT CYCLE STARTED -> investment_id: $investmentId | countdown_started: true',
        );
        HapticFeedback.mediumImpact();
        AppSnack.success('success'.tr, 'cycle_started_success'.tr);
        await fetchMyInvestments();
        await fetchDashboard();

        // Trigger earnings update event for automatic refresh
        triggerEarningsUpdate(source: 'investment_returns');
      } else {
        final errorMsg = response is Map ? response['error']?.toString() : null;
        debugPrint(
          '[PROFIT_ERROR] NEXT CYCLE FAILED TO START -> investment_id: $investmentId | error: $errorMsg',
        );
        AppSnack.error('error'.tr, errorMsg ?? 'unexpected_error'.tr);
      }
    } catch (e, stack) {
      debugPrint(
        '[PROFIT_ERROR] RPC EXCEPTION -> fn_start_next_cycle failed: $e | stack: $stack',
      );
      // Direct table update fallback if RPC fails (e.g. updated_at column missing error)
      try {
        await SupabaseService.client
            .from('user_investments')
            .update({
              'next_payout_at': DateTime.now()
                  .add(const Duration(hours: 24))
                  .toIso8601String(),
              'status': 'active',
            })
            .eq('id', investmentId)
            .eq('user_id', SupabaseService.userId!);

        debugPrint(
          '[PROFIT_CYCLE] NEXT CYCLE STARTED (Fallback) -> investment_id: $investmentId',
        );
        HapticFeedback.mediumImpact();
        AppSnack.success('success'.tr, 'cycle_started_success'.tr);
        await fetchMyInvestments();
        await fetchDashboard();
        triggerEarningsUpdate(source: 'investment_returns');
        return;
      } catch (fallbackError) {
        debugPrint(
          '[PROFIT_ERROR] NEXT CYCLE FAILED TO START -> fallback error: $fallbackError',
        );
        SafeGetx.debugTrace(
          className: 'HomeController',
          method: 'startNextCycle',
          feature: 'Home',
          status: 'ERROR',
          error: e,
          stackTrace: stack,
        );
        AppSnack.error('error'.tr, 'error_executing_operation'.tr);
      }
    } finally {
      cycleRestartLoading[investmentId] = false;
    }
  }

  Future<void> toggleAutoRestart(String investmentId, bool enabled) async {
    if (autoRestartToggleLoading[investmentId] == true) return;

    autoRestartToggleLoading[investmentId] = true;
    try {
      final response = await SupabaseService.client.rpc(
        'fn_toggle_auto_restart',
        params: {'p_investment_id': investmentId, 'p_enabled': enabled},
      );

      final success = response is Map && response['success'] == true;
      if (success) {
        HapticFeedback.lightImpact();
        AppSnack.success(
          'success'.tr,
          enabled ? 'auto_restart_enabled'.tr : 'auto_restart_disabled'.tr,
        );
        await fetchMyInvestments();
      } else {
        final errorMsg = response is Map ? response['error']?.toString() : null;
        AppSnack.error('error'.tr, errorMsg ?? 'unexpected_error'.tr);
      }
    } catch (e, stack) {
      // Direct table update fallback if RPC fails (e.g. updated_at column missing error)
      try {
        await SupabaseService.client
            .from('user_investments')
            .update({'auto_restart_enabled': enabled})
            .eq('id', investmentId)
            .eq('user_id', SupabaseService.userId!);

        HapticFeedback.lightImpact();
        AppSnack.success(
          'success'.tr,
          enabled ? 'auto_restart_enabled'.tr : 'auto_restart_disabled'.tr,
        );
        await fetchMyInvestments();
        return;
      } catch (fallbackError) {
        SafeGetx.debugTrace(
          className: 'HomeController',
          method: 'toggleAutoRestart',
          feature: 'Home',
          status: 'ERROR',
          error: e,
          stackTrace: stack,
        );
        AppSnack.error('error'.tr, 'error_executing_operation'.tr);
      }
    } finally {
      autoRestartToggleLoading[investmentId] = false;
    }
  }
}
