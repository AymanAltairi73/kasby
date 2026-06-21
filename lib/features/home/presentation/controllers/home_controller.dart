import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:kasby/core/services/supabase_service.dart';
import 'package:kasby/core/models/profile_model.dart';
import 'package:kasby/core/models/transaction_model.dart';
import 'package:kasby/core/models/notification_model.dart';
import 'package:kasby/core/models/user_investment_model.dart';
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
import 'package:kasby/core/services/fee_service.dart';

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
  final RxBool isLoadingNotifications = false.obs;
  final RxBool isLoadingInvestments = false.obs;
  final RxBool hasError = false.obs;

  // Points
  final RxInt userPoints = 0.obs;
  final RxInt totalEarnedKsp = 0.obs;
  final RxInt totalSpentKsp = 0.obs;
  final RxBool isLoadingPoints = false.obs;

  // Transfer Recipients (recent)
  final RxList<Map<String, String>> recentRecipients =
      <Map<String, String>>[].obs;

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

  Timer? _rewardTimer;
  Timer? _notificationReconnectTimer;
  Timer? _profileReconnectTimer;
  Timer? _transactionReconnectTimer;
  Timer? _investmentReconnectTimer;
  Timer? _pointsReconnectTimer;

  // Exponential backoff for reconnection (1s -> 2s -> 4s -> ... -> 60s max)
  Duration _reconnectDelay = const Duration(seconds: 1);

  Timer _scheduleReconnect(void Function() reconnect) {
    final delay = _reconnectDelay;
    _reconnectDelay = Duration(
      seconds: (_reconnectDelay.inSeconds * 2).clamp(1, 60),
    );
    return Timer(delay, reconnect);
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
      dashboard.value?.kycStatus ?? profile.value?.kycStatus ?? 'none';
  int get pointsBalance => userPoints.value;
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

  @override
  void onInit() {
    SafeGetx.debugTrace(
      className: 'HomeController',
      method: 'onInit',
      feature: 'Home',
      status: 'INFO',
    );
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    if (SupabaseService.isLoggedIn) {
      fetchAll();
      _listenToNotifications();
      _listenToProfile();
      _listenToTransactions();
      _listenToInvestments();
      _listenToPoints();
      fetchPendingRewards();
    }
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
              final newItems = newList.where((n) => !notifications.any((old) => old.id == n.id)).toList();
              
              for (var item in newItems) {
                if (!item.isRead && FCMService.to.isNotificationsEnabled.value) {
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
          },
          onError: (error, stack) {
            SafeGetx.debugTrace(
              className: 'HomeController',
              method: '_listenToNotifications',
              feature: 'Home',
              status: 'ERROR',
              error: error,
              stackTrace: stack,
            );
            _notificationReconnectTimer?.cancel();
            _notificationReconnectTimer = _scheduleReconnect(_listenToNotifications);
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
      icon: Icon(
        Icons.notifications_active_rounded,
        color: AppColors.darkGold,
      ),
      margin: const EdgeInsets.all(12),
      borderRadius: 16,
      duration: const Duration(seconds: 4),
      onTap: (_) => navigateFromNotification(notification),
    );
  }

  void _showMultipleNotificationsSnack(int count) {
    SafeGetx.snackbar(
      title: 'notifications'.tr,
      message: 'you_have_multiple_notifications'.trParams({'count': count.toString()}),
      snackPosition: SnackPosition.TOP,
      backgroundColor: AppColors.surface.withValues(alpha: 0.9),
      colorText: Colors.white,
      icon: Icon(
        Icons.notifications_active_rounded,
        color: AppColors.darkGold,
      ),
      margin: const EdgeInsets.all(12),
      borderRadius: 16,
      duration: const Duration(seconds: 4),
      onTap: (_) => NotificationNavigationService.navigateFromPayload(
        {'type': 'notification', 'route': '/notifications'},
        fromUserTap: true,
      ),
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
              profile.value = ProfileModel.fromJson(json);
              if (Get.isRegistered<AccountRestrictionService>()) {
                AccountRestrictionService.to.onProfileUpdated();
              }
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
            _log('Profile stream error', method: '_listenToProfile', isError: true, error: error, stackTrace: stack);
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
            _log('Transactions updated via real-time stream', method: '_listenToTransactions');
          },
          onError: (error, stack) {
            _log('Transactions stream error', method: '_listenToTransactions', isError: true, error: error, stackTrace: stack);
            _transactionReconnectTimer?.cancel();
            _transactionReconnectTimer = _scheduleReconnect(_listenToTransactions);
          },
        );
  }

  // ─── INVESTMENTS LISTENER ─────────────────────────────
  StreamSubscription? _investmentSubscription;

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
            myInvestments.value = data
                .map((json) => UserInvestmentModel.fromJson(json))
                .toList();

            // Update countdowns whenever investments refresh
            _updateRewardDistributionInfo();
            _log('Investments updated via real-time stream', method: '_listenToInvestments');
          },
          onError: (error, stack) {
            _log('Investments stream error', method: '_listenToInvestments', isError: true, error: error, stackTrace: stack);
            _investmentReconnectTimer?.cancel();
            _investmentReconnectTimer = _scheduleReconnect(_listenToInvestments);
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
              final row = data.first;
              userPoints.value = (row['current_balance'] as num?)?.toInt() ?? 0;
              totalEarnedKsp.value = (row['total_earned'] as num?)?.toInt() ?? 0;
              totalSpentKsp.value = (row['total_spent'] as num?)?.toInt() ?? 0;
              _log('Points updated via real-time stream', method: '_listenToPoints', params: {'balance': userPoints.value});
            }
          },
          onError: (error, stack) {
            _log('Points stream error', method: '_listenToPoints', isError: true, error: error, stackTrace: stack);
            _pointsReconnectTimer?.cancel();
            _pointsReconnectTimer = _scheduleReconnect(_listenToPoints);
          },
        );
  }

  void _log(String message, {String method = 'event', bool isError = false, Object? error, StackTrace? stackTrace, Map<String, Object?>? params}) {
    SafeGetx.debugTrace(
      className: 'HomeController',
      method: method,
      feature: 'Home',
      status: isError ? 'ERROR' : 'INFO',
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
    _resetBackoff();
    _listenToNotifications();
    _listenToProfile();
    _listenToTransactions();
    _listenToInvestments();
    _listenToPoints();
  }

  @override
  void onClose() {
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
    _pointsSubscription?.cancel();
    _rewardTimer?.cancel();
    _notificationReconnectTimer?.cancel();
    _profileReconnectTimer?.cancel();
    _transactionReconnectTimer?.cancel();
    _investmentReconnectTimer?.cancel();
    _pointsReconnectTimer?.cancel();
    super.onClose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      SafeGetx.debugTrace(
        className: 'HomeController',
        method: 'didChangeAppLifecycleState',
        feature: 'Home',
        status: 'INFO',
        message: 'App resumed: reconnecting streams',
      );
      if (SupabaseService.isLoggedIn) {
        reconnectStreams();
        refreshAll();
      }
    }
  }

  /// Fetch all data in parallel.
  Future<void> fetchAll() async {
    final stopwatch = Stopwatch()..start();
    await Future.wait([
      fetchProfile(),
      fetchDashboard(),
      fetchRecentTransactions(),
      fetchNotifications(),
      fetchMyInvestments(),
      fetchPoints(),
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
    recentRecipients.clear();
    unreadNotificationCount.value = 0;
    userPoints.value = 0;
    totalEarnedKsp.value = 0;
    totalSpentKsp.value = 0;
    hasError.value = false;
    pendingRewards.clear();
    nextRewardRelease.value = null;
    rewardCountdownText.value = '';
    canClaimRewards.value = false;
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
          message: 'Profile not found',
          durationMs: stopwatch.elapsedMilliseconds,
        );
        profile.value = null;
        if (Get.isRegistered<AccountRestrictionService>()) {
          await AccountRestrictionService.to.handleDeletedAccount();
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
      SafeGetx.debugTrace(className: 'HomeController', method: 'fetchDashboard', feature: 'Home', status: 'ERROR', error: e, stackTrace: stack);
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
      SafeGetx.debugTrace(className: 'HomeController', method: 'fetchRecentTransactions', feature: 'Home', status: 'ERROR', error: e, stackTrace: stack);
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
      SafeGetx.debugTrace(className: 'HomeController', method: 'fetchAllTransactions', feature: 'Home', status: 'ERROR', error: e, stackTrace: stack);
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

  Future<void> fetchNotifications() async {
    if (!SupabaseService.isLoggedIn) return;
    isLoadingNotifications.value = true;
    try {
      final response = await SupabaseService.client
          .from('notifications')
          .select()
          .eq('user_id', SupabaseService.userId!)
          .order('created_at', ascending: false)
          .limit(50);

      final list = (response as List)
          .map((json) => NotificationModel.fromJson(json))
          .toList();

      notifications.value = list;
      unreadNotificationCount.value = list.where((n) => !n.isRead).length;
    } catch (e, stack) {
      SafeGetx.debugTrace(className: 'HomeController', method: 'fetchNotifications', feature: 'Home', status: 'ERROR', error: e, stackTrace: stack);
    } finally {
      isLoadingNotifications.value = false;
    }
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
      SafeGetx.debugTrace(className: 'HomeController', method: 'markNotificationRead', feature: 'Home', status: 'ERROR', error: e, stackTrace: stack);
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
      SafeGetx.debugTrace(className: 'HomeController', method: 'markAllAsRead', feature: 'Home', status: 'ERROR', error: e, stackTrace: stack);
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
      SafeGetx.debugTrace(className: 'HomeController', method: 'fetchMyInvestments', feature: 'Home', status: 'ERROR', error: e, stackTrace: stack);
    } finally {
      isLoadingInvestments.value = false;
    }
  }

  // ─── POINTS ────────────────────────────────────────────

  Future<void> fetchPoints() async {
    if (!SupabaseService.isLoggedIn) return;
    isLoadingPoints.value = true;
    try {
      final response = await SupabaseService.client
          .from('user_points')
          .select('current_balance, total_earned, total_spent')
          .eq('user_id', SupabaseService.userId!)
          .maybeSingle();

      if (response != null) {
        userPoints.value = (response['current_balance'] as num?)?.toInt() ?? 0;
        totalEarnedKsp.value = (response['total_earned'] as num?)?.toInt() ?? 0;
        totalSpentKsp.value = (response['total_spent'] as num?)?.toInt() ?? 0;
      } else {
        userPoints.value = 0;
        totalEarnedKsp.value = 0;
        totalSpentKsp.value = 0;
      }
    } catch (e, stack) {
      SafeGetx.debugTrace(className: 'HomeController', method: 'fetchPoints', feature: 'Home', status: 'ERROR', error: e, stackTrace: stack);
    } finally {
      isLoadingPoints.value = false;
    }
  }

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
      SafeGetx.debugTrace(className: 'HomeController', method: 'fetchRecentRecipients', feature: 'Home', status: 'ERROR', error: e, stackTrace: stack);
    }
  }

  /// Try to extract a referral code from a transfer description.
  String _extractReferralCode(String description) {
    final match = RegExp(r'K-?\w+', caseSensitive: false).firstMatch(description);
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
      SafeGetx.debugTrace(className: 'HomeController', method: 'fetchPendingRewards', feature: 'Home', status: 'ERROR', error: e, stackTrace: stack);
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

    // 2. Check active investments (new automated system)
    final activeInvs = myInvestments.where((inv) => inv.status == 'active');
    for (final inv in activeInvs) {
      final start = inv.startDate ?? inv.createdAt;
      if (start != null) {
        // Calculate the next repeating milestone (every 24h from start)
        DateTime milestone = start.add(const Duration(hours: 24));
        // If milestone + 60 mins is in the past, move to the next 24h milestone
        while (milestone.add(const Duration(minutes: 60)).isBefore(now)) {
          milestone = milestone.add(const Duration(hours: 24));
        }

        if (earliest == null || milestone.isBefore(earliest)) {
          earliest = milestone;
        }
      }
    }

    nextRewardRelease.value = earliest;

    if (earliest != null) {
      final diff = earliest.difference(now);
      if (diff.isNegative) {
        // Within 60 min processing window
        isProcessingUI.value = true;
        canClaimRewards.value = pendingRewards.isNotEmpty;
        rewardCountdownText.value = pendingRewards.isNotEmpty ? '' : 'reward_processing'.tr;
      } else {
        isProcessingUI.value = false;
        canClaimRewards.value = false;
        rewardCountdownText.value = _formatDuration(diff);
      }
      _startRewardTimer();
    } else {
      isProcessingUI.value = false;
      rewardCountdownText.value = '';
      canClaimRewards.value = false;
      _rewardTimer?.cancel();
    }
  }

  void _startRewardTimer() {
    _rewardTimer?.cancel();
    _rewardTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final now = DateTime.now();

      // Update Summary Counter
      if (nextRewardRelease.value != null) {
        final difference = nextRewardRelease.value!.difference(now);
        
        if (difference.isNegative) {
          // Within Processing Window
          isProcessingUI.value = true;
          canClaimRewards.value = pendingRewards.isNotEmpty;
          rewardCountdownText.value = pendingRewards.isNotEmpty ? '' : 'reward_processing'.tr;
          
          // If we just entered the next milestone (crossed the 60m threshold), refresh
          if (difference.inMinutes <= -60) {
            _updateRewardDistributionInfo();
            fetchAll();
          }
        } else {
          isProcessingUI.value = false;
          canClaimRewards.value = false;
          rewardCountdownText.value = _formatDuration(difference);
        }
      }

      // Update Individual Investment Timers
      for (final inv in myInvestments.where((i) => i.status == 'active')) {
        final start = inv.startDate ?? inv.createdAt;
        if (start != null) {
          DateTime milestone = start.add(const Duration(hours: 24));
          while (milestone.add(const Duration(minutes: 60)).isBefore(now)) {
            milestone = milestone.add(const Duration(hours: 24));
          }
          
          final diff = milestone.difference(now);
          if (diff.isNegative) {
            investmentCountdowns[inv.id] = 'reward_processing'.tr;
          } else {
            investmentCountdowns[inv.id] = _formatDuration(diff);
          }
        }
      }
    });
  }

  String _formatDuration(Duration d) {
    if (d.isNegative) return "00:00:00";
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
      } else {
        AppSnack.error(
          'error'.tr,
          response['error']?.toString() ?? 'no_rewards_ready'.tr,
        );
      }
    } catch (e, stack) {
      SafeGetx.debugTrace(className: 'HomeController', method: 'claimRewards', feature: 'Home', status: 'ERROR', error: e, stackTrace: stack);
    } finally {
      isClaimingLoading.value = false;
    }
  }
}
