import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kasby/core/utils/safe_getx.dart';
import 'package:kasby/core/theme/app_colors.dart';
import 'package:kasby/core/widgets/kasby_button.dart';
import 'package:kasby/core/widgets/kasby_card.dart';
import 'package:kasby/core/services/supabase_service.dart';
import 'package:kasby/core/services/referral_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:uuid/uuid.dart';
import 'package:kasby/routes/app_routes.dart';

class InvestmentDetailsView extends StatefulWidget {
  const InvestmentDetailsView({super.key});

  @override
  State<InvestmentDetailsView> createState() => _InvestmentDetailsViewState();
}

class _InvestmentDetailsViewState extends State<InvestmentDetailsView> {
  final Map<String, dynamic> plan = Get.arguments;
  final TextEditingController amountController = TextEditingController();
  double estimatedProfit = 0.0;
  bool _isSubmitting = false;

  bool get isDark => Theme.of(context).brightness == Brightness.dark;

  @override
  void dispose() {
    amountController.dispose();
    super.dispose();
  }

  void calculateProfit(String val) {
    if (val.isEmpty) {
      setState(() => estimatedProfit = 0.0);
      return;
    }
    double amount = double.tryParse(val) ?? 0.0;
    
    double rawProfit = 0.0;
    if (plan['profit_percentage'] != null) {
      rawProfit = (plan['profit_percentage'] as num).toDouble();
    } else if (plan['profit'] != null) {
      rawProfit = double.tryParse(plan['profit'].toString().replaceAll(RegExp(r'[^\d.]'), '')) ?? 0.0;
    }
    
    double percentage = rawProfit / 100;
    setState(() {
      estimatedProfit = amount * percentage;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(plan['title']),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
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
                                fontSize: 14,
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
                              fontSize: 16,
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
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'estimated_profit'.tr,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '\$${estimatedProfit.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: AppColors.softGreen,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 48),
            _isSubmitting
                ? Center(
                    child: CircularProgressIndicator(color: AppColors.darkGold),
                  )
                : KasbyButton(
                    text: 'invest_now'.tr,
                    onPressed: () => _showConfirmationDialog(),
                  ),
            const SizedBox(height: 24),
            Center(
              child: Text(
                'risk_disclaimer'.tr,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                ),
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
      children: [
        Text(label, style: TextStyle(color: AppColors.textSecondary)),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontWeight: FontWeight.bold,
            fontSize: 16,
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
      Get.snackbar(
        'error'.tr,
        'fill_all_data'.tr,
        backgroundColor: AppColors.error.withValues(alpha: 0.7),
        colorText: Colors.white,
      );
      return;
    }

    Get.dialog(
      AlertDialog(
        backgroundColor: isDark ? AppColors.surface : AppColors.surfaceLight,
        title: Text('confirm_investment'.tr),
        content: Text(
          'invest_confirm_msg'.trParams({
            'amount': '\$${amountController.text}',
            'plan': plan['title'].toString(),
          }),
        ),
        actions: [
          TextButton(onPressed: () => Get.safeBack(), child: Text('cancel'.tr)),
          KasbyButton(
            width: 120,
            text: 'confirm'.tr,
            onPressed: () {
              Get.safeBack();
              _executeInvestment();
            },
          ),
        ],
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
        Get.snackbar(
          'error'.tr,
          'plan_data_incomplete'.tr,
          backgroundColor: AppColors.error.withValues(alpha: 0.7),
          colorText: Colors.white,
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
          final rpcResponse = rpcResult as Map<String, dynamic>;
          return {
            'investmentId': rpcResponse['investment_id']?.toString(),
          };
        },
      );

      final response = result as Map<String, dynamic>;

      if (response['success'] == true) {
        HapticFeedback.heavyImpact();

        // Process referral commission asynchronously
        ReferralService.processReferralCommission(
          investmentAmount: amount,
          investmentId: response['investment_id']?.toString(),
        );

        _showSuccessOverlay(
          amount,
          plan['title'] ?? '',
          response['message'] ?? 'investment_success_desc'.tr,
        );
      } else {
        SafeGetx.debugTrace(
          className: 'InvestmentDetailsView',
          method: '_executeInvestment',
          feature: 'Investment',
          status: 'WARNING',
          message: response['error']?.toString(),
        );
        Get.snackbar(
          'error'.tr,
          response['error'] ?? 'unexpected_error'.tr,
          backgroundColor: AppColors.error.withValues(alpha: 0.7),
          colorText: Colors.white,
        );
      }
    } catch (_) {
      Get.snackbar(
        'error'.tr,
        'error_executing_operation'.tr,
        backgroundColor: AppColors.error.withValues(alpha: 0.7),
        colorText: Colors.white,
      );
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
                  fontSize: 22,
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
                  fontSize: 14,
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
