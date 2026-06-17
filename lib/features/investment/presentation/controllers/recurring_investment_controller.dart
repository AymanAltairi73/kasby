import 'package:get/get.dart';
import 'package:kasby/core/models/investment_plan_model.dart';
import 'package:kasby/core/models/recurring_investment_model.dart';
import 'package:kasby/core/services/recurring_investment_service.dart';
import 'package:kasby/core/services/supabase_service.dart';
import 'package:kasby/core/utils/safe_getx.dart';

class RecurringInvestmentController extends GetxController {
  static RecurringInvestmentController get to => Get.find();

  final recurringInvestments = <RecurringInvestmentModel>[].obs;
  final availablePlans = <InvestmentPlanModel>[].obs;
  final isLoading = false.obs;
  final hasError = false.obs;
  final isCreating = false.obs;

  @override
  void onInit() {
    super.onInit();
    fetchAll();
    fetchPlans();
  }

  Future<void> fetchAll() async {
    isLoading.value = true;
    hasError.value = false;
    try {
      final result = await RecurringInvestmentService.fetchAll();
      recurringInvestments.assignAll(result);
    } catch (e) {
      hasError.value = true;
      SafeGetx.debugTrace(
        className: 'RecurringInvestmentController',
        method: 'fetchAll',
        feature: 'RecurringInvestment',
        status: 'ERROR',
        error: e,
      );
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> fetchPlans() async {
    try {
      final response = await SupabaseService.client
          .from('investment_plans')
          .select()
          .eq('is_active', true)
          .order('min_amount');

      availablePlans.assignAll(
        (response as List)
            .map((json) => InvestmentPlanModel.fromJson(json))
            .toList(),
      );
    } catch (e) {
      SafeGetx.debugTrace(
        className: 'RecurringInvestmentController',
        method: 'fetchPlans',
        feature: 'RecurringInvestment',
        status: 'ERROR',
        error: e,
      );
    }
  }

  Future<bool> create({
    required String planId,
    required double amount,
    required String frequency,
    int? customDays,
    String? planName,
  }) async {
    isCreating.value = true;
    try {
      final result = await RecurringInvestmentService.create(
        planId: planId,
        amount: amount,
        frequency: frequency,
        customDays: customDays,
        planName: planName,
      );
      if (result != null) {
        recurringInvestments.insert(0, result);
        return true;
      }
      return false;
    } catch (e) {
      SafeGetx.debugTrace(
        className: 'RecurringInvestmentController',
        method: 'create',
        feature: 'RecurringInvestment',
        status: 'ERROR',
        error: e,
      );
      return false;
    } finally {
      isCreating.value = false;
    }
  }

  Future<bool> pause(String id) async {
    try {
      final success = await RecurringInvestmentService.pause(id);
      if (success) {
        final idx = recurringInvestments.indexWhere((r) => r.id == id);
        if (idx != -1) {
          recurringInvestments[idx] = recurringInvestments[idx].copyWith(
            status: 'paused',
            updatedAt: DateTime.now(),
          );
        }
      }
      return success;
    } catch (e) {
      SafeGetx.debugTrace(
        className: 'RecurringInvestmentController',
        method: 'pause',
        feature: 'RecurringInvestment',
        status: 'ERROR',
        error: e,
      );
      return false;
    }
  }

  Future<bool> resume(String id) async {
    try {
      final item = recurringInvestments.firstWhereOrNull((r) => r.id == id);
      final success = await RecurringInvestmentService.resume(
        id,
        frequency: item?.frequency,
        customDays: item?.customDays,
      );
      if (success) {
        await fetchAll();
      }
      return success;
    } catch (e) {
      SafeGetx.debugTrace(
        className: 'RecurringInvestmentController',
        method: 'resume',
        feature: 'RecurringInvestment',
        status: 'ERROR',
        error: e,
      );
      return false;
    }
  }

  Future<bool> cancel(String id) async {
    try {
      final success = await RecurringInvestmentService.cancel(id);
      if (success) {
        final idx = recurringInvestments.indexWhere((r) => r.id == id);
        if (idx != -1) {
          recurringInvestments[idx] = recurringInvestments[idx].copyWith(
            status: 'cancelled',
            nextExecutionDate: null,
            updatedAt: DateTime.now(),
          );
        }
      }
      return success;
    } catch (e) {
      SafeGetx.debugTrace(
        className: 'RecurringInvestmentController',
        method: 'cancel',
        feature: 'RecurringInvestment',
        status: 'ERROR',
        error: e,
      );
      return false;
    }
  }

  Future<bool> edit(
    String id, {
    double? amount,
    String? frequency,
    int? customDays,
  }) async {
    try {
      final result = await RecurringInvestmentService.edit(
        id,
        amount: amount,
        frequency: frequency,
        customDays: customDays,
      );
      if (result != null) {
        final idx = recurringInvestments.indexWhere((r) => r.id == id);
        if (idx != -1) {
          recurringInvestments[idx] = result;
        }
        return true;
      }
      return false;
    } catch (e) {
      SafeGetx.debugTrace(
        className: 'RecurringInvestmentController',
        method: 'edit',
        feature: 'RecurringInvestment',
        status: 'ERROR',
        error: e,
      );
      return false;
    }
  }

  int get activeCount =>
      recurringInvestments.where((r) => r.isActive).length;

  int get pausedCount =>
      recurringInvestments.where((r) => r.isPaused).length;
}
