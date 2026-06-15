import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kasby/core/services/supabase_service.dart';
import 'package:kasby/core/utils/safe_getx.dart';
import 'package:kasby/core/models/transaction_model.dart';
import 'package:kasby/core/models/agent_model.dart';
import 'package:kasby/core/models/profile_model.dart';
import 'package:kasby/features/home/presentation/controllers/home_controller.dart';
import 'package:kasby/core/theme/app_colors.dart';
import 'dart:async';

class AgentController extends GetxController {
  static AgentController get to => Get.find();

  final RxList<TransactionModel> pendingOperations = <TransactionModel>[].obs;
  final Rx<AgentModel?> agentProfile = Rx<AgentModel?>(null);
  final RxBool isLoading = false.obs;
  final RxBool agentRecordMissing = false.obs;
  Timer? _heartbeatTimer;
  StreamSubscription? _notifSubscription;
  StreamSubscription? _txSubscription;

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
    SafeGetx.debugTrace(
      className: 'AgentController',
      method: 'onClose',
      feature: 'Profile',
      status: 'INFO',
    );
    _heartbeatTimer?.cancel();
    _notifSubscription?.cancel();
    _txSubscription?.cancel();
    super.onClose();
  }

  Future<void> refreshData() async {
    await Future.wait([
      fetchAgentProfile(),
      fetchPendingOperations(),
    ]);
  }

  void _listenToAssignments() {
    if (!SupabaseService.isLoggedIn) return;

    final userId = SupabaseService.userId!;

    // 1. Listen for Notifications assigned to Agent
    _notifSubscription = SupabaseService.client
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .listen((data) {
          SafeGetx.debugTrace(
            className: 'AgentController',
            method: '_listenToAssignments',
            feature: 'Profile',
            status: 'INFO',
            params: {'notifCount': data.length},
          );
          // Filter in Dart since stream only supports one eq filter
          final agentNotifs = data.where((n) => n['role_target'] == 'agent').toList();
          
          if (agentNotifs.any((notif) => notif['read_at'] == null)) {
            refreshData();
          }
        });

    // 2. Listen for Transactions directly assigned to Agent
    _txSubscription = SupabaseService.client
        .from('transactions')
        .stream(primaryKey: ['id'])
        .eq('reference_id', userId)
        .listen((data) {
          SafeGetx.debugTrace(
            className: 'AgentController',
            method: '_listenToAssignments',
            feature: 'Profile',
            status: 'INFO',
            params: {'txCount': data.length},
          );
          final txs = data.map((json) => TransactionModel.fromJson(json)).toList();
          
          // Filter for pending/processing only
          pendingOperations.value = txs.where((tx) => 
            tx.status == 'pending' || tx.status == 'processing'
          ).toList();
          
          // Refresh profile stats only when an agent record exists
          if (!agentRecordMissing.value) {
            fetchAgentProfile();
          }
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
          .select('*, profiles(full_name, city, country_code, phone, email, whatsapp, telegram, country, province, address)')
          .eq('user_id', SupabaseService.userId!)
          .maybeSingle();

      if (response == null) {
        final profile = HomeController.to.profile.value ??
            await _loadProfileRole();
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
      if (result is Map && result['success'] == true) {
        SafeGetx.debugTrace(
          className: 'AgentController',
          method: '_ensureAgentProfile',
          feature: 'Profile',
          status: 'SUCCESS',
          params: {'created': result['created']?.toString() ?? 'false'},
        );
        return true;
      }
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

  Future<void> fetchPendingOperations() async {
    if (!SupabaseService.isLoggedIn) return;
    isLoading.value = true;
    try {
      // Fetch operations assigned to this agent that are still pending
      // 🔧 FIX: Using reference_id (not processed_by) to match RLS policy
      // reference_id = agent assigned to the transaction (for RLS check)
      // processed_by = agent who actually processed it (set after completion)
      final response = await SupabaseService.client
          .from('transactions')
          .select()
          .eq('reference_id', SupabaseService.userId!)  // ✅ Matches RLS policy
          .or('status.eq.pending,status.eq.processing')
          .order('created_at', ascending: false);

      pendingOperations.value = (response as List)
          .map((json) => TransactionModel.fromJson(json))
          .toList();
    } catch (e, stack) {
      SafeGetx.debugTrace(
        className: 'AgentController',
        method: 'fetchPendingOperations',
        feature: 'Profile',
        status: 'ERROR',
        error: e,
        stackTrace: stack,
      );
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> approveDeposit(String transactionId) async {
    isLoading.value = true;
    try {
      final response = await SupabaseService.client.rpc(
        'agent_approve_deposit',
        params: {'p_transaction_id': transactionId},
      );

      if (response['success'] == true) {
        SafeGetx.snackbar(
          title: 'success'.tr,
          message: 'deposit_approved_successfully'.tr,
          backgroundColor: AppColors.softGreen,
          colorText: Colors.white,
        );
        fetchPendingOperations();
      } else {
        SafeGetx.snackbar(title: 'error'.tr, message: response['message'].toString());
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
      SafeGetx.snackbar(title: 'error'.tr, message: 'agent_process_error'.tr);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> confirmWithdrawal(String transactionId) async {
    isLoading.value = true;
    try {
      final response = await SupabaseService.client.rpc(
        'agent_confirm_withdrawal',
        params: {'p_transaction_id': transactionId},
      );

      if (response['success'] == true) {
        SafeGetx.snackbar(
          title: 'success'.tr,
          message: 'withdrawal_confirmed_successfully'.tr,
          backgroundColor: AppColors.softGreen,
          colorText: Colors.white,
        );
        fetchPendingOperations();
        fetchAgentProfile(); // Refresh profile to see escrow/commission changes
      } else {
        SafeGetx.snackbar(title: 'error'.tr, message: response['message'].toString());
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
      SafeGetx.snackbar(title: 'error'.tr, message: 'agent_process_error'.tr);
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
            'last_active_at': DateTime.now().toIso8601String()
          })
          .eq('id', agentProfile.value!.id);

      agentProfile.value = agentProfile.value!.copyWith(isAvailableNow: newStatus);

      SafeGetx.snackbar(
        title: 'success'.tr,
        message: newStatus ? 'agent_now_online'.tr : 'agent_now_offline'.tr,
        backgroundColor: newStatus ? AppColors.softGreen : AppColors.textSecondary,
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
    } catch (e, stack) {
      SafeGetx.debugTrace(
        className: 'AgentController',
        method: 'updateHeartbeat',
        feature: 'Profile',
        status: 'ERROR',
        error: e,
        stackTrace: stack,
      );
    }
  }
}
