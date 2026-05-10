import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kasby/core/services/supabase_service.dart';
import 'package:kasby/core/models/transaction_model.dart';
import 'package:kasby/core/models/agent_model.dart';
import 'package:kasby/core/theme/app_colors.dart';
import 'dart:async';

class AgentController extends GetxController {
  static AgentController get to => Get.find();

  final RxList<TransactionModel> pendingOperations = <TransactionModel>[].obs;
  final Rx<AgentModel?> agentProfile = Rx<AgentModel?>(null);
  final RxBool isLoading = false.obs;
  Timer? _heartbeatTimer;
  StreamSubscription? _notifSubscription;
  StreamSubscription? _txSubscription;

  @override
  void onInit() {
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
          debugPrint('[AGENT] Realtime Notif received: ${data.length} items');
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
          debugPrint('[AGENT] Realtime TX received: ${data.length} items');
          final txs = data.map((json) => TransactionModel.fromJson(json)).toList();
          
          // Filter for pending/processing only
          pendingOperations.value = txs.where((tx) => 
            tx.status == 'pending' || tx.status == 'processing'
          ).toList();
          
          // Also refresh profile stats whenever transaction changes
          fetchAgentProfile();
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
          .select('*, profiles(full_name, city, country_code, phone)')
          .eq('user_id', SupabaseService.userId!)
          .single();

      agentProfile.value = AgentModel.fromJson(response);
    } catch (e) {
      debugPrint('Error fetching agent profile: $e');
    }
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
    } catch (e) {
      debugPrint('Error fetching agent operations: $e');
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
        Get.snackbar(
          'success'.tr,
          'deposit_approved_successfully'.tr,
          backgroundColor: AppColors.softGreen,
          colorText: Colors.white,
        );
        fetchPendingOperations();
      } else {
        Get.snackbar('error'.tr, response['message']);
      }
    } catch (e) {
      debugPrint('Approve deposit error: $e');
      Get.snackbar('error'.tr, 'حدث خطأ أثناء معالجة الطلب');
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
        Get.snackbar(
          'success'.tr,
          'withdrawal_confirmed_successfully'.tr,
          backgroundColor: AppColors.softGreen,
          colorText: Colors.white,
        );
        fetchPendingOperations();
        fetchAgentProfile(); // Refresh profile to see escrow/commission changes
      } else {
        Get.snackbar('error'.tr, response['message']);
      }
    } catch (e) {
      debugPrint('Confirm withdrawal error: $e');
      Get.snackbar('error'.tr, 'حدث خطأ أثناء معالجة الطلب');
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

      Get.snackbar(
        'success'.tr,
        newStatus ? 'agent_now_online'.tr : 'agent_now_offline'.tr,
        backgroundColor: newStatus ? AppColors.softGreen : AppColors.textSecondary,
        colorText: Colors.white,
      );
    } catch (e) {
      debugPrint('Toggle availability error: $e');
    }
  }

  Future<void> updateHeartbeat() async {
    if (agentProfile.value == null) return;
    try {
      await SupabaseService.client
          .from('agents')
          .update({'last_active_at': DateTime.now().toIso8601String()})
          .eq('id', agentProfile.value!.id);
    } catch (e) {
      debugPrint('Heartbeat update error: $e');
    }
  }
}
