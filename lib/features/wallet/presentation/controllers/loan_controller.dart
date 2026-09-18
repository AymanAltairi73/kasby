import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kasby/core/services/snack_service.dart';
import 'package:kasby/core/services/supabase_service.dart';
import 'package:kasby/core/models/loan_model.dart';
import 'package:kasby/core/models/loan_repayment_model.dart';
import 'package:kasby/core/utils/safe_getx.dart';

class LoanController extends GetxController {
  static LoanController get to => Get.find();

  final RxList<LoanModel> loanHistory = <LoanModel>[].obs;
  final RxList<LoanModel> activeLoans = <LoanModel>[].obs;
  final RxList<LoanRepaymentModel> repaymentHistory =
      <LoanRepaymentModel>[].obs;

  final RxBool isLoadingHistory = false.obs;
  final RxBool isLoadingActive = false.obs;
  final RxBool isLoadingRepayments = false.obs;
  final RxBool isSubmitting = false.obs;

  final RxDouble activeInvestmentValue = 0.0.obs;
  final RxDouble serverInterestRate = 0.10.obs;
  final RxDouble loanMaxPercentage = 0.50.obs;
  final RxDouble existingLoanExposure = 0.0.obs;

  double get totalLoanCapacity =>
      (activeInvestmentValue.value * loanMaxPercentage.value);

  double get remainingLoanCapacity {
    final remaining = totalLoanCapacity - existingLoanExposure.value;
    return remaining > 0 ? remaining : 0.0;
  }

  @override
  void onInit() {
    SafeGetx.debugTrace(
      className: 'LoanController',
      method: 'onInit',
      feature: 'Wallet',
      status: 'INFO',
    );
    super.onInit();
    refreshData();
  }

  @override
  void onClose() {
    SafeGetx.debugTrace(
      className: 'LoanController',
      method: 'onClose',
      feature: 'Wallet',
      status: 'INFO',
    );
    super.onClose();
  }

  Future<void> refreshData() async {
    await Future.wait([
      fetchActiveInvestmentValue(),
      fetchLoanHistory(),
      fetchActiveLoans(),
      fetchRepaymentHistory(),
      fetchServerInterestRate(),
      fetchLoanMaxPercentage(),
    ]);
    calculateLoanExposure();
  }

  Future<void> fetchLoanMaxPercentage() async {
    try {
      final response = await SupabaseService.client
          .from('app_config')
          .select('value')
          .eq('key', 'loan_max_percentage')
          .maybeSingle();

      if (response != null && response['value'] != null) {
        final rate = double.tryParse(response['value'].toString());
        if (rate != null && rate > 0) {
          loanMaxPercentage.value = rate;
        }
      }
    } catch (e, stack) {
      SafeGetx.debugTrace(
        className: 'LoanController',
        method: 'fetchLoanMaxPercentage',
        feature: 'Wallet',
        status: 'ERROR',
        error: e,
        stackTrace: stack,
      );
    }
  }

  void calculateLoanExposure() {
    const exposureStatuses = {
      'pending',
      'approved',
      'active',
      'current',
      'partial_paid',
      'delayed',
      'overdue',
    };

    double totalExposure = 0.0;
    for (final loan in loanHistory) {
      if (exposureStatuses.contains(loan.status)) {
        final remainingPrincipal = loan.amount - loan.paidAmount;
        if (remainingPrincipal > 0) {
          totalExposure += remainingPrincipal;
        }
      }
    }
    existingLoanExposure.value = totalExposure;
  }

  Future<void> fetchServerInterestRate() async {
    try {
      final response = await SupabaseService.client
          .from('app_config')
          .select('value')
          .eq('key', 'loan_interest_rate')
          .maybeSingle();

      if (response != null && response['value'] != null) {
        final rate = double.tryParse(response['value'].toString());
        if (rate != null && rate > 0) {
          serverInterestRate.value = rate;
        }
      }
    } catch (e, stack) {
      SafeGetx.debugTrace(
        className: 'LoanController',
        method: 'fetchServerInterestRate',
        feature: 'Wallet',
        status: 'ERROR',
        error: e,
        stackTrace: stack,
      );
    }
  }

  Future<void> fetchActiveInvestmentValue() async {
    try {
      final response = await SupabaseService.client
          .from('wallets')
          .select('invested_balance')
          .eq('user_id', SupabaseService.userId!)
          .eq('currency', 'USD')
          .maybeSingle();

      if (response != null) {
        activeInvestmentValue.value =
            (response['invested_balance'] as num?)?.toDouble() ?? 0.0;
      }
    } catch (e, stack) {
      SafeGetx.debugTrace(
        className: 'LoanController',
        method: 'fetchActiveInvestmentValue',
        feature: 'Wallet',
        status: 'ERROR',
        error: e,
        stackTrace: stack,
      );
    }
  }

  Future<void> fetchLoanHistory() async {
    isLoadingHistory.value = true;
    try {
      final response = await SupabaseService.client
          .from('loans')
          .select()
          .eq('user_id', SupabaseService.userId!)
          .order('created_at', ascending: false);

      loanHistory.value = (response as List)
          .map((json) => LoanModel.fromJson(json))
          .toList();
      calculateLoanExposure();
    } catch (e, stack) {
      SafeGetx.debugTrace(
        className: 'LoanController',
        method: 'fetchLoanHistory',
        feature: 'Wallet',
        status: 'ERROR',
        error: e,
        stackTrace: stack,
      );
    } finally {
      isLoadingHistory.value = false;
    }
  }

  Future<void> fetchActiveLoans() async {
    isLoadingActive.value = true;
    try {
      final response = await SupabaseService.client
          .from('loans')
          .select()
          .eq('user_id', SupabaseService.userId!)
          .inFilter('status', [
            'active',
            'partial_paid',
            'overdue',
            'current',
            'delayed',
          ])
          .order('created_at', ascending: false);

      activeLoans.value = (response as List)
          .map((json) => LoanModel.fromJson(json))
          .toList();
    } catch (e, stack) {
      SafeGetx.debugTrace(
        className: 'LoanController',
        method: 'fetchActiveLoans',
        feature: 'Wallet',
        status: 'ERROR',
        error: e,
        stackTrace: stack,
      );
    } finally {
      isLoadingActive.value = false;
    }
  }

  Future<void> fetchRepaymentHistory() async {
    isLoadingRepayments.value = true;
    try {
      final response = await SupabaseService.client
          .from('loan_repayments')
          .select()
          .eq('user_id', SupabaseService.userId!)
          .order('created_at', ascending: false);

      repaymentHistory.value = (response as List)
          .map((json) => LoanRepaymentModel.fromJson(json))
          .toList();
    } catch (e, stack) {
      SafeGetx.debugTrace(
        className: 'LoanController',
        method: 'fetchRepaymentHistory',
        feature: 'Wallet',
        status: 'ERROR',
        error: e,
        stackTrace: stack,
      );
    } finally {
      isLoadingRepayments.value = false;
    }
  }

  Future<void> applyForLoan(double amount, int duration) async {
    if (amount <= 0) {
      AppSnack.error('error'.tr, 'invalid_amount'.tr);
      return;
    }
    if (remainingLoanCapacity <= 0) {
      AppSnack.error('error'.tr, 'loan_capacity_exhausted'.tr);
      return;
    }
    if (amount > remainingLoanCapacity) {
      AppSnack.error('error'.tr, 'amount_exceeds_max_loan'.tr);
      return;
    }

    isSubmitting.value = true;
    debugPrint(
      '[LOAN_CONTROLLER] 🚀 applyForLoan initiated: amount=$amount, duration=$duration months, userId=${SupabaseService.userId}',
    );
    try {
      final params = {'p_amount': amount, 'p_duration_months': duration};
      debugPrint('[LOAN_CONTROLLER] 📤 Sending RPC "create_loan" with params: $params');

      final response = await SupabaseService.client.rpc(
        'create_loan',
        params: params,
      );

      debugPrint('[LOAN_CONTROLLER] 📥 RPC "create_loan" raw response: $response');

      if (response != null && response['success'] == true) {
        debugPrint('[LOAN_CONTROLLER] ✅ Loan application successful!');
        Get.back();
        AppSnack.success(
          'success'.tr,
          'loan_applied_successfully'.tr,
        );
        refreshData();
      } else {
        final errorMsg = response?['message'] ?? response?['error'] ?? 'unknown_error'.tr;
        debugPrint('[LOAN_CONTROLLER] ❌ Loan application refused by backend: $errorMsg');
        AppSnack.error('error'.tr, errorMsg.toString());
      }
    } catch (e, stack) {
      debugPrint('[LOAN_CONTROLLER] 💥 Exception during applyForLoan: $e');
      debugPrint('[LOAN_CONTROLLER] 📜 Stack trace:\n$stack');
      SafeGetx.debugTrace(
        className: 'LoanController',
        method: 'applyForLoan',
        feature: 'Wallet',
        status: 'ERROR',
        error: e,
        stackTrace: stack,
      );
      AppSnack.error('error'.tr, 'loan_submission_error'.tr);
    } finally {
      isSubmitting.value = false;
      debugPrint('[LOAN_CONTROLLER] 🏁 applyForLoan finished.');
    }
  }

  Future<void> repayLoan(String loanId, double amount, String type) async {
    isSubmitting.value = true;
    try {
      SafeGetx.debugTrace(
        className: 'LoanController',
        method: 'repayLoan',
        feature: 'Wallet',
        status: 'INFO',
        params: {'loanId': loanId, 'amount': amount, 'type': type},
      );
      final response = await SupabaseService.client.rpc(
        'repay_loan',
        params: {
          'p_loan_id': loanId,
          'p_amount': amount,
          'p_type': type,
          'p_idempotency_key':
              'repay-$loanId-${DateTime.now().microsecondsSinceEpoch}',
        },
      );

      if (response['success'] == true) {
        SafeGetx.debugTrace(
          className: 'LoanController',
          method: 'repayLoan',
          feature: 'Wallet',
          status: 'SUCCESS',
          params: {'remaining': response['remaining']},
        );
        AppSnack.success(
          'success'.tr,
          response['message']?.toString() ?? 'repayment_success'.tr,
        );
        refreshData();
      } else {
        final message = response?['message']?.toString() ?? 'unknown_error'.tr;
        SafeGetx.debugTrace(
          className: 'LoanController',
          method: 'repayLoan',
          feature: 'Wallet',
          status: 'FAILED',
          params: {'message': message},
        );
        AppSnack.error('error'.tr, message);
      }
    } catch (e, stack) {
      SafeGetx.debugTrace(
        className: 'LoanController',
        method: 'repayLoan',
        feature: 'Wallet',
        status: 'ERROR',
        error: e,
        stackTrace: stack,
      );
      AppSnack.error('error'.tr, 'loan_repayment_error'.tr);
    } finally {
      isSubmitting.value = false;
    }
  }
}
