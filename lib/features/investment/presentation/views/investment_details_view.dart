import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kasby/core/controllers/currency_controller.dart';
import 'package:kasby/core/services/ksp_balance_service.dart';
import 'package:kasby/core/services/crash_reporting/crash_breadcrumb.dart';
import 'package:kasby/core/services/crash_reporting/crash_error_category.dart';
import 'package:kasby/core/services/crash_reporting_service.dart';
import 'package:kasby/core/utils/safe_getx.dart';
import 'package:kasby/core/theme/app_colors.dart';
import 'package:kasby/core/theme/kasby_typography.dart';
import 'package:kasby/core/widgets/kasby_button.dart';
import 'package:kasby/core/widgets/kasby_card.dart';
import 'package:kasby/core/services/supabase_service.dart';
import 'package:kasby/core/services/referral_service.dart';
import 'package:kasby/core/services/snack_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:uuid/uuid.dart';
import 'package:kasby/routes/app_routes.dart';
import 'package:kasby/core/widgets/kasby_shimmer.dart';

class InvestmentDetailsView extends StatefulWidget {
  const InvestmentDetailsView({super.key});

  @override
  State<InvestmentDetailsView> createState() => _InvestmentDetailsViewState();
}

class _InvestmentDetailsViewState extends State<InvestmentDetailsView> {
  final Map<String, dynamic> plan = Get.arguments;
  final TextEditingController amountController = TextEditingController();
  double estimatedProfit = 0.0;
  double estimatedDailyProfit = 0.0;
  bool _isSubmitting = false;

  bool get isDark => Get.isDarkMode;

  @override
  void dispose() {
    amountController.dispose();
    super.dispose();
  }

  void calculateProfit(String val) {
    if (val.isEmpty) {
      setState(() {
        estimatedProfit = 0.0;
        estimatedDailyProfit = 0.0;
      });
      return;
    }
    double amount = double.tryParse(val) ?? 0.0;

    double rawProfit = 0.0;
    if (plan['profit_percentage'] != null) {
      rawProfit = (plan['profit_percentage'] as num).toDouble();
    } else if (plan['profit'] != null) {
      rawProfit =
          double.tryParse(
            plan['profit'].toString().replaceAll(RegExp(r'[^\d.]'), ''),
          ) ??
          0.0;
    }

    // Total expected profit = amount × (percentage / 100)
    double percentage = rawProfit / 100;
    final totalProfit = amount * percentage;

    // Daily profit = totalProfit / duration_days (matches backend formula)
    final durationDays = (plan['duration_days'] as int?) ?? 30;
    final dailyProfit = durationDays > 0 ? totalProfit / durationDays : 0.0;

    setState(() {
      estimatedProfit = totalProfit;
      estimatedDailyProfit = dailyProfit;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(plan['title']),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          tooltip: 'back'.tr,
          onPressed: () => Get.safeBack(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Hero(
              tag: 'plan_${plan['id']}',
              child: Material(
                color: Colors.transparent,
                child: KasbyCard(
                  color: plan['color'].withValues(alpha: 0.05),
                  child: Column(
                    children: [
                      _buildDetailRow(
                        'expected_profit'.tr,
                        plan['profit'],
                        plan['color'],
                      ),
                      Divider(
                        color: isDark
                            ? Colors.white10
                            : Colors.black.withValues(alpha: 0.1),
                        height: 24,
                      ),
                      _buildDetailRow(
                        'min_amount'.tr,
                        plan['minAmount'],
                        isDark ? Colors.white : AppColors.textBodyLight,
                      ),
                      Divider(
                        color: isDark
                            ? Colors.white10
                            : Colors.black.withValues(alpha: 0.1),
                        height: 24,
                      ),
                      _buildDetailRow(
                        'investment_duration'.tr,
                        '30_months_2_5_years'.tr,
                        AppColors.darkGold,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 8),
                  child: Text(
                    'investment_amount'.tr,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.surface : AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.darkGold.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.attach_money_rounded,
                        color: AppColors.darkGold,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: amountController.text.isEmpty
                                ? null
                                : r'$' + amountController.text,
                            hint: Text(
                              'select_amount'.tr,
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: KasbyTypography.sp(ar: 14.0, en: 13.0, context: context),
                              ),
                            ),
                            icon: Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: AppColors.darkGold,
                            ),
                            dropdownColor: isDark
                                ? AppColors.surface
                                : AppColors.surfaceLight,
                            borderRadius: BorderRadius.circular(16),
                            isExpanded: true,
                            style: TextStyle(
                              color: isDark
                                  ? Colors.white
                                  : AppColors.textBodyLight,
                              fontWeight: FontWeight.bold,
                              fontSize: KasbyTypography.sp(ar: 16.0, en: 14.5, context: context),
                            ),
                            onChanged: (String? newValue) {
                              if (newValue != null) {
                                amountController.text = newValue.replaceAll(
                                  r'$',
                                  '',
                                );
                                calculateProfit(amountController.text);
                              }
                            },
                            items:
                                ((plan['amounts'] as List<String>?) != null &&
                                    (plan['amounts'] as List<String>)
                                        .isNotEmpty)
                                ? (plan['amounts'] as List<String>)
                                      .map<DropdownMenuItem<String>>((
                                        String value,
                                      ) {
                                        return DropdownMenuItem<String>(
                                          value: value,
                                          child: Text(value),
                                        );
                                      })
                                      .toList()
                                : _generateDefaultAmounts(
                                    plan['minAmount'],
                                  ).map<DropdownMenuItem<String>>((
                                    String value,
                                  ) {
                                    return DropdownMenuItem<String>(
                                      value: value,
                                      child: Text(value),
                                    );
                                  }).toList(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (estimatedProfit > 0)
              KasbyCard(
                color: AppColors.softGreen.withValues(alpha: 0.1),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            'estimated_profit'.tr,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            '\$${estimatedProfit.toStringAsFixed(2)}',
                            textAlign: TextAlign.end,
                            style: TextStyle(
                              color: AppColors.softGreen,
                              fontWeight: FontWeight.bold,
                              fontSize: KasbyTypography.sectionHeader(context),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Divider(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.06)
                          : Colors.black.withValues(alpha: 0.06),
                      height: 1,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            'daily_profit'.tr,
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: KasbyTypography.bodySecondary(context),
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            '+\$${estimatedDailyProfit.toStringAsFixed(4)}',
                            textAlign: TextAlign.end,
                            style: TextStyle(
                              color: AppColors.softGreen,
                              fontWeight: FontWeight.bold,
                              fontSize: KasbyTypography.body(context),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 48),
            _isSubmitting
                ? const KasbyShimmer(
                    width: double.infinity,
                    height: 52,
                    borderRadius: BorderRadius.all(Radius.circular(16)),
                  )
                : Semantics(
                    button: true,
                    label: 'invest_now'.tr,
                    child: KasbyButton(
                      text: 'invest_now'.tr,
                      onPressed: () => _showConfirmationDialog(),
                    ),
                  ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              color: valueColor,
              fontWeight: FontWeight.bold,
              fontSize: KasbyTypography.sp(ar: 16.0, en: 14.5, context: context),
            ),
          ),
        ),
      ],
    );
  }

  /// Generate default dropdown amounts based on the plan's minimum amount.
  List<String> _generateDefaultAmounts(String? minAmountStr) {
    final cleaned = (minAmountStr ?? '500').replaceAll(RegExp(r'[^\d.]'), '');
    final base = int.tryParse(cleaned) ?? 500;
    return [
      r'$'
          '$base',
      r'$'
          '${base * 2}',
      r'$'
          '${base * 5}',
      r'$'
          '${base * 10}',
    ];
  }

  void _showConfirmationDialog() {
    if (amountController.text.isEmpty) {
      AppSnack.error('error'.tr, 'fill_all_data'.tr);
      return;
    }

    bool termsAccepted = false;
    Get.dialog(
      StatefulBuilder(
        builder: (context, setLocalState) {
          return AlertDialog(
            backgroundColor: isDark
                ? AppColors.surface
                : AppColors.surfaceLight,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            title: Text('confirm_investment'.tr),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'invest_confirm_msg'.trParams({
                    'amount': '\$${amountController.text}',
                    'plan': plan['title'].toString(),
                  }),
                ),
                InkWell(
                  onTap: () =>
                      setLocalState(() => termsAccepted = !termsAccepted),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Checkbox(
                        value: termsAccepted,
                        activeColor: AppColors.darkGold,
                        onChanged: (v) =>
                            setLocalState(() => termsAccepted = v ?? false),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            'accept_plan_terms'.tr,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => SafeGetx.dismissOverlayIfOpen(),
                child: Text('cancel'.tr),
              ),
              KasbyButton(
                width: 120,
                text: 'confirm'.tr,
                onPressed: termsAccepted
                    ? () {
                        SafeGetx.dismissOverlayIfOpen();
                        _executeInvestment();
                      }
                    : null,
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _executeInvestment() async {
    setState(() => _isSubmitting = true);

    try {
      final amount = double.tryParse(amountController.text) ?? 0.0;
      final planId = plan['id'];
      final idempotencyKey = const Uuid().v4();

      if (planId == null) {
        SafeGetx.debugTrace(
          className: 'InvestmentDetailsView',
          method: '_executeInvestment',
          feature: 'Investment',
          status: 'WARNING',
          message: 'Plan ID is null',
        );
        AppSnack.error('error'.tr, 'plan_data_incomplete'.tr);
        return;
      }

      final availableCash = CurrencyController.to.totalBalance.value;
      if (amount > availableCash) {
        AppSnack.error(
          'error'.tr,
          'رصيد الكاش المتاح (\$${availableCash.toStringAsFixed(2)}) غير كافٍ لإكمال الاستثمار بمبلغ (\$${amount.toStringAsFixed(2)})',
        );
        return;
      }

      final result = await SafeGetx.traceAsync(
        className: 'InvestmentDetailsView',
        method: '_executeInvestment',
        feature: 'Investment',
        params: {
          'table': 'investments',
          'operation': 'RPC',
          'rpc': 'create_investment',
          'planId': planId,
          'amount': amount,
        },
        operation: () => SupabaseService.client.rpc(
          'create_investment',
          params: {
            'p_plan_id': planId,
            'p_amount': amount,
            'p_idempotency_key': idempotencyKey,
          },
        ),
        onSuccessParams: (rpcResult) {
          final rpcResponse = rpcResult is Map
              ? Map<String, dynamic>.from(rpcResult)
              : <String, dynamic>{};
          return {'investmentId': rpcResponse['investment_id']?.toString()};
        },
      );

      if (result is! Map) {
        throw Exception(
          'Invalid RPC response format: expected Map, got ${result?.runtimeType}',
        );
      }
      final response = Map<String, dynamic>.from(result);

      if (response['success'] == true) {
        HapticFeedback.heavyImpact();
        unawaited(CrashReportingService.log(CrashBreadcrumb.investmentCreated));

        if (Get.isRegistered<CurrencyController>()) {
          unawaited(CurrencyController.to.fetchWalletBalances());
        }
        if (Get.isRegistered<KspBalanceService>()) {
          unawaited(KspBalanceService.to.afterFinancialMutation(response));
        }

        // Process referral commission asynchronously
        ReferralService.processReferralCommission(
          investmentAmount: amount,
          investmentId: response['investment_id']?.toString(),
          planName: plan['title']?.toString(),
        );

        _showSuccessOverlay(
          amount,
          plan['title'] ?? '',
          response['message'] ?? 'investment_success_desc'.tr,
        );
      } else {
        final errorDetail = response['message'] ?? response['error'] ?? 'unexpected_error'.tr;
        SafeGetx.debugTrace(
          className: 'InvestmentDetailsView',
          method: '_executeInvestment',
          feature: 'Investment',
          status: 'WARNING',
          message: '$errorDetail (code: ${response['error']})',
        );
        unawaited(
          CrashReportingService.recordBusinessError(
            Exception(errorDetail.toString()),
            category: CrashErrorCategory.investments,
            operation: 'create_investment',
            context: {
              CrashCustomKey.investmentPlan: planId,
              'amount_range': CrashReportingService.balanceRange(amount),
              'details': response['details']?.toString() ?? '',
            },
          ),
        );
        AppSnack.error('error'.tr, errorDetail.toString());
      }
    } catch (e, st) {
      SafeGetx.debugTrace(
        className: 'InvestmentDetailsView',
        method: '_executeInvestment',
        feature: 'Investment',
        status: 'ERROR',
        message: 'Exception in _executeInvestment',
        error: e,
        stackTrace: st,
      );
      AppSnack.error('error'.tr, 'error_executing_operation'.tr);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showSuccessOverlay(double amount, String planTitle, String message) {
    Get.dialog(
      Center(
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(36),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surface : AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(32),
            border: Border.all(
              color: AppColors.softGreen.withValues(alpha: 0.2),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.softGreen.withValues(alpha: 0.1),
                blurRadius: 50,
                spreadRadius: 10,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.softGreen.withValues(alpha: 0.1),
                ),
                child: Icon(
                  Icons.auto_awesome_rounded,
                  color: AppColors.softGreen,
                  size: 72,
                ),
              ).animate().scale(duration: 500.ms, curve: Curves.elasticOut),
              const SizedBox(height: 24),
              Text(
                'investment_success'.tr,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isDark ? Colors.white : AppColors.textBodyLight,
                  fontSize: KasbyTypography.cardTitle(context),
                  fontWeight: FontWeight.w900,
                  decoration: TextDecoration.none,
                ),
              ).animate().fadeIn(delay: 200.ms),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: KasbyTypography.body(context),
                  fontWeight: FontWeight.normal,
                  decoration: TextDecoration.none,
                  height: 1.5,
                ),
              ).animate().fadeIn(delay: 300.ms),
              const SizedBox(height: 28),
              KasbyButton(
                text: 'done'.tr,
                onPressed: () {
                  Get.offAllNamed(Routes.home);
                },
              ),
            ],
          ),
        ),
      ),
      barrierDismissible: false,
    );
  }
}
