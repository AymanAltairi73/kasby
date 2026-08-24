import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:kasby/core/services/supabase_service.dart';
import 'package:kasby/core/utils/safe_getx.dart';
import 'package:kasby/core/models/transaction_model.dart';
import 'package:kasby/core/models/agent_model.dart';
import 'package:kasby/core/models/profile_model.dart';
import 'package:kasby/core/controllers/currency_controller.dart';
import 'package:kasby/features/home/presentation/controllers/home_controller.dart';
import 'package:kasby/core/theme/app_colors.dart';
import 'dart:async';

enum AgentTransactionFilter { pending, approved, rejected }

class AgentController extends GetxController {
  static AgentController get to => Get.find();

  final RxList<TransactionModel> operations = <TransactionModel>[].obs;
  final RxList<TransactionModel> pendingOperations = <TransactionModel>[].obs;
  final Rx<AgentModel?> agentProfile = Rx<AgentModel?>(null);
  final RxBool isLoading = false.obs;
  final RxBool agentRecordMissing = false.obs;
  final RxInt pendingCount = 0.obs;
  final RxInt unreadAgentNotifCount = 0.obs;
  final RxString searchQuery = ''.obs;
  final Rx<AgentTransactionFilter> statusFilter =
      AgentTransactionFilter.pending.obs;
  final RxString typeFilter = 'all'.obs; // all | deposit | withdrawal
  final RxInt totalCount = 0.obs;
  final RxInt currentPage = 0.obs;
  final RxMap<String, dynamic> performanceStats = <String, dynamic>{}.obs;
  static const int pageSize = 20;

  Timer? _heartbeatTimer;
  StreamSubscription? _notifSubscription;
  StreamSubscription? _txSubscription;
  Timer? _searchDebounce;

  String? get _agentId => agentProfile.value?.id;

  bool get isOnline => agentProfile.value?.isAvailableNow ?? false;

  Map<String, dynamic>? _parseRpcResponse(dynamic response) {
    if (response == null) return null;
    if (response is Map) {
      return Map<String, dynamic>.from(response);
    }
    return null;
  }

  String _rpcErrorMessage(Object error, [Map<String, dynamic>? response]) {
    if (response != null) {
      final message = response['message'] ?? response['error'];
      if (message != null && message.toString().trim().isNotEmpty) {
        return message.toString();
      }
    }
    if (error is PostgrestException) {
      return error.message;
    }
    return 'agent_process_error'.tr;
  }

  @override
  void onInit() {
    SafeGetx.debugTrace(
      className: 'AgentController',
      method: 'onInit',
      feature: 'Profile',
      status: 'INFO',
    );
    super.onInit();
    refreshData();
    _startHeartbeat();
    _listenToAssignments();
  }

  @override
  void onClose() {
    _heartbeatTimer?.cancel();
    _notifSubscription?.cancel();
    _txSubscription?.cancel();
    _searchDebounce?.cancel();
    super.onClose();
  }

  Future<void> refreshData() async {
    await fetchAgentProfile();
    if (Get.isRegistered<CurrencyController>()) {
      unawaited(CurrencyController.to.fetchWalletBalances());
    }
    await Future.wait([
      fetchOperations(),
      fetchPerformanceStats(),
      _fetchUnreadAgentNotifications(),
    ]);
  }

  Future<void> fetchPerformanceStats() async {
    if (!SupabaseService.isLoggedIn || _agentId == null) return;
    try {
      final response = await SupabaseService.client.rpc(
        'fn_get_agent_performance_stats',
      );
      if (response is Map && response['success'] == true) {
        performanceStats.value = Map<String, dynamic>.from(response);
      }
    } catch (e, stack) {
      SafeGetx.debugTrace(
        className: 'AgentController',
        method: 'fetchPerformanceStats',
        feature: 'Profile',
        status: 'ERROR',
        error: e,
        stackTrace: stack,
      );
    }
  }

  Future<void> openNotificationHistory() async {
    await Get.toNamed('/notifications');
  }

  void setStatusFilter(AgentTransactionFilter filter) {
    statusFilter.value = filter;
    currentPage.value = 0;
    fetchOperations();
  }

  void setTypeFilter(String type) {
    typeFilter.value = type;
    currentPage.value = 0;
    fetchOperations();
  }

  void search(String query) {
    searchQuery.value = query;
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      currentPage.value = 0;
      fetchOperations();
    });
  }

  Future<void> loadNextPage() async {
    if (operations.length >= totalCount.value) return;
    currentPage.value++;
    await fetchOperations(append: true);
  }

  void _listenToAssignments() {
    if (!SupabaseService.isLoggedIn) return;

    final userId = SupabaseService.userId!;

    _notifSubscription = SupabaseService.client
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .listen((data) {
          final agentNotifs = data
              .where((n) => n['role_target'] == 'agent')
              .toList();
          unreadAgentNotifCount.value = agentNotifs
              .where((n) => n['read_at'] == null)
              .length;
          if (agentNotifs.any((notif) => notif['read_at'] == null)) {
            refreshData();
          }
        });

    // Realtime refresh when agent profile is loaded
    ever(agentProfile, (profile) {
      _txSubscription?.cancel();
      if (profile?.id == null) return;

      _txSubscription = SupabaseService.client
          .from('transactions')
          .stream(primaryKey: ['id'])
          .eq('reference_id', profile!.id)
          .listen((_) => fetchOperations());
    });
  }

  void _startHeartbeat() {
    _heartbeatTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      if (agentProfile.value?.isAvailableNow ?? false) {
        updateHeartbeat();
      }
    });
  }

  Future<void> fetchAgentProfile() async {
    if (!SupabaseService.isLoggedIn) return;
    try {
      final response = await SupabaseService.client
          .from('agents')
          .select(
            '*, profiles(full_name, city, country_code, phone, email, whatsapp, telegram, country, province, address)',
          )
          .eq('user_id', SupabaseService.userId!)
          .maybeSingle();

      if (response == null) {
        final profile =
            HomeController.to.profile.value ?? await _loadProfileRole();
        if (profile?.role == 'agent') {
          final ensured = await _ensureAgentProfile();
          if (ensured) {
            await fetchAgentProfile();
            return;
          }
        }
        agentProfile.value = null;
        agentRecordMissing.value = true;
        return;
      }

      agentRecordMissing.value = false;
      agentProfile.value = AgentModel.fromJson(response);
    } catch (e, stack) {
      SafeGetx.debugTrace(
        className: 'AgentController',
        method: 'fetchAgentProfile',
        feature: 'Profile',
        status: 'ERROR',
        error: e,
        stackTrace: stack,
      );
    }
  }

  Future<ProfileModel?> _loadProfileRole() async {
    try {
      final response = await SupabaseService.client
          .from('profiles')
          .select()
          .eq('id', SupabaseService.userId!)
          .maybeSingle();
      if (response == null) return null;
      return ProfileModel.fromJson(response);
    } catch (_) {
      return null;
    }
  }

  Future<bool> _ensureAgentProfile() async {
    try {
      final result = await SupabaseService.client.rpc('ensure_agent_profile');
      if (result is Map && result['success'] == true) return true;
    } catch (e, stack) {
      SafeGetx.debugTrace(
        className: 'AgentController',
        method: '_ensureAgentProfile',
        feature: 'Profile',
        status: 'ERROR',
        error: e,
        stackTrace: stack,
      );
    }
    return false;
  }

  String _statusRpcParam() {
    switch (statusFilter.value) {
      case AgentTransactionFilter.pending:
        return 'pending';
      case AgentTransactionFilter.approved:
        return 'approved';
      case AgentTransactionFilter.rejected:
        return 'rejected';
    }
  }

  Future<void> fetchOperations({bool append = false}) async {
    if (!SupabaseService.isLoggedIn || _agentId == null) return;
    isLoading.value = true;
    try {
      final response = await SupabaseService.client.rpc(
        'fn_get_agent_transactions',
        params: {
          'p_status': _statusRpcParam(),
          'p_type': typeFilter.value == 'all' ? null : typeFilter.value,
          'p_search': searchQuery.value.trim().isEmpty
              ? null
              : searchQuery.value.trim(),
          'p_limit': pageSize,
          'p_offset': currentPage.value * pageSize,
        },
      );

      if (response is Map && response['success'] == true) {
        final rows = (response['data'] as List? ?? [])
            .map(
              (json) => TransactionModel.fromJson(
                Map<String, dynamic>.from(json as Map),
              ),
            )
            .toList();

        if (append) {
          operations.addAll(rows);
        } else {
          operations.value = rows;
        }
        totalCount.value = (response['total'] as num?)?.toInt() ?? rows.length;

        if (statusFilter.value == AgentTransactionFilter.pending) {
          pendingOperations.value = rows;
          pendingCount.value = totalCount.value;
        } else if (!append) {
          await _refreshPendingCount();
        }
      } else {
        await _fetchOperationsFallback(append: append);
      }
    } catch (e, stack) {
      SafeGetx.debugTrace(
        className: 'AgentController',
        method: 'fetchOperations',
        feature: 'Profile',
        status: 'ERROR',
        error: e,
        stackTrace: stack,
      );
      await _fetchOperationsFallback(append: append);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _fetchOperationsFallback({bool append = false}) async {
    if (_agentId == null) return;

    final response = await SupabaseService.client
        .from('transactions')
        .select()
        .eq('reference_id', _agentId!)
        .inFilter('type', ['deposit', 'withdrawal'])
        .order('created_at', ascending: false)
        .range(
          currentPage.value * pageSize,
          (currentPage.value + 1) * pageSize - 1,
        );

    var rows = (response as List)
        .map((json) => TransactionModel.fromJson(json))
        .toList();

    rows = rows.where((tx) {
      switch (statusFilter.value) {
        case AgentTransactionFilter.pending:
          return tx.status == 'pending' || tx.status == 'processing';
        case AgentTransactionFilter.approved:
          return tx.status == 'completed' || tx.status == 'approved';
        case AgentTransactionFilter.rejected:
          return tx.status == 'rejected';
      }
    }).toList();

    if (typeFilter.value != 'all') {
      rows = rows.where((tx) => tx.type == typeFilter.value).toList();
    }

    final q = searchQuery.value.trim().toLowerCase();
    if (q.isNotEmpty) {
      rows = rows
          .where(
            (tx) =>
                tx.id.toLowerCase().contains(q) ||
                tx.userId.toLowerCase().contains(q),
          )
          .toList();
    }

    if (append) {
      operations.addAll(rows);
    } else {
      operations.value = rows;
    }

    if (statusFilter.value == AgentTransactionFilter.pending) {
      pendingOperations.value = rows;
      pendingCount.value = rows.length;
    }
  }

  Future<void> _refreshPendingCount() async {
    if (_agentId == null) return;
    try {
      final response = await SupabaseService.client
          .from('transactions')
          .select('id')
          .eq('reference_id', _agentId!)
          .inFilter('status', ['pending', 'processing'])
          .inFilter('type', ['deposit', 'withdrawal']);
      pendingCount.value = (response as List).length;
    } catch (_) {}
  }

  Future<void> _fetchUnreadAgentNotifications() async {
    if (!SupabaseService.isLoggedIn) return;
    try {
      final response = await SupabaseService.client
          .from('notifications')
          .select('id')
          .eq('user_id', SupabaseService.userId!)
          .eq('role_target', 'agent')
          .filter('read_at', 'is', null);
      unreadAgentNotifCount.value = (response as List).length;
    } catch (_) {}
  }

  @Deprecated('Use fetchOperations')
  Future<void> fetchPendingOperations() => fetchOperations();

  Future<Map<String, dynamic>?> fetchCustomerDetails({
    required String userId,
    String? transactionId,
  }) async {
    if (!SupabaseService.isLoggedIn) return null;
    try {
      final response = await SupabaseService.client.rpc(
        'fn_get_agent_customer_details',
        params: {'p_user_id': userId, 'p_transaction_id': transactionId},
      );
      if (response is Map && response['success'] == true) {
        return Map<String, dynamic>.from(response);
      }
    } catch (e, stack) {
      SafeGetx.debugTrace(
        className: 'AgentController',
        method: 'fetchCustomerDetails',
        feature: 'Profile',
        status: 'ERROR',
        error: e,
        stackTrace: stack,
        params: {'userId': userId, 'transactionId': transactionId},
      );
    }
    return null;
  }

  Future<void> approveDeposit(String transactionId) async {
    isLoading.value = true;
    Map<String, dynamic>? parsed;
    try {
      SafeGetx.debugTrace(
        className: 'AgentController',
        method: 'approveDeposit',
        feature: 'Profile',
        status: 'INFO',
        params: {'transactionId': transactionId},
      );

      final response = await SupabaseService.client.rpc(
        'agent_approve_deposit',
        params: {'p_transaction_id': transactionId},
      );

      SafeGetx.debugTrace(
        className: 'AgentController',
        method: 'approveDeposit',
        feature: 'Profile',
        status: 'INFO',
        params: {'response': response},
      );

      parsed = _parseRpcResponse(response);

      if (parsed?['success'] == true) {
        final warning = parsed?['commission_warning']?.toString();
        SafeGetx.snackbar(
          title: 'success'.tr,
          message: warning != null && warning.isNotEmpty
              ? '${'deposit_approved_successfully'.tr}\n$warning'
              : 'deposit_approved_successfully'.tr,
          backgroundColor: AppColors.softGreen,
          colorText: Colors.white,
        );
        await refreshData();
      } else {
        SafeGetx.debugTrace(
          className: 'AgentController',
          method: 'approveDeposit',
          feature: 'Profile',
          status: 'ERROR',
          params: {'parsedResponse': parsed},
        );
        SafeGetx.snackbar(
          title: 'error'.tr,
          message: _rpcErrorMessage('', parsed),
        );
      }
    } catch (e, stack) {
      SafeGetx.debugTrace(
        className: 'AgentController',
        method: 'approveDeposit',
        feature: 'Profile',
        status: 'ERROR',
        params: {'transactionId': transactionId},
        error: e,
        stackTrace: stack,
      );
      SafeGetx.snackbar(
        title: 'error'.tr,
        message: _rpcErrorMessage(e, parsed),
      );
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> confirmWithdrawal(String transactionId) async {
    isLoading.value = true;
    Map<String, dynamic>? parsed;
    try {
      final response = await SupabaseService.client.rpc(
        'agent_confirm_withdrawal',
        params: {'p_transaction_id': transactionId},
      );
      parsed = _parseRpcResponse(response);

      if (parsed?['success'] == true) {
        final warning = parsed?['commission_warning']?.toString();
        SafeGetx.snackbar(
          title: 'success'.tr,
          message: warning != null && warning.isNotEmpty
              ? '${'withdrawal_confirmed_successfully'.tr}\n$warning'
              : 'withdrawal_confirmed_successfully'.tr,
          backgroundColor: AppColors.softGreen,
          colorText: Colors.white,
        );
        await refreshData();
      } else {
        SafeGetx.snackbar(
          title: 'error'.tr,
          message: _rpcErrorMessage('', parsed),
        );
      }
    } catch (e, stack) {
      SafeGetx.debugTrace(
        className: 'AgentController',
        method: 'confirmWithdrawal',
        feature: 'Profile',
        status: 'ERROR',
        params: {'transactionId': transactionId},
        error: e,
        stackTrace: stack,
      );
      SafeGetx.snackbar(
        title: 'error'.tr,
        message: _rpcErrorMessage(e, parsed),
      );
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> rejectTransaction(String transactionId, String reason) async {
    if (reason.trim().isEmpty) {
      SafeGetx.snackbar(title: 'error'.tr, message: 'rejection_reason_hint'.tr);
      return;
    }

    isLoading.value = true;
    Map<String, dynamic>? parsed;
    try {
      final response = await SupabaseService.client.rpc(
        'agent_reject_transaction',
        params: {'p_transaction_id': transactionId, 'p_reason': reason.trim()},
      );
      parsed = _parseRpcResponse(response);

      if (parsed?['success'] == true) {
        SafeGetx.snackbar(
          title: 'success'.tr,
          message: 'request_rejected'.tr,
          backgroundColor: AppColors.textSecondary,
          colorText: Colors.white,
        );
        await refreshData();
      } else {
        SafeGetx.snackbar(
          title: 'error'.tr,
          message: _rpcErrorMessage('', parsed),
        );
      }
    } catch (e, stack) {
      SafeGetx.debugTrace(
        className: 'AgentController',
        method: 'rejectTransaction',
        feature: 'Profile',
        status: 'ERROR',
        error: e,
        stackTrace: stack,
      );
      SafeGetx.snackbar(
        title: 'error'.tr,
        message: _rpcErrorMessage(e, parsed),
      );
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> toggleAvailability() async {
    if (agentProfile.value == null) return;

    final newStatus = !agentProfile.value!.isAvailableNow;
    try {
      await SupabaseService.client
          .from('agents')
          .update({
            'is_available_now': newStatus,
            'last_active_at': DateTime.now().toIso8601String(),
          })
          .eq('id', agentProfile.value!.id);

      agentProfile.value = agentProfile.value!.copyWith(
        isAvailableNow: newStatus,
        lastActiveAt: DateTime.now(),
      );

      if (newStatus) {
        await updateHeartbeat();
      }

      SafeGetx.snackbar(
        title: 'success'.tr,
        message: newStatus ? 'agent_now_online'.tr : 'agent_now_offline'.tr,
        backgroundColor: newStatus
            ? AppColors.softGreen
            : AppColors.textSecondary,
        colorText: Colors.white,
      );
    } catch (e, stack) {
      SafeGetx.debugTrace(
        className: 'AgentController',
        method: 'toggleAvailability',
        feature: 'Profile',
        status: 'ERROR',
        error: e,
        stackTrace: stack,
      );
    }
  }

  Future<void> updateHeartbeat() async {
    if (agentProfile.value == null) return;
    try {
      await SupabaseService.client
          .from('agents')
          .update({'last_active_at': DateTime.now().toIso8601String()})
          .eq('id', agentProfile.value!.id);
    } catch (_) {}
  }
}
