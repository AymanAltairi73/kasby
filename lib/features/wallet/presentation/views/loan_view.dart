import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kasby/core/utils/safe_getx.dart';
import 'package:kasby/core/theme/app_colors.dart';
import 'package:kasby/core/widgets/kasby_button.dart';
import 'package:kasby/core/widgets/kasby_card.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:kasby/core/widgets/kasby_text_field.dart';
import 'package:kasby/core/controllers/currency_controller.dart';
import 'package:kasby/features/wallet/presentation/controllers/loan_controller.dart';
import 'package:kasby/core/models/loan_model.dart';
import 'package:kasby/core/services/snack_service.dart';
import 'package:kasby/core/utils/date_helper.dart';

class LoanView extends StatefulWidget {
  const LoanView({super.key});

  @override
  State<LoanView> createState() => _LoanViewState();
}

class _LoanViewState extends State<LoanView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final currencyController = CurrencyController.to;
  final loanController = Get.put(LoanController());
  bool get isDark => Theme.of(context).brightness == Brightness.dark;

  bool receiveAsPoints = false;
  bool agreedToTerms = false;
  int selectedDuration = 3;
  final TextEditingController _amountController = TextEditingController();

  double get currentLoanAmount =>
      double.tryParse(_amountController.text) ?? 0.0;
  double get totalInterest =>
      currentLoanAmount *
      loanController.serverInterestRate.value *
      selectedDuration;
  double get totalRepayment => currentLoanAmount + totalInterest;

  void _incrementAmount() {
    double current = currentLoanAmount;
    setState(() {
      _amountController.text = (current + 10).toStringAsFixed(0);
    });
  }

  void _decrementAmount() {
    double current = currentLoanAmount;
    if (current > 10) {
      setState(() {
        _amountController.text = (current - 10).toStringAsFixed(0);
      });
    }
  }

  @override
  void initState() {
    super.initState();
    SafeGetx.debugTrace(
      className: 'LoanView',
      method: 'initState',
      feature: 'Wallet',
      status: 'INFO',
    );
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    SafeGetx.debugTrace(
      className: 'LoanView',
      method: 'dispose',
      feature: 'Wallet',
      status: 'INFO',
    );
    _tabController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('salefni_kasby'.tr),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          tooltip: 'back'.tr,
          onPressed: () => Get.safeBack(),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.darkGold,
          labelColor: AppColors.darkGold,
          unselectedLabelColor: isDark ? Colors.white38 : Colors.black38,
          tabs: [
            Tab(text: 'apply_loan'.tr),
            Tab(text: 'loan_history'.tr),
            Tab(text: 'repay_loan'.tr),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildApplyLoanTab(),
          _buildLoanHistoryTab(),
          _buildRepayLoanTab(),
        ],
      ),
    );
  }

  Widget _buildApplyLoanTab() {
    return Obx(() {
      if (loanController.isLoadingActive.value) {
        return Center(
          child: CircularProgressIndicator(color: AppColors.darkGold),
        );
      }
      return SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildEligibilityCard(),
            const SizedBox(height: 32),
            _buildAmountSelector(),
            const SizedBox(height: 32),
            _buildDurationSelector(),
            const SizedBox(height: 32),
            _buildRepaymentBreakdown(),
            const SizedBox(height: 32),
            // _buildTypeToggle(),
            // const SizedBox(height: 32),
            _buildTermsSection(),
            const SizedBox(height: 48),
            _buildSubmitButton(),
          ],
        ),
      );
    });
  }

  Widget _buildLoanHistoryTab() {
    return Obx(() {
      if (loanController.isLoadingHistory.value) {
        return Center(
          child: CircularProgressIndicator(color: AppColors.darkGold),
        );
      }
      return SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'loan_history'.tr,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ).animate().fadeIn().slideX(begin: -0.2),
            const SizedBox(height: 20),
            if (loanController.loanHistory.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Text(
                    'no_loan_history'.tr,
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              )
            else ...[
              _buildHistoryTable(),
              const SizedBox(height: 30),
              _buildTotalSummaryCard(),
            ],
            const SizedBox(height: 40),
          ],
        ),
      );
    });
  }

  Widget _buildHistoryTable() {
    return Container(
          decoration: BoxDecoration(
            color: (isDark ? Colors.white : Colors.black).withValues(
              alpha: 0.03,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: (isDark ? Colors.white : Colors.black).withValues(
                alpha: 0.05,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                blurRadius: 30,
                spreadRadius: -10,
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Table(
            columnWidths: const {
              0: FlexColumnWidth(1.5),
              1: FlexColumnWidth(1.2),
              2: FlexColumnWidth(1.2),
            },
            children: [
              // Header
              TableRow(
                decoration: BoxDecoration(
                  color: (isDark ? Colors.white : Colors.black).withValues(
                    alpha: 0.05,
                  ),
                ),
                children: [
                  _buildTableHeader('loan_date'.tr),
                  _buildTableHeader('loan_amount'.tr),
                  _buildTableHeader('loan_status'.tr),
                ],
              ),
              // Body
              ...loanController.loanHistory.map((loan) {
                return TableRow(
                  children: [
                    _buildTableCell(DateHelper.date(loan.createdAt)),
                    Obx(
                      () => _buildTableCell(
                        currencyController.formatAmount(loan.amount),
                      ),
                    ),
                    _buildStatusCell(loan),
                  ],
                );
              }),
            ],
          ),
        )
        .animate()
        .fadeIn(delay: const Duration(milliseconds: 200))
        .scale(begin: const Offset(0.95, 0.95));
  }

  Widget _buildTableHeader(String label) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Text(
        label,
        style: TextStyle(
          color: isDark
              ? AppColors.textSecondary
              : AppColors.textSecondaryLight,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildTableCell(String content) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Text(
        content,
        style: TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 13,
          color: isDark ? Colors.white : AppColors.textBodyLight,
        ),
      ),
    );
  }

  Widget _buildStatusCell(LoanModel loan) {
    final status = loan.status;
    final isRejected = status == 'rejected';
    final isPaid = status == 'paid';
    final isOverdue = status == 'overdue';
    final color = isPaid
        ? AppColors.softGreen
        : isOverdue
        ? AppColors.error
        : AppColors.darkGold;

    return Padding(
      padding: const EdgeInsets.all(8),
      child: GestureDetector(
        onTap: isRejected && loan.rejectionReason != null
            ? () => _showRejectionReason(loan.rejectionReason!)
            : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'enum_loan_$status'.tr,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (isRejected && loan.rejectionReason != null)
                Icon(Icons.info_outline_rounded, size: 12, color: color),
            ],
          ),
        ),
      ),
    );
  }

  void _showRejectionReason(String reason) {
    Get.dialog(
      AlertDialog(
        backgroundColor: isDark ? AppColors.surface : AppColors.surfaceLight,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.info_outline_rounded, color: AppColors.error),
            const SizedBox(width: 10),
            Text('rejection_reason'.tr),
          ],
        ),
        content: Text(
          reason,
          style: TextStyle(
            color: isDark ? Colors.white70 : AppColors.textBodyLight,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.safeBack(),
            child: Text(
              'close'.tr,
              style: TextStyle(color: AppColors.darkGold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalSummaryCard() {
    return KasbyCard(
      color: AppColors.darkGold.withValues(alpha: 0.1),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.darkGold.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.summarize_rounded, color: AppColors.darkGold),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'total_loans'.tr,
                  style: TextStyle(
                    color: isDark
                        ? AppColors.textSecondary
                        : AppColors.textSecondaryLight,
                    fontSize: 12,
                  ),
                ),
                Obx(
                  () => Text(
                    currencyController.formatAmount(
                      loanController.loanHistory.fold(
                        0.0,
                        (sum, item) => sum + item.amount,
                      ),
                    ),
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : AppColors.textBodyLight,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.2);
  }

  Widget _buildEligibilityCard() {
    return KasbyCard(
      color: AppColors.darkGold.withValues(alpha: 0.08),
      border: Border.all(color: AppColors.darkGold.withValues(alpha: 0.3)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.darkGold.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.account_balance_rounded,
                  color: AppColors.darkGold,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'active_investment_value'.tr,
                      style: TextStyle(
                        color: isDark
                            ? AppColors.textSecondary
                            : AppColors.textSecondaryLight,
                        fontSize: 12,
                      ),
                    ),
                    Obx(
                      () => Text(
                        currencyController.formatAmount(
                          loanController.activeInvestmentValue.value,
                        ),
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? Colors.white
                              : AppColors.textBodyLight,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Obx(() {
                final pct = (loanController.loanMaxPercentage.value * 100)
                    .toStringAsFixed(0);
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.darkGold.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.darkGold),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '$pct%',
                        style: TextStyle(
                          color: AppColors.darkGold,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        'loan_percentage'.tr,
                        style: TextStyle(
                          color: isDark ? Colors.white70 : Colors.black54,
                          fontSize: 9,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Divider(
              color: isDark
                  ? Colors.white10
                  : Colors.black.withValues(alpha: 0.08),
            ),
          ),
          Obx(() {
            final totalCap = loanController.totalLoanCapacity;
            final existingLoans = loanController.existingLoanExposure.value;
            final remaining = loanController.remainingLoanCapacity;

            return Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildMetricColumn(
                      'total_loan_capacity'.tr,
                      currencyController.formatAmount(totalCap),
                      isDark ? Colors.white70 : AppColors.textBodyLight,
                    ),
                    _buildMetricColumn(
                      'existing_loans'.tr,
                      currencyController.formatAmount(existingLoans),
                      existingLoans > 0
                          ? AppColors.error
                          : (isDark ? Colors.white60 : Colors.black54),
                    ),
                    _buildMetricColumn(
                      'remaining_loan_capacity'.tr,
                      currencyController.formatAmount(remaining),
                      AppColors.darkGold,
                      isHighlight: true,
                    ),
                  ],
                ),
                if (remaining <= 0 &&
                    loanController.activeInvestmentValue.value > 0) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.error.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: AppColors.error,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'loan_capacity_exhausted'.tr,
                            style: TextStyle(
                              color: AppColors.error,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            );
          }),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.1);
  }

  Widget _buildMetricColumn(
    String label,
    String value,
    Color valueColor, {
    bool isHighlight = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isDark
                ? AppColors.textSecondary
                : AppColors.textSecondaryLight,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: isHighlight ? 16 : 14,
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  Widget _buildAmountSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        KasbyTextField(
          label: 'loan_amount'.tr,
          hint: 'enter_amount_usd'.tr,
          controller: _amountController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          prefixIcon: Icon(
            Icons.attach_money_rounded,
            color: AppColors.darkGold,
          ),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(
                onPressed: () {
                  final max = loanController.remainingLoanCapacity;
                  if (max > 0) {
                    setState(() {
                      _amountController.text = max.toStringAsFixed(2);
                    });
                  }
                },
                child: Text(
                  'use_max'.tr,
                  style: TextStyle(
                    color: AppColors.darkGold,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.remove_circle_outline_rounded,
                  color: AppColors.textSecondary,
                ),
                tooltip: 'Decrease',
                onPressed: _decrementAmount,
              ),
              IconButton(
                icon: Icon(
                  Icons.add_circle_outline_rounded,
                  color: AppColors.darkGold,
                ),
                tooltip: 'Increase',
                onPressed: _incrementAmount,
              ),
            ],
          ),
        ),
        Obx(() {
          final isExceeded =
              currentLoanAmount > loanController.remainingLoanCapacity;
          if (isExceeded) {
            return Padding(
              padding: const EdgeInsets.only(top: 6, left: 8, right: 8),
              child: Text(
                'amount_exceeds_max_loan'.tr,
                style: TextStyle(
                  color: AppColors.error,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            );
          }
          return const SizedBox.shrink();
        }),
      ],
    );
  }

  Widget _buildDurationSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'loan_duration'.tr,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 80,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: 12,
            itemBuilder: (context, index) {
              final month = index + 1;
              final isSelected = selectedDuration == month;
              return GestureDetector(
                onTap: () => setState(() => selectedDuration = month),
                child: Container(
                  width: 80,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.darkGold
                        : (isDark ? AppColors.surface : AppColors.surfaceLight),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.darkGold
                          : (isDark ? Colors.white10 : Colors.black12),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$month',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: isSelected
                              ? Colors.black
                              : (isDark
                                    ? Colors.white
                                    : AppColors.textBodyLight),
                        ),
                      ),
                      Text(
                        'months'.trParams({'count': month.toString()}),
                        style: TextStyle(
                          fontSize: 10,
                          color: isSelected
                              ? Colors.black54
                              : (isDark ? Colors.white54 : Colors.black54),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    ).animate().fadeIn(delay: 200.ms).slideX(begin: 0.1);
  }

  Widget _buildRepaymentBreakdown() {
    return KasbyCard(
      color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.03),
      border: Border.all(color: AppColors.darkGold.withValues(alpha: 0.2)),
      child: Column(
        children: [
          Obx(
            () => _buildBreakdownRow(
              'loan_amount'.tr,
              currencyController.formatAmount(currentLoanAmount),
            ),
          ),
          const SizedBox(height: 12),
          Obx(
            () => _buildBreakdownRow(
              'loan_interest'.tr,
              currencyController.formatAmount(totalInterest),
              valueColor: AppColors.error,
              subtitle:
                  '${(loanController.serverInterestRate.value * 100).toStringAsFixed(0)}% / ${'months'.trParams({'count': '1'})}',
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Divider(
              color: isDark
                  ? Colors.white10
                  : Colors.black.withValues(alpha: 0.1),
            ),
          ),
          Obx(
            () => _buildBreakdownRow(
              'total_repayment'.tr,
              currencyController.formatAmount(totalRepayment),
              isBold: true,
              valueColor: AppColors.darkGold,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 400.ms).scale();
  }

  Widget _buildBreakdownRow(
    String label,
    String value, {
    bool isBold = false,
    Color? valueColor,
    String? subtitle,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isBold
                    ? (isDark ? Colors.white : AppColors.textBodyLight)
                    : (isDark
                          ? AppColors.textSecondary
                          : AppColors.textSecondaryLight),
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            if (subtitle != null)
              Text(
                subtitle,
                style: TextStyle(
                  color: isDark ? Colors.white38 : Colors.black38,
                  fontSize: 10,
                ),
              ),
          ],
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: isBold ? 18 : 14,
            color:
                valueColor ?? (isDark ? Colors.white : AppColors.textBodyLight),
          ),
        ),
      ],
    );
  }

  // Widget _buildTypeToggle() {
  //   return Column(
  //     crossAxisAlignment: CrossAxisAlignment.start,
  //     children: [
  //       Text(
  //         'loan_type'.tr,
  //         style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
  //       ),
  //       const SizedBox(height: 16),
  //       Row(
  //         children: [
  //           Expanded(
  //             child: _buildTypeItem(
  //               false,
  //               'wallets'.tr,
  //               Icons.account_balance_wallet_rounded,
  //             ),
  //           ),
  //           const SizedBox(width: 16),
  //           Expanded(
  //             child: _buildTypeItem(
  //               true,
  //               'points'.tr,
  //               'assets/images/ksp_coin.png',
  //             ),
  //           ),
  //         ],
  //       ),
  //     ],
  //   );
  // }

  // Widget _buildTypeItem(bool value, String label, dynamic icon) {
  //   final bool isSelected = receiveAsPoints == value;
  //   return GestureDetector(
  //     onTap: () => setState(() => receiveAsPoints = value),
  //     child: Container(
  //       padding: const EdgeInsets.symmetric(vertical: 16),
  //       decoration: BoxDecoration(
  //         color: isSelected
  //             ? AppColors.darkGold
  //             : (isDark ? AppColors.surface : AppColors.surfaceLight),
  //         borderRadius: BorderRadius.circular(16),
  //         border: Border.all(
  //           color: isSelected
  //               ? AppColors.darkGold
  //               : (isDark ? Colors.white10 : Colors.black12),
  //         ),
  //       ),
  //       child: Column(
  //         children: [
  //           icon is String
  //               ? Image.asset(
  //                   icon,
  //                   width: 24,
  //                   height: 24,
  //                   color: isSelected
  //                       ? Colors.black
  //                       : (isDark ? Colors.white54 : Colors.black54),
  //                 )
  //               : Icon(
  //                   icon as IconData,
  //                   color: isSelected
  //                       ? Colors.black
  //                       : (isDark ? Colors.white54 : Colors.black54),
  //                 ),
  //           const SizedBox(height: 8),
  //           Text(
  //             label,
  //             style: TextStyle(
  //               color: isSelected
  //                   ? Colors.black
  //                   : (isDark ? Colors.white54 : Colors.black54),
  //               fontWeight: FontWeight.bold,
  //             ),
  //           ),
  //         ],
  //       ),
  //     ),
  //   );
  // }

  Widget _buildTermsSection() {
    return Row(
      children: [
        Checkbox(
          value: agreedToTerms,
          activeColor: AppColors.darkGold,
          checkColor: Colors.black,
          onChanged: (val) => setState(() => agreedToTerms = val ?? false),
        ),
        Expanded(
          child: GestureDetector(
            onTap: () => setState(() => agreedToTerms = !agreedToTerms),
            child: Text(
              'legal_terms'.tr,
              style: TextStyle(
                color: isDark
                    ? AppColors.textSecondary
                    : AppColors.textSecondaryLight,
                fontSize: 12,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return Obx(() {
      if (loanController.isSubmitting.value) {
        return Center(
          child: CircularProgressIndicator(color: AppColors.darkGold),
        );
      }
      return KasbyButton(
        text: 'salefni_confirm'.tr,
        onPressed: agreedToTerms ? _handleSubmit : null,
      ).animate().fadeIn(delay: 400.ms);
    });
  }

  void _handleSubmit() {
    debugPrint(
      '[LOAN_VIEW] 👆 Loan confirm button tapped | Amount text: "${_amountController.text}", Parsed amount: $currentLoanAmount, Duration: $selectedDuration months, AgreedToTerms: $agreedToTerms',
    );

    if (currentLoanAmount <= 0) {
      debugPrint(
        '[LOAN_VIEW] ⚠️ Validation failed: Amount <= 0 ($currentLoanAmount)',
      );
      AppSnack.error('error'.tr, 'invalid_amount'.tr);
      return;
    }

    if (loanController.remainingLoanCapacity <= 0) {
      debugPrint(
        '[LOAN_VIEW] ⚠️ Validation failed: remaining capacity <= 0',
      );
      AppSnack.error('error'.tr, 'loan_capacity_exhausted'.tr);
      return;
    }

    if (currentLoanAmount > loanController.remainingLoanCapacity) {
      debugPrint(
        '[LOAN_VIEW] ⚠️ Validation failed: currentLoanAmount ($currentLoanAmount) > remainingLoanCapacity (${loanController.remainingLoanCapacity})',
      );
      AppSnack.error('error'.tr, 'amount_exceeds_max_loan'.tr);
      return;
    }

    debugPrint('[LOAN_VIEW] ➡️ Calling loanController.applyForLoan...');
    loanController.applyForLoan(currentLoanAmount, selectedDuration);
  }

  Widget _buildRepayLoanTab() {
    return Obx(() {
      if (loanController.isLoadingActive.value ||
          loanController.isLoadingRepayments.value) {
        return Center(
          child: CircularProgressIndicator(color: AppColors.darkGold),
        );
      }

      return SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'repay_active_loans'.tr,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            if (loanController.activeLoans.isEmpty)
              _buildEmptyState('no_active_loans'.tr)
            else
              ...loanController.activeLoans.map(
                (loan) => _buildActiveLoanCard(loan),
              ),

            const SizedBox(height: 40),
            Text(
              'repayment_history'.tr,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            if (loanController.repaymentHistory.isEmpty)
              _buildEmptyState('no_repayment_history'.tr)
            else
              _buildRepaymentHistoryTable(),
          ],
        ),
      );
    });
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Text(message, style: TextStyle(color: AppColors.textSecondary)),
      ),
    );
  }

  Widget _buildActiveLoanCard(LoanModel loan) {
    return KasbyCard(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'loan_balance'.tr,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    currencyController.formatAmount(loan.effectiveRemaining),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              _buildStatusCell(loan),
            ],
          ),
          const Divider(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildCompactStat(
                'total'.tr,
                currencyController.formatAmount(loan.totalDue ?? loan.amount),
              ),
              _buildCompactStat(
                'paid'.tr,
                currencyController.formatAmount(loan.paidAmount),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: AppColors.error,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'urgent_payment_warning'.tr,
                    style: TextStyle(
                      color: AppColors.error,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: KasbyButton(
                  text: 'full_repayment'.tr,
                  onPressed: () => _confirmRepayment(loan, true),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: KasbyButton(
                  text: 'partial_repayment'.tr,
                  color: AppColors.surface,
                  textColor: AppColors.darkGold,
                  onPressed: () => _confirmRepayment(loan, false),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompactStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: AppColors.textSecondary, fontSize: 10),
        ),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildRepaymentHistoryTable() {
    return Container(
      decoration: BoxDecoration(
        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Table(
        columnWidths: const {
          0: FlexColumnWidth(1.2),
          1: FlexColumnWidth(1.0),
          2: FlexColumnWidth(1.0),
        },
        children: [
          TableRow(
            decoration: BoxDecoration(
              color: (isDark ? Colors.white : Colors.black).withValues(
                alpha: 0.05,
              ),
            ),
            children: [
              _buildTableHeader('date'.tr),
              _buildTableHeader('amount'.tr),
              _buildTableHeader('type'.tr),
            ],
          ),
          ...loanController.repaymentHistory.map((rep) {
            return TableRow(
              children: [
                _buildTableCell(DateHelper.date(rep.createdAt)),
                _buildTableCell(currencyController.formatAmount(rep.amount)),
                _buildTableCell(rep.type == 'full' ? 'full'.tr : 'partial'.tr),
              ],
            );
          }),
        ],
      ),
    );
  }

  void _confirmRepayment(LoanModel loan, bool isFull) {
    if (isFull) {
      Get.dialog(
        AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text(
            'confirm_full_repayment'.tr,
            style: const TextStyle(color: Colors.white),
          ),
          content: Text(
            'full_repayment_desc'.trParams({
              'amount': currencyController.formatAmount(
                loan.effectiveRemaining,
              ),
            }),
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Get.back(),
              child: Text(
                'cancel'.tr,
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.darkGold,
              ),
              onPressed: loanController.isSubmitting.value
                  ? null
                  : () {
                      Get.back();
                      loanController.repayLoan(
                        loan.id,
                        loan.effectiveRemaining,
                        'full',
                      );
                    },
              child: Text(
                'confirm'.tr,
                style: const TextStyle(color: Colors.black),
              ),
            ),
          ],
        ),
        barrierDismissible: false,
      );
    } else {
      final TextEditingController partialAmountController =
          TextEditingController();
      Get.dialog(
        AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text(
            'partial_repayment'.tr,
            style: const TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'enter_repayment_amount'.tr,
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 16),
              KasbyTextField(
                controller: partialAmountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                hint: currencyController.formatAmount(0),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Get.back(),
              child: Text(
                'cancel'.tr,
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.darkGold,
              ),
              onPressed: loanController.isSubmitting.value
                  ? null
                  : () {
                      final amount =
                          double.tryParse(
                            partialAmountController.text.replaceAll(',', ''),
                          ) ??
                          0.0;
                      if (amount <= 0 || amount > loan.effectiveRemaining) {
                        AppSnack.error('error'.tr, 'invalid_amount'.tr);
                        return;
                      }
                      Get.back();
                      loanController.repayLoan(loan.id, amount, 'partial');
                    },
              child: Text(
                'confirm'.tr,
                style: const TextStyle(color: Colors.black),
              ),
            ),
          ],
        ),
        barrierDismissible: false,
      );
    }
  }
}
