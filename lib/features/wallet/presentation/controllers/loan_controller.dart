import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kasby/core/services/supabase_service.dart';
import 'package:kasby/core/models/loan_model.dart';
import 'package:kasby/core/models/loan_repayment_model.dart';
import 'package:kasby/core/theme/app_colors.dart';

class LoanController extends GetxController {
  static LoanController get to => Get.find();

  final RxList<LoanModel> loanHistory = <LoanModel>[].obs;
  final RxList<LoanModel> activeLoans = <LoanModel>[].obs;
  final RxList<LoanRepaymentModel> repaymentHistory = <LoanRepaymentModel>[].obs;
  
  final RxBool isLoadingHistory = false.obs;
  final RxBool isLoadingActive = false.obs;
  final RxBool isLoadingRepayments = false.obs;
  final RxBool isSubmitting = false.obs;
  
  final RxDouble activeInvestmentValue = 0.0.obs;

  @override
  void onInit() {
    super.onInit();
    refreshData();
  }

  Future<void> refreshData() async {
    await Future.wait([
      fetchActiveInvestmentValue(),
      fetchLoanHistory(),
      fetchActiveLoans(),
      fetchRepaymentHistory(),
    ]);
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
        activeInvestmentValue.value = (response['invested_balance'] as num?)?.toDouble() ?? 0.0;
      }
    } catch (e) {
      debugPrint('Error fetching wallet: $e');
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
    } catch (e, stack) {
      debugPrint('[LoanController] Error in fetchLoanHistory: $e');
      debugPrint('Stack: $stack');
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
          .inFilter('status', ['active', 'partial_paid', 'overdue'])
          .order('created_at', ascending: false);

      activeLoans.value = (response as List)
          .map((json) => LoanModel.fromJson(json))
          .toList();
    } catch (e, stack) {
      debugPrint('[LoanController] Error in fetchActiveLoans: $e');
      debugPrint('Stack: $stack');
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
      debugPrint('[LoanController] Error in fetchRepaymentHistory: $e');
      debugPrint('Stack: $stack');
    } finally {
      isLoadingRepayments.value = false;
    }
  }

  Future<void> applyForLoan(double amount, int duration) async {
    isSubmitting.value = true;
    try {
      final response = await SupabaseService.client.rpc(
        'create_loan',
        params: {
          'p_amount': amount,
          'p_duration_months': duration,
        },
      );

      if (response['success'] == true) {
        Get.back();
        Get.snackbar(
          'success'.tr, 
          'loan_applied_successfully'.tr,
          backgroundColor: AppColors.softGreen,
          colorText: Colors.white,
        );
        refreshData();
      } else {
        Get.snackbar('error'.tr, response?['message'] ?? 'Unknown error occurred');
      }
    } catch (e, stack) {
      debugPrint('[LoanController] Error in applyForLoan: $e');
      debugPrint('Stack: $stack');
      Get.snackbar('error'.tr, 'An error occurred while submitting the loan request');
    } finally {
      isSubmitting.value = false;
    }
  }

  Future<void> repayLoan(String loanId, double amount, String type) async {
    isSubmitting.value = true;
    try {
      final response = await SupabaseService.client.rpc(
        'repay_loan',
        params: {
          'p_loan_id': loanId,
          'p_amount': amount,
          'p_type': type,
        },
      );

      if (response['success'] == true) {
        Get.snackbar(
          'success'.tr, 
          'repayment_success'.tr,
          backgroundColor: AppColors.softGreen,
          colorText: Colors.white,
        );
        refreshData();
      } else {
        Get.snackbar('error'.tr, response?['message'] ?? 'Unknown error occurred');
      }
    } catch (e, stack) {
      debugPrint('[LoanController] Error in repayLoan: $e');
      debugPrint('Stack: $stack');
      Get.snackbar('error'.tr, 'An error occurred during repayment');
    } finally {
      isSubmitting.value = false;
    }
  }
}
